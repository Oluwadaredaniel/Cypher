import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'theme/app_theme.dart';
import 'providers/connection_provider.dart';
import 'providers/file_provider.dart';
import 'providers/system_provider.dart';

import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/connection_screen.dart';
import 'screens/pairing_screen.dart';
import 'screens/home_screen.dart';
import 'screens/file_browser_screen.dart';
import 'screens/file_preview_screen.dart';
import 'screens/controls_screen.dart';
import 'screens/clipboard_screen.dart';
import 'screens/guest_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/disconnected_screen.dart';
import 'screens/send_to_pc_screen.dart';
import 'screens/transfer_progress_screen.dart';
import 'screens/guide_screen.dart';
import 'screens/master_control_screen.dart';
import 'screens/process_manager_screen.dart';
import 'screens/app_launcher_screen.dart';
import 'screens/active_tasks_screen.dart';
import 'screens/screen_recorder_screen.dart';
import 'screens/phone_browser_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/drop_zone_screen.dart';
import 'screens/wake_on_lan_screen.dart';
import 'screens/clipboard_history_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0F0F11),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Request permissions for file operations
  await _requestPermissions();

  runApp(const CypherApp());
}

Future<void> _requestPermissions() async {
  try {
    final permissions = [
      Permission.storage,           // Read/Write files
      Permission.manageExternalStorage, // Full storage access (Android 11+)
      Permission.camera,            // Camera for potential future features
      Permission.locationWhenInUse, // Location for local network discovery
      Permission.photos,            // Photo access for screenshots
      Permission.mediaLibrary,      // Media access
    ];

    // Request all permissions
    final statuses = await permissions.request();

    // Log permission status for debugging
    for (final status in statuses.entries) {
      if (status.value.isDenied) {
        print('Permission ${status.key} denied');
      } else if (status.value.isPermanentlyDenied) {
        print('Permission ${status.key} permanently denied - open app settings');
      }
    }
  } catch (e) {
    print('Error requesting permissions: $e');
  }
}

class CypherApp extends StatelessWidget {
  const CypherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionProvider()..init()),
        ChangeNotifierProvider(create: (_) => FileProvider()),
        ChangeNotifierProvider(create: (_) => SystemProvider()),
      ],
      child: MaterialApp(
        title: 'CYPHER',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        initialRoute: '/',
        onGenerateRoute: _generateRoute,
      ),
    );
  }

  static Route<dynamic>? _generateRoute(RouteSettings s) {
    Widget page;

    switch (s.name) {
      case '/':
        page = const SplashScreen();
      case '/onboarding':
        page = const OnboardingScreen();
      case '/setup':
        page = const SetupScreen();
      case '/connection':
        page = const ConnectionScreen();
      case '/pairing':
        page = const PairingScreen();
      case '/home':
        page = const HomeScreen();
      case '/browser':
        final a = s.arguments as Map<String, dynamic>?;
        page = FileBrowserScreen(initialPath: a?['path']);
      case '/preview':
        final a = s.arguments as Map<String, dynamic>? ?? {};
        page = FilePreviewScreen(
          filePath:  a['filePath']  ?? '',
          fileName:  a['fileName']  ?? '',
          fileSize:  a['fileSize']  ?? 0,
          fileExtension: a['fileExtension'] ?? '',
        );
      case '/controls':
        page = const ControlsScreen();
      case '/clipboard':
        page = const ClipboardScreen();
      case '/guest':
        page = const GuestScreen();
      case '/activity':
        page = const ActivityScreen();
      case '/notifications':
        page = const NotificationScreen();
      case '/settings':
        page = const SettingsScreen();
      case '/disconnected':
        page = const DisconnectedScreen();
      case '/send':
        final a = s.arguments as Map<String, dynamic>?;
        page = SendToPCScreen(sharedFiles: a?['sharedFiles']);
      case '/transfers':
        page = const TransferProgressScreen();
      case '/guide':
        page = const GuideScreen();
      case '/master_control':
        page = const MasterControlScreen();
      case '/processes':
        page = const ProcessManagerScreen();
      case '/apps_launcher':
        page = const AppLauncherScreen();
      case '/active_tasks':
        page = const ActiveTasksScreen();
      case '/recorder':
        page = const ScreenRecorderScreen();
      case '/phone_browser':
        page = const PhoneBrowserScreen();
      case '/drop':
        page = const DropZoneScreen();
      case '/wol':
        page = const WakeOnLanScreen();
      case '/clipboard-history':
        page = const ClipboardHistoryScreen();
      default:
        page = const SplashScreen();
    }

    return PageRouteBuilder(
      settings: s,
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 150),
      transitionsBuilder: (_, anim, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }
}