import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../main.dart';

// ═══════════════════════════════════════════════════════════════
// ANA SAYFA (Home Tab) — Cyan-Free Premium Design
// ═══════════════════════════════════════════════════════════════
class HomeTab extends StatelessWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.2,
            colors: [Color(0xFF0E1525), kBg],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              const SizedBox(height: 60),
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [kAccentBlue.withOpacity(0.2), kPurple.withOpacity(0.2)]),
                  border: Border.all(color: kAccentBlue.withOpacity(0.3), width: 1.5),
                  boxShadow: [BoxShadow(color: kAccentBlue.withOpacity(0.15), blurRadius: 40)],
                ),
                child: const Icon(Icons.insights_rounded, size: 38, color: kAccentOrange),
              ),
              const SizedBox(height: 40),
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(colors: [kAccentOrange, kPurple]).createShader(b),
                child: const Text(
                  'Profesyonel\nKripto Analizi',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Gelişmiş teknik analiz araçları,\nçizim katmanı ve kişiselleştirilebilir alarm sistemi\nile kendi stratejinizi oluşturun.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.6, color: Colors.white.withOpacity(0.45)),
              ),
              const SizedBox(height: 48),
              _feat(Icons.candlestick_chart_rounded, 'Mum Grafiği', 'Profesyonel candlestick chart ─ 7 zaman dilimi', kAccentBlue),
              const SizedBox(height: 12),
              _feat(Icons.auto_graph_rounded, '30 İndikatör', 'RSI, MACD, Bollinger, Ichimoku ─ Konfigüre edilebilir', kPurple),
              const SizedBox(height: 12),
              _feat(Icons.draw_rounded, 'Çizim Araçları', 'Trend, Fibonacci, Destek/Direnç ─ Kalıcı çizimler', kAccentOrange),
              const SizedBox(height: 12),
              _feat(Icons.notifications_active_rounded, 'Akıllı Alarm', 'Kompleks kural tabanlı bildirim sistemi', kEmerald),
              const SizedBox(height: 12),
              _feat(Icons.dashboard_customize_rounded, 'Multi-Pane', '4 bağımsız alt panel ─ Resize edilebilir', kGold),
              const SizedBox(height: 48),
              Container(
                width: double.infinity, height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kAccentBlue, kPurple]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: kAccentBlue.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 6))],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      final s = context.findAncestorStateOfType<MainScaffoldState>();
                      s?.navigateToMarkets();
                    },
                    child: const Center(
                      child: Text('Piyasaları Keşfet  →',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text('Powered by Flutter & Python',
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.15), letterSpacing: 1.5)),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _feat(IconData ic, String t, String s, Color accent) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: kCard.withOpacity(0.7),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: accent.withOpacity(0.1)),
    ),
    child: Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(ic, color: accent, size: 22),
      ),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 3),
        Text(s, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.35))),
      ])),
      Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.15), size: 20),
    ]),
  );
}
