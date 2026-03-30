
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════
// FAVORİ YÖNETİCİSİ — SharedPreferences Kalıcılık
// ═══════════════════════════════════════════════════════════════
class FavManager {
  static const _key = 'fav_coins';

  static Future<Set<String>> load() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_key) ?? []).toSet();
  }

  static Future<void> save(Set<String> favs) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_key, favs.toList());
  }
}
