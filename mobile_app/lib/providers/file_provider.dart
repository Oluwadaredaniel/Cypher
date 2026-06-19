import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

enum TransferStatus { idle, uploading, downloading, paused, done, error }

class TransferTask {
  final String id;
  final String name;
  final bool isUpload;
  int received;
  int total;
  TransferStatus status;
  String? error;
  String? localPath;

  TransferTask({
    required this.id,
    required this.name,
    required this.isUpload,
    this.received = 0,
    this.total    = 0,
    this.status   = TransferStatus.idle,
    this.error,
    this.localPath,
  });

  double get progress => total > 0 ? received / total : 0.0;
}

class FileProvider extends ChangeNotifier {
  String _currentPath = '';
  List<dynamic> _items = [];
  bool _isLoading = false;
  String? _error;
  final List<TransferTask> _transfers = [];
  final Set<String> _selectedPaths = {};

  String    get currentPath   => _currentPath;
  List<dynamic> get items     => _items;
  bool      get isLoading     => _isLoading;
  String?   get error         => _error;
  List<TransferTask> get transfers => _transfers;
  Set<String> get selectedPaths   => _selectedPaths;
  bool        get hasSelection    => _selectedPaths.isNotEmpty;

  // ── Browse ────────────────────────────────────────────────────
  Future<void> loadRoot(String ip) async {
    _isLoading = true;
    _error = null;
    _currentPath = '';
    notifyListeners();

    try {
      _items = await ApiService.getRootFiles(ip);
    } catch (e) {
      _error = e.toString();
      _items = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> browse(String ip, String path) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _items = await ApiService.browseFiles(ip, path);
      _currentPath = path;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh(String ip) async {
    if (_currentPath.isEmpty) {
      await loadRoot(ip);
    } else {
      await browse(ip, _currentPath);
    }
  }

  // ── Selection ─────────────────────────────────────────────────
  void toggleSelection(String path) {
    if (_selectedPaths.contains(path)) {
      _selectedPaths.remove(path);
    } else {
      _selectedPaths.add(path);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedPaths.clear();
    notifyListeners();
  }

  void selectAll() {
    for (final item in _items) {
      final path = item['path'] as String? ?? '';
      if (path.isNotEmpty) _selectedPaths.add(path);
    }
    notifyListeners();
  }

  // ── Download ──────────────────────────────────────────────────
  Future<TransferTask?> download(String ip, String remotePath, String name) async {
    final task = TransferTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      isUpload: false,
      status: TransferStatus.downloading,
    );
    _transfers.insert(0, task);
    notifyListeners();

    try {
      final localPath = await ApiService.downloadFile(
        ip, remotePath, name,
        onProgress: (recv, total) {
          task.received = recv;
          task.total    = total;
          notifyListeners();
        },
      );
      task.localPath = localPath;
      task.status    = TransferStatus.done;
    } catch (e) {
      task.status = TransferStatus.error;
      task.error  = e.toString();
    }

    notifyListeners();
    return task;
  }

  // ── Upload ────────────────────────────────────────────────────
  Future<void> upload(String ip, String localPath, String destination, String name) async {
    final task = TransferTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      isUpload: true,
      status: TransferStatus.uploading,
    );
    _transfers.insert(0, task);
    notifyListeners();

    try {
      await ApiService.uploadFile(
        ip, localPath, destination,
        onProgress: (sent, total) {
          task.received = sent;
          task.total    = total;
          notifyListeners();
        },
      );
      task.status = TransferStatus.done;
    } catch (e) {
      task.status = TransferStatus.error;
      task.error  = e.toString();
    }

    notifyListeners();
  }

  // ── Delete ────────────────────────────────────────────────────
  Future<bool> delete(String ip, String path) async {
    try {
      await ApiService.deleteFile(ip, path);
      _items.removeWhere((i) => i['path'] == path);
      _selectedPaths.remove(path);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void clearTransfers() {
    _transfers.removeWhere((t) => t.status == TransferStatus.done || t.status == TransferStatus.error);
    notifyListeners();
  }
}
