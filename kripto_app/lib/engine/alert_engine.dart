import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models.dart';
import '../engine/tech_engine.dart';

// ═══════════════════════════════════════════════════════════════
// ALARM MOTORU — Client-Side, Timer-Based Background Processing
// Ana thread'i yormamak için minimal hesaplama döngüsü
// ═══════════════════════════════════════════════════════════════
class AlertEngine {
  static const _storageKey = 'alert_rules';
  static final AlertEngine _instance = AlertEngine._internal();
  factory AlertEngine() => _instance;
  AlertEngine._internal();

  final List<AlertRule> _rules = [];
  Timer? _checkTimer;
  final _alertStream = StreamController<AlertNotification>.broadcast();

  Stream<AlertNotification> get alertStream => _alertStream.stream;
  List<AlertRule> get rules => List.unmodifiable(_rules);

  /// Başlat
  Future<void> init() async {
    await _loadRules();
    _startChecking();
  }

  /// Yeni alarm ekle
  Future<void> addRule(AlertRule rule) async {
    _rules.add(rule);
    await _saveRules();
  }

  /// Alarm güncelle
  Future<void> updateRule(AlertRule rule) async {
    final idx = _rules.indexWhere((r) => r.id == rule.id);
    if (idx >= 0) {
      _rules[idx] = rule;
      await _saveRules();
    }
  }

  /// Alarm sil
  Future<void> removeRule(String id) async {
    _rules.removeWhere((r) => r.id == id);
    await _saveRules();
  }

  /// Alarmı aktif/pasif yap
  Future<void> toggleRule(String id) async {
    final idx = _rules.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      _rules[idx].isActive = !_rules[idx].isActive;
      await _saveRules();
    }
  }

  /// Manuel kontrol — Candle verisi ile
  void checkRules(String symbol, List<CandleData> candles) {
    if (candles.isEmpty) return;
    final activeRules = _rules.where((r) => r.isActive && r.symbol == symbol).toList();
    if (activeRules.isEmpty) return;

    // İndikatör değerlerini hesapla (son mum için)
    final values = _computeCurrentValues(candles);

    for (final rule in activeRules) {
      final triggered = _evaluateRule(rule, values);
      if (triggered) {
        // Cooldown: Aynı alarm 60 saniyede bir kez tetiklenir
        if (rule.lastTriggered != null &&
            DateTime.now().difference(rule.lastTriggered!).inSeconds < 60) {
          continue;
        }
        rule.lastTriggered = DateTime.now();
        rule.triggerCount++;
        _alertStream.add(AlertNotification(
          rule: rule,
          timestamp: DateTime.now(),
          message: _buildMessage(rule, values),
        ));
        _saveRules();
      }
    }
  }

  Map<AlertSource, double> _computeCurrentValues(List<CandleData> candles) {
    final closes = candles.map((c) => c.close).toList();
    final lastIdx = candles.length - 1;
    final values = <AlertSource, double>{};

    values[AlertSource.price] = candles[lastIdx].close;
    values[AlertSource.volume] = candles[lastIdx].volume;

    // RSI
    final rsiData = TechEngine.rsi(closes, 14);
    if (lastIdx < rsiData.length && rsiData[lastIdx] != null) {
      values[AlertSource.rsi] = rsiData[lastIdx]!;
    }

    // MACD
    final macdData = TechEngine.macd(closes);
    if (lastIdx < macdData['line']!.length && macdData['line']![lastIdx] != null) {
      values[AlertSource.macdLine] = macdData['line']![lastIdx]!;
    }
    if (lastIdx < macdData['hist']!.length && macdData['hist']![lastIdx] != null) {
      values[AlertSource.macdHistogram] = macdData['hist']![lastIdx]!;
    }

    // EMA 9
    final ema9Data = TechEngine.ema(closes, 9);
    if (lastIdx < ema9Data.length && ema9Data[lastIdx] != null) {
      values[AlertSource.ema9] = ema9Data[lastIdx]!;
    }

    // SMA 25
    final sma25Data = TechEngine.sma(closes, 25);
    if (lastIdx < sma25Data.length && sma25Data[lastIdx] != null) {
      values[AlertSource.sma25] = sma25Data[lastIdx]!;
    }

    // ADX
    final adxData = TechEngine.adx(candles);
    if (lastIdx < adxData.length && adxData[lastIdx] != null) {
      values[AlertSource.adx] = adxData[lastIdx]!;
    }

    // ATR
    final atrData = TechEngine.atr(candles);
    if (lastIdx < atrData.length && atrData[lastIdx] != null) {
      values[AlertSource.atr] = atrData[lastIdx]!;
    }

    // CCI
    final cciData = TechEngine.cci(candles);
    if (lastIdx < cciData.length && cciData[lastIdx] != null) {
      values[AlertSource.cci] = cciData[lastIdx]!;
    }

    // MFI
    final mfiData = TechEngine.mfi(candles);
    if (lastIdx < mfiData.length && mfiData[lastIdx] != null) {
      values[AlertSource.mfi] = mfiData[lastIdx]!;
    }

    // Momentum
    final momData = TechEngine.momentum(closes);
    if (lastIdx < momData.length && momData[lastIdx] != null) {
      values[AlertSource.momentum] = momData[lastIdx]!;
    }

    return values;
  }

  bool _evaluateRule(AlertRule rule, Map<AlertSource, double> values) {
    if (rule.conditions.isEmpty) return false;

    final results = rule.conditions.map((cond) {
      final currentValue = values[cond.source];
      if (currentValue == null) return false;

      switch (cond.comparator) {
        case AlertComparator.greaterThan: return currentValue > cond.value;
        case AlertComparator.lessThan: return currentValue < cond.value;
        case AlertComparator.greaterOrEqual: return currentValue >= cond.value;
        case AlertComparator.lessOrEqual: return currentValue <= cond.value;
        case AlertComparator.crossesAbove: return currentValue > cond.value; // Simplified
        case AlertComparator.crossesBelow: return currentValue < cond.value; // Simplified
      }
    }).toList();

    if (rule.operator == AlertLogicOperator.and) {
      return results.every((r) => r);
    } else {
      return results.any((r) => r);
    }
  }

  String _buildMessage(AlertRule rule, Map<AlertSource, double> values) {
    final parts = rule.conditions.map((c) {
      final current = values[c.source]?.toStringAsFixed(2) ?? '?';
      return '${c.sourceLabel} ($current) ${c.comparatorLabel} ${c.value.toStringAsFixed(2)}';
    }).join(rule.operator == AlertLogicOperator.and ? ' VE ' : ' VEYA ');
    return '${rule.name}: $parts';
  }

  void _startChecking() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      // Alarm kontrolü coin_detail_screen'den checkRules() ile tetiklenir
    });
  }

  Future<void> _loadRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null) {
        final list = json.decode(data) as List;
        _rules.clear();
        _rules.addAll(list.map((j) => AlertRule.fromJson(j as Map<String, dynamic>)));
      }
    } catch (_) {}
  }

  Future<void> _saveRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = json.encode(_rules.map((r) => r.toJson()).toList());
      await prefs.setString(_storageKey, data);
    } catch (_) {}
  }

  void dispose() {
    _checkTimer?.cancel();
    _alertStream.close();
  }
}

class AlertNotification {
  final AlertRule rule;
  final DateTime timestamp;
  final String message;

  AlertNotification({required this.rule, required this.timestamp, required this.message});
}
