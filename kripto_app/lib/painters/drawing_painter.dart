import 'dart:math';

import 'package:flutter/material.dart';

import '../core/models.dart';

// ═══════════════════════════════════════════════════════════════
// DRAWING PAINTER — Interaktif Çizim Katmanı
// Trend Line, Horizontal Ray, Fibonacci, Freehand Brush
// Çizimler fiyat/indeks bazlı sabitlenir → zoom/pan kayması yok
// ═══════════════════════════════════════════════════════════════
class DrawingPainter extends CustomPainter {
  final List<DrawingObject> drawings;
  final List<CandleData> candles;
  final double scrollOffset;
  final double candleW;
  final DrawingObject? activeDrawing; // Aktif çizim (devam eden)
  final Offset? cursorPos; // Fare pozisyonu (aktif çizim için)

  DrawingPainter({
    required this.drawings,
    required this.candles,
    required this.scrollOffset,
    required this.candleW,
    this.activeDrawing,
    this.cursorPos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final xAxisH = 28.0;
    final chartH = (size.height - xAxisH) * 0.78;
    final gap = candleW * 0.2;
    final bodyW = candleW - gap;
    final visCount = (size.width / candleW).ceil() + 2;
    final startIdx = (scrollOffset / candleW).floor().clamp(0, candles.length - 1);
    final endIdx = (startIdx + visCount).clamp(0, candles.length);

    // Fiyat aralığı (mum painter ile senkronize)
    double minP = double.infinity, maxP = -double.infinity;
    for (int i = startIdx; i < endIdx; i++) {
      minP = min(minP, candles[i].low);
      maxP = max(maxP, candles[i].high);
    }
    final pad = (maxP - minP) * 0.08;
    minP -= pad; maxP += pad;
    if (maxP == minP) maxP = minP + 1;

    double priceToY(double p) => chartH - (p - minP) / (maxP - minP) * chartH;
    double idxToX(int i) => (i - startIdx) * candleW - (scrollOffset % candleW) + gap / 2 + bodyW / 2;

    // Mevcut çizimleri render et
    for (final d in drawings) {
      _renderDrawing(canvas, size, d, priceToY, idxToX, chartH);
    }

    // Aktif çizimi render et
    if (activeDrawing != null) {
      _renderDrawing(canvas, size, activeDrawing!, priceToY, idxToX, chartH, isActive: true);
    }
  }

  void _renderDrawing(Canvas canvas, Size size, DrawingObject drawing,
      double Function(double) priceToY, double Function(int) idxToX, double chartH, {bool isActive = false}) {
    final color = Color(drawing.colorValue);
    final paint = Paint()
      ..color = isActive ? color.withOpacity(0.7) : color
      ..strokeWidth = drawing.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    switch (drawing.type) {
      case DrawingType.trendLine:
        _drawTrendLine(canvas, size, drawing, paint, priceToY, idxToX);
        break;
      case DrawingType.horizontalRay:
        _drawHorizontalRay(canvas, size, drawing, paint, priceToY, idxToX);
        break;
      case DrawingType.fibonacci:
        _drawFibonacci(canvas, size, drawing, paint, priceToY, idxToX, chartH);
        break;
      case DrawingType.brush:
        _drawBrush(canvas, drawing, paint, priceToY, idxToX);
        break;
    }

    // Anchor noktaları göster
    if (isActive || drawing.anchors.length <= 2) {
      final dotPaint = Paint()..color = color..style = PaintingStyle.fill;
      for (final anchor in drawing.anchors) {
        final x = idxToX(anchor.candleIndex);
        final y = priceToY(anchor.price);
        canvas.drawCircle(Offset(x, y), 4, dotPaint);
        canvas.drawCircle(Offset(x, y), 4, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
      }
    }
  }

  void _drawTrendLine(Canvas canvas, Size size, DrawingObject drawing, Paint paint,
      double Function(double) priceToY, double Function(int) idxToX) {
    if (drawing.anchors.length < 2) return;
    final p1 = Offset(idxToX(drawing.anchors[0].candleIndex), priceToY(drawing.anchors[0].price));
    final p2 = Offset(idxToX(drawing.anchors[1].candleIndex), priceToY(drawing.anchors[1].price));

    // Sonsuz uzatma (ekran sınırlarına kadar)
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    if (dx.abs() < 0.001) {
      canvas.drawLine(Offset(p1.dx, 0), Offset(p1.dx, size.height), paint);
    } else {
      final slope = dy / dx;
      final startX = -size.width;
      final endX = size.width * 2;
      final startY = p1.dy + slope * (startX - p1.dx);
      final endY = p1.dy + slope * (endX - p1.dx);
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }

    // Ana çizgi vurgusu
    canvas.drawLine(p1, p2, Paint()..color = paint.color..strokeWidth = paint.strokeWidth + 0.5..style = PaintingStyle.stroke);
  }

  void _drawHorizontalRay(Canvas canvas, Size size, DrawingObject drawing, Paint paint,
      double Function(double) priceToY, double Function(int) idxToX) {
    if (drawing.anchors.isEmpty) return;
    final y = priceToY(drawing.anchors[0].price);
    final x = idxToX(drawing.anchors[0].candleIndex);

    // Sol ve sağa sonsuz uzat
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);

    // Fiyat etiketi
    final label = _fmtP(drawing.anchors[0].price);
    final tp = TextPainter(
      text: TextSpan(text: label, style: TextStyle(color: paint.color, fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    final bgPaint = Paint()..color = paint.color.withOpacity(0.15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width - tp.width - 10, y - 9, tp.width + 8, 18), const Radius.circular(3)),
      bgPaint,
    );
    tp.paint(canvas, Offset(size.width - tp.width - 6, y - tp.height / 2));
  }

  void _drawFibonacci(Canvas canvas, Size size, DrawingObject drawing, Paint paint,
      double Function(double) priceToY, double Function(int) idxToX, double chartH) {
    if (drawing.anchors.length < 2) return;
    final p1Price = drawing.anchors[0].price;
    final p2Price = drawing.anchors[1].price;
    final diff = p2Price - p1Price;

    final levels = [0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0];
    final levelColors = [
      const Color(0xFFEF5350), // 0%
      const Color(0xFFFF7043), // 23.6%
      const Color(0xFFFFCA28), // 38.2%
      const Color(0xFF66BB6A), // 50%
      const Color(0xFF42A5F5), // 61.8%
      const Color(0xFFAB47BC), // 78.6%
      const Color(0xFF78909C), // 100%
    ];

    for (int i = 0; i < levels.length; i++) {
      final level = levels[i];
      final price = p1Price + diff * (1 - level);
      final y = priceToY(price);

      // Çizgi
      final linePaint = Paint()
        ..color = levelColors[i].withOpacity(0.6)
        ..strokeWidth = level == 0.5 || level == 0.618 ? 1.5 : 0.8;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);

      // Arka plan
      if (i < levels.length - 1) {
        final nextPrice = p1Price + diff * (1 - levels[i + 1]);
        final nextY = priceToY(nextPrice);
        canvas.drawRect(
          Rect.fromLTRB(0, min(y, nextY), size.width, max(y, nextY)),
          Paint()..color = levelColors[i].withOpacity(0.04),
        );
      }

      // Etiket
      final label = '${(level * 100).toStringAsFixed(1)}% (${_fmtP(price)})';
      final tp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(color: levelColors[i], fontSize: 9, fontFamily: 'monospace')),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(4, y - tp.height - 2));
    }
  }

  void _drawBrush(Canvas canvas, DrawingObject drawing, Paint paint,
      double Function(double) priceToY, double Function(int) idxToX) {
    if (drawing.anchors.length < 2) return;
    final path = Path();
    path.moveTo(idxToX(drawing.anchors[0].candleIndex), priceToY(drawing.anchors[0].price));
    for (int i = 1; i < drawing.anchors.length; i++) {
      path.lineTo(idxToX(drawing.anchors[i].candleIndex), priceToY(drawing.anchors[i].price));
    }
    canvas.drawPath(path, paint);
  }

  String _fmtP(double p) => p >= 1000 ? p.toStringAsFixed(2) : p >= 1 ? p.toStringAsFixed(4) : p.toStringAsFixed(8);

  @override
  bool shouldRepaint(covariant DrawingPainter o) => true;
}
