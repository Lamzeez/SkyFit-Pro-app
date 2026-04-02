import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../services/storage_service.dart';
import '../widgets/custom_widgets.dart';
import 'register_view.dart';
import '../home_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _canUseBiometrics = false;
  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _checkBiometricPreference();
    // Refresh UI as user types to check lockout for specific emails
    _emailController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricPreference() async {
    final enabled = await _storage.read('biometric_enabled');
    if (enabled == 'true') {
      setState(() => _canUseBiometrics = true);
    }
  }

  bool _validateForm(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    authViewModel.clearError();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      authViewModel.setError("Please enter your email address.");
      return false;
    }

    // Email regex check
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      authViewModel.setError("Please enter a valid email format.");
      return false;
    }

    if (password.isEmpty) {
      authViewModel.setError("Please enter your password.");
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? const Color(0xFF0D1321) : const Color(0xFFF0F4FA);
    final Color cardBg = isDark ? const Color(0xFF131C2E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: GestureDetector(
        onTap: () {
          authViewModel.clearError();
          authViewModel.clearSuccess();
        },
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Logo Header ──────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF38B6FF), Color(0xFF00E5CC)],
                        ).createShader(bounds),
                        child: const Icon(
                          Icons.cloud_queue,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF38B6FF), Color(0xFF00E5CC)],
                        ).createShader(bounds),
                        child: const Text(
                          'SkyFit Pro',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 44),

                  // ── Headline ─────────────────────────────────────────────
                  const Text(
                    'Welcome back',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your atmospheric fitness companion awaits.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Form Card ────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1E2D45)
                            : Colors.black.withValues(alpha: 0.06),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Email
                        Text(
                          'Email Address',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          controller: _emailController,
                          label: '',
                          hintText: 'name@example.com',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.email_outlined,
                        ),

                        const SizedBox(height: 20),

                        // Password
                        Text(
                          'Password',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          controller: _passwordController,
                          label: '',
                          hintText: '••••••••',
                          isPassword: true,
                          prefixIcon: Icons.lock_outline_rounded,
                        ),

                        const SizedBox(height: 24),

                        // Sign In button
                        CustomButton(
                          text: 'Sign In',
                          isLoading: authViewModel.isLoading,
                          onPressed: () async {
                            if (_validateForm(context)) {
                              bool success = await authViewModel.login(
                                _emailController.text,
                                _passwordController.text,
                              );
                              if (success && mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const HomeView()),
                                );
                              }
                            }
                          },
                        ),

                        // Biometric Section
                        if (_canUseBiometrics) ...[
                          const SizedBox(height: 12),
                          if (authViewModel.isEmailLockedOut(_emailController.text.trim()))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                "3 consecutive fail attempts, biometrics login disabled. Login with email and password instead.",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                onPressed: authViewModel.isLoading
                                    ? null
                                    : () async {
                                        bool success = await authViewModel
                                            .authenticateWithBiometrics(
                                                enteredEmail:
                                                    _emailController.text);
                                        if (success && mounted) {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    const HomeView()),
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.fingerprint,
                                    color: Color(0xFF38B6FF)),
                                label: const Text(
                                  'Login with Biometrics',
                                  style: TextStyle(color: Color(0xFF38B6FF)),
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: 24),

                        // OR CONTINUE WITH divider
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: isDark
                                    ? Colors.white12
                                    : Colors.black12,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'OR CONTINUE WITH',
                                style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 1.1,
                                  color:
                                      isDark ? Colors.white30 : Colors.black38,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: isDark
                                    ? Colors.white12
                                    : Colors.black12,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Google SSO button
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.14),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: authViewModel.isLoading
                                ? null
                                : () async {
                                    bool success =
                                        await authViewModel.signInWithGoogle();
                                    if (success && mounted) {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const HomeView()),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? const Color(0xFF1E2535)
                                  : const Color(0xFFF3F5F8),
                              elevation: 0,
                              surfaceTintColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF2A3650)
                                      : Colors.black.withValues(alpha: 0.08),
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Official Google Icon
                                Image.asset(
                                  'lib/icons/google-icon-48.png',
                                  width: 22,
                                  height: 22,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Google',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Facebook SSO button
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.14),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: authViewModel.isLoading
                                ? null
                                : () async {
                                    bool success =
                                        await authViewModel.signInWithFacebook();
                                    if (success && mounted) {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const HomeView()),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? const Color(0xFF1E2535)
                                  : const Color(0xFFF3F5F8),
                              elevation: 0,
                              surfaceTintColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF2A3650)
                                      : Colors.black.withValues(alpha: 0.08),
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Official Facebook Icon
                                Image.asset(
                                  'lib/icons/facebook_logo.png',
                                  width: 22,
                                  height: 22,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Facebook',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'New to the platform?  ',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          authViewModel.clearError();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const RegisterView()),
                          );
                        },
                        child: const Text(
                          'Create an account',
                          style: TextStyle(
                            color: Color(0xFF38B6FF),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    ],
  ),
),
);
}
}

/// Simulated coloured Google "G" icon using a simple styled Text.
// Removed custom painter classes as they are replaced by an asset.
