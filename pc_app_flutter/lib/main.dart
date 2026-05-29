import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/dashboard_screen.dart';
import 'services/theme_service.dart';
import 'services/backend_manager.dart';

/**
 * STARTUP SEQUENCE (FIX 3):
 * 1. App launches → show loading/splash screen (StartupScreen)
 * 2. Start Python subprocess via BackendManager (Captures stdout/stderr)
 * 3. Give Python 1 second to breathe (FIX 6)
 * 4. Wait for /ping to return 200 (Health check loop - FIX 1)
 * 5. If health check passes within 15 seconds:
 *    → Hide loading screen
 *    → Show main dashboard (DashboardScreen)
 *    → Begin normal API calls (FIX 7)
 * 6. If health check fails after 15 seconds:
 *    → Show error screen: "Could not start CYPHER"
 *    → Show "Try Again" button (Restarts sequence)
 *    → Show backend logs (FIX 5)
 */

void main() async {
  // 1. Core initialization
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 2. Initialize Window Manager
    await windowManager.ensureInitialized();

    // 3. Configure Window
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1100, 700),
      minimumSize: Size(900, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: "CYPHER",
    );

    // 4. Show window when ready (Non-blocking)
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    // 5. Launch Flutter UI immediately
    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeService(),
        child: const CypherPC(),
      ),
    );
  } catch (e) {
    debugPrint("Startup Error: $e");
    // Fallback launch
    runApp(ChangeNotifierProvider(create: (_) => ThemeService(), child: const CypherPC()));
  }
}

class CypherPC extends StatelessWidget {
  const CypherPC({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          title: 'CYPHER',
          debugShowCheckedModeBanner: false,
          themeMode: themeService.themeMode,
          theme: ThemeService.lightTheme,
          darkTheme: ThemeService.darkTheme,
          home: const StartupScreen(),
        );
      },
    );
  }
}

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  final BackendManager _backend = BackendManager();
  bool _hasError = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initSystem();
  }

  Future<void> _initSystem() async {
    if (!mounted) return;
    setState(() {
      _isInitializing = true;
      _hasError = false;
    });

    // 1. Start Python subprocess
    final started = await _backend.start();
    if (!started) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasError = true;
        });
      }
      return;
    }

    // 2. Wait for /ping to return 200 (health check loop)
    final ready = await _backend.waitForBackendReady();

    if (ready) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF6C63FF);

    if (_hasError) {
      return Scaffold(
        backgroundColor: const Color(0xFF08080A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
              const SizedBox(height: 24),
              Text(
                "COULD NOT START CYPHER",
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _backend.errorLog.isNotEmpty
                      ? _backend.errorLog.length > 500
                          ? "...${_backend.errorLog.substring(_backend.errorLog.length - 500)}"
                          : _backend.errorLog
                      : "The backend service failed to respond in time.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(fontSize: 10, color: Colors.white24),
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _initSystem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("TRY AGAIN"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF08080A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withOpacity(0.1), width: 1),
              ),
              child: Icon(Icons.shield_moon_outlined, color: accent, size: 64),
            ),
            const SizedBox(height: 48),
            Text(
              "LOADING CYPHER",
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "STARTING UP SYSTEM...",
              style: GoogleFonts.roboto(
                fontSize: 10,
                color: Colors.white24,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 280,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white.withOpacity(0.03),
                valueColor: AlwaysStoppedAnimation(accent),
                minHeight: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
