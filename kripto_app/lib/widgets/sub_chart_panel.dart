import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/models.dart';
import '../painters/indicator_panel_painter.dart';
import '../engine/indicator_pipeline.dart';

// ═══════════════════════════════════════════════════════════════
// RESIZE EDİLEBİLİR ALT GRAFİK PANELİ
// Sürükle-yeniden boyutlandır, aç/kapat animasyonu
// ═══════════════════════════════════════════════════════════════
class SubChartPanel extends StatefulWidget {
  final IndType type;
  final List<CandleData> candles;
  final double scrollOffset;
  final double candleW;
  final Map<String, dynamic> params;
  final IndicatorPipeline pipeline;
  final VoidCallback onClose;
  final double initialHeight;
  final ValueChanged<double> onHeightChanged;

  const SubChartPanel({
    Key? key,
    required this.type,
    required this.candles,
    required this.scrollOffset,
    required this.candleW,
    required this.params,
    required this.pipeline,
    required this.onClose,
    this.initialHeight = 100,
    required this.onHeightChanged,
  }) : super(key: key);

  @override
  State<SubChartPanel> createState() => _SubChartPanelState();
}

class _SubChartPanelState extends State<SubChartPanel> with SingleTickerProviderStateMixin {
  late double _height;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _height = widget.initialHeight;
    _animCtrl = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _close() async {
    if (_isClosing) return;
    _isClosing = true;
    await _animCtrl.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final info = kIndicators[widget.type]!;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SizeTransition(
        sizeFactor: _fadeAnim,
        axisAlignment: -1,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Resize tutamağı + başlık
          GestureDetector(
            onVerticalDragUpdate: (d) {
              setState(() {
                _height = (_height + d.delta.dy).clamp(60.0, 200.0);
              });
              widget.onHeightChanged(_height);
            },
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                color: kSurface,
                border: Border(
                  top: BorderSide(color: info.color.withOpacity(0.15), width: 1),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                // Drag handle
                Container(
                  width: 18, height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                // Renk noktası
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: info.color,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [BoxShadow(color: info.color.withOpacity(0.3), blurRadius: 4)],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  info.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.5),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                // Kapat butonu
                InkWell(
                  onTap: _close,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 14, color: Colors.white.withOpacity(0.3)),
                  ),
                ),
              ]),
            ),
          ),
          // Grafik alanı
          SizedBox(
            height: _height,
            child: widget.candles.isEmpty
              ? const SizedBox()
              : CustomPaint(
                  size: Size(MediaQuery.of(context).size.width, _height),
                  painter: IndicatorPanelPainter(
                    type: widget.type,
                    candles: widget.candles,
                    scrollOffset: widget.scrollOffset,
                    candleW: widget.candleW,
                    params: widget.params,
                    pipeline: widget.pipeline,
                  ),
                ),
          ),
        ]),
      ),
    );
  }
}
