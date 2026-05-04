import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class MasterControlScreen extends StatefulWidget {
  const MasterControlScreen({super.key});

  @override
  State<MasterControlScreen> createState() => _MasterControlScreenState();
}

class _MasterControlScreenState extends State<MasterControlScreen> {
  // Broadcast Controllers
  final TextEditingController titleController = TextEditingController();
  final TextEditingController msgController = TextEditingController();
  final TextEditingController linkController = TextEditingController();
  final TextEditingController btnController = TextEditingController();
  
  // Metadata Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController versionController = TextEditingController();
  final TextEditingController publisherController = TextEditingController();
  final TextEditingController publisherUrlController = TextEditingController();
  final TextEditingController appIdController = TextEditingController();
  final TextEditingController passController = TextEditingController();

  bool isActive = true;
  bool isSendingBroadcast = false;
  bool isSendingMetadata = false;

  // Production URL for Emerald's Central Hub
  final String hubUrl = "https://cypher-3ctq.onrender.com";
  final String masterKey = "emerald-admin";

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    titleController.dispose();
    msgController.dispose();
    linkController.dispose();
    btnController.dispose();
    nameController.dispose();
    versionController.dispose();
    publisherController.dispose();
    publisherUrlController.dispose();
    appIdController.dispose();
    passController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      // Fetch Broadcast
      final bRes = await http.get(Uri.parse('$hubUrl/api/broadcast'));
      if (bRes.statusCode == 200) {
        final data = jsonDecode(bRes.body);
        setState(() {
          titleController.text = data['title'] ?? "";
          msgController.text = data['message'] ?? "";
          linkController.text = data['link'] ?? "";
          btnController.text = data['link_text'] ?? "Join";
          isActive = data['active'] ?? true;
        });
      }

      // Fetch Metadata
      final mRes = await http.get(Uri.parse('$hubUrl/api/metadata'));
      if (mRes.statusCode == 200) {
        final data = jsonDecode(mRes.body);
        setState(() {
          nameController.text = data['app_name'] ?? "CYPHER";
          versionController.text = data['app_version'] ?? "1.0.0";
          publisherController.text = data['app_publisher'] ?? "Emerald Dev";
          publisherUrlController.text = data['app_publisher_url'] ?? "";
          appIdController.text = data['app_id'] ?? "";
          passController.text = data['master_password'] ?? "emerald-admin";
        });
      }
    } catch (_) {}
  }

  Future<void> _deployBroadcast() async {
    setState(() => isSendingBroadcast = true);
    try {
      await http.post(
        Uri.parse('$hubUrl/master/broadcast'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'key': masterKey,
          'broadcast': {
            'title': titleController.text,
            'message': msgController.text,
            'link': linkController.text,
            'link_text': btnController.text,
            'active': isActive,
          }
        }),
      );
      _showSuccess("Broadcast Deployed Globally");
    } catch (e) {
      _showError("Failed to deploy broadcast");
    }
    setState(() => isSendingBroadcast = false);
  }

  Future<void> _deployMetadata() async {
    setState(() => isSendingMetadata = true);
    try {
      await http.post(
        Uri.parse('$hubUrl/master/metadata'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'key': masterKey,
          'metadata': {
            'app_name': nameController.text,
            'app_version': versionController.text,
            'app_publisher': publisherController.text,
            'app_publisher_url': publisherUrlController.text,
            'app_id': appIdController.text,
            'master_password': passController.text,
          }
        }),
      );
      _showSuccess("Ecosystem Identity Updated");
    } catch (e) {
      _showError("Failed to update metadata");
    }
    setState(() => isSendingMetadata = false);
  }

  void _showSuccess(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("🚀 $msg"), backgroundColor: Colors.green),
      );
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ $msg"), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("MASTER CONTROL", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 2)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection("ANALYTICS"),
            _buildStatCard(),
            
            const SizedBox(height: 32),
            _buildSection("GLOBAL BROADCAST"),
            _buildField("Banner Title", titleController),
            _buildField("Description", msgController, maxLines: 3),
            _buildField("Action Link (WhatsApp/TikTok)", linkController),
            _buildField("Button Label", btnController),
            
            Row(
              children: [
                Switch(
                  value: isActive,
                  onChanged: (v) => setState(() => isActive = v),
                  activeColor: const Color(0xFF6C63FF),
                ),
                Text("Enable banner for all users", style: GoogleFonts.outfit(color: Colors.white)),
              ],
            ),
            
            const SizedBox(height: 20),
            _buildActionButton("DEPLOY BROADCAST", isSendingBroadcast, _deployBroadcast),

            const SizedBox(height: 40),
            _buildSection("ECOSYSTEM IDENTITY (METADATA)"),
            _buildField("App Name", nameController),
            _buildField("App Version", versionController),
            _buildField("Publisher Name", publisherController),
            _buildField("Publisher URL", publisherUrlController),
            _buildField("Inno Setup AppID (PC)", appIdController),
            _buildField("Master Login Password", passController),

            const SizedBox(height: 20),
            _buildActionButton("UPDATE ECOSYSTEM IDENTITY", isSendingMetadata, _deployMetadata, color: Colors.white10),
            
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(label, style: GoogleFonts.outfit(color: const Color(0xFF6C63FF), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
    );
  }

  Widget _buildStatCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          const Text("📊", style: TextStyle(fontSize: 32)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Project Health", style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
              Text("Production", style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildField(String hint, TextEditingController ctrl, {int maxLines = 1}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: GoogleFonts.outfit(color: Colors.white),
        decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.white24), border: InputBorder.none),
      ),
    );
  }

  Widget _buildActionButton(String label, bool loading, VoidCallback action, {Color color = const Color(0xFF6C63FF)}) {
    return GestureDetector(
      onTap: loading ? null : action,
      child: Container(
        height: 60,
        width: double.infinity,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(30)),
        child: Center(
          child: loading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(label, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
