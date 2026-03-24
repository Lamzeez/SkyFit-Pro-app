import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'viewmodels/theme_viewmodel.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/user_viewmodel.dart';
import 'viewmodels/weather_viewmodel.dart';
import 'services/session_manager.dart';
import 'views/auth/login_view.dart';
import 'views/home_view.dart';
import 'utils/env_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    if (EnvConfig.isFirebaseConfigured) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: EnvConfig.firebaseApiKey,
          authDomain: EnvConfig.firebaseAuthDomain,
          projectId: EnvConfig.firebaseProjectId,
          storageBucket: EnvConfig.firebaseStorageBucket,
          messagingSenderId: EnvConfig.firebaseMessagingSenderId,
          appId: EnvConfig.firebaseAppId,
          measurementId: EnvConfig.firebaseMeasurementId,
        ),
      );
    } else {
      print("Firebase not configured. App will run in mock mode.");
    }
  } catch (e) {
    print("Error initializing Firebase: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeViewModel()),
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => UserViewModel()),
        ChangeNotifierProvider(create: (_) => WeatherViewModel()),
      ],
      child: const SkyFitProApp(),
    ),
  );
}

class SkyFitProApp extends StatefulWidget {
  const SkyFitProApp({super.key});

  @override
  State<SkyFitProApp> createState() => _SkyFitProAppState();
}

class _SkyFitProAppState extends State<SkyFitProApp> {
  late SessionManager _sessionManager;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _sessionManager = SessionManager(onLogout: () {
      context.read<AuthViewModel>().logout();
      _navigatorKey.currentState?.pushReplacementNamed('/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final themeViewModel = context.watch<ThemeViewModel>();

    return Listener(
      onPointerDown: (_) => _sessionManager.resetTimer(),
      onPointerMove: (_) => _sessionManager.resetTimer(),
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'SkyFit Pro',
        theme: themeViewModel.currentTheme,
        home: _getHome(authViewModel),
        routes: {
          '/login': (context) => const LoginView(),
          '/home': (context) => const HomeView(),
        },
      ),
    );
  }

  Widget _getHome(AuthViewModel authViewModel) {
    if (authViewModel.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (authViewModel.user != null) {
      _sessionManager.startTimer();
      return const HomeView();
    }
    return const LoginView();
  }
}
