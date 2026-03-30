import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/models.dart';

// ═══════════════════════════════════════════════════════════════
// ÇİZİM ARAÇLARI TOOLBAR
// Sol kenar dikey floating toolbar
// ═══════════════════════════════════════════════════════════════
class DrawingToolbar extends StatelessWidget {
  final DrawingType? activeTool;
  final VoidCallback onTrendLine;
  final VoidCallback onHorizontalRay;
  final VoidCallback onFibonacci;
  final VoidCallback onBrush;
  final VoidCallback onDelete;
  final VoidCallback onUndo;
  final VoidCallback onClose;
  final bool hasDrawings;

  const DrawingToolbar({
    Key? key,
    this.activeTool,
    required this.onTrendLine,
    required this.onHorizontalRay,
    required this.onFibonacci,
    required this.onBrush,
    required this.onDelete,
    required this.onUndo,
    required this.onClose,
    this.hasDrawings = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 8,
      top: 60,
      child: Container(
        decoration: BoxDecoration(
          color: kCard.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kAccentBlue.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(2, 2)),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _toolButton(
            icon: Icons.show_chart_rounded,
            tooltip: 'Trend Çizgisi',
            isActive: activeTool == DrawingType.trendLine,
            onTap: onTrendLine,
            color: const Color(0xFFFF8F00),
          ),
          const SizedBox(height: 2),
          _toolButton(
            icon: Icons.horizontal_rule_rounded,
            tooltip: 'Yatay Işın (Destek/Direnç)',
            isActive: activeTool == DrawingType.horizontalRay,
            onTap: onHorizontalRay,
            color: const Color(0xFF42A5F5),
          ),
          const SizedBox(height: 2),
          _toolButton(
            icon: Icons.architecture_rounded,
            tooltip: 'Fibonacci',
            isActive: activeTool == DrawingType.fibonacci,
            onTap: onFibonacci,
            color: const Color(0xFFAB47BC),
          ),
          const SizedBox(height: 2),
          _toolButton(
            icon: Icons.brush_rounded,
            tooltip: 'Serbest Çizim',
            isActive: activeTool == DrawingType.brush,
            onTap: onBrush,
            color: const Color(0xFF66BB6A),
          ),
          if (hasDrawings) ...[
            Container(margin: const EdgeInsets.symmetric(vertical: 4), width: 24, height: 1, color: Colors.white.withOpacity(0.1)),
            _toolButton(
              icon: Icons.undo_rounded,
              tooltip: 'Geri Al',
              onTap: onUndo,
              color: Colors.white54,
            ),
            const SizedBox(height: 2),
            _toolButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Tümünü Sil',
              onTap: onDelete,
              color: kRed.withOpacity(0.7),
            ),
          ],
          Container(margin: const EdgeInsets.symmetric(vertical: 4), width: 24, height: 1, color: Colors.white.withOpacity(0.1)),
          _toolButton(
            icon: Icons.close_rounded,
            tooltip: 'Araçları Kapat',
            onTap: onClose,
            color: Colors.white38,
            size: 16,
          ),
        ]),
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required Color color,
    bool isActive = false,
    double size = 18,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isActive ? kAccentBlue.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isActive ? Border.all(color: kAccentBlue.withOpacity(0.5), width: 1) : null,
            ),
            child: Icon(icon, size: size, color: isActive ? kAccentOrange : color),
          ),
        ),
      ),
    );
  }
}
