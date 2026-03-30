import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../core/constants.dart';
import '../core/models.dart';
import '../engine/indicator_pipeline.dart';
import '../engine/alert_engine.dart';
import '../painters/candlestick_painter.dart';
import '../painters/drawing_painter.dart';
import '../widgets/drawing_toolbar.dart';
import '../widgets/sub_chart_panel.dart';
import '../widgets/indicator_config_modal.dart';
import '../widgets/alert_builder_modal.dart';
import '../services/api_service.dart';
import '../services/drawing_storage.dart';

// ═══════════════════════════════════════════════════════════════
// COİN DETAY EKRANI — Multi-Pane Grafik Terminal
// Çizim araçları, konfigüre edilebilir indikatörler, alarm sistemi
// ═══════════════════════════════════════════════════════════════
class CoinDetailScreen extends StatefulWidget {
  final String symbol, name;
  const CoinDetailScreen({Key? key, required this.symbol, required this.name}) : super(key: key);
  @override
  State<CoinDetailScreen> createState() => _CoinDetailScreenState();
}

class _CoinDetailScreenState extends State<CoinDetailScreen> {
  // Grafik state
  List<CandleData> _candles = [];
  bool _chartLoading = true;
  String _interval = '1h';
  double _scrollOffset = 0;
  double _candleW = 12;
  int? _crosshairIdx;

  // İndikatör state
  Set<IndType> _activeInds = {};
  Map<IndType, Map<String, dynamic>> _indParams = {};
  final IndicatorPipeline _pipeline = IndicatorPipeline();
  final Map<IndType, double> _panelHeights = {};

  // Çizim state
  List<DrawingObject> _drawings = [];
  DrawingType? _activeTool;
  DrawingObject? _currentDrawing;
  bool _showDrawingTools = false;

  // Sinyal state
  bool _sigLoading = true;
  Map<String, dynamic>? _sigData;

  // Alarm
  StreamSubscription? _alertSub;

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadSavedConfig();
    _loadDrawings();
    _fetchKlines();
    _fetchSignals();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchKlines();
      // Alarm kontrolü
      AlertEngine().checkRules(widget.symbol, _candles);
    });
    // Alarm bildirimi dinle
    _alertSub = AlertEngine().alertStream.listen(_onAlertTriggered);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _alertSub?.cancel();
    super.dispose();
  }

  void _onAlertTriggered(AlertNotification notif) {
    if (!mounted) return;
    if (notif.rule.symbol != widget.symbol) return;
    // Uygulama içi bildirim
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.notifications_active_rounded, color: kAccentOrange, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(notif.rule.name, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white))),
          ]),
          const SizedBox(height: 4),
          Text(notif.message, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
          const SizedBox(height: 4),
          Text('Bu bir analiz uyarısıdır, yatırım tavsiyesi değildir.',
            style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: Colors.white.withOpacity(0.4))),
        ]),
        backgroundColor: kCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 6),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _loadSavedConfig() async {
    final config = await IndicatorConfigModal.loadConfig();
    if (mounted) {
      setState(() {
        _activeInds = config['active'] as Set<IndType>;
        _indParams = config['params'] as Map<IndType, Map<String, dynamic>>;
      });
    }
  }

  Future<void> _loadDrawings() async {
    final drawings = await DrawingStorage.load(widget.symbol);
    if (mounted) setState(() => _drawings = drawings);
  }

  Future<void> _saveDrawings() async {
    await DrawingStorage.save(widget.symbol, _drawings);
  }

  Future<void> _fetchKlines() async {
    final candles = await ApiService.fetchKlines(widget.symbol, _interval);
    if (candles.isNotEmpty && mounted) {
      setState(() {
        _candles = candles;
        _chartLoading = false;
        _scrollOffset = max(0, candles.length * _candleW - MediaQuery.of(context).size.width + 60);
        _pipeline.invalidate();
      });
    } else if (mounted) {
      setState(() => _chartLoading = false);
    }
  }

  Future<void> _fetchSignals() async {
    setState(() => _sigLoading = true);
    final data = await ApiService.fetchSignals(widget.symbol);
    if (mounted) setState(() { _sigData = data; _sigLoading = false; });
  }

  void _changeInterval(String iv) {
    setState(() { _interval = iv; _chartLoading = true; _pipeline.invalidate(); });
    _fetchKlines();
  }

  // ─── Çizim İşlemleri ───
  void _setDrawingTool(DrawingType? type) {
    setState(() {
      if (_activeTool == type) {
        _activeTool = null;
        _currentDrawing = null;
      } else {
        _activeTool = type;
        _currentDrawing = null;
      }
    });
  }

  void _onChartTap(Offset localPos) {
    if (_activeTool == null || _candles.isEmpty) {
      // Normal crosshair
      final idx = ((_scrollOffset + localPos.dx) / _candleW).floor();
      if (idx >= 0 && idx < _candles.length) {
        setState(() => _crosshairIdx = idx);
      }
      return;
    }

    // Çizim modu
    final chartH = 320.0;
    final xAxisH = 28.0;
    final usableH = (chartH - xAxisH) * 0.78;
    final gap = _candleW * 0.2;
    final bodyW = _candleW - gap;
    final visCount = (MediaQuery.of(context).size.width / _candleW).ceil() + 2;
    final startIdx = (_scrollOffset / _candleW).floor().clamp(0, _candles.length - 1);
    final endIdx = (startIdx + visCount).clamp(0, _candles.length);

    double minP = double.infinity, maxP = -double.infinity;
    for (int i = startIdx; i < endIdx; i++) {
      minP = min(minP, _candles[i].low);
      maxP = max(maxP, _candles[i].high);
    }
    final pad = (maxP - minP) * 0.08;
    minP -= pad; maxP += pad;
    if (maxP == minP) maxP = minP + 1;

    final candleIdx = ((_scrollOffset + localPos.dx) / _candleW).floor().clamp(0, _candles.length - 1);
    final price = maxP - (localPos.dy / usableH) * (maxP - minP);
    final anchor = AnchorPoint(candleIdx, price);

    setState(() {
      if (_activeTool == DrawingType.horizontalRay) {
        // Tek nokta yeterli
        final drawing = DrawingObject(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: DrawingType.horizontalRay,
          anchors: [anchor],
          colorValue: 0xFF42A5F5,
        );
        _drawings.add(drawing);
        _activeTool = null;
        _saveDrawings();
      } else if (_activeTool == DrawingType.brush) {
        if (_currentDrawing == null) {
          _currentDrawing = DrawingObject(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: DrawingType.brush,
            anchors: [anchor],
            colorValue: 0xFF66BB6A,
            strokeWidth: 2.0,
          );
        }
      } else {
        // Trend Line & Fibonacci — 2 nokta gerekiyor
        if (_currentDrawing == null) {
          _currentDrawing = DrawingObject(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: _activeTool!,
            anchors: [anchor],
            colorValue: _activeTool == DrawingType.fibonacci ? 0xFFAB47BC : 0xFFFF8F00,
          );
        } else {
          final finalDrawing = DrawingObject(
            id: _currentDrawing!.id,
            type: _currentDrawing!.type,
            anchors: [..._currentDrawing!.anchors, anchor],
            colorValue: _currentDrawing!.colorValue,
            strokeWidth: _currentDrawing!.strokeWidth,
          );
          _drawings.add(finalDrawing);
          _currentDrawing = null;
          _activeTool = null;
          _saveDrawings();
        }
      }
    });
  }

  void _onChartPanUpdate(Offset localPos) {
    if (_activeTool == DrawingType.brush && _currentDrawing != null) {
      final chartH = 320.0;
      final xAxisH = 28.0;
      final usableH = (chartH - xAxisH) * 0.78;
      final visCount = (MediaQuery.of(context).size.width / _candleW).ceil() + 2;
      final startIdx = (_scrollOffset / _candleW).floor().clamp(0, _candles.length - 1);
      final endIdx = (startIdx + visCount).clamp(0, _candles.length);

      double minP = double.infinity, maxP = -double.infinity;
      for (int i = startIdx; i < endIdx; i++) {
        minP = min(minP, _candles[i].low);
        maxP = max(maxP, _candles[i].high);
      }
      final pad = (maxP - minP) * 0.08;
      minP -= pad; maxP += pad;
      if (maxP == minP) maxP = minP + 1;

      final candleIdx = ((_scrollOffset + localPos.dx) / _candleW).floor().clamp(0, _candles.length - 1);
      final price = maxP - (localPos.dy / usableH) * (maxP - minP);

      setState(() {
        _currentDrawing = DrawingObject(
          id: _currentDrawing!.id,
          type: _currentDrawing!.type,
          anchors: [..._currentDrawing!.anchors, AnchorPoint(candleIdx, price)],
          colorValue: _currentDrawing!.colorValue,
          strokeWidth: _currentDrawing!.strokeWidth,
        );
      });
    }
  }

  void _onBrushEnd() {
    if (_activeTool == DrawingType.brush && _currentDrawing != null) {
      setState(() {
        _drawings.add(_currentDrawing!);
        _currentDrawing = null;
      });
      _saveDrawings();
    }
  }

  void _undoDrawing() {
    if (_drawings.isNotEmpty) {
      setState(() => _drawings.removeLast());
      _saveDrawings();
    }
  }

  void _clearDrawings() {
    setState(() => _drawings.clear());
    DrawingStorage.clear(widget.symbol);
  }

  // ─── Gösterge Modalı ───
  void _showIndicatorMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => IndicatorConfigModal(
        activeIndicators: _activeInds,
        indicatorParams: _indParams,
        onApply: (active, params) {
          setState(() {
            _activeInds = active;
            _indParams = params;
            _pipeline.invalidate();
          });
        },
      ),
    );
  }

  // ─── Alarm Modalları ───
  void _showAlertBuilder() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AlertBuilderModal(symbol: widget.symbol, coinName: widget.name),
    ).then((result) {
      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ Alarm başarıyla kuruldu'),
            backgroundColor: kEmerald.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    });
  }

  void _showAlertList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AlertListModal(symbol: widget.symbol),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activePanels = _activeInds.where((i) => kIndicators[i]!.cat == IndCat.panel).toList();
    final panelsToShow = activePanels.take(4).toList(); // Max 4 panel

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          // Çizim araçları toggle
          IconButton(
            icon: Icon(Icons.draw_rounded,
              color: _showDrawingTools ? kAccentOrange : Colors.white.withOpacity(0.5), size: 20),
            tooltip: 'Çizim Araçları',
            onPressed: () => setState(() {
              _showDrawingTools = !_showDrawingTools;
              if (!_showDrawingTools) { _activeTool = null; _currentDrawing = null; }
            }),
          ),
          // İndikatörler
          IconButton(
            icon: const Icon(Icons.auto_graph_rounded, color: kAccentOrange, size: 22),
            tooltip: 'Göstergeler',
            onPressed: _showIndicatorMenu,
          ),
          // Alarm oluştur
          IconButton(
            icon: Icon(Icons.notification_add_rounded, color: kAccentOrange.withOpacity(0.8), size: 20),
            tooltip: 'Alarm Kur',
            onPressed: _showAlertBuilder,
          ),
          // Alarm listesi
          IconButton(
            icon: Icon(Icons.notifications_rounded, color: Colors.white.withOpacity(0.4), size: 20),
            tooltip: 'Alarmlarım',
            onPressed: _showAlertList,
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: Colors.white.withOpacity(0.5)),
            onPressed: () { _fetchKlines(); _fetchSignals(); },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent, kAccentBlue.withOpacity(0.2), kPurple.withOpacity(0.2), Colors.transparent,
              ]),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Zaman dilimi seçici
          Container(
            color: kSurface,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: kIntervals.map((iv) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => _changeInterval(iv),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _interval == iv ? kAccentBlue.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: _interval == iv ? Border.all(color: kAccentBlue.withOpacity(0.3)) : null,
                    ),
                    child: Text(iv, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: _interval == iv ? kAccentOrange : Colors.white.withOpacity(0.35),
                    )),
                  ),
                ),
              )).toList(),
            ),
          ),
          // Ana Grafik Alanı
          _chartLoading
            ? SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(kAccentBlue.withOpacity(0.6)),
                )),
              )
            : Stack(children: [
                // Grafik + Çizimler
                GestureDetector(
                  onHorizontalDragUpdate: _activeTool == null ? (d) {
                    setState(() {
                      _scrollOffset = (_scrollOffset - d.delta.dx).clamp(
                        0.0, max(0, _candles.length * _candleW - MediaQuery.of(context).size.width + 60));
                      _crosshairIdx = null;
                    });
                  } : null,
                  onScaleUpdate: _activeTool == null ? (d) {
                    if (d.scale != 1.0) {
                      setState(() {
                        _candleW = (_candleW * d.scale).clamp(4.0, 40.0);
                        _scrollOffset = _scrollOffset.clamp(
                          0.0, max(0, _candles.length * _candleW - MediaQuery.of(context).size.width + 60));
                      });
                    }
                  } : null,
                  onTapDown: (d) => _onChartTap(d.localPosition),
                  onPanUpdate: _activeTool == DrawingType.brush ? (d) => _onChartPanUpdate(d.localPosition) : null,
                  onPanEnd: _activeTool == DrawingType.brush ? (_) => _onBrushEnd() : null,
                  child: Listener(
                    onPointerSignal: (e) {
                      if (e is PointerScrollEvent) {
                        setState(() {
                          _candleW = (_candleW - e.scrollDelta.dy * 0.02).clamp(4.0, 40.0);
                          _scrollOffset = _scrollOffset.clamp(
                            0.0, max(0, _candles.length * _candleW - MediaQuery.of(context).size.width + 60));
                        });
                      }
                    },
                    child: Container(
                      height: 320,
                      margin: const EdgeInsets.fromLTRB(0, 4, 0, 0),
                      color: kBg,
                      child: Stack(children: [
                        // Ana mum grafiği
                        CustomPaint(
                          size: Size(MediaQuery.of(context).size.width, 320),
                          painter: CandlestickPainter(
                            candles: _candles,
                            scrollOffset: _scrollOffset,
                            candleW: _candleW,
                            crosshairIdx: _crosshairIdx,
                            activeOverlays: _activeInds,
                            overlayParams: _indParams,
                            pipeline: _pipeline,
                            interval: _interval,
                          ),
                        ),
                        // Çizim katmanı
                        if (_drawings.isNotEmpty || _currentDrawing != null)
                          CustomPaint(
                            size: Size(MediaQuery.of(context).size.width, 320),
                            painter: DrawingPainter(
                              drawings: _drawings,
                              candles: _candles,
                              scrollOffset: _scrollOffset,
                              candleW: _candleW,
                              activeDrawing: _currentDrawing,
                            ),
                          ),
                      ]),
                    ),
                  ),
                ),
                // Çizim toolbar'ı
                if (_showDrawingTools)
                  DrawingToolbar(
                    activeTool: _activeTool,
                    onTrendLine: () => _setDrawingTool(DrawingType.trendLine),
                    onHorizontalRay: () => _setDrawingTool(DrawingType.horizontalRay),
                    onFibonacci: () => _setDrawingTool(DrawingType.fibonacci),
                    onBrush: () => _setDrawingTool(DrawingType.brush),
                    onDelete: _clearDrawings,
                    onUndo: _undoDrawing,
                    onClose: () => setState(() {
                      _showDrawingTools = false;
                      _activeTool = null;
                      _currentDrawing = null;
                    }),
                    hasDrawings: _drawings.isNotEmpty,
                  ),
                // Aktif araç bilgisi
                if (_activeTool != null)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: kAccentOrange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kAccentOrange.withOpacity(0.3)),
                      ),
                      child: Text(
                        _activeTool == DrawingType.trendLine ? '✏️ Trend — 2 nokta seçin'
                          : _activeTool == DrawingType.horizontalRay ? '↔ Yatay — 1 nokta seçin'
                          : _activeTool == DrawingType.fibonacci ? '📐 Fib — 2 nokta seçin'
                          : '🖌️ Fırça — Sürükleyin',
                        style: const TextStyle(fontSize: 10, color: kAccentOrange, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ]),
          // Alt paneller (max 4)
          ...panelsToShow.map((ind) {
            final params = _indParams[ind] ?? kIndicators[ind]!.defaultParams;
            final height = _panelHeights[ind] ?? 100.0;
            return SubChartPanel(
              key: ValueKey(ind),
              type: ind,
              candles: _candles,
              scrollOffset: _scrollOffset,
              candleW: _candleW,
              params: params,
              pipeline: _pipeline,
              initialHeight: height,
              onHeightChanged: (h) => _panelHeights[ind] = h,
              onClose: () => setState(() {
                _activeInds.remove(ind);
                _panelHeights.remove(ind);
              }),
            );
          }),
          const SizedBox(height: 16),
          // Canlı sinyal verisi
          _buildLiveSection(),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _buildLiveSection() {
    if (_sigLoading) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(
          strokeWidth: 2, valueColor: AlwaysStoppedAnimation(kAccentBlue.withOpacity(0.5)))),
      );
    }
    final sig = (_sigData?['signal_data'] as Map<String, dynamic>?) ?? {};
    final ind = (_sigData?['indicator_data'] as Map<String, dynamic>?) ?? {};
    final dir = (sig['direction'] as String?) ?? 'NEUTRAL';
    final price = (ind['price'] as num?)?.toDouble() ?? 0.0;
    final rsiV = (ind['rsi'] as num?)?.toDouble() ?? 0.0;
    final adxVal = (ind['adx'] as num?)?.toDouble() ?? 0.0;
    final macdVal = (ind['macd'] as num?)?.toDouble() ?? 0.0;
    final ema9 = (ind['ema9'] as num?)?.toDouble() ?? 0.0;

    Color dc;
    IconData di;
    String dl;
    switch (dir.toUpperCase()) {
      case 'LONG': dc = kGreen; di = Icons.trending_up_rounded; dl = '⬆ LONG'; break;
      case 'SHORT': dc = kRed; di = Icons.trending_down_rounded; dl = '⬇ SHORT'; break;
      default: dc = const Color(0xFF455A64); di = Icons.remove_rounded; dl = '— NEUTRAL';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Sinyal kartı
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [dc.withOpacity(0.8), dc.withOpacity(0.45)]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: dc.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(di, size: 24, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ANALİZ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.7), letterSpacing: 2)),
              Text(dl, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
            ])),
            if (price > 0) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Fiyat', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.6))),
              Text('\$${_fmtN(price)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
          ]),
        ),
        // Disclaimer
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: kAccentBlue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Bu bilgiler kullanıcı tanımlı veri analizi sonucudur. Yatırım tavsiyesi niteliği taşımaz.',
            style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.25), fontStyle: FontStyle.italic),
          ),
        ),
        const SizedBox(height: 16),
        // İndikatör grid
        Row(children: [
          Container(
            width: 4, height: 18,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [kAccentOrange, kPurple],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text('CANLI İNDİKATÖRLER',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.35), letterSpacing: 2)),
        ]),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            _indCard('RSI', rsiV.toStringAsFixed(1), Icons.speed_rounded,
              rsiV >= 70 ? kRed : rsiV <= 30 ? kGreen : kGold,
              rsiV >= 70 ? 'Aşırı Alım' : rsiV <= 30 ? 'Aşırı Satım' : 'Nötr'),
            _indCard('ADX', adxVal.toStringAsFixed(1), Icons.show_chart_rounded,
              adxVal >= 25 ? kAccentBlue : const Color(0xFF78909C),
              adxVal >= 40 ? 'Çok Güçlü' : adxVal >= 25 ? 'Güçlü' : 'Zayıf'),
            _indCard('MACD', macdVal.toStringAsFixed(2), Icons.bar_chart_rounded,
              macdVal >= 0 ? kGreen : kRed,
              macdVal >= 0 ? 'Pozitif' : 'Negatif'),
            _indCard('EMA 9', _fmtN(ema9), Icons.timeline_rounded,
              kPurple,
              price > ema9 ? 'Üstünde' : 'Altında'),
          ],
        ),
      ]),
    );
  }

  Widget _indCard(String t, String v, IconData ic, Color c, String sub) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: c.withOpacity(0.15)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        Icon(ic, size: 14, color: c.withOpacity(0.7)),
        const SizedBox(width: 6),
        Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.4), letterSpacing: 1)),
      ]),
      Text(v, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
        child: Text(sub, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: c.withOpacity(0.9))),
      ),
    ]),
  );

  String _fmtN(double n) => n >= 1000
    ? n.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},')
    : n.toStringAsFixed(2);
}
