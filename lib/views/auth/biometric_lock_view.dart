import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../widgets/custom_widgets.dart';

class BiometricLockView extends StatefulWidget {
  const BiometricLockView({super.key});

  @override
  State<BiometricLockView> createState() => _BiometricLockViewState();
}

class _BiometricLockViewState extends State<BiometricLockView> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _usePin = false;
  bool _usePassword = false;

  @override
  void initState() {
    super.initState();
    // Auto-setup initial state based on what's enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVM = context.read<AuthViewModel>();
      if (!authVM.user!.biometricEnabled && authVM.pinEnabled) {
        setState(() => _usePin = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = authViewModel.user;

    if (user == null) return const SizedBox.shrink();

    // Determine what to show
    bool isLockedOut = authViewModel.biometricLockedOut || _usePassword;
    bool showPinEntry = !isLockedOut && _usePin;
    bool showBiometricButton = !isLockedOut && !showPinEntry && user.biometricEnabled;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Branded Icon
                Icon(
                  isLockedOut ? Icons.lock_outline : (showPinEntry ? Icons.dialpad : Icons.fingerprint),
                  size: 80,
                  color: const Color(0xFF38B6FF),
                ),
                const SizedBox(height: 24),
                Text(
                  isLockedOut ? "Account Lock" : "Welcome back,",
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                Text(
                  user.fullName,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                
                // 1. PASSWORD FALLBACK (Shown if 3 fails or user selects it)
                if (isLockedOut) ...[
                  Text(
                    authViewModel.biometricLockedOut 
                      ? "Too many failed attempts. Enter password to unlock."
                      : "Enter your account password to continue.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    controller: _passwordController,
                    label: "Password",
                    isPassword: true,
                    validator: (v) => v!.isEmpty ? "Enter password" : null,
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    text: "Unlock with Password",
                    isLoading: authViewModel.isLoading,
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        await authViewModel.verifyPassword(_passwordController.text);
                      }
                    },
                  ),
                ] 
                
                // 2. PIN ENTRY
                else if (showPinEntry) ...[
                  const Text("Enter your Secure PIN"),
                  const SizedBox(height: 20),
                  CustomTextField(
                    controller: _pinController,
                    label: "PIN Code",
                    isPassword: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: (v) => v!.length < 4 ? "Enter 4-6 digits" : null,
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    text: "Verify PIN",
                    isLoading: authViewModel.isLoading,
                    onPressed: () async {
                      // Removed form validation to ensure every click counts as an attempt
                      await authViewModel.verifyPin(_pinController.text);
                    },
                  ),
                ]

                // 3. BIOMETRIC BUTTON (Only if enabled)
                else if (showBiometricButton) ...[
                  CustomButton(
                    text: "Authenticate with Biometrics",
                    onPressed: () async {
                      await authViewModel.authenticateWithBiometrics();
                    },
                  ),
                ],

                const SizedBox(height: 24),

                // --- FOOTER OPTIONS ---
                if (!isLockedOut) ...[
                  // Option: Sign in with PIN (If not currently showing PIN)
                  if (!_usePin && authViewModel.pinEnabled)
                    TextButton.icon(
                      onPressed: () => setState(() { _usePin = true; _usePassword = false; }),
                      icon: const Icon(Icons.dialpad, size: 16),
                      label: const Text("Sign in with PIN"),
                    ),
                  
                  // Option: Sign in with Biometrics (If currently showing PIN but bio enabled)
                  if (_usePin && user.biometricEnabled)
                    TextButton.icon(
                      onPressed: () => setState(() { _usePin = false; _usePassword = false; }),
                      icon: const Icon(Icons.fingerprint, size: 16),
                      label: const Text("Use Biometrics instead"),
                    ),

                  // Option: Sign in with Password instead
                  TextButton.icon(
                    onPressed: () => setState(() { _usePassword = true; _usePin = false; }),
                    icon: const Icon(Icons.password, size: 16),
                    label: const Text("Sign in with password instead"),
                  ),
                ],

                // Global Option: Sign Out
                TextButton(
                  onPressed: () => authViewModel.logout(),
                  child: Text(
                    "Sign Out / Switch Account",
                    style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
