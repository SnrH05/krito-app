import 'dart:math';
import '../core/models.dart';

// ═══════════════════════════════════════════════════════════════
// TEKNİK İNDİKATÖR MOTORU — 30 İndikatör
// Kaynak veri seçimi destekli (close, hl2, hlc3, ohlc4)
// ═══════════════════════════════════════════════════════════════
class TechEngine {
  /// Kaynak veriyi CandleData listesinden çıkarır
  static List<double> getSource(List<CandleData> candles, String source) {
    switch (source) {
      case 'open': return candles.map((c) => c.open).toList();
      case 'high': return candles.map((c) => c.high).toList();
      case 'low': return candles.map((c) => c.low).toList();
      case 'hl2': return candles.map((c) => c.hl2).toList();
      case 'hlc3': return candles.map((c) => c.hlc3).toList();
      case 'ohlc4': return candles.map((c) => c.ohlc4).toList();
      default: return candles.map((c) => c.close).toList();
    }
  }

  // ── SMA ──
  static List<double?> sma(List<double> src, int p) {
    final r = List<double?>.filled(src.length, null);
    for (int i = p - 1; i < src.length; i++) {
      double sum = 0;
      for (int j = i - p + 1; j <= i; j++) sum += src[j];
      r[i] = sum / p;
    }
    return r;
  }

  // ── EMA ──
  static List<double?> ema(List<double> src, int p) {
    final r = List<double?>.filled(src.length, null);
    final k = 2.0 / (p + 1);
    double? prev;
    for (int i = 0; i < src.length; i++) {
      if (i < p - 1) { r[i] = null; continue; }
      if (prev == null) {
        double s = 0;
        for (int j = i - p + 1; j <= i; j++) s += src[j];
        prev = s / p;
      } else {
        prev = src[i] * k + prev * (1 - k);
      }
      r[i] = prev;
    }
    return r;
  }

  // ── WMA ──
  static List<double?> wma(List<double> src, int p) {
    final r = List<double?>.filled(src.length, null);
    final denom = p * (p + 1) / 2;
    for (int i = p - 1; i < src.length; i++) {
      double s = 0;
      for (int j = 0; j < p; j++) s += src[i - p + 1 + j] * (j + 1);
      r[i] = s / denom;
    }
    return r;
  }

  // ── DEMA ──
  static List<double?> dema(List<double> src, int p) {
    final e1 = ema(src, p);
    final e1c = e1.map((v) => v ?? 0.0).toList();
    final e2 = ema(e1c, p);
    final r = List<double?>.filled(src.length, null);
    for (int i = 0; i < src.length; i++) {
      if (e1[i] != null && e2[i] != null) r[i] = 2 * e1[i]! - e2[i]!;
    }
    return r;
  }

  // ── TEMA ──
  static List<double?> tema(List<double> src, int p) {
    final e1 = ema(src, p);
    final e1c = e1.map((v) => v ?? 0.0).toList();
    final e2 = ema(e1c, p);
    final e2c = e2.map((v) => v ?? 0.0).toList();
    final e3 = ema(e2c, p);
    final r = List<double?>.filled(src.length, null);
    for (int i = 0; i < src.length; i++) {
      if (e1[i] != null && e2[i] != null && e3[i] != null) {
        r[i] = 3 * e1[i]! - 3 * e2[i]! + e3[i]!;
      }
    }
    return r;
  }

  // ── HMA ──
  static List<double?> hma(List<double> src, int p) {
    final half = wma(src, p ~/ 2);
    final full = wma(src, p);
    final diff = List<double>.filled(src.length, 0);
    for (int i = 0; i < src.length; i++) {
      diff[i] = (half[i] ?? 0) * 2 - (full[i] ?? 0);
    }
    return wma(diff, sqrt(p.toDouble()).toInt().clamp(1, p));
  }

  // ── RSI ──
  static List<double?> rsi(List<double> closes, int p) {
    final r = List<double?>.filled(closes.length, null);
    if (closes.length < p + 1) return r;
    double avgG = 0, avgL = 0;
    for (int i = 1; i <= p; i++) {
      final d = closes[i] - closes[i - 1];
      if (d > 0) avgG += d; else avgL -= d;
    }
    avgG /= p;
    avgL /= p;
    r[p] = avgL == 0 ? 100 : 100 - 100 / (1 + avgG / avgL);
    for (int i = p + 1; i < closes.length; i++) {
      final d = closes[i] - closes[i - 1];
      avgG = (avgG * (p - 1) + (d > 0 ? d : 0)) / p;
      avgL = (avgL * (p - 1) + (d < 0 ? -d : 0)) / p;
      r[i] = avgL == 0 ? 100 : 100 - 100 / (1 + avgG / avgL);
    }
    return r;
  }

  // ── MACD ──
  static Map<String, List<double?>> macd(List<double> src, {int fast = 12, int slow = 26, int sig = 9}) {
    final f = ema(src, fast);
    final s = ema(src, slow);
    final line = List<double?>.filled(src.length, null);
    for (int i = 0; i < src.length; i++) {
      if (f[i] != null && s[i] != null) line[i] = f[i]! - s[i]!;
    }
    final lc = line.map((v) => v ?? 0.0).toList();
    final signal = ema(lc, sig);
    final hist = List<double?>.filled(src.length, null);
    for (int i = 0; i < src.length; i++) {
      if (line[i] != null && signal[i] != null) hist[i] = line[i]! - signal[i]!;
    }
    return {'line': line, 'signal': signal, 'hist': hist};
  }

  // ── Bollinger Bands ──
  static Map<String, List<double?>> bollinger(List<double> src, {int p = 20, double m = 2}) {
    final mid = sma(src, p);
    final upper = List<double?>.filled(src.length, null);
    final lower = List<double?>.filled(src.length, null);
    for (int i = p - 1; i < src.length; i++) {
      double s = 0;
      for (int j = i - p + 1; j <= i; j++) s += pow(src[j] - mid[i]!, 2) as double;
      final sd = sqrt(s / p);
      upper[i] = mid[i]! + m * sd;
      lower[i] = mid[i]! - m * sd;
    }
    return {'upper': upper, 'mid': mid, 'lower': lower};
  }

  // ── Stochastic ──
  static Map<String, List<double?>> stochastic(List<CandleData> c, {int kP = 14, int dP = 3}) {
    final kLine = List<double?>.filled(c.length, null);
    for (int i = kP - 1; i < c.length; i++) {
      double hi = -1e18, lo = 1e18;
      for (int j = i - kP + 1; j <= i; j++) {
        hi = max(hi, c[j].high);
        lo = min(lo, c[j].low);
      }
      kLine[i] = hi == lo ? 50 : (c[i].close - lo) / (hi - lo) * 100;
    }
    final dLine = sma(kLine.map((v) => v ?? 0).toList(), dP);
    return {'k': kLine, 'd': dLine};
  }

  // ── ADX ──
  static List<double?> adx(List<CandleData> c, {int p = 14}) {
    final r = List<double?>.filled(c.length, null);
    if (c.length < p * 2) return r;
    final tr = List<double>.filled(c.length, 0);
    final pDM = List<double>.filled(c.length, 0);
    final mDM = List<double>.filled(c.length, 0);
    for (int i = 1; i < c.length; i++) {
      tr[i] = [c[i].high - c[i].low, (c[i].high - c[i - 1].close).abs(), (c[i].low - c[i - 1].close).abs()].reduce(max);
      final up = c[i].high - c[i - 1].high;
      final dn = c[i - 1].low - c[i].low;
      pDM[i] = up > dn && up > 0 ? up : 0;
      mDM[i] = dn > up && dn > 0 ? dn : 0;
    }
    double aTR = 0, aPDM = 0, aMDM = 0;
    for (int i = 1; i <= p; i++) { aTR += tr[i]; aPDM += pDM[i]; aMDM += mDM[i]; }
    double prevADX = 0;
    int adxCount = 0;
    for (int i = p; i < c.length; i++) {
      if (i > p) {
        aTR = aTR - aTR / p + tr[i];
        aPDM = aPDM - aPDM / p + pDM[i];
        aMDM = aMDM - aMDM / p + mDM[i];
      }
      final pDI = aTR == 0 ? 0.0 : aPDM / aTR * 100;
      final mDI = aTR == 0 ? 0.0 : aMDM / aTR * 100;
      final dx = (pDI + mDI) == 0 ? 0.0 : ((pDI - mDI).abs() / (pDI + mDI) * 100);
      if (adxCount < p) {
        prevADX += dx;
        adxCount++;
        if (adxCount == p) prevADX /= p;
      } else {
        prevADX = (prevADX * (p - 1) + dx) / p;
      }
      if (adxCount >= p) r[i] = prevADX;
    }
    return r;
  }

  // ── ATR ──
  static List<double?> atr(List<CandleData> c, {int p = 14}) {
    final r = List<double?>.filled(c.length, null);
    if (c.length < p + 1) return r;
    double sum = 0;
    for (int i = 1; i <= p; i++) {
      sum += [c[i].high - c[i].low, (c[i].high - c[i - 1].close).abs(), (c[i].low - c[i - 1].close).abs()].reduce(max);
    }
    r[p] = sum / p;
    for (int i = p + 1; i < c.length; i++) {
      final tr = [c[i].high - c[i].low, (c[i].high - c[i - 1].close).abs(), (c[i].low - c[i - 1].close).abs()].reduce(max);
      r[i] = (r[i - 1]! * (p - 1) + tr) / p;
    }
    return r;
  }

  // ── CCI ──
  static List<double?> cci(List<CandleData> c, {int p = 20}) {
    final tp = c.map((k) => (k.high + k.low + k.close) / 3).toList();
    final ma = sma(tp, p);
    final r = List<double?>.filled(c.length, null);
    for (int i = p - 1; i < c.length; i++) {
      double md = 0;
      for (int j = i - p + 1; j <= i; j++) md += (tp[j] - ma[i]!).abs();
      md /= p;
      r[i] = md == 0 ? 0 : (tp[i] - ma[i]!) / (0.015 * md);
    }
    return r;
  }

  // ── Williams %R ──
  static List<double?> williamsR(List<CandleData> c, {int p = 14}) {
    final r = List<double?>.filled(c.length, null);
    for (int i = p - 1; i < c.length; i++) {
      double hi = -1e18, lo = 1e18;
      for (int j = i - p + 1; j <= i; j++) {
        hi = max(hi, c[j].high);
        lo = min(lo, c[j].low);
      }
      r[i] = hi == lo ? -50 : (hi - c[i].close) / (hi - lo) * -100;
    }
    return r;
  }

  // ── OBV ──
  static List<double?> obv(List<CandleData> c) {
    final r = List<double?>.filled(c.length, null);
    r[0] = 0;
    for (int i = 1; i < c.length; i++) {
      final prev = r[i - 1] ?? 0.0;
      if (c[i].close > c[i - 1].close) r[i] = prev + c[i].volume;
      else if (c[i].close < c[i - 1].close) r[i] = prev - c[i].volume;
      else r[i] = prev;
    }
    return r;
  }

  // ── MFI ──
  static List<double?> mfi(List<CandleData> c, {int p = 14}) {
    final r = List<double?>.filled(c.length, null);
    if (c.length < p + 1) return r;
    for (int i = p; i < c.length; i++) {
      double posF = 0, negF = 0;
      for (int j = i - p + 1; j <= i; j++) {
        final tp = (c[j].high + c[j].low + c[j].close) / 3;
        final tpP = (c[j - 1].high + c[j - 1].low + c[j - 1].close) / 3;
        final mf = tp * c[j].volume;
        if (tp > tpP) posF += mf; else negF += mf;
      }
      r[i] = negF == 0 ? 100 : 100 - 100 / (1 + posF / negF);
    }
    return r;
  }

  // ── Momentum / ROC ──
  static List<double?> momentum(List<double> src, {int p = 10}) {
    final r = List<double?>.filled(src.length, null);
    for (int i = p; i < src.length; i++) r[i] = src[i] - src[i - p];
    return r;
  }

  static List<double?> roc(List<double> src, {int p = 10}) {
    final r = List<double?>.filled(src.length, null);
    for (int i = p; i < src.length; i++) {
      r[i] = src[i - p] == 0 ? 0 : (src[i] - src[i - p]) / src[i - p] * 100;
    }
    return r;
  }

  // ── VWAP ──
  static List<double?> vwap(List<CandleData> c) {
    final r = List<double?>.filled(c.length, null);
    double cumTPV = 0, cumV = 0;
    for (int i = 0; i < c.length; i++) {
      final tp = (c[i].high + c[i].low + c[i].close) / 3;
      cumTPV += tp * c[i].volume;
      cumV += c[i].volume;
      r[i] = cumV == 0 ? tp : cumTPV / cumV;
    }
    return r;
  }

  // ── Keltner ──
  static Map<String, List<double?>> keltner(List<CandleData> c, {int p = 20, double m = 1.5}) {
    final closes = c.map((k) => k.close).toList();
    final mid = ema(closes, p);
    final a = atr(c, p: p);
    final upper = List<double?>.filled(c.length, null);
    final lower = List<double?>.filled(c.length, null);
    for (int i = 0; i < c.length; i++) {
      if (mid[i] != null && a[i] != null) {
        upper[i] = mid[i]! + m * a[i]!;
        lower[i] = mid[i]! - m * a[i]!;
      }
    }
    return {'upper': upper, 'mid': mid, 'lower': lower};
  }

  // ── Donchian ──
  static Map<String, List<double?>> donchian(List<CandleData> c, {int p = 20}) {
    final upper = List<double?>.filled(c.length, null);
    final lower = List<double?>.filled(c.length, null);
    final mid = List<double?>.filled(c.length, null);
    for (int i = p - 1; i < c.length; i++) {
      double hi = -1e18, lo = 1e18;
      for (int j = i - p + 1; j <= i; j++) {
        hi = max(hi, c[j].high);
        lo = min(lo, c[j].low);
      }
      upper[i] = hi;
      lower[i] = lo;
      mid[i] = (hi + lo) / 2;
    }
    return {'upper': upper, 'mid': mid, 'lower': lower};
  }

  // ── Std Dev ──
  static List<double?> stdDev(List<double> src, {int p = 20}) {
    final ma = sma(src, p);
    final r = List<double?>.filled(src.length, null);
    for (int i = p - 1; i < src.length; i++) {
      double s = 0;
      for (int j = i - p + 1; j <= i; j++) s += pow(src[j] - ma[i]!, 2) as double;
      r[i] = sqrt(s / p);
    }
    return r;
  }

  // ── Chaikin MF ──
  static List<double?> chaikinMF(List<CandleData> c, {int p = 20}) {
    final r = List<double?>.filled(c.length, null);
    for (int i = p - 1; i < c.length; i++) {
      double mv = 0, sv = 0;
      for (int j = i - p + 1; j <= i; j++) {
        final hl = c[j].high - c[j].low;
        final mfm = hl == 0 ? 0.0 : ((c[j].close - c[j].low) - (c[j].high - c[j].close)) / hl;
        mv += mfm * c[j].volume;
        sv += c[j].volume;
      }
      r[i] = sv == 0 ? 0 : mv / sv;
    }
    return r;
  }

  // ── Force Index ──
  static List<double?> forceIndex(List<CandleData> c, {int p = 13}) {
    final fi = List<double>.filled(c.length, 0);
    for (int i = 1; i < c.length; i++) {
      fi[i] = (c[i].close - c[i - 1].close) * c[i].volume;
    }
    return ema(fi, p);
  }

  // ── Parabolic SAR ──
  static List<double?> parabolicSar(List<CandleData> c, {double af0 = 0.02, double afMax = 0.2}) {
    if (c.length < 2) return List<double?>.filled(c.length, null);
    final r = List<double?>.filled(c.length, null);
    bool isUp = c[1].close > c[0].close;
    double sar = isUp ? c[0].low : c[0].high;
    double ep = isUp ? c[1].high : c[1].low;
    double af = af0;
    r[0] = sar;
    r[1] = sar;
    for (int i = 2; i < c.length; i++) {
      sar = sar + af * (ep - sar);
      if (isUp) {
        sar = min(sar, min(c[i - 1].low, c[i - 2].low));
        if (c[i].low < sar) {
          isUp = false; sar = ep; ep = c[i].low; af = af0;
        } else {
          if (c[i].high > ep) { ep = c[i].high; af = min(af + af0, afMax); }
        }
      } else {
        sar = max(sar, max(c[i - 1].high, c[i - 2].high));
        if (c[i].high > sar) {
          isUp = true; sar = ep; ep = c[i].high; af = af0;
        } else {
          if (c[i].low < ep) { ep = c[i].low; af = min(af + af0, afMax); }
        }
      }
      r[i] = sar;
    }
    return r;
  }

  // ── Ichimoku ──
  static Map<String, List<double?>> ichimoku(List<CandleData> c, {int tenkan = 9, int kijun = 26, int senkou = 52}) {
    List<double?> midLine(int p) {
      final r = List<double?>.filled(c.length, null);
      for (int i = p - 1; i < c.length; i++) {
        double hi = -1e18, lo = 1e18;
        for (int j = i - p + 1; j <= i; j++) {
          hi = max(hi, c[j].high);
          lo = min(lo, c[j].low);
        }
        r[i] = (hi + lo) / 2;
      }
      return r;
    }
    return {
      'tenkan': midLine(tenkan),
      'kijun': midLine(kijun),
      'senkouA': midLine(tenkan),
      'senkouB': midLine(senkou),
    };
  }
}
