import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class ImageEditorScreen extends StatefulWidget {
  final File imageFile;
  final String pcIpAddress;
  final String authToken;

  const ImageEditorScreen({
    super.key,
    required this.imageFile,
    required this.pcIpAddress,
    required this.authToken,
  });

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  List<Offset?> _points = [];
  bool _isSaving = false;

  String get _baseUrl => "http://${widget.pcIpAddress}:5000";

  Future<void> _syncToPC() async {
    setState(() => _isSaving = true);
    try {
      // 1. Capture the edited image from RepaintBoundary
      RenderRepaintBoundary boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();
      
      // 2. Base64 encode
      String base64Image = "data:image/png;base64,${base64Encode(pngBytes)}";

      // 3. Send to PC Clipboard via Hub
      final response = await http.post(
        Uri.parse('$_baseUrl/clipboard/phone'),
        headers: {
          'X-Auth-Token': widget.authToken,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'text': base64Image}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Synced to PC Clipboard ✓")));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to sync image")));
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text("Edit & Sync", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: () => setState(() => _points = []), icon: const Icon(Icons.refresh_rounded)),
          if (!_isSaving)
            TextButton(
              onPressed: _syncToPC,
              child: Text("SYNC", style: GoogleFonts.outfit(color: const Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
            )
          else
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF)))),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: RepaintBoundary(
                key: _boundaryKey,
                child: Stack(
                  children: [
                    Image.file(widget.imageFile, fit: BoxFit.contain),
                    Positioned.fill(
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            RenderBox renderBox = context.findRenderObject() as RenderBox;
                            _points.add(renderBox.globalToLocal(details.localPosition));
                          });
                        },
                        onPanEnd: (details) => _points.add(null),
                        child: CustomPaint(
                          painter: DrawingPainter(points: _points),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildToolbar(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Color(0xFF111111), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.edit_rounded, color: Color(0xFF6C63FF)),
          const SizedBox(width: 12),
          Text("Highlight with finger to draw", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<Offset?> points;
  DrawingPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = const Color(0xFF6C63FF).withOpacity(0.5)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}
