import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/services.dart';

class TransferItem {
  final String id;
  final String fileName;
  final int totalBytes;
  final String direction; // "download" or "upload"
  final String destinationPath;
  double progress; // 0.0 to 1.0
  double speedMbps;
  int secondsRemaining;
  bool isComplete;
  bool hasError;
  String? errorMessage;

  TransferItem({
    required this.id,
    required this.fileName,
    required this.totalBytes,
    required this.direction,
    required this.destinationPath,
    this.progress = 0.0,
    this.speedMbps = 0.0,
    this.secondsRemaining = 0,
    this.isComplete = false,
    this.hasError = false,
    this.errorMessage,
  });
}

class TransferProgressScreen extends StatefulWidget {
  final String pcIpAddress;
  final String authToken;
  final List<TransferItem> transfers;

  const TransferProgressScreen({
    super.key,
    required this.pcIpAddress,
    required this.authToken,
    required this.transfers,
  });

  @override
  State<TransferProgressScreen> createState() => _TransferProgressScreenState();
}

class _TransferProgressScreenState extends State<TransferProgressScreen> {
  late List<TransferItem> _currentTransfers;

  @override
  void initState() {
    super.initState();
    _currentTransfers = List.from(widget.transfers);
  }

  void updateTransfer(String id, double progress, double speed, int secondsRemaining) {
    if (!mounted) return;
    setState(() {
      final index = _currentTransfers.indexWhere((t) => t.id == id);
      if (index != -1) {
        _currentTransfers[index].progress = progress;
        _currentTransfers[index].speedMbps = speed;
        _currentTransfers[index].secondsRemaining = secondsRemaining;
      }
    });
  }

  void completeTransfer(String id) {
    if (!mounted) return;
    HapticFeedback.mediumImpact(); // Standard compatibility
    setState(() {
      final index = _currentTransfers.indexWhere((t) => t.id == id);
      if (index != -1) {
        _currentTransfers[index].isComplete = true;
        _currentTransfers[index].progress = 1.0;
        _currentTransfers[index].speedMbps = 0;
      }
    });
  }

  void failTransfer(String id, String error) {
    if (!mounted) return;
    HapticFeedback.vibrate(); // Standard compatibility
    setState(() {
      final index = _currentTransfers.indexWhere((t) => t.id == id);
      if (index != -1) {
        _currentTransfers[index].hasError = true;
        _currentTransfers[index].errorMessage = error;
      }
    });
  }

  void _clearCompleted() {
    setState(() {
      _currentTransfers.removeWhere((t) => t.isComplete);
    });
  }

  double get _totalActiveSpeed {
    double total = 0;
    for (var t in _currentTransfers) {
      if (!t.isComplete && !t.hasError) total += t.speedMbps;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final activeTransfers = _currentTransfers.where((t) => !t.isComplete).toList();
    final completedTransfers = _currentTransfers.where((t) => t.isComplete).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Transfers", 
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            if (activeTransfers.isNotEmpty)
              Text("Total Speed: ${_totalActiveSpeed.toStringAsFixed(1)} MB/s", 
                style: GoogleFonts.outfit(color: const Color(0xFF6C63FF), fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      body: _currentTransfers.isEmpty 
        ? _buildEmptyState()
        : FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              physics: const BouncingScrollPhysics(),
              children: [
                if (activeTransfers.isNotEmpty) ...[
                  ...activeTransfers.map((item) => _buildTransferCard(item)),
                ],
                if (completedTransfers.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("COMPLETED", 
                        style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      TextButton(
                        onPressed: _clearCompleted,
                        child: Text("Clear All", 
                          style: GoogleFonts.outfit(color: const Color(0xFF6C63FF), fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...completedTransfers.map((item) => _buildTransferCard(item)),
                ],
                const SizedBox(height: 100),
              ],
            ),
          ),
    );
  }

  Widget _buildTransferCard(TransferItem item) {
    bool inProgress = !item.isComplete && !item.hasError;
    Color accentColor = item.hasError 
        ? const Color(0xFFFF453A) 
        : (item.isComplete ? const Color(0xFF30D158) : const Color(0xFF6C63FF));

    Widget cardContent = Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: item.hasError ? Colors.red.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildFileIcon(item.fileName, accentColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.fileName, 
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(item.direction == "download" ? "Receiving from PC" : "Sending to PC", 
                        style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 12)),
                  ],
                ),
              ),
              Text("${(item.progress * 100).toInt()}%", 
                  style: GoogleFonts.outfit(color: accentColor, fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: item.progress,
              minHeight: 8,
              backgroundColor: Colors.black,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (inProgress) ...[
                Text("⏳ ${item.secondsRemaining}s remaining", 
                    style: GoogleFonts.outfit(color: const Color(0xFF86868B), fontSize: 12)),
                GestureDetector(
                  onTap: () => _confirmCancel(item.id),
                  child: Text("Cancel", style: GoogleFonts.outfit(color: const Color(0xFFFF453A), fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ] else if (item.isComplete) ...[
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF30D158), size: 16),
                    const SizedBox(width: 6),
                    Text("Successful", style: GoogleFonts.outfit(color: const Color(0xFF30D158), fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ] else ...[
                Text("Failed", style: GoogleFonts.outfit(color: const Color(0xFFFF453A), fontSize: 12, fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: () => _showToast("Retrying..."),
                  child: Text("Retry", style: GoogleFonts.outfit(color: const Color(0xFF6C63FF), fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return item.hasError ? ShakeX(child: cardContent) : cardContent;
  }

  Widget _buildFileIcon(String fileName, Color accentColor) {
    IconData icon = Icons.insert_drive_file_rounded;
    String ext = fileName.split('.').last.toLowerCase();
    if (['mp4', 'mov'].contains(ext)) icon = Icons.movie_filter_rounded;
    if (['jpg', 'png'].contains(ext)) icon = Icons.image_rounded;
    if (['mp3', 'wav'].contains(ext)) icon = Icons.music_note_rounded;

    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(color: accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
      child: Center(child: Icon(icon, color: accentColor, size: 24)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ZoomIn(
            child: const Icon(Icons.cloud_done_rounded, color: Color(0xFF6C63FF), size: 80),
          ),
          const SizedBox(height: 24),
          Text("Queue Clean", 
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60),
            child: _buildPrimaryButton("Return Home", () => Navigator.pop(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 56,
        decoration: BoxDecoration(color: const Color(0xFF6C63FF), borderRadius: BorderRadius.circular(100)),
        child: Center(
          child: Text(text, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _confirmCancel(String id) {
    HapticFeedback.vibrate();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text("Stop Transfer?", style: GoogleFonts.outfit(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("No")),
          TextButton(
            onPressed: () {
              setState(() => _currentTransfers.removeWhere((t) => t.id == id));
              Navigator.pop(context);
            }, 
            child: const Text("Stop", style: TextStyle(color: Color(0xFFFF453A)))
          ),
        ],
      ),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}