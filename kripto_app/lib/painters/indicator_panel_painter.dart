import 'dart:math';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/models.dart';

import '../engine/indicator_pipeline.dart';

// ═══════════════════════════════════════════════════════════════
// İNDİKATÖR PANEL PAİNTER — Alt panel osilatör render
// Pipeline tabanlı, cache'li hesaplama
// ═══════════════════════════════════════════════════════════════
class IndicatorPanelPainter extends CustomPainter {
  final IndType type;
  final List<CandleData> candles;
  final double scrollOffset;
  final double candleW;
  final Map<String, dynamic> params;
  final IndicatorPipeline pipeline;

  IndicatorPanelPainter({
    required this.type,
    required this.candles,
    required this.scrollOffset,
    required this.candleW,
    required this.params,
    required this.pipeline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    final gap = candleW * 0.2;
    final bodyW = candleW - gap;
    final visCount = (size.width / candleW).ceil() + 2;
    final si = (scrollOffset / candleW).floor().clamp(0, candles.length - 1);
    final ei = (si + visCount).clamp(0, candles.length);
    double iToX(int i) => (i - si) * candleW - (scrollOffset % candleW) + gap / 2;
    final info = kIndicators[type]!;

    // Grid
    final gP = Paint()..color = const Color(0xFF1A1E25)..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), gP);
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), gP);

    // İndikatör adı etiket
    final labelTp = TextPainter(
      text: TextSpan(text: info.name, style: TextStyle(color: info.color.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    labelTp.paint(canvas, Offset(4, 2));

    final result = pipeline.compute(type, candles, params);

    if (type == IndType.macd) {
      _drawMACD(canvas, size, result, si, ei, iToX, bodyW);
    } else if (type == IndType.stochastic) {
      _drawStochastic(canvas, size, result, si, ei, iToX, bodyW, info);
    } else if (type == IndType.volume) {
      _drawVolume(canvas, size, si, ei, iToX, bodyW);
    } else {
      _drawGenericPanel(canvas, size, result, si, ei, iToX, bodyW, info);
    }
  }

  void _drawMACD(Canvas canvas, Size size, IndicatorResult result, int si, int ei,
      double Function(int) iToX, double bodyW) {
    final m = result.series;
    double minV = double.infinity, maxV = -double.infinity;
    for (int i = si; i < ei; i++) {
      for (final k in ['line', 'signal', 'hist']) {
        final v = i < m[k]!.length ? m[k]![i] : null;
        if (v != null) { minV = min(minV, v); maxV = max(maxV, v); }
      }
    }
    if (minV == maxV) { minV -= 1; maxV += 1; }
    double vToY(double v) => size.height - (v - minV) / (maxV - minV) * size.height;

    // Histogram
    for (int i = si; i < ei; i++) {
      if (i >= m['hist']!.length || m['hist']![i] == null) continue;
      final v = m['hist']![i]!;
      final x = iToX(i);
      final zY = vToY(0);
      final vY = vToY(v);
      canvas.drawRect(
        Rect.fromLTRB(x, min(zY, vY), x + bodyW, max(zY, vY)),
        Paint()..color = (v >= 0 ? kGreen : kRed).withOpacity(0.4),
      );
    }

    _drawPanelLine(canvas, m['line']!, si, ei, size, minV, maxV, iToX, bodyW,
      Paint()..color = kIndicators[IndType.macd]!.color..strokeWidth = 1.5..style = PaintingStyle.stroke);
    _drawPanelLine(canvas, m['signal']!, si, ei, size, minV, maxV, iToX, bodyW,
      Paint()..color = const Color(0xFFFF6E40)..strokeWidth = 1..style = PaintingStyle.stroke);

    // Zero line
    final zeroY = vToY(0);
    if (zeroY > 0 && zeroY < size.height) {
      canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY),
        Paint()..color = Colors.white.withOpacity(0.1)..strokeWidth = 0.5);
    }
  }

  void _drawStochastic(Canvas canvas, Size size, IndicatorResult result, int si, int ei,
      double Function(int) iToX, double bodyW, IndInfo info) {
    _drawPanelLine(canvas, result.series['k']!, si, ei, size, 0, 100, iToX, bodyW,
      Paint()..color = info.color..strokeWidth = 1.5..style = PaintingStyle.stroke);
    _drawPanelLine(canvas, result.series['d']!, si, ei, size, 0, 100, iToX, bodyW,
      Paint()..color = const Color(0xFFFF6E40)..strokeWidth = 1..style = PaintingStyle.stroke);

    // 20/80 lines
    final lP = Paint()..color = Colors.white.withOpacity(0.1)..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, size.height * 0.2), Offset(size.width, size.height * 0.2), lP);
    canvas.drawLine(Offset(0, size.height * 0.8), Offset(size.width, size.height * 0.8), lP);
  }

  void _drawVolume(Canvas canvas, Size size, int si, int ei,
      double Function(int) iToX, double bodyW) {
    double maxV = 0;
    for (int i = si; i < ei; i++) {
      maxV = max(maxV, candles[i].volume);
    }
    if (maxV == 0) return;

    for (int i = si; i < ei; i++) {
      final c = candles[i];
      final x = iToX(i);
      final vh = (c.volume / maxV) * size.height * 0.85;
      final color = c.isBullish ? kGreen : kRed;
      canvas.drawRect(
        Rect.fromLTWH(x, size.height - vh, bodyW, vh),
        Paint()..color = color.withOpacity(0.5),
      );
    }
  }

  void _drawGenericPanel(Canvas canvas, Size size, IndicatorResult result, int si, int ei,
      double Function(int) iToX, double bodyW, IndInfo info) {
    final mainKey = result.series.keys.first;
    final data = result.series[mainKey]!;
    double fixMin = result.minValue;
    double fixMax = result.maxValue;

    if (fixMin == 0 && fixMax == 0) {
      for (int i = si; i < ei; i++) {
        if (i < data.length && data[i] != null) {
          fixMin = min(fixMin, data[i]!);
          fixMax = max(fixMax, data[i]!);
        }
      }
      if (fixMin == fixMax) { fixMin -= 1; fixMax += 1; }
    }

    _drawPanelLine(canvas, data, si, ei, size, fixMin, fixMax, iToX, bodyW,
      Paint()..color = info.color..strokeWidth = 1.5..style = PaintingStyle.stroke);

    // RSI / MFI 30-70 çizgileri
    if (type == IndType.rsi || type == IndType.mfi) {
      final lP = Paint()..color = Colors.white.withOpacity(0.1)..strokeWidth = 0.5;
      final y30 = size.height - (30 - fixMin) / (fixMax - fixMin) * size.height;
      final y70 = size.height - (70 - fixMin) / (fixMax - fixMin) * size.height;
      canvas.drawLine(Offset(0, y30), Offset(size.width, y30), lP);
      canvas.drawLine(Offset(0, y70), Offset(size.width, y70), lP);

      // Değer etiketi (sağda)
      if (si < data.length && ei > 0) {
        final lastVisible = min(ei - 1, data.length - 1);
        if (data[lastVisible] != null) {
          final val = data[lastVisible]!;
          final valY = size.height - (val - fixMin) / (fixMax - fixMin) * size.height;
          final tp = TextPainter(
            text: TextSpan(
              text: val.toStringAsFixed(1),
              style: TextStyle(color: info.color.withOpacity(0.7), fontSize: 9, fontFamily: 'monospace'),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(size.width - tp.width - 4, valY - tp.height / 2));
        }
      }
    }

    // Min/Max labels
    final minTp = TextPainter(
      text: TextSpan(text: fixMin.toStringAsFixed(1), style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    minTp.paint(canvas, Offset(size.width - minTp.width - 4, size.height - minTp.height - 2));

    final maxTp = TextPainter(
      text: TextSpan(text: fixMax.toStringAsFixed(1), style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    maxTp.paint(canvas, Offset(size.width - maxTp.width - 4, 2));
  }

  void _drawPanelLine(Canvas canvas, List<double?> data, int si, int ei, Size size,
      double minV, double maxV, double Function(int) iToX, double bw, Paint p) {
    final path = Path();
    bool started = false;
    for (int i = si; i < ei; i++) {
      if (i >= data.length || data[i] == null) { started = false; continue; }
      final x = iToX(i) + bw / 2;
      final y = size.height - (data[i]! - minV) / (maxV - minV) * size.height;
      if (!started) { path.moveTo(x, y); started = true; } else { path.lineTo(x, y); }
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant IndicatorPanelPainter o) => true;
}
