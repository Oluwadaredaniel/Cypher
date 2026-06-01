import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../widgets/glass_container.dart';
import '../../services/bridge_service.dart';

class SecurityTab extends StatefulWidget {
  final bool isDark;
  final Color accent;
  final List<dynamic> sessions;
  final String pcIp;
  final Function(String) onRevokeSession;

  const SecurityTab({
    super.key,
    required this.isDark,
    required this.accent,
    required this.sessions,
    required this.pcIp,
    required this.onRevokeSession,
  });

  @override
  State<SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<SecurityTab> {
  String _selectedExpiration = "1 Hour";
  String? _generatedToken;
  String? _generatedUrl;
  bool _isGenerating = false;

  final BridgeService _bridge = BridgeService();

  int _getDurationMinutes() {
    switch (_selectedExpiration) {
      case "15 Minutes": return 15;
      case "1 Hour": return 60;
      case "1 Day": return 1440;
      default: return 60;
    }
  }

  void _generateLink() async {
    setState(() => _isGenerating = true);

    try {
      // 1. Get shared folders to authorize for this guest
      final folders = await _bridge.getSharedFolders();
      final paths = folders.map((f) => f['path'].toString()).toList();

      if (paths.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No folders are shared. Add a folder in the 'Shared Files' tab first."))
          );
        }
        setState(() => _isGenerating = false);
        return;
      }

      // 2. Create session on backend
      final result = await _bridge.createGuestSession(paths, _getDurationMinutes());

      if (mounted && result != null && result['success'] == true) {
        setState(() {
          _generatedToken = result['token'];
          _generatedUrl = result['url'];
          _isGenerating = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to generate link. Check backend logs."))
          );
        }
        setState(() => _isGenerating = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Bridge Error: $e"))
        );
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeader("Guest Access", "Allow temporary local access to shared files."),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: widget.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(100), border: Border.all(color: widget.accent.withOpacity(0.2))),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, color: widget.accent, size: 14),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text("Secure Connection Active",
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold, color: widget.accent)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _buildCreateLinkCard(),
                    const SizedBox(height: 24),
                    _buildQuickConnectCard(),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 7,
                child: _buildActiveSessionsCard(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Text("LIVE CONNECTION", style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white24 : Colors.black26, letterSpacing: 2)),
          ],
        ),
        const SizedBox(height: 8),
        Text(title, style: GoogleFonts.roboto(fontSize: 32, fontWeight: FontWeight.w800, color: widget.isDark ? Colors.white : Colors.black)),
        Text(sub, style: GoogleFonts.roboto(fontSize: 14, color: widget.isDark ? Colors.white24 : Colors.black38)),
      ],
    );
  }

  Widget _buildCreateLinkCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: widget.accent.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.link_rounded, color: widget.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text("Create Guest Link", style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 24),
          Text("LINK EXPIRATION", style: GoogleFonts.roboto(fontSize: 9, color: widget.isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedExpiration,
                isExpanded: true,
                dropdownColor: widget.isDark ? const Color(0xFF1A1A1E) : Colors.white,
                items: ["15 Minutes", "1 Hour", "1 Day"].map((String val) {
                  return DropdownMenuItem<String>(value: val, child: Text(val, style: GoogleFonts.roboto(fontSize: 14, color: widget.isDark ? Colors.white70 : Colors.black87)));
                }).toList(),
                onChanged: (v) => setState(() => _selectedExpiration = v!),
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isGenerating ? null : _generateLink,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 8,
                shadowColor: widget.accent.withOpacity(0.4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isGenerating)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  else
                    const Icon(Icons.add_link_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Flexible(child: Text(_isGenerating ? "GENERATING..." : "Generate Link", style: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQuickConnectCard() {
    String qrData = _generatedUrl ?? "http://${widget.pcIp}:5000/guest/access";

    return GlassContainer(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Quick Connect", style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black), overflow: TextOverflow.ellipsis),
          Text(_generatedToken != null ? "Guest link active." : "Scan to open the file portal.", style: GoogleFonts.roboto(fontSize: 13, color: widget.isDark ? Colors.white24 : Colors.black38), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: QrImageView(data: qrData, size: 140),
            ),
          ),
          if (_generatedToken != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SelectableText(_generatedUrl!, style: GoogleFonts.roboto(fontSize: 9, color: widget.accent), textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionsCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: widget.accent.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.devices_rounded, color: widget.accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text("Active Sessions", style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(10)),
                child: Text("${widget.sessions.length} ACTIVE", style: GoogleFonts.roboto(fontSize: 9, color: widget.isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (widget.sessions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.person_off_outlined, size: 48, color: widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.1)),
                    const SizedBox(height: 16),
                    Text("No active guest sessions.", style: GoogleFonts.roboto(color: widget.isDark ? Colors.white12 : Colors.black12)),
                  ],
                ),
              ),
            )
          else
            ...widget.sessions.map((s) {
              final token = s['token']?.toString() ?? "";
              final shortToken = token.length > 8 ? token.substring(0, 8) : token;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _sessionItem(
                  "Guest - $shortToken",
                  "Expires in ${(s['time_remaining_seconds'] ?? 0) ~/ 60}m",
                  Icons.person_pin_circle_rounded,
                  s['is_active'] ?? true,
                  token,
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _sessionItem(String name, String sub, IconData icon, bool active, String token) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withOpacity(0.01) : Colors.black.withOpacity(0.01),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: widget.isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: widget.isDark ? Colors.white24 : Colors.black26, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: active ? const Color(0xFF10B981) : Colors.amber, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(sub, style: GoogleFonts.roboto(fontSize: 11, color: widget.isDark ? Colors.white24 : Colors.black38), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: token.isEmpty ? null : () => widget.onRevokeSession(token),
            child: Text("Revoke", style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent.withOpacity(0.7))),
          ),
        ],
      ),
    );
  }
}
