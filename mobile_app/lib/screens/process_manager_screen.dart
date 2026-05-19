import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:http/http.dart' as http;

class ProcessManagerScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;

  const ProcessManagerScreen({
    super.key,
    required this.pcIpAddress,
    required this.authToken,
  });

  @override
  State<ProcessManagerScreen> createState() => _ProcessManagerScreenState();
}

class _ProcessManagerScreenState extends State<ProcessManagerScreen> {
  List<dynamic> _processes = [];
  List<dynamic> _filteredProcesses = [];
  bool _isLoading = true;
  bool _isError = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchProcesses();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && _searchQuery.isEmpty) _fetchProcesses(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String get _baseUrl => "http://${widget.pcIpAddress}:5000";
  Map<String, String> get _headers => {"X-Auth-Token": widget.authToken, "Content-Type": "application/json"};

  Future<void> _fetchProcesses({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/processes'), headers: _headers).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is! List) throw Exception("Invalid data format");
        
        final List<dynamic> data = decoded;
        data.sort((a, b) => (b['cpu_percent'] ?? 0).compareTo(a['cpu_percent'] ?? 0));
        
        if (mounted) {
          setState(() {
            _processes = data;
            _applyFilter();
            _isLoading = false;
            _isError = false;
          });
        }
      } else {
        throw Exception();
      }
    } catch (e) {
      if (mounted) {
        setState(() { 
          _isLoading = false; 
          if (_processes.isEmpty) _isError = true; 
        });
      }
    }
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredProcesses = _processes;
    } else {
      _filteredProcesses = _processes.where((p) => 
        p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
        p['pid'].toString().contains(_searchQuery)
      ).toList();
    }
  }

  Future<void> _killProcess(int pid, String name) async {
    HapticFeedback.heavyImpact();
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Kill Process?", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to terminate $name (PID: $pid)?", style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("End Task", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/processes/kill'),
          headers: _headers,
          body: jsonEncode({"pid": pid}),
        );
        if (response.statusCode == 200) {
          _showToast("Process terminated");
          _fetchProcesses(silent: true);
        } else {
          _showToast("Failed to kill process (Access Denied)", isError: true);
        }
      } catch (e) {
        _showToast("Network error", isError: true);
      }
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
      backgroundColor: isError ? Colors.redAccent : const Color(0xFF6C63FF),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchField(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
              : _isError 
                ? _buildErrorState()
                : _buildProcessList(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text("Task Manager", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      actions: [
        IconButton(onPressed: () => _fetchProcesses(), icon: const Icon(Icons.refresh, color: Colors.white70)),
      ],
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() { _searchQuery = v; _applyFilter(); }),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Search processes...",
          hintStyle: const TextStyle(color: Colors.white24),
          prefixIcon: const Icon(Icons.search, color: Colors.white24),
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildProcessList() {
    if (_filteredProcesses.isEmpty) {
      return Center(child: Text("No processes found", style: GoogleFonts.outfit(color: Colors.white24)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filteredProcesses.length,
      itemBuilder: (context, index) {
        final p = _filteredProcesses[index];
        final double cpu = (p['cpu_percent'] ?? 0.0).toDouble();
        final double mem = (p['memory_mb'] ?? 0.0).toDouble();
        
        return FadeInUp(
          duration: const Duration(milliseconds: 300),
          delay: Duration(milliseconds: index < 10 ? index * 50 : 0),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                  child: Center(
                    child: Text(
                      (p['name'] != null && p['name'].toString().isNotEmpty) 
                        ? p['name'].toString().substring(0, 1).toUpperCase() 
                        : "?", 
                      style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)
                    )
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['name'], style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                      Text("PID: ${p['pid']} • ${mem.toStringAsFixed(1)} MB", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("${cpu.toStringAsFixed(1)}%", style: GoogleFonts.outfit(color: cpu > 10 ? Colors.orangeAccent : Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                    const Text("CPU", style: TextStyle(color: Colors.grey, fontSize: 9)),
                  ],
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                  onPressed: () => _killProcess(p['pid'], p['name']),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Text("Failed to load processes", style: GoogleFonts.outfit(color: Colors.white)),
          TextButton(onPressed: () => _fetchProcesses(), child: const Text("Try Again")),
        ],
      ),
    );
  }
}
