import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class BridgeService {
  static const String baseUrl = "http://127.0.0.1:5000";
  static const String internalToken = "cypher-internal-pc-app-token-2024";

  // [ZERO LATENCY FIX] Get the pairing code from disk if backend is still starting
  Future<String> getConnectCode() async {
    // 1. Try Network first
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/connect-code"),
        headers: {"X-Auth-Token": internalToken},
      ).timeout(const Duration(seconds: 1));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['code'] ?? "------";
      }
    } catch (_) {}

    // 2. Fallback: Read from local storage (Persistent between restarts)
    try {
      String appData = Platform.environment['APPDATA'] ?? "";
      if (appData.isEmpty) {
        // Fallback for dev environment or if APPDATA is missing
        final home = Platform.environment['USERPROFILE'] ?? "";
        appData = p.join(home, 'AppData', 'Roaming');
      }

      final file = File(p.join(appData, "Cypher", "pairing_code.txt"));
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}

    return "------";
  }

  // Rotate the pairing code
  Future<String> refreshConnectCode() async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/connect-code"),
        headers: {"X-Auth-Token": internalToken},
      ).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['code'] ?? "------";
      }
    } catch (_) {}
    return "------";
  }

  // Get linked devices
  Future<List<dynamic>> getPairedDevices() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/paired-devices"),
        headers: {"X-Auth-Token": internalToken},
      ).timeout(const Duration(seconds: 1));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return [];
  }

  // Get real system stats (CPU, RAM, etc)
  Future<Map<String, dynamic>> getSystemStats() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/system-stats"),
        headers: {"X-Auth-Token": internalToken},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint("Stats Fetch Error: $e");
    }
    return {}; // Return empty to indicate failure
  }

  // Get Network info (IP, Hostname)
  Future<Map<String, dynamic>> getNetworkInfo() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/network"),
        headers: {"X-Auth-Token": internalToken},
      ).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return {"pc_ip": "127.0.0.1", "hostname": "localhost"};
  }

  // Get current active file transfers
  Future<Map<String, dynamic>> getTransfers() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/files/transfers"),
        headers: {"X-Auth-Token": internalToken},
      ).timeout(const Duration(seconds: 1));
      if (res.statusCode == 200) return Map<String, dynamic>.from(jsonDecode(res.body));
    } catch (_) {}
    return {};
  }

  // Get shared folders
  Future<List<dynamic>> getSharedFolders() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/files/shared"),
        headers: {"X-Auth-Token": internalToken},
      ).timeout(const Duration(seconds: 1));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return [];
  }

  // Get security sessions
  Future<List<dynamic>> getSecuritySessions() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/guest/sessions"),
        headers: {"X-Auth-Token": internalToken},
      ).timeout(const Duration(seconds: 1));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['sessions'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  // Get dynamic activity log
  Future<List<dynamic>> getActivityLog() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/system/activity"),
        headers: {"X-Auth-Token": internalToken},
      ).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return [];
  }

  // Create Guest Session
  Future<Map<String, dynamic>?> createGuestSession(List<String> folders, int durationMinutes) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/guest/create"),
        headers: {
          "X-Auth-Token": internalToken,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "folders": folders,
          "duration_minutes": durationMinutes,
        }),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  // End Guest Session
  Future<bool> endGuestSession(String guestToken) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/guest/end"),
        headers: {
          "X-Auth-Token": internalToken,
          "Content-Type": "application/json",
        },
        body: jsonEncode({"guest_token": guestToken}),
      ).timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  // Optimize system — returns freed MB and action list, or null on failure
  Future<Map<String, dynamic>?> optimizeSystem() async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/system/optimize"),
        headers: {"X-Auth-Token": internalToken},
      ).timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  // Get all settings
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/settings"),
        headers: {"X-Auth-Token": internalToken},
      ).timeout(const Duration(seconds: 1));
      if (res.statusCode == 200) return Map<String, dynamic>.from(jsonDecode(res.body));
    } catch (_) {}
    return {};
  }

  // Save specific settings
  Future<bool> saveSettings(Map<String, dynamic> settings) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/settings"),
        headers: {
          "X-Auth-Token": internalToken,
          "Content-Type": "application/json",
        },
        body: jsonEncode(settings),
      ).timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {}
    return false;
  }
}
