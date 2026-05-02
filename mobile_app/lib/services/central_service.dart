import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CentralService {
  // Production URL for Emerald's Central Hub
  static const String _baseUrl = "https://cypher-3ctq.onrender.com/api";

  static Future<void> reportInstall() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('install_reported') == true) return;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/analytics/install'),
        body: jsonEncode({
          'platform': 'android',
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        await prefs.setBool('install_reported', true);
      }
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> getBroadcast() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/broadcast'))
          .timeout(const Duration(seconds: 4));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return null;
  }
}
