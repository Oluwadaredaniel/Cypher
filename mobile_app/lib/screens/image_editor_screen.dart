import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../widgets/glass_container.dart';

class ImageEditorScreen extends StatefulWidget {
  final dynamic imageFile;
  final String pcIpAddress;
  final String authToken;

  const ImageEditorScreen({super.key, this.imageFile, required this.pcIpAddress, required this.authToken});

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  String _activeTool = "Select";
  Color _activeColor = const Color(0xFF6C63FF);
  double _zoomScale = 1.0;
  double _brightness = 0.0;
  double _contrast = 1.0;

  List<DrawnPath> _paths = [];
  DrawnPath? _currentPath;

  // Crop state
  Rect _cropRect = const Rect.fromLTWH(50, 50, 200, 200);
  bool _isResizingCrop = false;
  String? _currentHandle;

  final List<Map<String, dynamic>> _tools = [
    {"id": "Select", "icon": Icons.near_me_rounded},
    {"id": "Crop", "icon": Icons.crop_rounded},
    {"id": "Draw", "icon": Icons.gesture_rounded},
    {"id": "Text", "icon": Icons.text_fields_rounded},
    {"id": "Shape", "icon": Icons.square_rounded},
  ];

  void _handleToolChange(String id) {
    HapticFeedback.lightImpact();
    setState(() => _activeTool = id);
  }

  void _undo() {
    if (_paths.isNotEmpty) {
      setState(() => _paths.removeLast());
    }
  }

  void _updateCropRect(Offset delta, String? handle) {
    setState(() {
      if (handle == null) {
        _cropRect = _cropRect.shift(delta);
      } else {
        double left = _cropRect.left;
        double top = _cropRect.top;
        double right = _cropRect.right;
        double bottom = _cropRect.bottom;

        if (handle.contains('top')) top += delta.dy;
        if (handle.contains('bottom')) bottom += delta.dy;
        if (handle.contains('left')) left += delta.dx;
        if (handle.contains('right')) right += delta.dx;

        // Ensure minimum size
        if (right - left < 50) return;
        if (bottom - top < 50) return;

        _cropRect = Rect.fromLTRB(left, top, right, bottom);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF6C63FF);

    return Scaffold(
      backgroundColor: const Color(0xFF0D141D),
      body: Column(
        children: [
          _buildHeader(accent),
          Expanded(
            child: Row(
              children: [
                _buildSidebar(accent),
                Expanded(child: _buildCanvasArea(accent)),
              ],
            ),
          ),
          _buildBottomActions(accent),
        ],
      ),
    );
  }

  Widget _buildHeader(Color accent) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF080F17).withOpacity(0.8),
        border: const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: accent),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Text("CYPHER", style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w800, color: accent, letterSpacing: -1)),
              const SizedBox(width: 16),
              Container(width: 1, height: 16, color: Colors.white10),
              const SizedBox(width: 16),
              Text("IMAGE_EDITOR.PNG", style: GoogleFonts.roboto(fontSize: 10, color: Colors.white24)),
            ],
          ),
          Row(
            children: [
              _headerBtn("Undo", Icons.undo_rounded, _undo),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Changes applied and saved")));
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: accent.withOpacity(0.3), blurRadius: 10)],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text("Export", style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerBtn(String label, IconData icon, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.roboto(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(Color accent) {
    return Container(
      width: 72,
      decoration: const BoxDecoration(
        color: Color(0xFF080F17),
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          ..._tools.map((t) => _toolBtn(t['id'], t['icon'], accent)).toList(),
          const Spacer(),
          _colorCircle(accent, _activeColor == accent),
          _colorCircle(const Color(0xFFFFB786), _activeColor == const Color(0xFFFFB786)),
          _colorCircle(Colors.redAccent, _activeColor == Colors.redAccent),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _toolBtn(String id, IconData icon, Color accent) {
    bool active = _activeTool == id;
    return GestureDetector(
      onTap: () => _handleToolChange(id),
      child: Container(
        width: 48, height: 48,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: active ? accent.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: active ? accent : Colors.white24, size: 22),
      ),
    );
  }

  Widget _colorCircle(Color color, bool active) {
    return GestureDetector(
      onTap: () => setState(() => _activeColor = color),
      child: Container(
        width: 24, height: 24,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: active ? 2 : 0),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)],
        ),
      ),
    );
  }

  Widget _buildCanvasArea(Color accent) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF0D141D)),
      child: Center(
        child: GestureDetector(
          onPanStart: (details) {
            if (_activeTool == "Draw") {
              _currentPath = DrawnPath(color: _activeColor, points: [details.localPosition]);
            } else if (_activeTool == "Crop") {
              _checkCropHandle(details.localPosition);
            }
          },
          onPanUpdate: (details) {
            if (_activeTool == "Draw" && _currentPath != null) {
              setState(() => _currentPath!.points.add(details.localPosition));
            } else if (_activeTool == "Crop") {
              _updateCropRect(details.delta, _currentHandle);
            }
          },
          onPanEnd: (details) {
            if (_activeTool == "Draw" && _currentPath != null) {
              setState(() {
                _paths.add(_currentPath!);
                _currentPath = null;
              });
            } else if (_activeTool == "Crop") {
              _currentHandle = null;
            }
          },
          child: Stack(
            children: [
              // Background Image
              ColorFiltered(
                colorFilter: ColorFilter.matrix([
                  _contrast, 0, 0, 0, _brightness * 255,
                  0, _contrast, 0, 0, _brightness * 255,
                  0, 0, _contrast, 0, _brightness * 255,
                  0, 0, 0, 1, 0,
                ]),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: const Color(0xFF192029), borderRadius: BorderRadius.circular(12)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildImageSource(),
                  ),
                ),
              ),

              // Annotation Layer
              Positioned.fill(
                child: CustomPaint(
                  painter: CanvasPainter(paths: _paths, currentPath: _currentPath),
                ),
              ),

              // Crop Overlay
              if (_activeTool == "Crop")
                Positioned.fill(
                  child: CustomPaint(
                    painter: CropPainter(cropRect: _cropRect),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSource() {
    if (widget.imageFile is File) return Image.file(widget.imageFile, fit: BoxFit.contain);
    if (widget.imageFile is Uint8List) return Image.memory(widget.imageFile, fit: BoxFit.contain);
    if (widget.imageFile is String) {
       return Image.network(
        widget.imageFile,
        headers: {'X-Auth-Token': widget.authToken},
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 50, color: Colors.white24),
      );
    }
    return const Icon(Icons.image_not_supported, size: 50, color: Colors.white24);
  }

  void _checkCropHandle(Offset localPosition) {
    const handleSize = 20.0;
    if ((localPosition - _cropRect.topLeft).distance < handleSize) _currentHandle = "topleft";
    else if ((localPosition - _cropRect.topRight).distance < handleSize) _currentHandle = "topright";
    else if ((localPosition - _cropRect.bottomLeft).distance < handleSize) _currentHandle = "bottomleft";
    else if ((localPosition - _cropRect.bottomRight).distance < handleSize) _currentHandle = "bottomright";
    else if (_cropRect.contains(localPosition)) _currentHandle = null; // Move
    else _currentHandle = "none"; // Outside
  }

  Widget _buildBottomActions(Color accent) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF080F17).withOpacity(0.8),
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.zoom_out_rounded, color: Colors.white24), onPressed: () => setState(() => _zoomScale -= 0.1)),
          Text("${(_zoomScale * 100).toInt()}%", style: GoogleFonts.roboto(fontSize: 12, color: Colors.white38)),
          IconButton(icon: const Icon(Icons.zoom_in_rounded, color: Colors.white24), onPressed: () => setState(() => _zoomScale += 0.1)),
          const SizedBox(width: 32),
          Container(width: 1, height: 24, color: Colors.white10),
          const SizedBox(width: 32),
          Icon(Icons.layers_rounded, color: accent, size: 20),
          const SizedBox(width: 8),
          Text("LAYER 0", style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38)),
        ],
      ),
    );
  }
}

class DrawnPath {
  final Color color;
  final List<Offset> points;
  DrawnPath({required this.color, required this.points});
}

class CanvasPainter extends CustomPainter {
  final List<DrawnPath> paths;
  final DrawnPath? currentPath;
  CanvasPainter({required this.paths, this.currentPath});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 3.0..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    for (var path in paths) {
      paint.color = path.color;
      if (path.points.length < 2) continue;
      for (int i = 0; i < path.points.length - 1; i++) {
        canvas.drawLine(path.points[i], path.points[i + 1], paint);
      }
    }
    if (currentPath != null && currentPath!.points.length >= 2) {
      paint.color = currentPath!.color;
      for (int i = 0; i < currentPath!.points.length - 1; i++) {
        canvas.drawLine(currentPath!.points[i], currentPath!.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CropPainter extends CustomPainter {
  final Rect cropRect;
  CropPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.5)..style = PaintingStyle.fill;

    // Dim background outside crop
    canvas.drawPath(Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRect(cropRect)), paint);

    // Draw crop border
    final borderPaint = Paint()..color = const Color(0xFF6C63FF)..strokeWidth = 2.0..style = PaintingStyle.stroke;
    canvas.drawRect(cropRect, borderPaint);

    // Draw handles
    final handlePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawCircle(cropRect.topLeft, 6, handlePaint);
    canvas.drawCircle(cropRect.topRight, 6, handlePaint);
    canvas.drawCircle(cropRect.bottomLeft, 6, handlePaint);
    canvas.drawCircle(cropRect.bottomRight, 6, handlePaint);
  }

  @override
  bool shouldRepaint(covariant CropPainter oldDelegate) => true;
}
