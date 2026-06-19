import 'dart:async';
import 'storage_service.dart';

class ClipboardEntry {
  final String text;
  final DateTime timestamp;
  final String source; // 'phone', 'pc'

  ClipboardEntry({
    required this.text,
    required this.timestamp,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'source': source,
  };

  factory ClipboardEntry.fromJson(Map<String, dynamic> json) => ClipboardEntry(
    text: json['text'] as String? ?? '',
    timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    source: json['source'] as String? ?? 'pc',
  );
}

class ClipboardService {
  static const _maxHistory = 50;
  static const _storageKey = 'clipboard_history';

  static Future<List<ClipboardEntry>> getHistory() async {
    try {
      final data = await StorageService.getJson(_storageKey);
      if (data is List) {
        return data
            .map((x) => ClipboardEntry.fromJson(x as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> addToHistory(String text, {String source = 'pc'}) async {
    try {
      if (text.isEmpty || text.length > 10000) return;

      final history = await getHistory();

      // Avoid duplicate consecutive entries
      if (history.isNotEmpty && history.first.text == text) {
        return;
      }

      history.insert(0, ClipboardEntry(
        text: text,
        timestamp: DateTime.now(),
        source: source,
      ));

      // Keep only latest 50 entries
      if (history.length > _maxHistory) {
        history.removeRange(_maxHistory, history.length);
      }

      await StorageService.saveJson(_storageKey, history.map((e) => e.toJson()).toList());
    } catch (_) {}
  }

  static Future<void> clearHistory() async {
    try {
      await StorageService.saveJson(_storageKey, []);
    } catch (_) {}
  }

  static Future<void> removeEntry(String text) async {
    try {
      final history = await getHistory();
      history.removeWhere((e) => e.text == text);
      await StorageService.saveJson(_storageKey, history.map((e) => e.toJson()).toList());
    } catch (_) {}
  }
}
