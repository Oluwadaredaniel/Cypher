import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
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
  // State variables
  String _activeTool = "Select";
  Color _activeColor = const Color(0xFF6C63FF);
  double _zoomScale = 0.85;
  double _brightness = 0.0;
  double _contrast = 1.0;

  // Drawing state
  List<DrawnPath> _paths = [];
  DrawnPath? _currentPath;

  // Tools mapping
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

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeService>(context);
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
                if (MediaQuery.of(context).size.width > 900) _buildPropertiesPanel(accent),
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
              Text("EDITOR_v1.PNG", style: GoogleFonts.roboto(fontSize: 10, color: Colors.white24)),
            ],
          ),
          Row(
            children: [
              _headerBtn("Undo", Icons.undo_rounded, _undo),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Image exported successfully")));
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
          _colorCircle(accent, true),
          _colorCircle(const Color(0xFFFFB786), false),
          _colorCircle(Colors.redAccent, false),
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
      decoration: const BoxDecoration(
        color: Color(0xFF0D141D),
        image: DecorationImage(
          image: AssetImage('assets/images/canvas_dot.png'), // Fallback to pattern
          repeat: ImageRepeat.repeat,
          opacity: 0.1,
        ),
      ),
      child: Center(
        child: InteractiveViewer(
          minScale: 0.1, maxScale: 4.0,
          child: GestureDetector(
            onPanStart: (details) {
              if (_activeTool == "Draw") {
                _currentPath = DrawnPath(color: _activeColor, points: [details.localPosition]);
              }
            },
            onPanUpdate: (details) {
              if (_activeTool == "Draw" && _currentPath != null) {
                setState(() {
                  _currentPath!.points.add(details.localPosition);
                });
              }
            },
            onPanEnd: (details) {
              if (_activeTool == "Draw" && _currentPath != null) {
                setState(() {
                  _paths.add(_currentPath!);
                  _currentPath = null;
                });
              }
            },
            child: Stack(
              children: [
                // The Image with Adjustments
                ColorFiltered(
                  colorFilter: ColorFilter.matrix([
                    _contrast, 0, 0, 0, _brightness * 255,
                    0, _contrast, 0, 0, _brightness * 255,
                    0, 0, _contrast, 0, _brightness * 255,
                    0, 0, 0, 1, 0,
                  ]),
                  child: Hero(
                    tag: 'editor-image',
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF192029),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: widget.imageFile is File
                          ? Image.file(widget.imageFile, fit: BoxFit.contain)
                          : widget.imageFile is Uint8List
                              ? Image.memory(widget.imageFile, fit: BoxFit.contain)
                              : Image.network("https://lh3.googleusercontent.com/aida-public/AB6AXuAVlrajdi-GO-ocIj5JIDZdJNedpuOgWk1g6-f76fuX-ikzXIzvqWWsJVOZ4ONrUjx_0eY3pOEFriGSVuEiuz_5IeKOOXF7Yiu6LFBCNhzgCmDIvPcr40oEZJ9UdUW6SY7H8JoGL_sOONmKxWf1j96Mrtp8m0t-taWSbacMHsK449QMUDM2bVPiFc3RujUDiLmuw564lD0CRYjGL5poFxWM3hGrSF0DrHxTwSr4qGZgEhV2UDTdgZ6ZyAqZezBcQvcN-du5puwPjCs"),
                      ),
                    ),
                  ),
                ),

                // Drawing Layer
                Positioned.fill(
                  child: CustomPaint(
                    painter: CanvasPainter(paths: _paths, currentPath: _currentPath),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
          _bottomIcon(Icons.zoom_out_rounded),
          const SizedBox(width: 12),
          Text("${(_zoomScale * 100).toInt()}%", style: GoogleFonts.roboto(fontSize: 12, color: Colors.white38)),
          const SizedBox(width: 12),
          _bottomIcon(Icons.zoom_in_rounded),
          const SizedBox(width: 32),
          Container(width: 1, height: 24, color: Colors.white10),
          const SizedBox(width: 32),
          _bottomIcon(Icons.layers_rounded, label: "Layers"),
          const SizedBox(width: 32),
          _bottomIcon(Icons.dark_mode_rounded),
        ],
      ),
    );
  }

  Widget _bottomIcon(IconData icon, {String? label}) {
    return Row(
      children: [
        Icon(icon, color: Colors.white24, size: 20),
        if (label != null) ...[
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.roboto(fontSize: 12, color: Colors.white24)),
        ]
      ],
    );
  }

  Widget _buildPropertiesPanel(Color accent) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Color(0xFF080F17),
        border: Border(left: BorderSide(color: Colors.white10)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("ADJUSTMENT", style: GoogleFonts.roboto(fontSize: 10, color: Colors.white24, letterSpacing: 2)),
          const SizedBox(height: 24),
          _propertySlider("Brightness", _brightness, -1.0, 1.0, (v) => setState(() => _brightness = v)),
          const SizedBox(height: 24),
          _propertySlider("Contrast", _contrast, 0.5, 2.0, (v) => setState(() => _contrast = v)),
          const SizedBox(height: 40),
          Text("ANNOTATION STYLE", style: GoogleFonts.roboto(fontSize: 10, color: Colors.white24, letterSpacing: 2)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _styleBtn("Pencil", Icons.edit_rounded, true, accent)),
              const SizedBox(width: 12),
              Expanded(child: _styleBtn("Brush", Icons.brush_rounded, false, accent)),
            ],
          ),
          const Spacer(),
          GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFFFFB786), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Smart Guide", style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.bold)),
                      Text("Snapping is active", style: GoogleFonts.roboto(fontSize: 11, color: Colors.white24)),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _propertySlider(String label, double val, double min, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.roboto(fontSize: 13, color: Colors.white70)),
            Text(val.toStringAsFixed(1), style: GoogleFonts.roboto(fontSize: 12, color: const Color(0xFF6C63FF))),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            activeTrackColor: const Color(0xFF6C63FF),
            inactiveTrackColor: Colors.white10,
            thumbColor: Colors.white,
            overlayColor: const Color(0xFF6C63FF).withOpacity(0.1),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(value: val, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }

  Widget _styleBtn(String label, IconData icon, bool active, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: active ? accent.withOpacity(0.1) : Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? accent.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: active ? accent : Colors.white24, size: 20),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.roboto(fontSize: 8, color: active ? Colors.white : Colors.white24)),
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
    for (var path in paths) {
      _drawPath(canvas, path);
    }
    if (currentPath != null) {
      _drawPath(canvas, currentPath!);
    }
  }

  void _drawPath(Canvas canvas, DrawnPath drawnPath) {
    if (drawnPath.points.length < 2) return;

    final paint = Paint()
      ..color = drawnPath.color
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(drawnPath.points.first.dx, drawnPath.points.first.dy);
    for (var i = 1; i < drawnPath.points.length; i++) {
      path.lineTo(drawnPath.points[i].dx, drawnPath.points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
