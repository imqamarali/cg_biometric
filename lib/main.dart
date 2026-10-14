import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:window_size/window_size.dart';
import 'dart:io';

import 'providers/session_provider.dart';
import 'services/api_service.dart';
import 'providers/navigation_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/loading_provider.dart';
import 'providers/server_connection_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'theme/ace_theme.dart';
import 'widgets/loading_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle('Creative Garage PVT LTD');
    setWindowMinSize(const Size(900, 600));

    final screen = await getCurrentScreen();
    if (screen != null) {
      final frame = screen.visibleFrame;
      final width = (frame.width * 0.9).clamp(900.0, 1500.0);
      final height = (frame.height * 0.9).clamp(600.0, 900.0);
      setWindowFrame(
        Rect.fromLTWH(
          frame.left + (frame.width - width) / 2,
          frame.top + (frame.height - height) / 2,
          width,
          height,
        ),
      );
    }
  }

  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> get hasSession => ApiService.hasSession();

  void _bindSessionExpiry() {
    ApiService.onSessionExpired = (message) {
      final nav = navigatorKey.currentState;
      final ctx = navigatorKey.currentContext;
      if (nav == null || ctx == null) return;
      ctx.read<ServerConnectionProvider>().stop();
      ctx.read<SessionProvider>().loadSession();
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen(notice: message)),
        (_) => false,
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    _bindSessionExpiry();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => LoadingProvider()),
        ChangeNotifierProvider(create: (_) => ServerConnectionProvider()),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Biometric Authentication',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.light,
        theme: Ace.theme(),
        builder: (context, child) {
          return Scaffold(
            body: SafeArea(
              child: ResponsiveBreakpoints.builder(
                child: child!,
                breakpoints: const [
                  Breakpoint(start: 0, end: 450, name: MOBILE),
                  Breakpoint(start: 451, end: 800, name: TABLET),
                  Breakpoint(start: 801, end: 1920, name: DESKTOP),
                ],
              ),
            ),
          );
        },
        home: FutureBuilder<bool>(
          future: hasSession,
          builder: (context, snapshot) {
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;

            return LoadingOverlay(
              isLoading: isLoading,
              child: () {
                if (snapshot.hasError) return const LoginScreen();
                if (snapshot.data == true) return const DashboardScreen();
                return const LoginScreen();
              }(),
            );
          },
        ),
      ),
    );
  }
}
