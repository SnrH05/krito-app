import 'dart:math';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/models.dart';

import '../engine/indicator_pipeline.dart';

// ═══════════════════════════════════════════════════════════════
// CANDLESTICK PAINTER — Yüksek Performanslı Custom Painter
// X ekseni timestamps dahil
// ═══════════════════════════════════════════════════════════════
class CandlestickPainter extends CustomPainter {
  final List<CandleData> candles;
  final double scrollOffset;
  final double candleW;
  final int? crosshairIdx;
  final Set<IndType> activeOverlays;
  final Map<IndType, Map<String, dynamic>> overlayParams;
  final IndicatorPipeline pipeline;
  final String interval;

  CandlestickPainter({
    required this.candles,
    required this.scrollOffset,
    required this.candleW,
    this.crosshairIdx,
    required this.activeOverlays,
    required this.overlayParams,
    required this.pipeline,
    this.interval = '1h',
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final xAxisH = 28.0; // X ekseni yüksekliği
    final chartH = (size.height - xAxisH) * 0.78;
    final volH = (size.height - xAxisH) * 0.18;
    final volTop = chartH + (size.height - xAxisH) * 0.04;
    final gap = candleW * 0.2;
    final bodyW = candleW - gap;
    final visCount = (size.width / candleW).ceil() + 2;
    final startIdx = (scrollOffset / candleW).floor().clamp(0, candles.length - 1);
    final endIdx = (startIdx + visCount).clamp(0, candles.length);
    if (startIdx >= endIdx) return;

    // Fiyat aralığı
    double minP = double.infinity, maxP = -double.infinity, maxV = 0;
    for (int i = startIdx; i < endIdx; i++) {
      minP = min(minP, candles[i].low);
      maxP = max(maxP, candles[i].high);
      maxV = max(maxV, candles[i].volume);
    }
    final pad = (maxP - minP) * 0.08;
    minP -= pad;
    maxP += pad;
    if (maxP == minP) maxP = minP + 1;

    double priceToY(double p) => chartH - (p - minP) / (maxP - minP) * chartH;
    double idxToX(int i) => (i - startIdx) * candleW - (scrollOffset % candleW) + gap / 2;

    // Grid
    final gridP = Paint()..color = const Color(0xFF1A1E25)..strokeWidth = 0.5;
    for (int i = 0; i < 5; i++) {
      final y = chartH * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridP);
    }

    // Fiyat etiketleri (Y ekseni)
    final textStyle = TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontFamily: 'monospace');
    for (int i = 0; i < 5; i++) {
      final p = maxP - (maxP - minP) * i / 4;
      final tp = TextPainter(
        text: TextSpan(text: _fmtP(p), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 4, chartH * i / 4 - tp.height / 2));
    }

    // Mumlar
    final bullP = Paint()..color = kGreen;
    final bearP = Paint()..color = kRed;
    final bullWick = Paint()..color = kGreen..strokeWidth = 1.2;
    final bearWick = Paint()..color = kRed..strokeWidth = 1.2;

    for (int i = startIdx; i < endIdx; i++) {
      final c = candles[i];
      final x = idxToX(i);
      final isBull = c.isBullish;
      final paint = isBull ? bullP : bearP;
      final wick = isBull ? bullWick : bearWick;
      final cx = x + bodyW / 2;

      // Fitil
      canvas.drawLine(Offset(cx, priceToY(c.high)), Offset(cx, priceToY(c.low)), wick);

      // Gövde
      final oY = priceToY(c.open);
      final cY = priceToY(c.close);
      final top = min(oY, cY);
      final h = max((oY - cY).abs(), 1.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, top, bodyW, h), const Radius.circular(1)),
        paint,
      );

      // Hacim
      if (maxV > 0) {
        final vh = (c.volume / maxV) * volH;
        final vP = Paint()..color = (isBull ? kGreen : kRed).withOpacity(0.25);
        canvas.drawRect(Rect.fromLTWH(x, volTop + volH - vh, bodyW, vh), vP);
      }
    }

    // X Ekseni — Dinamik Timestamps
    _drawXAxis(canvas, size, startIdx, endIdx, idxToX, bodyW, xAxisH, chartH + volH + (size.height - xAxisH) * 0.04);

    // Overlay İndikatörler
    for (final ind in activeOverlays) {
      final info = kIndicators[ind]!;
      if (info.cat != IndCat.overlay) continue;
      final params = overlayParams[ind] ?? info.defaultParams;
      _drawOverlay(canvas, size, ind, candles, startIdx, endIdx, minP, maxP, chartH, idxToX, priceToY, bodyW, params);
    }

    // Crosshair
    if (crosshairIdx != null && crosshairIdx! >= startIdx && crosshairIdx! < endIdx) {
      _drawCrosshair(canvas, size, crosshairIdx!, startIdx, endIdx, bodyW, chartH, priceToY, idxToX);
    }
  }

  void _drawXAxis(Canvas canvas, Size size, int si, int ei, double Function(int) iToX, double bodyW, double xAxisH, double yPos) {
    // X ekseni çizgisi
    final linePaint = Paint()..color = const Color(0xFF1A1E25)..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, yPos), Offset(size.width, yPos), linePaint);

    // Etiket aralığı — zoom seviyesine göre adapte
    final labelInterval = _getLabelInterval();
    final textStyle = TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 9, fontFamily: 'monospace');

    for (int i = si; i < ei; i++) {
      if (i % labelInterval != 0) continue;
      final x = iToX(i) + bodyW / 2;
      if (x < 0 || x > size.width - 40) continue;

      final label = _formatTimestamp(candles[i].timestamp);
      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      // Tick çizgisi
      canvas.drawLine(Offset(x, yPos), Offset(x, yPos + 4), linePaint);
      tp.paint(canvas, Offset(x - tp.width / 2, yPos + 6));
    }
  }

  int _getLabelInterval() {
    if (candleW >= 30) return 2;
    if (candleW >= 20) return 3;
    if (candleW >= 12) return 5;
    if (candleW >= 8) return 8;
    if (candleW >= 5) return 15;
    return 25;
  }

  String _formatTimestamp(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    switch (interval) {
      case '1s':
      case '10s':
        return '${_pad(dt.hour)}:${_pad(dt.minute)}:${_pad(dt.second)}';
      case '1m':
      case '5m':
      case '1h':
        return '${_pad(dt.hour)}:${_pad(dt.minute)}';
      case '1d':
        return '${dt.day} ${_monthShort(dt.month)}';
      case '1w':
        return '${dt.day} ${_monthShort(dt.month)} ${dt.year.toString().substring(2)}';
      default:
        return '${_pad(dt.hour)}:${_pad(dt.minute)}';
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
  String _monthShort(int m) => const ['','Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'][m];

  void _drawOverlay(Canvas canvas, Size size, IndType type, List<CandleData> c, int si, int ei,
      double minP, double maxP, double chartH, double Function(int) idxToX, double Function(double) priceToY, double bodyW, Map<String, dynamic> params) {
    final info = kIndicators[type]!;
    final paint = Paint()..color = info.color..strokeWidth = 1.5..style = PaintingStyle.stroke;

    final result = pipeline.compute(type, c, params);
    final series = result.series;

    if (type == IndType.ichimoku) {
      if (series['tenkan'] != null) {
        _drawLine(canvas, series['tenkan']!, si, ei, priceToY, idxToX, bodyW,
          Paint()..color = const Color(0xFF2196F3)..strokeWidth = 1..style = PaintingStyle.stroke);
      }
      if (series['kijun'] != null) {
        _drawLine(canvas, series['kijun']!, si, ei, priceToY, idxToX, bodyW,
          Paint()..color = const Color(0xFFFF5722)..strokeWidth = 1..style = PaintingStyle.stroke);
      }
      return;
    }

    // Band indicators (3 lines)
    if (series.containsKey('upper') && series.containsKey('mid') && series.containsKey('lower')) {
      _drawLine(canvas, series['upper']!, si, ei, priceToY, idxToX, bodyW, paint);
      _drawLine(canvas, series['mid']!, si, ei, priceToY, idxToX, bodyW,
        Paint()..color = info.color.withOpacity(0.5)..strokeWidth = 1..style = PaintingStyle.stroke);
      _drawLine(canvas, series['lower']!, si, ei, priceToY, idxToX, bodyW, paint);
      return;
    }

    // Single line
    if (series.containsKey('line')) {
      _drawLine(canvas, series['line']!, si, ei, priceToY, idxToX, bodyW, paint);
    }
  }

  void _drawLine(Canvas canvas, List<double?> data, int si, int ei,
      double Function(double) pToY, double Function(int) iToX, double bw, Paint p) {
    final path = Path();
    bool started = false;
    for (int i = si; i < ei; i++) {
      if (i >= data.length || data[i] == null) { started = false; continue; }
      final x = iToX(i) + bw / 2;
      final y = pToY(data[i]!);
      if (!started) { path.moveTo(x, y); started = true; } else { path.lineTo(x, y); }
    }
    canvas.drawPath(path, p);
  }

  void _drawCrosshair(Canvas canvas, Size size, int ci, int si, int ei, double bodyW,
      double chartH, double Function(double) priceToY, double Function(int) idxToX) {
    final c = candles[ci];
    final x = idxToX(ci) + bodyW / 2;
    final chP = Paint()..color = Colors.white.withOpacity(0.3)..strokeWidth = 0.5;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), chP);
    final y = priceToY(c.close);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), chP);

    // Fiyat etiketi (sağda)
    final priceLabel = _fmtP(c.close);
    final priceTp = TextPainter(
      text: TextSpan(text: priceLabel, style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace')),
      textDirection: TextDirection.ltr,
    )..layout();
    final priceBg = Paint()..color = kAccentBlue.withOpacity(0.9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width - priceTp.width - 12, y - 10, priceTp.width + 8, 20), const Radius.circular(4)),
      priceBg,
    );
    priceTp.paint(canvas, Offset(size.width - priceTp.width - 8, y - priceTp.height / 2));

    // OHLCV tooltip
    final dt = DateTime.fromMillisecondsSinceEpoch(c.timestamp);
    final lines = [
      '${_pad(dt.day)}/${_pad(dt.month)} ${_pad(dt.hour)}:${_pad(dt.minute)}',
      'O: ${_fmtP(c.open)}',
      'H: ${_fmtP(c.high)}',
      'L: ${_fmtP(c.low)}',
      'C: ${_fmtP(c.close)}',
      'V: ${_fmtVol(c.volume)}',
    ];
    final bgP = Paint()..color = const Color(0xEE111419);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(8, 8, 145, 115), const Radius.circular(10)), bgP);
    // Border glow
    final borderP = Paint()..color = kAccentBlue.withOpacity(0.3)..strokeWidth = 1..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(8, 8, 145, 115), const Radius.circular(10)), borderP);

    for (int li = 0; li < lines.length; li++) {
      final isFirst = li == 0;
      final tp = TextPainter(
        text: TextSpan(
          text: lines[li],
          style: TextStyle(
            color: isFirst ? kAccentOrange : Colors.white.withOpacity(0.85),
            fontSize: isFirst ? 10 : 11,
            fontFamily: 'monospace',
            fontWeight: isFirst ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(16, 14.0 + li * 17));
    }
  }

  String _fmtP(double p) => p >= 1000 ? p.toStringAsFixed(2) : p >= 1 ? p.toStringAsFixed(4) : p.toStringAsFixed(8);
  String _fmtVol(double v) => v >= 1e9 ? '${(v / 1e9).toStringAsFixed(2)}B' : v >= 1e6 ? '${(v / 1e6).toStringAsFixed(2)}M' : v >= 1e3 ? '${(v / 1e3).toStringAsFixed(1)}K' : v.toStringAsFixed(0);

  @override
  bool shouldRepaint(covariant CandlestickPainter o) => true;
}
