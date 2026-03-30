import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/api_service.dart';
import '../services/favorites_manager.dart';
import 'coin_detail_screen.dart';

// ═══════════════════════════════════════════════════════════════
// PİYASALAR EKRANI — Arama + Tümü/Favorilerim
// ═══════════════════════════════════════════════════════════════
class MarketsTab extends StatefulWidget {
  const MarketsTab({Key? key}) : super(key: key);
  @override
  State<MarketsTab> createState() => _MarketsTabState();
}

class _MarketsTabState extends State<MarketsTab> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _query = '';
  Set<String> _favs = {};
  Map<String, dynamic> _tickers = {};
  bool _tickersLoading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase()));
    _loadFavs();
    _fetchTickers();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchTickers());
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFavs() async {
    _favs = await FavManager.load();
    if (mounted) setState(() {});
  }

  Future<void> _toggleFav(String sym) async {
    setState(() {
      if (_favs.contains(sym)) _favs.remove(sym); else _favs.add(sym);
    });
    await FavManager.save(_favs);
  }

  Future<void> _fetchTickers() async {
    final tickers = await ApiService.fetchTickers();
    if (tickers.isNotEmpty && mounted) {
      setState(() { _tickers = tickers; _tickersLoading = false; });
    } else if (mounted) {
      setState(() => _tickersLoading = false);
    }
  }

  List<Map<String, String>> _filtered(bool favOnly) {
    return kCoins.where((c) {
      if (favOnly && !_favs.contains(c['s'])) return false;
      if (_query.isNotEmpty) {
        return c['s']!.toLowerCase().contains(_query) || c['n']!.toLowerCase().contains(_query);
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Başlık
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(children: [
            Container(
              width: 4, height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [kAccentOrange, kPurple],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Popüler Coinler', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: kAccentBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('${kCoins.length} coin',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kAccentBlue.withOpacity(0.8))),
            ),
          ]),
        ),
        // Arama
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kAccentBlue.withOpacity(0.1)),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Coin ara ─ BTC, Ethereum…',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.3)),
                suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.3), size: 18),
                      onPressed: () => _searchCtrl.clear(),
                    )
                  : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              ),
            ),
          ),
        ),
        // TabBar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(12)),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(color: kAccentBlue.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              labelColor: kAccentOrange,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: [
                const Tab(text: 'Tümü'),
                Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Favorilerim'),
                  if (_favs.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: kAccentOrange.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text('${_favs.length}', style: const TextStyle(fontSize: 10, color: kAccentOrange)),
                    ),
                  ],
                ])),
              ],
            ),
          ),
        ),
        // Tablo başlığı
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: Row(children: [
            Text('COIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.2), letterSpacing: 2)),
            const Spacer(),
            Text('FİYAT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.2), letterSpacing: 2)),
            const SizedBox(width: 45),
            SizedBox(
              width: 70,
              child: Text('24S %', textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.2), letterSpacing: 2)),
            ),
          ]),
        ),
        Divider(color: Colors.white.withOpacity(0.05), height: 1, indent: 20, endIndent: 20),
        // Liste
        Expanded(
          child: TabBarView(controller: _tabCtrl, children: [
            _buildList(false),
            _buildList(true),
          ]),
        ),
      ]),
    ),
  );

  Widget _buildList(bool favOnly) {
    final coins = _filtered(favOnly);
    if (coins.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(favOnly ? Icons.star_border_rounded : Icons.search_off_rounded, size: 48, color: Colors.white.withOpacity(0.15)),
        const SizedBox(height: 12),
        Text(favOnly ? 'Henüz favori eklenmedi' : 'Sonuç bulunamadı',
          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 15)),
      ]));
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: coins.length,
      itemBuilder: (ctx, i) {
        final c = coins[i];
        final sym = c['s']!;
        final name = c['n']!;
        final t = _tickers[sym] as Map<String, dynamic>?;
        final price = t != null ? (t['price'] as num).toDouble() : 0.0;
        final change = t != null ? (t['change'] as num).toDouble() : 0.0;
        final isPos = change >= 0;
        return InkWell(
          onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => CoinDetailScreen(symbol: sym, name: name))),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.03)))),
            child: Row(children: [
              GestureDetector(
                onTap: () => _toggleFav(sym),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    _favs.contains(sym) ? Icons.star_rounded : Icons.star_border_rounded,
                    color: _favs.contains(sym) ? kGold : Colors.white.withOpacity(0.15),
                    size: 20,
                  ),
                ),
              ),
              Container(
                width: 36, height: 36, alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_coinColor(sym).withOpacity(0.25), _coinColor(sym).withOpacity(0.08)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  sym.replaceAll('USDT', '').substring(0, min(3, sym.replaceAll('USDT', '').length)),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _coinColor(sym)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                Text(sym, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.25))),
              ])),
              if (_tickersLoading)
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(
                  strokeWidth: 1.5, valueColor: AlwaysStoppedAnimation(Colors.white.withOpacity(0.2))))
              else
                Text(_fmtPrice(price), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(width: 12),
              Container(
                width: 72,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: (isPos ? kGreen : kRed).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${isPos ? "+" : ""}${change.toStringAsFixed(2)}%',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isPos ? kGreen : kRed),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  String _fmtPrice(double p) {
    if (p >= 1000) return '\$${p.toStringAsFixed(2).replaceAllMapped(RegExp(r"(\d)(?=(\d{3})+\.)"), (m) => "${m[1]},")}';
    if (p >= 1) return '\$${p.toStringAsFixed(2)}';
    if (p >= 0.001) return '\$${p.toStringAsFixed(4)}';
    return '\$${p.toStringAsFixed(8)}';
  }

  Color _coinColor(String s) => HSLColor.fromAHSL(1, (s.codeUnits.fold<int>(0, (a, b) => a + b) * 37 % 360).toDouble(), 0.7, 0.6).toColor();
}
