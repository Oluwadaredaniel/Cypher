import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider with ChangeNotifier {
  String _pcIpAddress = '';
  String _authToken = '';
  bool _isConnected = false;
  Map<String, dynamic> _systemStats = {};

  String get pcIpAddress => _pcIpAddress;
  String get authToken => _authToken;
  bool get isConnected => _isConnected;
  Map<String, dynamic> get systemStats => _systemStats;

  Future<void> loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    _pcIpAddress = prefs.getString('pc_ip_address') ?? '';
    _authToken = prefs.getString('auth_token') ?? '';
    notifyListeners();
  }

  Future<void> saveIpAddress(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    _pcIpAddress = ip;
    await prefs.setString('pc_ip_address', ip);
    notifyListeners();
  }

  Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = token;
    await prefs.setString('auth_token', token);
    notifyListeners();
  }

  void setConnected(bool status) {
    _isConnected = status;
    notifyListeners();
  }

  void updateStats(Map<String, dynamic> stats) {
    _systemStats = stats;
    notifyListeners();
  }
}
