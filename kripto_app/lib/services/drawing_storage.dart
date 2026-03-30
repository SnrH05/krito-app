import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models.dart';

// ═══════════════════════════════════════════════════════════════
// ÇİZİM KAYIT SERVİSİ — SharedPreferences ile kalıcılık
// Her coin için ayrı çizim seti
// ═══════════════════════════════════════════════════════════════
class DrawingStorage {
  static const _prefix = 'drawings_';

  static Future<List<DrawingObject>> load(String symbol) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('$_prefix$symbol');
      if (data != null) {
        final list = json.decode(data) as List;
        return list.map((j) => DrawingObject.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> save(String symbol, List<DrawingObject> drawings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = json.encode(drawings.map((d) => d.toJson()).toList());
      await prefs.setString('$_prefix$symbol', data);
    } catch (_) {}
  }

  static Future<void> clear(String symbol) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$symbol');
    } catch (_) {}
  }
}
