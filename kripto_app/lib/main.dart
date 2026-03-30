import 'package:flutter/material.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'engine/alert_engine.dart';
import 'screens/home_tab.dart';
import 'screens/markets_tab.dart';

// ═══════════════════════════════════════════════════════════════
// UYGULAMA GİRİŞ NOKTASI
// ═══════════════════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Alarm motorunu başlat
  await AlertEngine().init();
  runApp(const CryptoPlatformApp());
}

class CryptoPlatformApp extends StatelessWidget {
  const CryptoPlatformApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Kripto Analiz Platformu',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: const MainScaffold(),
  );
}

// ═══════════════════════════════════════════════════════════════
// ANA İSKELET — Bottom Navigation
// ═══════════════════════════════════════════════════════════════
class MainScaffold extends StatefulWidget {
  const MainScaffold({Key? key}) : super(key: key);
  @override
  State<MainScaffold> createState() => MainScaffoldState();
}

class MainScaffoldState extends State<MainScaffold> {
  int _idx = 0;
  final _screens = const [HomeTab(), MarketsTab()];

  void navigateToMarkets() => setState(() => _idx = 1);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _idx, children: _screens),
    bottomNavigationBar: Container(
      decoration: BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kAccentBlue.withOpacity(0.08))),
      ),
      child: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: kAccentOrange,
        unselectedItemColor: Colors.white24,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Ana Sayfa'),
          BottomNavigationBarItem(icon: Icon(Icons.candlestick_chart_rounded), label: 'Piyasalar'),
        ],
      ),
    ),
  );
}
