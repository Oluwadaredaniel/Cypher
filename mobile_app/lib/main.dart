import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/central_service.dart';
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
import 'screens/remote_view_screen.dart';
import 'screens/remote_keyboard_screen.dart';
import 'screens/phone_browser_screen.dart';
import 'services/socket_service.dart';
import 'services/theme_service.dart';
import 'package:provider/provider.dart';
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

  final SocketService _socketService = SocketService();

  @override
  void initState() {
    super.initState();
    _initNativeShareListener();
    _initConnectionMonitor();
  }

  void _initConnectionMonitor() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('pc_ip_address') ?? '';
    final token = prefs.getString('auth_token') ?? '';

    if (ip.isNotEmpty && token.isNotEmpty) {
      _socketService.connect(ip, token);
      _socketService.connectionStatus.listen((isConnected) {
        if (!isConnected && mounted) {
           // Basic logic to prevent pushing if already disconnected or on splash
           final currentRoute = ModalRoute.of(context)?.settings.name;
           if (currentRoute != '/' && currentRoute != '/disconnected') {
             navigatorKey.currentState?.pushNamed('/disconnected', arguments: {
               'pcIpAddress': ip,
               'authToken': token,
             });
           }
        }
      });
    }
  }

  void _initNativeShareListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == "onSharedFiles") {
        final List<dynamic> files = call.arguments;
        _handleSharedMedia(files.cast<String>());
      }
      return null;
    });

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
  
  try {
    await Firebase.initializeApp();
    FirebaseAnalytics.instance.logAppOpen();
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }
  
  await CentralService.reportInstall();

  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  Workmanager().registerPeriodicTask(
    "cypher-battery-check",
    "checkBatteryStatus",
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: const CypherApp(),
    ),
  );
}

class CypherApp extends StatelessWidget {
  const CypherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          title: 'CYPHER',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          themeMode: themeService.themeMode,
          theme: ThemeService.lightTheme,
          darkTheme: ThemeService.darkTheme,
          builder: (context, child) => SharingWrapper(child: child!),
          initialRoute: '/',
          onGenerateRoute: (settings) {
            final args = settings.arguments as Map<String, dynamic>?;

            switch (settings.name) {
              case '/':
                return CustomPageRoute(settings: settings, builder: (context) => const SplashScreen());
              case '/onboarding':
                return CustomPageRoute(settings: settings, builder: (context) => const OnboardingScreen());
              case '/setup':
                return CustomPageRoute(settings: settings, builder: (context) => const SetupScreen());
              case '/connection':
                return CustomPageRoute(settings: settings, builder: (context) => const ConnectionScreen());
              case '/pairing':
                return CustomPageRoute(settings: settings, builder: (context) => PairingScreen(pcIpAddress: args?['pcIpAddress'] ?? ''));
              case '/home':
                return CustomPageRoute(settings: settings, builder: (context) => HomeScreen(pcIpAddress: args?['pcIpAddress'] ?? '', authToken: args?['authToken'] ?? ''));
              case '/browser':
                return CustomPageRoute(settings: settings, builder: (context) => FileBrowserScreen(pcIpAddress: args?['pcIpAddress'] ?? '', authToken: args?['authToken'] ?? '', initialPath: args?['initialPath']));
              case '/send':
                return CustomPageRoute(settings: settings, builder: (context) => SendToPCScreen(pcIpAddress: args?['pcIpAddress'] ?? '', authToken: args?['authToken'] ?? '', preSelectedFile: args?['preSelectedFile'], sharedFiles: args?['sharedFiles']));
              case '/controls':
                return CustomPageRoute(settings: settings, builder: (context) => ControlsScreen(pcIpAddress: args?['pcIpAddress'] ?? '', authToken: args?['authToken'] ?? ''));
              case '/clipboard':
                return CustomPageRoute(settings: settings, builder: (context) => ClipboardScreen(pcIpAddress: args?['pcIpAddress'] ?? '', authToken: args?['authToken'] ?? ''));
              case '/guest':
                return CustomPageRoute(settings: settings, builder: (context) => GuestScreen(pcIpAddress: args?['pcIpAddress'] ?? '', authToken: args?['authToken'] ?? ''));
              case '/activity':
                return CustomPageRoute(settings: settings, builder: (context) => ActivityScreen(pcIpAddress: args?['pcIpAddress'] ?? '', authToken: args?['authToken'] ?? ''));
              case '/notifications':
                return CustomPageRoute(settings: settings, builder: (context) => NotificationScreen(pcIpAddress: args?['pcIpAddress'] ?? '', authToken: args?['authToken'] ?? ''));
              case '/settings':
                return CustomPageRoute(settings: settings, builder: (context) => SettingsScreen(pcIpAddress: args?['pcIpAddress'] ?? '', authToken: args?['authToken'] ?? ''));
              case '/disconnected':
                return CustomPageRoute(settings: settings, builder: (context) => DisconnectedScreen(pcIpAddress: args?['pcIpAddress'] ?? '', authToken: args?['authToken'] ?? '', onReconnected: () => Navigator.pushReplacementNamed(context, '/home')));
              case '/preview':
                return CustomPageRoute(settings: settings, builder: (context) => FilePreviewScreen(pcIpAddress: args?['pcIpAddress'] ?? '', authToken: args?['authToken'] ?? '', filePath: args?['filePath'] ?? '', fileName: args?['fileName'] ?? '', fileSize: args?['fileSize'] ?? 0, fileExtension: args?['fileExtension'] ?? ''));
              case '/transfers':
                return CustomPageRoute(settings: settings, builder: (context) => TransferProgressScreen(pcIpAddress: args?['pcIpAddress'] ?? '', authToken: args?['authToken'] ?? '', transfers: args?['transfers'] ?? []));
              case '/guide':
                return CustomPageRoute(settings: settings, builder: (context) => const GuideScreen());
              case '/master_control':
                return CustomPageRoute(settings: settings, builder: (context) => const MasterControlScreen());
              case '/processes':
                return CustomPageRoute(settings: settings, builder: (context) => ProcessManagerScreen(pcIpAddress: args?['pcIpAddress'] ?? '', authToken: args?['authToken'] ?? ''));
              case '/apps_launcher':
                return CustomPageRoute(settings: settings, builder: (context) => AppLauncherScreen(pcIpAddress: args?['pcIpAddress'] ?? '', authToken: args?['authToken'] ?? ''));
              case '/active_tasks':
                return CustomPageRoute(settings: settings, builder: (context) => ActiveTasksScreen(pcIpAddress: args?['pcIpAddress'] ?? '', authToken: args?['authToken'] ?? ''));
              case '/recorder':
                return CustomPageRoute(settings: settings, builder: (context) => ScreenRecorderScreen(pcIpAddress: args?['pcIpAddress'] ?? '', authToken: args?['authToken'] ?? ''));
              case '/image_editor':
                return CustomPageRoute(settings: settings, builder: (context) => ImageEditorScreen(imageFile: args?['imageFile'], pcIpAddress: args?['pcIpAddress'] ?? '', authToken: args?['authToken'] ?? ''));
              case '/remote_view':
                return CustomPageRoute(settings: settings, builder: (context) => RemoteViewScreen(pcIpAddress: args?['pcIpAddress'] ?? '', authToken: args?['authToken'] ?? ''));
              case '/keyboard':
                return CustomPageRoute(settings: settings, builder: (context) => RemoteKeyboardScreen(pcIpAddress: args?['pcIpAddress'] ?? '', authToken: args?['authToken'] ?? ''));
              case '/phone_browser':
                return CustomPageRoute(settings: settings, builder: (context) => PhoneBrowserScreen(pcIpAddress: args?['pcIpAddress'] ?? '', authToken: args?['authToken'] ?? ''));
              default:
                return CustomPageRoute(settings: settings, builder: (context) => const SplashScreen());
            }
          },
        );
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
            const curve = Curves.easeInOutCubic;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(position: animation.drive(tween), child: FadeTransition(opacity: animation, child: child));
          },
          transitionDuration: const Duration(milliseconds: 400),
        );
}
