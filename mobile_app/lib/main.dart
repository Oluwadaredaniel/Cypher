import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/central_service.dart';
import 'screens/send_to_pc_screen.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

// Existing Screen Imports
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/pairing_screen.dart';
import 'screens/home_screen.dart';
import 'screens/file_browser_screen.dart';

// New Feature Screen Imports
import 'screens/controls_screen.dart';
import 'screens/clipboard_screen.dart';
import 'screens/guest_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/disconnected_screen.dart';
import 'screens/send_to_pc_screen.dart';
import 'screens/transfer_progress_screen.dart';
import 'screens/file_preview_screen.dart';
import 'screens/connection_screen.dart';
import 'screens/guide_screen.dart';
import 'screens/master_control_screen.dart';
import 'screens/process_manager_screen.dart';
import 'screens/app_launcher_screen.dart';
import 'screens/active_tasks_screen.dart';
import 'screens/screen_recorder_screen.dart';
import 'screens/image_editor_screen.dart';
import 'dart:async';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class SharingWrapper extends StatefulWidget {
  final Widget child;
  const SharingWrapper({super.key, required this.child});

  @override
  State<SharingWrapper> createState() => _SharingWrapperState();
}

class _SharingWrapperState extends State<SharingWrapper> {
  static const platform = MethodChannel('app/share');

  @override
  void initState() {
    super.initState();
    _initNativeShareListener();
  }

  void _initNativeShareListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == "onSharedFiles") {
        final List<dynamic> files = call.arguments;
        _handleSharedMedia(files.cast<String>());
      }
    });

    // Check for initial sharing data (if app was opened via intent)
    platform.invokeMethod('getSharedFiles').then((files) {
      if (files != null) {
        _handleSharedMedia(List<String>.from(files));
      }
    });
  }

  void _handleSharedMedia(List<String> files) async {
    if (files.isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('pc_ip_address') ?? '';
    final token = prefs.getString('auth_token') ?? '';

    if (ip.isEmpty || token.isEmpty) return;

    navigatorKey.currentState?.pushNamed('/send', arguments: {
      'pcIpAddress': ip,
      'authToken': token,
      'sharedFiles': files,
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ip = prefs.getString('pc_ip_address') ?? '';
      final token = prefs.getString('auth_token') ?? '';
      
      if (ip.isEmpty || token.isEmpty) return true;

      final response = await http.get(
        Uri.parse('http://$ip:5000/battery/status'),
        headers: {'X-Auth-Token': token},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['is_critical'] == true) {
          // In a real app, use flutter_local_notifications here
          print("ALERT: PC Battery is low! (${data['percent']}%)");
        }
      }
    } catch (e) {
      print("Background check failed: $e");
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    FirebaseAnalytics.instance.logAppOpen();
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }
  
  // Analytics: Report Install to Emerald's Central Hub
  await CentralService.reportInstall();

  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  Workmanager().registerPeriodicTask(
    "cypher-battery-check",
    "checkBatteryStatus",
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
  );

  runApp(const CypherApp());
}

class CypherApp extends StatelessWidget {
  const CypherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CYPHER',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6C63FF),
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme),
      ),
      builder: (context, child) => SharingWrapper(child: child!),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return CustomPageRoute(
              settings: settings,
              builder: (context) => const SplashScreen(),
            );

          case '/onboarding':
            return CustomPageRoute(
              settings: settings,
              builder: (context) => const OnboardingScreen(),
            );

          case '/setup':
            return CustomPageRoute(
              settings: settings,
              builder: (context) => const SetupScreen(),
            );

          case '/connection':
            return CustomPageRoute(
              settings: settings,
              builder: (context) => const ConnectionScreen(),
            );

          case '/pairing':
            final args = settings.arguments as Map<String, dynamic>?;
            return CustomPageRoute(
              settings: settings,
              builder: (context) => PairingScreen(pcIpAddress: args?['pcIpAddress'] ?? ''),
            );

          case '/home':
            final args = settings.arguments as Map<String, dynamic>?;
            return CustomPageRoute(
              settings: settings,
              builder: (context) => HomeScreen(
                pcIpAddress: args?['pcIpAddress'] ?? '',
                authToken: args?['authToken'] ?? '',
              ),
            );

          case '/browser':
            final args = settings.arguments as Map<String, dynamic>?;
            return CustomPageRoute(
              settings: settings,
              builder: (context) => FileBrowserScreen(
                pcIpAddress: args?['pcIpAddress'] ?? '',
                authToken: args?['authToken'] ?? '',
                initialPath: args?['initialPath'],
              ),
            );

          case '/send':
            final args = settings.arguments as Map<String, dynamic>?;
            return CustomPageRoute(
              settings: settings,
              builder: (context) => SendToPCScreen(
                pcIpAddress: args?['pcIpAddress'] ?? '',
                authToken: args?['authToken'] ?? '',
                preSelectedFile: args?['preSelectedFile'],
                sharedFiles: args?['sharedFiles'],
              ),
            );

          case '/controls':
            final args = settings.arguments as Map<String, dynamic>?;
            return CustomPageRoute(
              settings: settings,
              builder: (context) => ControlsScreen(
                pcIpAddress: args?['pcIpAddress'] ?? '',
                authToken: args?['authToken'] ?? '',
              ),
            );

          case '/clipboard':
            final args = settings.arguments as Map<String, dynamic>?;
            return CustomPageRoute(
              settings: settings,
              builder: (context) => ClipboardScreen(
                pcIpAddress: args?['pcIpAddress'] ?? '',
                authToken: args?['authToken'] ?? '',
              ),
            );

          case '/guest':
            final args = settings.arguments as Map<String, dynamic>?;
            return CustomPageRoute(
              settings: settings,
              builder: (context) => GuestScreen(
                pcIpAddress: args?['pcIpAddress'] ?? '',
                authToken: args?['authToken'] ?? '',
              ),
            );

          case '/activity':
            final args = settings.arguments as Map<String, dynamic>?;
            return CustomPageRoute(
              settings: settings,
              builder: (context) => ActivityScreen(
                pcIpAddress: args?['pcIpAddress'] ?? '',
                authToken: args?['authToken'] ?? '',
              ),
            );

          case '/notifications':
            final args = settings.arguments as Map<String, dynamic>?;
            return CustomPageRoute(
              settings: settings,
              builder: (context) => NotificationScreen(
                pcIpAddress: args?['pcIpAddress'] ?? '',
                authToken: args?['authToken'] ?? '',
              ),
            );

          case '/settings':
            final args = settings.arguments as Map<String, dynamic>?;
            return CustomPageRoute(
              settings: settings,
              builder: (context) => SettingsScreen(
                pcIpAddress: args?['pcIpAddress'] ?? '',
                authToken: args?['authToken'] ?? '',
              ),
            );

          case '/disconnected':
            final args = settings.arguments as Map<String, dynamic>?;
            return CustomPageRoute(
              settings: settings,
              builder: (context) => DisconnectedScreen(
                pcIpAddress: args?['pcIpAddress'] ?? '',
                authToken: args?['authToken'] ?? '',
                onReconnected: () => Navigator.pushReplacementNamed(context, '/home'),
              ),
            );

          case '/preview':
            final args = settings.arguments as Map<String, dynamic>?;
            return CustomPageRoute(
              settings: settings,
              builder: (context) => FilePreviewScreen(
                pcIpAddress: args?['pcIpAddress'] ?? '',
                authToken: args?['authToken'] ?? '',
                filePath: args?['filePath'] ?? '',
                fileName: args?['fileName'] ?? '',
                fileSize: args?['fileSize'] ?? 0,
                fileExtension: args?['fileExtension'] ?? '',
              ),
            );

          case '/transfers':
            final args = settings.arguments as Map<String, dynamic>?;
            return CustomPageRoute(
              settings: settings,
              builder: (context) => TransferProgressScreen(
                pcIpAddress: args?['pcIpAddress'] ?? '',
                authToken: args?['authToken'] ?? '',
                transfers: args?['transfers'] ?? [],
              ),
            );

          case '/guide':
            return CustomPageRoute(
              settings: settings,
              builder: (context) => const GuideScreen(),
            );

          case '/master_control':
            return CustomPageRoute(
              settings: settings,
              builder: (context) => const MasterControlScreen(),
            );

          case '/processes':
            final args = settings.arguments as Map<String, dynamic>?;
            return CustomPageRoute(
              settings: settings,
              builder: (context) => ProcessManagerScreen(
                pcIpAddress: args?['pcIpAddress'] ?? '',
                authToken: args?['authToken'] ?? '',
              ),
            );

          case '/apps_launcher':
            final args = settings.arguments as Map<String, dynamic>?;
            return CustomPageRoute(
              settings: settings,
              builder: (context) => AppLauncherScreen(
                pcIpAddress: args?['pcIpAddress'] ?? '',
                authToken: args?['authToken'] ?? '',
              ),
            );

          case '/active_tasks':
            final args = settings.arguments as Map<String, dynamic>?;
            return CustomPageRoute(
              settings: settings,
              builder: (context) => ActiveTasksScreen(
                pcIpAddress: args?['pcIpAddress'] ?? '',
                authToken: args?['authToken'] ?? '',
              ),
            );

          case '/recorder':
            final args = settings.arguments as Map<String, dynamic>?;
            return CustomPageRoute(
              settings: settings,
              builder: (context) => ScreenRecorderScreen(
                pcIpAddress: args?['pcIpAddress'] ?? '',
                authToken: args?['authToken'] ?? '',
              ),
            );

          case '/image_editor':
            final args = settings.arguments as Map<String, dynamic>?;
            return CustomPageRoute(
              settings: settings,
              builder: (context) => ImageEditorScreen(
                imageFile: args?['imageFile'],
                pcIpAddress: args?['pcIpAddress'] ?? '',
                authToken: args?['authToken'] ?? '',
              ),
            );

          default:
            return CustomPageRoute(
              settings: settings,
              builder: (context) => const SplashScreen(),
            );
        }
      },
    );
  }
}

class CustomPageRoute extends PageRouteBuilder {
  final Widget Function(BuildContext) builder;
  @override
  final RouteSettings settings;

  CustomPageRoute({required this.builder, required this.settings})
      : super(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutQuart;

            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        );
}