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

    // 1. TRY PACKAGED EXE FIRST (Professional/Production Mode)
    final exePath = p.join(backendDir, 'dist', 'cypher_node.exe');
    if (await File(exePath).exists()) {
      debugPrint("Latching Packaged Node: $exePath");
      try {
        _process = await Process.start(exePath, [], workingDirectory: backendDir);
        _setupProcessPiping();
        return await waitForBackendReady();
      } catch (e) {
        debugPrint("Packaged Node failed: $e");
      }
    }

    // 2. FALLBACK TO SYSTEM PYTHON (Development Mode)
    final scriptPath = p.join(backendDir, 'service.py');
    final List<String> pythonCommands = ['python', 'python3', 'py', 'python.exe'];

    for (var cmd in pythonCommands) {
      try {
        debugPrint("Attempting Dev-Mode start via $cmd...");
        final process = await Process.start(
          cmd,
          [scriptPath],
          runInShell: true,
          workingDirectory: backendDir,
        );

        bool immediatelyFailed = false;
        process.stderr.transform(utf8.decoder).listen((data) {
          if (data.contains("is not recognized") || data.contains("not found")) {
            immediatelyFailed = true;
          }
          _errorLog += data;
        });

        await Future.delayed(const Duration(milliseconds: 600));

        if (immediatelyFailed) {
          process.kill();
          continue;
        }

        _process = process;
        _setupProcessPiping();
        return await waitForBackendReady();
      } catch (e) {
        _errorLog += "Failed with $cmd: $e\n";
      }
    }
    return false;
  }

  void _setupProcessPiping() {
    if (_process == null) return;
    _process!.stdout.transform(utf8.decoder).listen((data) => debugPrint("Node Output: $data"));
    _process!.stderr.transform(utf8.decoder).listen((data) => debugPrint("Node Error: $data"));
    _process!.exitCode.then((code) {
      if (code != 0) _isReady = false;
    });
  }

  Future<bool> waitForBackendReady({
    int maxAttempts = 30,
    Duration interval = const Duration(milliseconds: 500),
  }) async {
    // FIX 6 — GIVE PYTHON EXTRA STARTUP TIME
    await Future.delayed(const Duration(seconds: 1));

    for (int i = 0; i < maxAttempts; i++) {
      try {
        final response = await http.get(
          Uri.parse('http://127.0.0.1:5000/ping'),
        ).timeout(const Duration(seconds: 1));

        if (response.statusCode == 200) {
          debugPrint('Backend ready after ${i + 1} attempts');
          _isReady = true;
          return true;
        }
      } catch (_) {
        // Still starting up, wait and retry
      }
      await Future.delayed(interval);
    }
    _isReady = false;
    return false; // Failed to start after 15 seconds
  }

  void stop() {
    _process?.kill();
    _process = null;
    _isReady = false;
  }
}
