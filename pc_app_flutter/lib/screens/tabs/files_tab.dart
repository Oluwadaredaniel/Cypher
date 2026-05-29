import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/glass_container.dart';

class FilesTab extends StatelessWidget {
  final bool isDark;
  final Color accent;
  final List<dynamic> sharedFolders;
  final VoidCallback onAddFolder;
  final Function(String) onRemoveFolder;

  const FilesTab({
    super.key,
    required this.isDark,
    required this.accent,
    required this.sharedFolders,
    required this.onAddFolder,
    required this.onRemoveFolder,
  });

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
              _buildHeader("Shared Folders", "Manage directories accessible from your phone."),
              _actionBtn("Add Folder", Icons.create_new_folder_rounded, onAddFolder),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: GlassContainer(
                  padding: const EdgeInsets.all(28),
                  height: 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                child: Icon(Icons.storage_rounded, color: accent, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text("Sharing Hub", style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text("${sharedFolders.length} active locations shared with your phone.", style: GoogleFonts.roboto(fontSize: 13, color: isDark ? Colors.white30 : Colors.black38)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Sync Status", style: GoogleFonts.roboto(fontSize: 9, color: isDark ? Colors.white24 : Colors.black26)),
                                Row(
                                  children: [
                                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Text("Online", style: GoogleFonts.roboto(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                                  ],
                                )
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(value: 1.0, minHeight: 2, backgroundColor: isDark ? Colors.white10 : Colors.black12, valueColor: AlwaysStoppedAnimation(accent)),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 8,
                child: GlassContainer(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02), border: Border(bottom: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black12))),
                        child: Row(
                          children: [
                            Expanded(child: Text("FOLDER LOCATION", style: GoogleFonts.roboto(fontSize: 9, color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 48),
                            Text("ACTION", style: GoogleFonts.roboto(fontSize: 9, color: isDark ? Colors.white24 : Colors.black26, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      if (sharedFolders.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(40),
                          child: Text("No folders shared yet.", style: GoogleFonts.roboto(color: isDark ? Colors.white24 : Colors.black26)),
                        )
                      else
                        ...sharedFolders.map((f) => _folderRow(f['name'], f['path'])).toList(),
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

  Widget _buildHeader(String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Text("LIVE CONNECTION", style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 2)),
          ],
        ),
        const SizedBox(height: 8),
        Text(title, style: GoogleFonts.roboto(fontSize: 32, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
        Text(sub, style: GoogleFonts.roboto(fontSize: 14, color: isDark ? Colors.white24 : Colors.black38)),
      ],
    );
  }

  Widget _actionBtn(String label, IconData icon, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _folderRow(String name, String path) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black12))),
      child: Row(
        children: [
          Icon(Icons.folder_rounded, color: accent, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                Text(path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(fontSize: 9, color: isDark ? Colors.white12 : Colors.black12)),
              ],
            ),
          ),
          const SizedBox(width: 48),
          IconButton(
            onPressed: () => onRemoveFolder(path),
            icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.withOpacity(0.6), size: 18),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}
