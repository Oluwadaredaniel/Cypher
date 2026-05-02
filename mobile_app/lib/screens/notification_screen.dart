import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;

  const NotificationScreen({
    super.key,
    required this.pcIpAddress,
    required this.authToken,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<dynamic> _notifications = [];
  String _activeFilter = "All";
  bool _isLoading = true;
  final List<String> _filters = ["All", "System", "Files", "Guest"];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  String get _baseUrl => "http://${widget.pcIpAddress}:5000";
  Map<String, String> get _headers => {
        "X-Auth-Token": widget.authToken,
        "Content-Type": "application/json",
      };

  // --- DATA LOGIC ---

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/notifications'), headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _notifications = data;
            _isLoading = false;
          });
        }
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("Couldn't reach your PC. Check your connection.", isError: true);
      }
    }
  }

  void _dismissNotification(int index) {
    final filteredList = _filteredNotifications;
    final itemToDismiss = filteredList[index];
    
    // Find the original index in the main list to handle undo correctly
    final originalIndex = _notifications.indexOf(itemToDismiss);

    setState(() {
      _notifications.removeAt(originalIndex);
    });

    HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Notification cleared", style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: "UNDO",
          textColor: const Color(0xFF6C63FF),
          onPressed: () {
            setState(() {
              _notifications.insert(originalIndex, itemToDismiss);
            });
          },
        ),
      ),
    );
  }

  void _clearAll() async {
    if (_notifications.isEmpty) return;
    
    HapticFeedback.mediumImpact();
    // Visual stagger effect before clearing data
    await Future.delayed(const Duration(milliseconds: 200));
    
    if (mounted) {
      setState(() {
        _notifications.clear();
      });
      _showSnackBar("All notifications cleared");
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF6C63FF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  List<dynamic> get _filteredNotifications {
    if (_activeFilter == "All") return _notifications;
    return _notifications.where((n) {
      final app = n['app_name']?.toString().toLowerCase() ?? "";
      final title = n['title']?.toString().toLowerCase() ?? "";
      final filter = _activeFilter.toLowerCase();
      
      if (filter == "files") return app.contains("file") || title.contains("folder");
      if (filter == "system") return app.contains("system") || app.contains("battery") || app.contains("windows");
      
      return app.contains(filter);
    }).toList();
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF6C63FF),
              backgroundColor: const Color(0xFF1A1A1A),
              onRefresh: _fetchNotifications,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF), strokeWidth: 2))
                  : _filteredNotifications.isEmpty
                      ? _buildEmptyState()
                      : _buildNotificationList(),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D0D0D),
      elevation: 0,
      centerTitle: false,
      leadingWidth: 56,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      title: Text("Activity", style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
      actions: [
        if (_notifications.isNotEmpty)
          FadeIn(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _clearAll,
                child: Text("Clear all", style: GoogleFonts.outfit(color: const Color(0xFF6C63FF), fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          bool isActive = _activeFilter == _filters[index];
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _activeFilter = _filters[index]);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF6C63FF) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isActive ? Colors.transparent : const Color(0xFF2C2C2E)),
              ),
              child: Center(
                child: Text(
                  _filters[index],
                  style: GoogleFonts.outfit(
                    color: isActive ? Colors.white : const Color(0xFF86868B),
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView( // Wrap in ListView to enable RefreshIndicator pull-to-refresh
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        FadeInUp(
          duration: const Duration(milliseconds: 500),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: const Color(0xFF1A1A1A), shape: BoxShape.circle),
                child: const Text("💤", style: TextStyle(fontSize: 48)),
              ),
              const SizedBox(height: 24),
              Text("No new alerts", style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _activeFilter == "All" 
                    ? "When your PC sends a notification, it will show up here instantly."
                    : "No notifications found for the '$_activeFilter' category.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 14, height: 1.5),
                ),
              ),
              const SizedBox(height: 32),
              if (_activeFilter != "All")
                OutlinedButton(
                  onPressed: () => setState(() => _activeFilter = "All"),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2C2C2E)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                  child: Text("Show All", style: GoogleFonts.outfit(color: Colors.white)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationList() {
    final filtered = _filteredNotifications;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        return StaggeredFadeInUp(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Dismissible(
              key: Key(item['id']?.toString() ?? UniqueKey().toString()),
              direction: DismissDirection.endToStart,
              onDismissed: (direction) => _dismissNotification(index),
              background: Container(
                padding: const EdgeInsets.only(right: 24),
                alignment: Alignment.centerRight,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.8), 
                  borderRadius: BorderRadius.circular(20)
                ),
                child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
              ),
              child: _buildNotificationCard(item),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationCard(Map item) {
    String timeString = "Now";
    try {
      if (item['timestamp'] != null) {
        timeString = item['timestamp'].toString().length >= 5 
            ? item['timestamp'].toString().substring(0, 5) 
            : item['timestamp'].toString();
      }
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2C2C2E), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNotificationIcon(item['app_name'] ?? ""),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      (item['app_name'] ?? "Alert").toString().toUpperCase(),
                      style: GoogleFonts.outfit(color: const Color(0xFF6C63FF), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                    ),
                    Text(
                      timeString,
                      style: GoogleFonts.outfit(color: const Color(0xFF3A3A3C), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item['title'] ?? "No Title",
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  item['message'] ?? "No description available",
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon(String appName) {
    IconData iconData;
    Color circleColor;
    final name = appName.toLowerCase();

    if (name.contains("system") || name.contains("battery") || name.contains("power")) {
      iconData = Icons.bolt_rounded;
      circleColor = Colors.amber;
    } else if (name.contains("file") || name.contains("explorer") || name.contains("download")) {
      iconData = Icons.description_rounded;
      circleColor = const Color(0xFF6C63FF);
    } else if (name.contains("guest") || name.contains("user") || name.contains("security")) {
      iconData = Icons.shield_outlined;
      circleColor = Colors.cyanAccent;
    } else if (name.contains("spotify") || name.contains("media")) {
      iconData = Icons.play_circle_fill_rounded;
      circleColor = Colors.greenAccent;
    } else {
      iconData = Icons.notifications_active_rounded;
      circleColor = const Color(0xFF86868B);
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: circleColor.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(iconData, color: circleColor, size: 22),
    );
  }
}

class StaggeredFadeInUp extends StatelessWidget {
  final int index;
  final Widget child;

  const StaggeredFadeInUp({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      delay: Duration(milliseconds: index * 40),
      from: 20,
      child: child,
    );
  }
}