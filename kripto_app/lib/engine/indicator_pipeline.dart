import '../core/constants.dart';
import '../core/models.dart';
import 'tech_engine.dart';

// ═══════════════════════════════════════════════════════════════
// İNDİKATÖR PIPELINE — Cache + Batch Hesaplama
// Birden fazla indikatörü aynı anda, birbirini ezmeden hesaplar
// ═══════════════════════════════════════════════════════════════
class IndicatorPipeline {
  // Cache anahtarı: indType + params hash + candle count
  final Map<String, IndicatorResult> _cache = {};
  int _lastCandleCount = 0;
  int _lastCandleHash = 0;

  /// Cache'i geçersiz kıl
  void invalidate() {
    _cache.clear();
    _lastCandleCount = 0;
    _lastCandleHash = 0;
  }

  /// Mum verisi değişti mi kontrol et
  bool _isCacheValid(List<CandleData> candles) {
    if (candles.isEmpty) return false;
    final hash = candles.last.timestamp ^ candles.length;
    if (_lastCandleCount != candles.length || _lastCandleHash != hash) {
      _lastCandleCount = candles.length;
      _lastCandleHash = hash;
      _cache.clear();
      return false;
    }
    return true;
  }

  /// Tekil indikatör hesapla (cache'li)
  IndicatorResult compute(IndType type, List<CandleData> candles, Map<String, dynamic> params) {
    _isCacheValid(candles);

    final cacheKey = '${type.name}_${params.hashCode}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final result = _computeRaw(type, candles, params);
    _cache[cacheKey] = result;
    return result;
  }

  /// Birden fazla indikatörü toplu hesapla
  Map<IndType, IndicatorResult> computeAll(
    List<CandleData> candles,
    Map<IndType, Map<String, dynamic>> activeConfigs,
  ) {
    _isCacheValid(candles);
    final results = <IndType, IndicatorResult>{};
    for (final entry in activeConfigs.entries) {
      results[entry.key] = compute(entry.key, candles, entry.value);
    }
    return results;
  }

  /// Ham hesaplama
  IndicatorResult _computeRaw(IndType type, List<CandleData> candles, Map<String, dynamic> params) {
    final source = params['source'] as String? ?? 'close';
    final src = TechEngine.getSource(candles, source);
    final closes = candles.map((c) => c.close).toList();

    switch (type) {
      case IndType.sma7:
        return _wrapSingle(type, TechEngine.sma(src, params['period'] as int? ?? 7));
      case IndType.sma25:
        return _wrapSingle(type, TechEngine.sma(src, params['period'] as int? ?? 25));
      case IndType.sma99:
        return _wrapSingle(type, TechEngine.sma(src, params['period'] as int? ?? 99));
      case IndType.ema7:
        return _wrapSingle(type, TechEngine.ema(src, params['period'] as int? ?? 7));
      case IndType.ema25:
        return _wrapSingle(type, TechEngine.ema(src, params['period'] as int? ?? 25));
      case IndType.ema99:
        return _wrapSingle(type, TechEngine.ema(src, params['period'] as int? ?? 99));
      case IndType.wma:
        return _wrapSingle(type, TechEngine.wma(src, params['period'] as int? ?? 20));
      case IndType.dema:
        return _wrapSingle(type, TechEngine.dema(src, params['period'] as int? ?? 20));
      case IndType.tema:
        return _wrapSingle(type, TechEngine.tema(src, params['period'] as int? ?? 20));
      case IndType.hma:
        return _wrapSingle(type, TechEngine.hma(src, params['period'] as int? ?? 20));
      case IndType.vwap:
        return _wrapSingle(type, TechEngine.vwap(candles));
      case IndType.parabolicSar:
        return _wrapSingle(type, TechEngine.parabolicSar(candles,
          af0: (params['af'] as num?)?.toDouble() ?? 0.02,
          afMax: (params['maxAf'] as num?)?.toDouble() ?? 0.2));

      case IndType.bollinger:
        final b = TechEngine.bollinger(src,
          p: params['period'] as int? ?? 20,
          m: (params['multiplier'] as num?)?.toDouble() ?? 2.0);
        return IndicatorResult(typeKey: type.name, series: b);

      case IndType.keltner:
        final k = TechEngine.keltner(candles,
          p: params['period'] as int? ?? 20,
          m: (params['multiplier'] as num?)?.toDouble() ?? 1.5);
        return IndicatorResult(typeKey: type.name, series: k);

      case IndType.donchian:
        final d = TechEngine.donchian(candles, p: params['period'] as int? ?? 20);
        return IndicatorResult(typeKey: type.name, series: d);

      case IndType.ichimoku:
        final ich = TechEngine.ichimoku(candles,
          tenkan: params['tenkan'] as int? ?? 9,
          kijun: params['kijun'] as int? ?? 26,
          senkou: params['senkou'] as int? ?? 52);
        return IndicatorResult(typeKey: type.name, series: ich);

      case IndType.rsi:
        return _wrapPanel(type, 'rsi', TechEngine.rsi(src, params['period'] as int? ?? 14), 0, 100);
      case IndType.macd:
        final m = TechEngine.macd(src,
          fast: params['fast'] as int? ?? 12,
          slow: params['slow'] as int? ?? 26,
          sig: params['signal'] as int? ?? 9);
        return IndicatorResult(typeKey: type.name, series: m);
      case IndType.stochastic:
        final st = TechEngine.stochastic(candles,
          kP: params['kPeriod'] as int? ?? 14,
          dP: params['dPeriod'] as int? ?? 3);
        return IndicatorResult(typeKey: type.name, series: st, minValue: 0, maxValue: 100);
      case IndType.adx:
        return _wrapPanel(type, 'adx', TechEngine.adx(candles, p: params['period'] as int? ?? 14), 0, 60);
      case IndType.atr:
        return _wrapPanelAuto(type, 'atr', TechEngine.atr(candles, p: params['period'] as int? ?? 14));
      case IndType.cci:
        return _wrapPanel(type, 'cci', TechEngine.cci(candles, p: params['period'] as int? ?? 20), -200, 200);
      case IndType.williamsR:
        return _wrapPanel(type, 'williamsR', TechEngine.williamsR(candles, p: params['period'] as int? ?? 14), -100, 0);
      case IndType.obv:
        return _wrapPanelAuto(type, 'obv', TechEngine.obv(candles));
      case IndType.mfi:
        return _wrapPanel(type, 'mfi', TechEngine.mfi(candles, p: params['period'] as int? ?? 14), 0, 100);
      case IndType.momentum:
        return _wrapPanelAuto(type, 'momentum', TechEngine.momentum(src, p: params['period'] as int? ?? 10));
      case IndType.roc:
        return _wrapPanel(type, 'roc', TechEngine.roc(src, p: params['period'] as int? ?? 10), -10, 10);
      case IndType.stdDev:
        return _wrapPanelAuto(type, 'stdDev', TechEngine.stdDev(src, p: params['period'] as int? ?? 20));
      case IndType.chaikinMF:
        return _wrapPanel(type, 'chaikinMF', TechEngine.chaikinMF(candles, p: params['period'] as int? ?? 20), -0.5, 0.5);
      case IndType.forceIndex:
        return _wrapPanelAuto(type, 'forceIndex', TechEngine.forceIndex(candles, p: params['period'] as int? ?? 13));
      case IndType.volume:
        final vols = candles.map((c) => c.volume as double?).toList();
        return _wrapPanelAuto(type, 'volume', vols);
    }
  }

  IndicatorResult _wrapSingle(IndType type, List<double?> data) {
    return IndicatorResult(typeKey: type.name, series: {'line': data});
  }

  IndicatorResult _wrapPanel(IndType type, String key, List<double?> data, double fixMin, double fixMax) {
    return IndicatorResult(typeKey: type.name, series: {key: data}, minValue: fixMin, maxValue: fixMax);
  }

  IndicatorResult _wrapPanelAuto(IndType type, String key, List<double?> data) {
    double mn = double.infinity, mx = -double.infinity;
    for (final v in data) {
      if (v != null) {
        if (v < mn) mn = v;
        if (v > mx) mx = v;
      }
    }
    if (mn == double.infinity) { mn = 0; mx = 1; }
    if (mn == mx) { mn -= 1; mx += 1; }
    return IndicatorResult(typeKey: type.name, series: {key: data}, minValue: mn, maxValue: mx);
  }
}
