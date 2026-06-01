import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class BackendManager {
  static final BackendManager _instance = BackendManager._internal();
  factory BackendManager() => _instance;
  BackendManager._internal();

  Process? _process;
  String _errorLog = "";
  bool _isReady = false;

  bool get isReady => _isReady;
  String get errorLog => _errorLog;

  Future<bool> start() async {
    _errorLog = "";
    final projectRoot = Directory.current.path;
    final backendDir = p.join(projectRoot, 'backend');

    // 1. TRY PACKAGED EXE FIRST
    final exePath = p.join(backendDir, 'dist', 'cypher_node.exe');
    if (await File(exePath).exists()) {
      try {
        _process = await Process.start(exePath, [], workingDirectory: backendDir);
        _setupProcessPiping();
        return await waitForBackendReady();
      } catch (e) {
        debugPrint("Packaged Node failed: $e");
      }
    }

    // 2. FALLBACK TO SYSTEM PYTHON
    final scriptPath = p.join(backendDir, 'service.py');
    final List<String> pythonCommands = [
      r'C:\Users\hp\AppData\Local\Programs\Python\Python312\python.exe',
      'python', 'python3', 'py', 'python.exe'
    ];

    for (var cmd in pythonCommands) {
      try {
        debugPrint("Attempting start via $cmd...");
        final process = await Process.start(
          cmd,
          ['-u', scriptPath],
          runInShell: true,
          workingDirectory: backendDir,
        );

        _process = process;
        _setupProcessPiping();

        // Wait a bit to see if it crashes immediately
        await Future.delayed(const Duration(milliseconds: 1000));

        if (await waitForBackendReady(maxAttempts: 10)) {
          return true;
        } else {
          // If this command didn't work, kill and try next
          process.kill();
          _process = null;
        }
      } catch (e) {
        _errorLog += "Failed with $cmd: $e\n";
      }
    }
    return false;
  }

  void _setupProcessPiping() {
    if (_process == null) return;

    // Using utf8.decoder.bind to handle streams correctly
    _process!.stdout.transform(utf8.decoder).listen((data) {
       debugPrint("Node Output: $data");
       if (data.contains("already running")) {
         _errorLog = "CYPHER is already running in another process.";
       }
    });

    _process!.stderr.transform(utf8.decoder).listen((data) {
      debugPrint("Node Error: $data");
      _errorLog += data;
    });

    _process!.exitCode.then((code) {
      if (code != 0) _isReady = false;
    });
  }

  Future<bool> waitForBackendReady({
    int maxAttempts = 20,
    Duration interval = const Duration(milliseconds: 500),
  }) async {
    for (int i = 0; i < maxAttempts; i++) {
      try {
        final response = await http.get(
          Uri.parse('http://127.0.0.1:5000/ping'),
        ).timeout(const Duration(seconds: 1));

        if (response.statusCode == 200) {
          debugPrint('Backend ready');
          _isReady = true;
          return true;
        }
      } catch (_) {}
      await Future.delayed(interval);
    }
    return false;
  }

  void stop() {
    _process?.kill();
    _process = null;
    _isReady = false;
  }
}
