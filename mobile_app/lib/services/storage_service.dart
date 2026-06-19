import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _keyToken      = 'auth_token';
  static const _keyIp         = 'pc_ip_address';
  static const _keyDeviceId   = 'device_id';
  static const _keyDeviceName = 'device_name';
  static const _keyIsPaired   = 'is_paired';
  static const _keyPcName     = 'pc_name';
  static const _keyOnboarded  = 'onboarding_done';

  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ── Auth ─────────────────────────────────────────────────────
  static Future<void>   saveToken(String token) async => (await _prefs).setString(_keyToken, token);
  static Future<String?> getToken() async => (await _prefs).getString(_keyToken);

  static Future<void>   saveIp(String ip) async => (await _prefs).setString(_keyIp, ip);
  static Future<String?> getIp() async => (await _prefs).getString(_keyIp);

  static Future<void>   saveDeviceId(String id) async => (await _prefs).setString(_keyDeviceId, id);
  static Future<String?> getDeviceId() async => (await _prefs).getString(_keyDeviceId);

  static Future<void>   saveDeviceName(String name) async => (await _prefs).setString(_keyDeviceName, name);
  static Future<String?> getDeviceName() async => (await _prefs).getString(_keyDeviceName);

  static Future<void> savePcName(String name) async => (await _prefs).setString(_keyPcName, name);
  static Future<String?> getPcName() async => (await _prefs).getString(_keyPcName);

  static Future<void> setIsPaired(bool val) async => (await _prefs).setBool(_keyIsPaired, val);
  static Future<bool> getIsPaired() async => (await _prefs).getBool(_keyIsPaired) ?? false;

  static Future<void> setOnboarded(bool val) async => (await _prefs).setBool(_keyOnboarded, val);
  static Future<bool> getOnboarded() async => (await _prefs).getBool(_keyOnboarded) ?? false;

  static Future<void> clearPairing() async {
    final p = await _prefs;
    await p.remove(_keyToken);
    await p.remove(_keyIp);
    await p.remove(_keyIsPaired);
    await p.remove(_keyPcName);
    await p.remove(_keyDeviceId);
    await p.remove(_keyDeviceName);
  }

  // ── JSON Storage ──────────────────────────────────────────────
  static Future<dynamic> getJson(String key) async {
    final p = await _prefs;
    final str = p.getString(key);
    if (str == null) return null;
    try {
      return jsonDecode(str);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveJson(String key, dynamic value) async {
    final p = await _prefs;
    await p.setString(key, jsonEncode(value));
  }

  // ── Convenience ───────────────────────────────────────────────
  static Future<Map<String, String?>> getConnectionData() async {
    return {
      'token': await getToken(),
      'ip':    await getIp(),
    };
  }
}
