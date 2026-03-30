import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';


// ═══════════════════════════════════════════════════════════════
// İNDİKATÖR KONFİGÜRASYON MODALI
// Parametre editörleri, kaynak seçimi, kalıcı kayıt
// ═══════════════════════════════════════════════════════════════
class IndicatorConfigModal extends StatefulWidget {
  final Set<IndType> activeIndicators;
  final Map<IndType, Map<String, dynamic>> indicatorParams;
  final Function(Set<IndType>, Map<IndType, Map<String, dynamic>>) onApply;

  const IndicatorConfigModal({
    Key? key,
    required this.activeIndicators,
    required this.indicatorParams,
    required this.onApply,
  }) : super(key: key);

  static Future<Map<String, dynamic>> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeList = prefs.getStringList('active_indicators') ?? [];
      final paramsStr = prefs.getString('indicator_params');

      final active = <IndType>{};
      for (final name in activeList) {
        try {
          active.add(IndType.values.firstWhere((t) => t.name == name));
        } catch (_) {}
      }

      final params = <IndType, Map<String, dynamic>>{};
      if (paramsStr != null) {
        final decoded = json.decode(paramsStr) as Map<String, dynamic>;
        for (final e in decoded.entries) {
          try {
            final type = IndType.values.firstWhere((t) => t.name == e.key);
            params[type] = Map<String, dynamic>.from(e.value as Map);
          } catch (_) {}
        }
      }

      return {'active': active, 'params': params};
    } catch (_) {
      return {'active': <IndType>{}, 'params': <IndType, Map<String, dynamic>>{}};
    }
  }

  @override
  State<IndicatorConfigModal> createState() => _IndicatorConfigModalState();
}

class _IndicatorConfigModalState extends State<IndicatorConfigModal> {
  late Set<IndType> _active;
  late Map<IndType, Map<String, dynamic>> _params;
  IndType? _configuring; // Parametre düzenleme açık olan indikatör

  @override
  void initState() {
    super.initState();
    _active = Set.from(widget.activeIndicators);
    _params = {};
    for (final e in widget.indicatorParams.entries) {
      _params[e.key] = Map.from(e.value);
    }
  }

  void _toggle(IndType type) {
    setState(() {
      if (_active.contains(type)) {
        _active.remove(type);
        _configuring = null;
      } else {
        // Panel indikatörler için max 4 kontrol
        final info = kIndicators[type]!;
        if (info.cat == IndCat.panel) {
          final panelCount = _active.where((t) => kIndicators[t]!.cat == IndCat.panel).length;
          if (panelCount >= 4) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Maksimum 4 alt panel desteklenmektedir.'),
                backgroundColor: kRed.withOpacity(0.9),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
            return;
          }
        }
        _active.add(type);
      }
    });
  }

  Map<String, dynamic> _getParams(IndType type) {
    if (_params.containsKey(type)) return _params[type]!;
    final defaults = Map<String, dynamic>.from(kIndicators[type]!.defaultParams);
    _params[type] = defaults;
    return defaults;
  }

  void _apply() {
    widget.onApply(_active, _params);
    _saveConfig();
    Navigator.pop(context);
  }

  Future<void> _saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeList = _active.map((t) => t.name).toList();
      await prefs.setStringList('active_indicators', activeList);

      final paramsMap = <String, dynamic>{};
      for (final e in _params.entries) {
        paramsMap[e.key.name] = e.value;
      }
      await prefs.setString('indicator_params', json.encode(paramsMap));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final overlays = kIndicators.entries.where((e) => e.value.cat == IndCat.overlay).toList();
    final panels = kIndicators.entries.where((e) => e.value.cat == IndCat.panel).toList();
    final panelCount = _active.where((t) => kIndicators[t]!.cat == IndCat.panel).length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // Handle bar
        Center(child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
        )),
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [kAccentBlue.withOpacity(0.2), kPurple.withOpacity(0.2)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_graph_rounded, color: kAccentOrange, size: 20),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Göstergeler', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
              Text('${_active.length} aktif · $panelCount/4 panel',
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.35))),
            ]),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() { _active.clear(); _configuring = null; }),
              child: Text('Temizle', style: TextStyle(color: kRed.withOpacity(0.7), fontSize: 13)),
            ),
          ]),
        ),
        // List
        Expanded(child: ListView(physics: const BouncingScrollPhysics(), children: [
          _buildSection('OVERLAY — Fiyat Üzerinde', overlays),
          _buildSection('PANEL — Grafik Altında (Maks 4)', panels),
          const SizedBox(height: 20),
        ])),
        // Apply button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Uygula', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildSection(String title, List<MapEntry<IndType, IndInfo>> items) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Text(title,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.3), letterSpacing: 2)),
      ),
      ...items.map((e) => _buildIndicatorItem(e.key, e.value)),
    ]);
  }

  Widget _buildIndicatorItem(IndType type, IndInfo info) {
    final isActive = _active.contains(type);
    final isConfiguring = _configuring == type;
    final hasParams = info.defaultParams.isNotEmpty;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      InkWell(
        onTap: () => _toggle(type),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          color: isActive ? kAccentBlue.withOpacity(0.05) : Colors.transparent,
          child: Row(children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: info.color,
                borderRadius: BorderRadius.circular(3),
                boxShadow: isActive ? [BoxShadow(color: info.color.withOpacity(0.4), blurRadius: 6)] : null,
              ),
            ),
            const SizedBox(width: 14),
            Text(info.name, style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? Colors.white : Colors.white54,
            )),
            const Spacer(),
            // Config button
            if (isActive && hasParams) InkWell(
              onTap: () => setState(() => _configuring = isConfiguring ? null : type),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  isConfiguring ? Icons.tune_rounded : Icons.settings_rounded,
                  size: 16,
                  color: isConfiguring ? kAccentOrange : Colors.white.withOpacity(0.3),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (isActive) const Icon(Icons.check_circle_rounded, color: kAccentBlue, size: 20)
            else Icon(Icons.circle_outlined, color: Colors.white.withOpacity(0.15), size: 20),
          ]),
        ),
      ),
      // Config panel
      if (isConfiguring && isActive) _buildConfigPanel(type, info),
    ]);
  }

  Widget _buildConfigPanel(IndType type, IndInfo info) {
    final params = _getParams(type);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: info.color.withOpacity(0.2)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Kaynak seçimi
        if (params.containsKey('source')) _buildSourceSelector(params),
        // Parametre slider'ları
        ...params.entries.where((e) => e.key != 'source').map((e) {
          if (e.value is int) {
            return _buildIntSlider(e.key, params);
          } else if (e.value is double) {
            return _buildDoubleSlider(e.key, params);
          }
          return const SizedBox();
        }),
      ]),
    );
  }

  Widget _buildSourceSelector(Map<String, dynamic> params) {
    const sources = ['close', 'open', 'high', 'low', 'hl2', 'hlc3', 'ohlc4'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Text('Kaynak', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4))),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(8)),
          child: DropdownButton<String>(
            value: params['source'] as String? ?? 'close',
            dropdownColor: kCard,
            underline: const SizedBox(),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            isDense: true,
            items: sources.map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
            onChanged: (v) => setState(() => params['source'] = v),
          ),
        ),
      ]),
    );
  }

  Widget _buildIntSlider(String key, Map<String, dynamic> params) {
    final value = (params[key] as int).toDouble();
    final range = _getRange(key);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(
          width: 70,
          child: Text(_paramLabel(key), style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4))),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value.clamp(range[0], range[1]),
              min: range[0],
              max: range[1],
              divisions: (range[1] - range[0]).toInt(),
              onChanged: (v) => setState(() => params[key] = v.toInt()),
            ),
          ),
        ),
        SizedBox(
          width: 30,
          child: Text('${params[key]}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kAccentOrange)),
        ),
      ]),
    );
  }

  Widget _buildDoubleSlider(String key, Map<String, dynamic> params) {
    final value = (params[key] as num).toDouble();
    final range = _getDoubleRange(key);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(
          width: 70,
          child: Text(_paramLabel(key), style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4))),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value.clamp(range[0], range[1]),
              min: range[0],
              max: range[1],
              divisions: ((range[1] - range[0]) * 10).toInt(),
              onChanged: (v) => setState(() => params[key] = double.parse(v.toStringAsFixed(1))),
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kAccentOrange)),
        ),
      ]),
    );
  }

  List<double> _getRange(String key) {
    switch (key) {
      case 'period': return [2, 200];
      case 'fast': return [2, 50];
      case 'slow': return [5, 100];
      case 'signal': return [2, 30];
      case 'kPeriod': return [2, 50];
      case 'dPeriod': return [2, 20];
      case 'tenkan': return [2, 50];
      case 'kijun': return [5, 50];
      case 'senkou': return [10, 100];
      default: return [1, 100];
    }
  }

  List<double> _getDoubleRange(String key) {
    switch (key) {
      case 'multiplier': return [0.5, 4.0];
      case 'af': return [0.01, 0.1];
      case 'maxAf': return [0.1, 0.5];
      default: return [0.1, 10.0];
    }
  }

  String _paramLabel(String key) {
    switch (key) {
      case 'period': return 'Periyot';
      case 'fast': return 'Fast';
      case 'slow': return 'Slow';
      case 'signal': return 'Signal';
      case 'multiplier': return 'Çarpan';
      case 'kPeriod': return 'K Per.';
      case 'dPeriod': return 'D Per.';
      case 'tenkan': return 'Tenkan';
      case 'kijun': return 'Kijun';
      case 'senkou': return 'Senkou';
      case 'af': return 'AF';
      case 'maxAf': return 'Max AF';
      default: return key;
    }
  }
}
