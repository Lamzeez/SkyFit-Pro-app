import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../widgets/custom_widgets.dart';
import '../home_view.dart';
import 'email_verification_view.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Uint8List? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // Password strength states
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;
  bool _hasMinLength = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_updatePasswordStrength);
    _passwordController.dispose();
    _emailController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength() {
    final password = _passwordController.text;
    setState(() {
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      _hasMinLength = password.length >= 8;
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image =
          await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final Uint8List imageData = await image.readAsBytes();
        setState(() => _selectedImage = imageData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  bool _validateForm(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    authViewModel.clearError();

    final fullName = _fullNameController.text.trim();
    final ageStr = _ageController.text.trim();
    final heightStr = _heightController.text.trim();
    final weightStr = _weightController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // 1. Full Name validation
    if (fullName.isEmpty) {
      authViewModel.setError("Please enter your full name.");
      return false;
    }
    final fullNameRegex = RegExp(r"^[a-zA-Z\s'\.-]+$");
    if (!fullNameRegex.hasMatch(fullName)) {
      authViewModel.setError("Full name must only contain letters, spaces, dots, and dashes.");
      return false;
    }
    if (fullName.length < 2) {
      authViewModel.setError("Full name is too short. Please enter your real name.");
      return false;
    }

    // 2. Age validation
    if (ageStr.isEmpty) {
      authViewModel.setError("Please enter your age.");
      return false;
    }
    final age = int.tryParse(ageStr);
    if (age == null || age < 5 || age > 100) {
      authViewModel.setError("Please enter a valid age (between 5 and 100).");
      return false;
    }

    // 3. Height validation
    if (heightStr.isEmpty) {
      authViewModel.setError("Please enter your height (cm).");
      return false;
    }
    final height = double.tryParse(heightStr);
    if (height == null || height < 50 || height > 250) {
      authViewModel.setError("Please enter a realistic height (between 50cm and 250cm).");
      return false;
    }

    // 4. Weight validation
    if (weightStr.isEmpty) {
      authViewModel.setError("Please enter your weight (kg).");
      return false;
    }
    final weight = double.tryParse(weightStr);
    if (weight == null || weight < 10 || weight > 300) {
      authViewModel.setError("Please enter a realistic weight (between 10kg and 300kg).");
      return false;
    }

    // 5. Email Address validation
    if (email.isEmpty) {
      authViewModel.setError("Please enter your email address.");
      return false;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      authViewModel.setError("The email format is invalid. Please use a proper email (e.g., user@example.com).");
      return false;
    }

    // 6. Password validation
    if (password.isEmpty) {
      authViewModel.setError("Please create a password.");
      return false;
    }
    if (!_hasMinLength || !_hasUppercase || !_hasLowercase || !_hasNumber || !_hasSpecialChar) {
      authViewModel.setError("Password must have at least 8 characters, including an uppercase letter, a lowercase letter, a number, and a special character.");
      return false;
    }

    // 7. Confirm Password validation
    if (confirmPassword.isEmpty) {
      authViewModel.setError("Please confirm your password.");
      return false;
    }
    if (password != confirmPassword) {
      authViewModel.setError("Passwords do not match. Please re-enter your password.");
      return false;
    }

    return true;
  }

  double _getStrengthPercent() {
    int points = 0;
    if (_hasMinLength) points++;
    if (_hasUppercase) points++;
    if (_hasLowercase) points++;
    if (_hasNumber) points++;
    if (_hasSpecialChar) points++;
    return points / 5;
  }

  Color _getStrengthColor() {
    double percent = _getStrengthPercent();
    if (percent <= 0.2) return Colors.redAccent;
    if (percent <= 0.4) return Colors.orange; // Darker orange
    if (percent <= 0.6) return const Color(0xFFBDB700); // Ochre/Dark Yellow for visibility
    if (percent <= 0.8) return const Color(0xFF2E7D32); // Darker Green
    return const Color(0xFF009688); // Teal/Strong Green
  }

  String _getStrengthText() {
    double percent = _getStrengthPercent();
    if (percent <= 0) return '';
    if (percent <= 0.2) return 'Your Password is Weak';
    if (percent <= 0.4) return 'Your Password is Fair';
    if (percent <= 0.6) return 'Your Password is Good';
    if (percent <= 0.8) return 'Your Password is Strong';
    return 'Your Password is Very Strong';
  }

  String _getMissingRequirementsText() {
    List<String> missing = [];
    if (!_hasMinLength) missing.add('at least 8 characters');
    if (!_hasUppercase) missing.add('an uppercase letter');
    if (!_hasLowercase) missing.add('a lowercase letter');
    if (!_hasNumber) missing.add('a number');
    if (!_hasSpecialChar) missing.add('a special character');

    if (missing.isEmpty) return 'Perfect! Your password is secure.';

    String text = 'Your password must contain: ';
    for (int i = 0; i < missing.length; i++) {
      text += missing[i];
      if (i < missing.length - 2) {
        text += ', ';
      } else if (i == missing.length - 2) {
        text += ', and ';
      }
    }
    return text;
  }

  Widget _buildPasswordStrengthIndicator(bool isDark) {
    final double percent = _getStrengthPercent();
    final Color color = _getStrengthColor();
    final String text = _getStrengthText();
    final String requirements = _getMissingRequirementsText();

    if (_passwordController.text.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Glowing Bar
        Stack(
          children: [
            // Background track
            Container(
              height: 4,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Progress bar with glow
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              width: MediaQuery.of(context).size.width * 0.8 * percent, // Approximate
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width - 88, // Account for padding
              ),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Strength text and Requirements
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              child: Text(text),
            ),
            if (percent < 1.0) ...[
              const SizedBox(height: 4),
              Text(
                requirements,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black45,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ],
    );
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
                constraints: const BoxConstraints(maxWidth: 480),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // ── Logo Header ──────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF38B6FF), Color(0xFF00E5CC)],
                        ).createShader(bounds),
                        child: const Icon(Icons.cloud_queue,
                            size: 44, color: Colors.white),
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

                  const SizedBox(height: 32),

                  const Text(
                    'Create Account',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Join your atmospheric fitness journey',
                    style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white54 : Colors.black45),
                  ),

                  const SizedBox(height: 28),

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
                      children: [
                        // Profile picture
                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 102,
                                height: 102,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF38B6FF),
                                      Color(0xFF00E5CC)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: isDark
                                    ? const Color(0xFF1A2235)
                                    : Colors.blueGrey.shade50,
                                backgroundImage: _selectedImage != null
                                    ? MemoryImage(_selectedImage!)
                                    : null,
                                child: _selectedImage == null
                                    ? Icon(Icons.add_a_photo,
                                        size: 32,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.blueGrey)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add Profile Picture',
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark ? Colors.white38 : Colors.black38),
                        ),

                        const SizedBox(height: 24),

                        // Full Name
                        _label('Full Name', isDark),
                        const SizedBox(height: 8),
                        CustomTextField(
                          controller: _fullNameController,
                          label: '',
                          hintText: 'Alex Rivera',
                          prefixIcon: Icons.person_outline,
                          validator: (v) =>
                              v!.isEmpty ? 'Enter full name' : null,
                        ),

                        const SizedBox(height: 16),

                        // Age / Height / Weight row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Age', isDark),
                                  const SizedBox(height: 8),
                                  CustomTextField(
                                    controller: _ageController,
                                    label: '',
                                    hintText: '28',
                                    keyboardType: TextInputType.number,
                                    prefixIcon: null, // Removed to save space
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    validator: (v) =>
                                        v!.isEmpty ? 'Required' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8), // Reduced from 12
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Height (cm)', isDark),
                                  const SizedBox(height: 8),
                                  CustomTextField(
                                    controller: _heightController,
                                    label: '',
                                    hintText: '175',
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    prefixIcon: null, // Removed to save space
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                    validator: (v) =>
                                        v!.isEmpty ? 'Required' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8), // Reduced from 12
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Weight (kg)', isDark),
                                  const SizedBox(height: 8),
                                  CustomTextField(
                                    controller: _weightController,
                                    label: '',
                                    hintText: '70.0',
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    prefixIcon: null, // Removed to save space
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                    validator: (v) =>
                                        v!.isEmpty ? 'Required' : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Email
                        _label('Email Address', isDark),
                        const SizedBox(height: 8),
                        CustomTextField(
                          controller: _emailController,
                          label: '',
                          hintText: 'name@example.com',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.email_outlined,
                          validator: (v) => v!.isEmpty ? 'Enter email' : null,
                        ),

                        const SizedBox(height: 16),

                        // Password
                        _label('Password', isDark),
                        const SizedBox(height: 8),
                        CustomTextField(
                          controller: _passwordController,
                          label: '',
                          hintText: '••••••••',
                          isPassword: true,
                          prefixIcon: Icons.lock_outline_rounded,
                        ),
                        const SizedBox(height: 12),
                        _buildPasswordStrengthIndicator(isDark),

                        const SizedBox(height: 16),

                        // Confirm Password
                        _label('Confirm Password', isDark),
                        const SizedBox(height: 8),
                        CustomTextField(
                          controller: _confirmPasswordController,
                          label: '',
                          hintText: '••••••••',
                          isPassword: true,
                          prefixIcon: Icons.lock_reset_rounded,
                        ),

                        const SizedBox(height: 24),

                        CustomButton(
                          text: 'Create Account',
                          isLoading: authViewModel.isLoading,
                          onPressed: () async {
                            if (_validateForm(context)) {
                              final registrationData = {
                                'email': _emailController.text.trim(),
                                'password': _passwordController.text,
                                'fullName': _fullNameController.text.trim(),
                                'age': int.parse(_ageController.text.trim()),
                                'weight': double.parse(_weightController.text.trim()),
                                'height': double.parse(_heightController.text.trim()),
                                'profileImageData': _selectedImage,
                              };

                              bool success = await authViewModel.sendOTPForRegistration(
                                _emailController.text.trim(),
                                registrationData,
                              );

                              if (success && mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EmailVerificationView(
                                      email: _emailController.text.trim(),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Already have account link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?  ',
                        style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: () {
                          authViewModel.clearError();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Sign in',
                          style: TextStyle(
                            color: Color(0xFF38B6FF),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
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

  Widget _label(String text, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }
}
