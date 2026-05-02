import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;

class ActivityScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;
  const ActivityScreen({super.key, required this.pcIpAddress, required this.authToken});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<Map<String, dynamic>> _allItems = [];
  String _activeFilter = 'All';
  bool _isLoading = true;
  final List<String> _filters = ['All', 'Files', 'Controls', 'Connections'];

  String get _baseUrl => 'http://${widget.pcIpAddress}:5000';
  Map<String, String> get _headers => {'X-Auth-Token': widget.authToken};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  String _translateAction(String endpoint) {
    if (endpoint.contains('/files/browse')) return 'Browsed files';
    if (endpoint.contains('/files/download')) return 'Downloaded a file';
    if (endpoint.contains('/files/upload')) return 'Sent a file to PC';
    if (endpoint.contains('/files/delete')) return 'Deleted a file';
    if (endpoint.contains('/power/shutdown')) return 'Shut down PC';
    if (endpoint.contains('/power/restart')) return 'Restarted PC';
    if (endpoint.contains('/power/sleep')) return 'Put PC to sleep';
    if (endpoint.contains('/power/lock')) return 'Locked PC';
    if (endpoint.contains('/screenshot')) return 'Took a screenshot';
    if (endpoint.contains('/clipboard')) return 'Used clipboard';
    if (endpoint.contains('/media')) return 'Controlled media';
    if (endpoint.contains('/type')) return 'Typed on PC';
    if (endpoint.contains('/apps/launch')) return 'Opened an app';
    return 'Performed an action';
  }

  String _filterCategory(String endpoint) {
    if (endpoint.contains('/files')) return 'Files';
    if (endpoint.contains('/power') || endpoint.contains('/media') ||
        endpoint.contains('/screenshot') || endpoint.contains('/type') ||
        endpoint.contains('/clipboard')) return 'Controls';
    if (endpoint.contains('/pair') || endpoint.contains('/events')) return 'Connections';
    return 'Other';
  }

  String _formatTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts.replaceAll(' ', 'T'));
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final itemDay = DateTime(dt.year, dt.month, dt.day);
      final timeStr = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
      if (itemDay == today) return 'Today at $timeStr';
      if (itemDay == yesterday) return 'Yesterday at $timeStr';
      return '${dt.day}/${dt.month} at $timeStr';
    } catch (_) { return ts; }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        http.get(Uri.parse('$_baseUrl/history'), headers: _headers),
        http.get(Uri.parse('$_baseUrl/events'), headers: _headers),
      ]).timeout(const Duration(seconds: 8));

      final List<Map<String, dynamic>> merged = [];

      if (results[0].statusCode == 200) {
        final history = jsonDecode(results[0].body) as List;
        for (final item in history) {
          merged.add({
            'action': _translateAction(item['endpoint'] ?? ''),
            'timestamp': _formatTimestamp(item['timestamp'] ?? ''),
            'success': item['success'] ?? true,
            'category': _filterCategory(item['endpoint'] ?? ''),
            'type': 'command',
          });
        }
      }

      if (results[1].statusCode == 200) {
        final events = jsonDecode(results[1].body) as List;
        for (final event in events) {
          merged.add({
            'action': event['event'] == 'connected'
              ? '📱 ${event['device'] ?? 'Device'} connected'
              : '📱 Device disconnected',
            'timestamp': _formatTimestamp(event['timestamp'] ?? ''),
            'success': true,
            'category': 'Connections',
            'type': 'event',
          });
        }
      }

      merged.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
      if (mounted) setState(() { _allItems = merged; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_activeFilter == 'All') return _allItems;
    return _allItems.where((i) => i['category'] == _activeFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Activity', style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => setState(() => _allItems.clear()),
            child: Text('Clear', style: GoogleFonts.outfit(color: const Color(0xFF86868B))),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _filters.map((f) {
                final active = _activeFilter == f;
                return GestureDetector(
                  onTap: () { HapticFeedback.selectionClick(); setState(() => _activeFilter = f); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10, top: 8, bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF6C63FF) : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(f, style: GoogleFonts.outfit(
                        color: active ? Colors.white : const Color(0xFF86868B),
                        fontSize: 13, fontWeight: FontWeight.w600,
                      )),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
              : _filtered.isEmpty
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('📋', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 16),
                      Text('Nothing yet', style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Your activity will appear here', style: GoogleFonts.outfit(color: const Color(0xFF86868B))),
                    ],
                  ))
                : RefreshIndicator(
                    color: const Color(0xFF6C63FF),
                    onRefresh: _fetchData,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final item = _filtered[index];
                        return FadeInLeft(
                          delay: Duration(milliseconds: index * 40),
                          duration: const Duration(milliseconds: 400),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(
                                    color: (item['success'] as bool) ? const Color(0xFF30D158) : const Color(0xFFFF453A),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['action'] as String,
                                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                      Text(item['timestamp'] as String,
                                        style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (item['success'] as bool)
                                      ? const Color(0xFF30D158).withOpacity(0.15)
                                      : const Color(0xFFFF453A).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    (item['success'] as bool) ? 'Done' : 'Failed',
                                    style: GoogleFonts.outfit(
                                      color: (item['success'] as bool) ? const Color(0xFF30D158) : const Color(0xFFFF453A),
                                      fontSize: 11, fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
