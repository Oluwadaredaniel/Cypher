import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SystemProvider extends ChangeNotifier {
  // Stats
  double _cpu    = 0;
  double _ram    = 0;
  double _disk   = 0;
  int    _volume = 50;
  String _activeWindow = '';
  bool   _isPlaying   = false;
  Map<String, dynamic> _battery = {};
  Map<String, dynamic> _network = {};
  List<dynamic> _processes = [];
  List<dynamic> _apps      = [];
  List<dynamic> _activity  = [];
  List<dynamic> _notifications = [];
  String? _pcClipboard;
  bool _loading = false;

  Timer? _statsTimer;

  double get cpu            => _cpu;
  double get ram            => _ram;
  double get disk           => _disk;
  int    get volume         => _volume;
  String get activeWindow   => _activeWindow;
  bool   get isPlaying      => _isPlaying;
  Map<String, dynamic> get battery => _battery;
  Map<String, dynamic> get network => _network;
  List<dynamic> get processes    => _processes;
  List<dynamic> get apps         => _apps;
  List<dynamic> get activity     => _activity;
  List<dynamic> get notifications => _notifications;
  String? get pcClipboard       => _pcClipboard;
  bool    get isLoading         => _loading;

  // ── Poll Loop ─────────────────────────────────────────────────
  void startPolling(String ip) {
    _statsTimer?.cancel();
    _fetchStats(ip);
    _statsTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchStats(ip));
  }

  void stopPolling() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  Future<void> _fetchStats(String ip) async {
    try {
      final stats = await ApiService.getSystemStats(ip);
      _cpu  = (stats['cpu']  as num?)?.toDouble() ?? _cpu;
      _ram  = (stats['ram']  as num?)?.toDouble() ?? _ram;
      _disk = (stats['disk'] as num?)?.toDouble() ?? _disk;
      notifyListeners();
    } catch (_) {}
  }

  // ── On-demand fetches ─────────────────────────────────────────
  Future<void> fetchVolume(String ip) async {
    try {
      _volume = await ApiService.getVolume(ip);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchActiveWindow(String ip) async {
    try {
      final data = await ApiService.getActiveWindow(ip);
      _activeWindow = data['window'] as String? ?? '';
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchBattery(String ip) async {
    try {
      _battery = await ApiService.getBattery(ip);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchNetwork(String ip) async {
    try {
      _network = await ApiService.getNetwork(ip);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchProcesses(String ip) async {
    _loading = true;
    notifyListeners();
    try {
      _processes = await ApiService.getProcesses(ip);
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<void> fetchApps(String ip) async {
    _loading = true;
    notifyListeners();
    try {
      _apps = await ApiService.getInstalledApps(ip);
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<void> fetchActivity(String ip) async {
    try {
      _activity = await ApiService.getActivity(ip);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchNotifications(String ip) async {
    try {
      _notifications = await ApiService.getNotifications(ip);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchClipboard(String ip) async {
    try {
      final data = await ApiService.getPcClipboard(ip);
      _pcClipboard = data['text'] as String? ?? data['content'] as String?;
      notifyListeners();
    } catch (_) {}
  }

  // ── Media ─────────────────────────────────────────────────────
  Future<void> togglePlayPause(String ip) async {
    await ApiService.mediaPlayPause(ip);
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  Future<void> nextTrack(String ip)  async => ApiService.mediaNext(ip);
  Future<void> prevTrack(String ip)  async => ApiService.mediaPrev(ip);
  Future<void> stopMedia(String ip)  async => ApiService.mediaStop(ip);
  Future<void> toggleMute(String ip) async => ApiService.mediaMute(ip);

  Future<void> setVolume(String ip, int v) async {
    _volume = v;
    notifyListeners();
    await ApiService.setVolume(ip, v);
  }

  // ── App Management ────────────────────────────────────────────
  Future<bool> closeApp(String ip, String appName) async {
    try {
      await ApiService.closeApp(ip, name: appName);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Power ─────────────────────────────────────────────────────
  Future<void> shutdown(String ip)  async => ApiService.shutdown(ip);
  Future<void> restart(String ip)   async => ApiService.restart(ip);
  Future<void> sleep(String ip)     async => ApiService.sleep(ip);
  Future<void> hibernate(String ip) async => ApiService.hibernate(ip);
  Future<void> lock(String ip)      async => ApiService.lock(ip);

  // ── Processes ─────────────────────────────────────────────────
  Future<bool> killProcess(String ip, int pid) async {
    try {
      await ApiService.killProcess(ip, pid);
      _processes.removeWhere((p) => p['pid'] == pid);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Apps ──────────────────────────────────────────────────────
  Future<void> launchApp(String ip, String path) async => ApiService.launchApp(ip, path);

  @override
  void dispose() {
    _statsTimer?.cancel();
    super.dispose();
  }
}
