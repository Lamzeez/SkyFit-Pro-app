import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'viewmodels/theme_viewmodel.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/user_viewmodel.dart';
import 'viewmodels/weather_viewmodel.dart';
import 'services/session_manager.dart';
import 'views/widgets/custom_widgets.dart';
import 'views/auth/login_view.dart';
import 'views/auth/biometric_lock_view.dart';
import 'views/home_view.dart';
import 'views/profile_view.dart';
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
  String? _sessionWarning;
  bool _timerStarted = false;

  @override
  void initState() {
    super.initState();
    _sessionManager = SessionManager(
      onLogout: () {
        if (mounted) {
          setState(() {
            _sessionWarning = null;
            _timerStarted = false;
          });
        }
        final authVM = context.read<AuthViewModel>();
        authVM.logout(showSuccess: false);
        authVM.setError("Session expired due to inactivity. Please log in again.");
        _navigatorKey.currentState?.pushReplacementNamed('/login');
      },
      onWarning: () {
        if (mounted) {
          setState(() => _sessionWarning = "Your session will expire in 30 seconds due to inactivity.");
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final themeViewModel = context.watch<ThemeViewModel>();

    return Listener(
      onPointerDown: (_) {
        if (authViewModel.user != null) {
          if (_sessionWarning != null) {
            setState(() => _sessionWarning = null);
          }
          _sessionManager.resetTimer();
        }
        // Also clear global error/success on tap anywhere
        if (authViewModel.error != null) authViewModel.clearError();
        if (authViewModel.success != null) authViewModel.clearSuccess();
      },
      onPointerMove: (_) {
        if (authViewModel.user != null) {
          if (_sessionWarning != null) {
            setState(() => _sessionWarning = null);
          }
          _sessionManager.resetTimer();
        }
      },
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        title: 'SkyFit Pro',
        theme: themeViewModel.currentTheme,
        home: _getHome(authViewModel),
        routes: {
          '/login': (context) => const LoginView(),
          '/home': (context) => const HomeView(),
        },
        builder: (context, child) {
          return Stack(
            children: [
              if (child != null) child,
              // Session Warning Banner
              Positioned(
                top: MediaQuery.of(context).padding.top + 370,
                left: 20,
                right: 20,
                child: Material(
                  color: Colors.transparent,
                  child: Center(
                    child: AnimatedWarningBanner(message: _sessionWarning),
                  ),
                ),
              ),
              // Global Error Banner
              Positioned(
                top: MediaQuery.of(context).padding.top + 370,
                left: 20,
                right: 20,
                child: Material(
                  color: Colors.transparent,
                  child: Center(
                    child: AnimatedErrorBanner(
                      message: authViewModel.error != null
                          ? mapAuthError(authViewModel.error!)
                          : null,
                    ),
                  ),
                ),
              ),
              // Global Success Banner
              Positioned(
                top: MediaQuery.of(context).padding.top + 370,
                left: 20,
                right: 20,
                child: Material(
                  color: Colors.transparent,
                  child: Center(
                    child: AnimatedSuccessBanner(
                      message: authViewModel.success,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _getHome(AuthViewModel authViewModel) {
    if (authViewModel.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (authViewModel.user != null) {
      if (!authViewModel.isBiometricAuthenticated) {
        return const BiometricLockView();
      }
      
      // Only start the timer once when entering the authenticated home state
      if (!_timerStarted) {
        _timerStarted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _sessionManager.startTimer();
        });
      }
      return const HomeView();
    }
    
    // Reset state when logged out
    if (_timerStarted) {
      _timerStarted = false;
      _sessionManager.stopTimer();
    }
    return const LoginView();
  }
}
