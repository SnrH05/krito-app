import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/models.dart';

// ═══════════════════════════════════════════════════════════════
// API SERVİSİ — Backend proxy üzerinden Binance verileri
// Backend CORS çözümü içeriyor → Flutter web güvenli
// ═══════════════════════════════════════════════════════════════
class ApiService {

  // ═══════════════════════════════════════════════════════════════
  // KLINES
  // ═══════════════════════════════════════════════════════════════
  static Future<List<CandleData>> fetchKlines(String symbol, String interval, {int limit = 500}) async {
    try {
      // Binance '1s' ve '10s' desteklemiyor — backend de desteklemez
      String safeInterval = interval;
      if (interval == '1s' || interval == '10s') {
        safeInterval = '1m';
      }

      final r = await http.get(
        Uri.parse('$kBaseUrl/api/klines?symbol=$symbol&interval=$safeInterval&limit=$limit'),
      ).timeout(const Duration(seconds: 12));

      if (r.statusCode == 200) {
        final j = json.decode(r.body);
        if (j['status'] == 'success') {
          return (j['candles'] as List)
              .map((c) => CandleData.fromJson(c as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      print('[ApiService] fetchKlines error: $e');
    }
    return [];
  }

  // ═══════════════════════════════════════════════════════════════
  // TICKERS (24h fiyat + değişim)
  // ═══════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> fetchTickers() async {
    try {
      final r = await http.get(
        Uri.parse('$kBaseUrl/api/tickers'),
      ).timeout(const Duration(seconds: 15));

      if (r.statusCode == 200) {
        final j = json.decode(r.body);
        if (j['status'] == 'success') {
          return j['tickers'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      print('[ApiService] fetchTickers error: $e');
    }
    return {};
  }

  // ═══════════════════════════════════════════════════════════════
  // SIGNALS
  // ═══════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> fetchSignals(String symbol) async {
    try {
      final r = await http.get(
        Uri.parse('$kBaseUrl/api/signals?symbol=$symbol'),
      ).timeout(const Duration(seconds: 12));

      if (r.statusCode == 200) {
        return json.decode(r.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('[ApiService] fetchSignals error: $e');
    }
    return null;
  }
}
