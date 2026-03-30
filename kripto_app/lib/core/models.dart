

// ═══════════════════════════════════════════════════════════════
// MUM VERİSİ
// ═══════════════════════════════════════════════════════════════
class CandleData {
  final int timestamp;
  final double open, high, low, close, volume;
  const CandleData({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });
  bool get isBullish => close >= open;

  double get hl2 => (high + low) / 2;
  double get hlc3 => (high + low + close) / 3;
  double get ohlc4 => (open + high + low + close) / 4;

  factory CandleData.fromJson(Map<String, dynamic> j) => CandleData(
    timestamp: j['t'] as int,
    open: (j['o'] as num).toDouble(),
    high: (j['h'] as num).toDouble(),
    low: (j['l'] as num).toDouble(),
    close: (j['c'] as num).toDouble(),
    volume: (j['v'] as num).toDouble(),
  );
}

// ═══════════════════════════════════════════════════════════════
// İNDİKATÖR KONFİGÜRASYON MODELİ
// ═══════════════════════════════════════════════════════════════
class IndicatorConfig {
  final String typeKey; // IndType.name
  Map<String, dynamic> params;
  bool enabled;

  IndicatorConfig({required this.typeKey, required this.params, this.enabled = true});

  Map<String, dynamic> toJson() => {'typeKey': typeKey, 'params': params, 'enabled': enabled};

  factory IndicatorConfig.fromJson(Map<String, dynamic> j) => IndicatorConfig(
    typeKey: j['typeKey'] as String,
    params: Map<String, dynamic>.from(j['params'] as Map),
    enabled: j['enabled'] as bool? ?? true,
  );
}

// ═══════════════════════════════════════════════════════════════
// İNDİKATÖR HESAPLAMA SONUCU
// ═══════════════════════════════════════════════════════════════
class IndicatorResult {
  final String typeKey;
  final Map<String, List<double?>> series;
  double minValue;
  double maxValue;

  IndicatorResult({
    required this.typeKey,
    required this.series,
    this.minValue = 0,
    this.maxValue = 0,
  });
}

// ═══════════════════════════════════════════════════════════════
// ÇİZİM MODELLERİ
// ═══════════════════════════════════════════════════════════════
enum DrawingType { trendLine, horizontalRay, fibonacci, brush }

class AnchorPoint {
  final int candleIndex;
  final double price;
  const AnchorPoint(this.candleIndex, this.price);

  Map<String, dynamic> toJson() => {'candleIndex': candleIndex, 'price': price};
  factory AnchorPoint.fromJson(Map<String, dynamic> j) =>
      AnchorPoint(j['candleIndex'] as int, (j['price'] as num).toDouble());
}

class DrawingObject {
  final String id;
  final DrawingType type;
  final List<AnchorPoint> anchors;
  final int colorValue;
  final double strokeWidth;

  DrawingObject({
    required this.id,
    required this.type,
    required this.anchors,
    this.colorValue = 0xFFFF8F00,
    this.strokeWidth = 1.5,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'anchors': anchors.map((a) => a.toJson()).toList(),
    'colorValue': colorValue,
    'strokeWidth': strokeWidth,
  };

  factory DrawingObject.fromJson(Map<String, dynamic> j) => DrawingObject(
    id: j['id'] as String,
    type: DrawingType.values[j['type'] as int],
    anchors: (j['anchors'] as List).map((a) => AnchorPoint.fromJson(a as Map<String, dynamic>)).toList(),
    colorValue: j['colorValue'] as int? ?? 0xFFFF8F00,
    strokeWidth: (j['strokeWidth'] as num?)?.toDouble() ?? 1.5,
  );
}

// ═══════════════════════════════════════════════════════════════
// ALARM MODELLERİ
// ═══════════════════════════════════════════════════════════════
enum AlertSource { price, rsi, macdLine, macdHistogram, ema9, sma25, volume, adx, atr, cci, mfi, momentum }
enum AlertComparator { greaterThan, lessThan, greaterOrEqual, lessOrEqual, crossesAbove, crossesBelow }
enum AlertLogicOperator { and, or }

class AlertCondition {
  final AlertSource source;
  final AlertComparator comparator;
  final double value;

  AlertCondition({required this.source, required this.comparator, required this.value});

  Map<String, dynamic> toJson() => {
    'source': source.index,
    'comparator': comparator.index,
    'value': value,
  };

  factory AlertCondition.fromJson(Map<String, dynamic> j) => AlertCondition(
    source: AlertSource.values[j['source'] as int],
    comparator: AlertComparator.values[j['comparator'] as int],
    value: (j['value'] as num).toDouble(),
  );

  String get sourceLabel {
    switch (source) {
      case AlertSource.price: return 'Fiyat';
      case AlertSource.rsi: return 'RSI';
      case AlertSource.macdLine: return 'MACD Line';
      case AlertSource.macdHistogram: return 'MACD Histogram';
      case AlertSource.ema9: return 'EMA 9';
      case AlertSource.sma25: return 'SMA 25';
      case AlertSource.volume: return 'Hacim';
      case AlertSource.adx: return 'ADX';
      case AlertSource.atr: return 'ATR';
      case AlertSource.cci: return 'CCI';
      case AlertSource.mfi: return 'MFI';
      case AlertSource.momentum: return 'Momentum';
    }
  }

  String get comparatorLabel {
    switch (comparator) {
      case AlertComparator.greaterThan: return '>';
      case AlertComparator.lessThan: return '<';
      case AlertComparator.greaterOrEqual: return '≥';
      case AlertComparator.lessOrEqual: return '≤';
      case AlertComparator.crossesAbove: return '↗ Kesiyor';
      case AlertComparator.crossesBelow: return '↘ Kesiyor';
    }
  }
}

class AlertRule {
  final String id;
  String name;
  final String symbol;
  final List<AlertCondition> conditions;
  final AlertLogicOperator operator;
  bool isActive;
  DateTime? lastTriggered;
  int triggerCount;

  AlertRule({
    required this.id,
    required this.name,
    required this.symbol,
    required this.conditions,
    this.operator = AlertLogicOperator.and,
    this.isActive = true,
    this.lastTriggered,
    this.triggerCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'symbol': symbol,
    'conditions': conditions.map((c) => c.toJson()).toList(),
    'operator': operator.index,
    'isActive': isActive,
    'lastTriggered': lastTriggered?.toIso8601String(),
    'triggerCount': triggerCount,
  };

  factory AlertRule.fromJson(Map<String, dynamic> j) => AlertRule(
    id: j['id'] as String,
    name: j['name'] as String,
    symbol: j['symbol'] as String,
    conditions: (j['conditions'] as List).map((c) => AlertCondition.fromJson(c as Map<String, dynamic>)).toList(),
    operator: AlertLogicOperator.values[j['operator'] as int? ?? 0],
    isActive: j['isActive'] as bool? ?? true,
    lastTriggered: j['lastTriggered'] != null ? DateTime.tryParse(j['lastTriggered'] as String) : null,
    triggerCount: j['triggerCount'] as int? ?? 0,
  );
}
