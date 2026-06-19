import 'package:flutter/material.dart';
import '../theme/colors.dart';

class FileIcon extends StatelessWidget {
  final String name;
  final bool isDir;
  final double size;

  const FileIcon({super.key, required this.name, this.isDir = false, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = isDir
        ? (Icons.folder_rounded, const Color(0xFFF59E0B))
        : _iconForExtension(name.split('.').last.toLowerCase());

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }

  static (IconData, Color) _iconForExtension(String ext) {
    return switch (ext) {
      'pdf'                         => (Icons.picture_as_pdf_rounded, const Color(0xFFEF4444)),
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' || 'bmp' || 'svg'
                                    => (Icons.image_rounded, const Color(0xFF22C55E)),
      'mp4' || 'mkv' || 'avi' || 'mov' || 'wmv' || 'webm'
                                    => (Icons.play_circle_rounded, const Color(0xFF8B5CF6)),
      'mp3' || 'wav' || 'flac' || 'aac' || 'm4a'
                                    => (Icons.music_note_rounded, const Color(0xFF3B82F6)),
      'zip' || 'rar' || '7z' || 'tar' || 'gz'
                                    => (Icons.folder_zip_rounded, const Color(0xFFF59E0B)),
      'doc' || 'docx'               => (Icons.article_rounded, const Color(0xFF3B82F6)),
      'xls' || 'xlsx'               => (Icons.table_chart_rounded, const Color(0xFF22C55E)),
      'ppt' || 'pptx'               => (Icons.slideshow_rounded, const Color(0xFFF97316)),
      'txt' || 'md'                 => (Icons.text_snippet_rounded, CypherColors.textSecondary),
      'dart' || 'py' || 'js' || 'ts' || 'kt' || 'java' || 'cpp' || 'c' || 'h'
                                    => (Icons.code_rounded, const Color(0xFF8B5CF6)),
      'apk'                         => (Icons.android_rounded, const Color(0xFF22C55E)),
      'exe' || 'msi'                => (Icons.window_rounded, const Color(0xFF3B82F6)),
      _                             => (Icons.insert_drive_file_rounded, CypherColors.textMuted),
    };
  }
}
