import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/user_viewmodel.dart';
import '../viewmodels/theme_viewmodel.dart';
import '../viewmodels/weather_viewmodel.dart';
import 'widgets/custom_widgets.dart';

import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:convert';

/// Thin wrapper — used when navigating to Profile as a standalone route.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1321) : const Color(0xFFF0F4FA),
      body: const SafeArea(
        child: ProfileBody(showTopBar: true),
      ),
    );
  }
}

/// The actual profile content — embeddable in HomeView (showTopBar: false)
/// or standalone via ProfileView (showTopBar: true).
class ProfileBody extends StatefulWidget {
  final bool showTopBar;
  const ProfileBody({super.key, this.showTopBar = true});

  @override
  State<ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<ProfileBody> {
  bool _initialized = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Check if profile is incomplete and force edit sheet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVM = context.read<AuthViewModel>();
      final userVM = context.read<UserViewModel>();
      if (authVM.user != null && !authVM.user!.isProfileComplete) {
        _openEditSheet(context, userVM, isMandatory: true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final user = context.watch<AuthViewModel>().user;
      if (user != null) {
        context.read<UserViewModel>().setUser(user);
        _initialized = true;
      }
    }
  }

  Future<void> _pickAndUploadImage(UserViewModel userViewModel) async {
    final authVM = context.read<AuthViewModel>();
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final Uint8List fileData = await image.readAsBytes();
        final url = await userViewModel.uploadProfilePicture(fileData);
        if (url != null && mounted) {
          authVM.setSuccess("Profile picture updated successfully");
          await authVM.refreshUser();
        }
      }
    } catch (e) {
      if (mounted) {
        authVM.setError("Error picking image: $e");
      }
    }
  }

  ImageProvider? _getProfileImage(String? url) {
    if (url == null) return null;
    if (url.startsWith('data:image')) {
      final base64String = url.split(',').last;
      return MemoryImage(base64Decode(base64String));
    }
    return NetworkImage(url);
  }

  // ── Opens the bottom-sheet edit form ─────────────────────────────────────
  void _openEditSheet(BuildContext context, UserViewModel userViewModel, {bool isMandatory = false}) {
    final authViewModel = context.read<AuthViewModel>();
    final user = userViewModel.user ?? authViewModel.user;
    if (user == null) return;

    final nameCtrl = TextEditingController(text: user.fullName);
    final ageCtrl = TextEditingController(text: user.age > 0 ? user.age.toString() : '');
    final heightCtrl =
        TextEditingController(text: user.height.toStringAsFixed(0));
    final weightCtrl =
        TextEditingController(text: user.weight > 0 ? user.weight.toStringAsFixed(1) : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: !isMandatory, // Prevent closing if mandatory
      enableDrag: !isMandatory,    // Prevent swiping down if mandatory
      backgroundColor: Colors.transparent,
      builder: (context) {
        return PopScope(
          canPop: !isMandatory, // Prevent back button closing
          child: Consumer<AuthViewModel>(
            builder: (context, authVM, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final sheetBg = isDark ? const Color(0xFF131C2E) : Colors.white;

            return GestureDetector(
              onTap: () {
                authVM.clearError();
                authVM.clearSuccess();
              },
              behavior: HitTestBehavior.translucent,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: sheetBg,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Sheet drag handle
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color:
                                    isDark ? Colors.white24 : Colors.black12,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isMandatory 
                              ? 'Please complete your profile details to continue.' 
                              : 'Update your personal details below.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isMandatory ? const Color(0xFF38B6FF) : (isDark ? Colors.white38 : Colors.black38),
                              fontWeight: isMandatory ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Full Name
                          _sheetLabel('Full Name', isDark),
                          const SizedBox(height: 6),
                          CustomTextField(
                            controller: nameCtrl,
                            label: '',
                            hintText: 'Full Name',
                            prefixIcon: Icons.person_outline,
                          ),

                          const SizedBox(height: 16),

                          // Age + Height row
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _sheetLabel('Age', isDark),
                                    const SizedBox(height: 6),
                                    CustomTextField(
                                      controller: ageCtrl,
                                      label: '',
                                      keyboardType: TextInputType.number,
                                      prefixIcon: Icons.calendar_today_outlined,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _sheetLabel('Height (cm)', isDark),
                                    const SizedBox(height: 6),
                                    CustomTextField(
                                      controller: heightCtrl,
                                      label: '',
                                      keyboardType: const TextInputType
                                          .numberWithOptions(decimal: true),
                                      prefixIcon: Icons.height,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'[0-9.]'))
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Weight
                          _sheetLabel('Weight (kg)', isDark),
                          const SizedBox(height: 6),
                          CustomTextField(
                            controller: weightCtrl,
                            label: '',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            prefixIcon: Icons.monitor_weight_outlined,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'))
                            ],
                          ),

                          const SizedBox(height: 28),

                          // Save button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () async {
                                final name = nameCtrl.text.trim();
                                final ageStr = ageCtrl.text.trim();
                                final heightStr = heightCtrl.text.trim();
                                final weightStr = weightCtrl.text.trim();

                                authVM.clearError();

                                // 1. Full Name validation
                                if (name.isEmpty) {
                                  authVM.setError("Please enter your full name.");
                                  return;
                                }
                                final fullNameRegex = RegExp(r"^[a-zA-Z\s'\.-]+$");
                                if (!fullNameRegex.hasMatch(name)) {
                                  authVM.setError("Full name must only contain letters, spaces, dots, and dashes.");
                                  return;
                                }
                                if (name.length < 2) {
                                  authVM.setError("Full name is too short. Please enter your real name.");
                                  return;
                                }

                                // 2. Age validation
                                if (ageStr.isEmpty) {
                                  authVM.setError("Please enter your age.");
                                  return;
                                }
                                final newAge = int.tryParse(ageStr);
                                if (newAge == null || newAge < 5 || newAge > 100) {
                                  authVM.setError("Please enter a valid age (between 5 and 100).");
                                  return;
                                }

                                // 3. Height validation
                                if (heightStr.isEmpty) {
                                  authVM.setError("Please enter your height (cm).");
                                  return;
                                }
                                final newHeight = double.tryParse(heightStr);
                                if (newHeight == null || newHeight < 50 || newHeight > 250) {
                                  authVM.setError("Please enter a realistic height (between 50cm and 250cm).");
                                  return;
                                }

                                // 4. Weight validation
                                if (weightStr.isEmpty) {
                                  authVM.setError("Please enter your weight (kg).");
                                  return;
                                }
                                final newWeight = double.tryParse(weightStr);
                                if (newWeight == null || newWeight < 10 || newWeight > 300) {
                                  authVM.setError("Please enter a realistic weight (between 10kg and 300kg).");
                                  return;
                                }

                                bool success = await userViewModel.updateProfile(
                                  fullName: name,
                                  age: newAge,
                                  weight: newWeight,
                                  height: newHeight,
                                );
                                if (success && mounted) {
                                  if (newWeight != user.weight ||
                                      newHeight != user.height) {
                                    // Profile update that affects BMI/Activity suggestions
                                    await context
                                        .read<WeatherViewModel>()
                                        .clearSelectedActivity();
                                  }
                                  await authVM.refreshUser();
                                  if (mounted) {
                                    Navigator.pop(context);
                                    authVM.setSuccess("Profile updated successfully");
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF38B6FF),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Save Changes',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          if (isMandatory) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                onPressed: () async {
                                  Navigator.pop(context); // Close sheet
                                  await authVM.logout();
                                },
                                icon: const Icon(Icons.exit_to_app, color: Colors.redAccent, size: 18),
                                label: const Text(
                                  'Exit & Logout',
                                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

  Widget _sheetLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white70 : Colors.black54,
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, AuthViewModel authViewModel) {
    showDialog(
      context: context,
      builder: (context) => ConfirmLogoutDialog(
        onCancel: () => Navigator.pop(context),
        onConfirm: () async {
          Navigator.pop(context);
          await authViewModel.logout();
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final userViewModel = context.watch<UserViewModel>();
    final themeViewModel = context.watch<ThemeViewModel>();
    final user = userViewModel.user ?? authViewModel.user;

    if (user == null) {
      return const Center(child: Text('Not logged in'));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? const Color(0xFF131C2E) : Colors.white;
    final Color borderColor = isDark
        ? const Color(0xFF1E2D45)
        : Colors.black.withValues(alpha: 0.06);
    const memberYear = '2023';

    // BMI-derived color
    final bmi = user.bmi;
    final bmiCategory = user.weightCategory;
    final Color bmiColor = _bmiColor(bmiCategory);

    return GestureDetector(
      onTap: () {
        authViewModel.clearError();
        authViewModel.clearSuccess();
      },
      behavior: HitTestBehavior.translucent,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // ── Optional Top Bar ─────────────────────────────────────────────
            if (widget.showTopBar)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF38B6FF), Color(0xFF00E5CC)],
                      ).createShader(bounds),
                      child: const Icon(Icons.cloud_queue,
                          size: 22, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF38B6FF), Color(0xFF00E5CC)],
                      ).createShader(bounds),
                      child: const Text(
                        'SkyFit Pro',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showLogoutConfirmation(context, authViewModel),
                      icon: Icon(Icons.logout_rounded,
                          color: isDark ? Colors.white54 : Colors.black38,
                          size: 18),
                      label: Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : Colors.black38,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Hero Banner ──────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF0F2440),
                          const Color(0xFF0D1321),
                        ]
                      : [
                          const Color(0xFF38B6FF).withValues(alpha: 0.18),
                          const Color(0xFFF0F4FA),
                        ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  // Avatar
                  GestureDetector(
                    onTap: () => _pickAndUploadImage(userViewModel),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Gradient ring
                        Container(
                          width: 112,
                          height: 112,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF38B6FF), Color(0xFF00E5CC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        CircleAvatar(
                          radius: 52,
                          backgroundColor: isDark
                              ? const Color(0xFF1A2235)
                              : Colors.blueGrey.shade100,
                          backgroundImage: _getProfileImage(user.profilePictureUrl),
                          child: user.profilePictureUrl == null
                              ? Icon(Icons.person,
                                  size: 48,
                                  color:
                                      isDark ? Colors.white38 : Colors.blueGrey)
                              : null,
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Color(0xFF38B6FF),
                              shape: BoxShape.circle,
                            ),
                          child: const Icon(Icons.photo_camera,
                              size: 15, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Name
                Text(
                  user.fullName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),

                const SizedBox(height: 18),

                // Edit Profile button
                GestureDetector(
                  onTap: () => _openEditSheet(context, userViewModel),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFF38B6FF).withValues(alpha: 0.6)),
                      borderRadius: BorderRadius.circular(20),
                      color: const Color(0xFF38B6FF).withValues(alpha: 0.08),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_outlined,
                            size: 14, color: Color(0xFF38B6FF)),
                        const SizedBox(width: 6),
                        const Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF38B6FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── BMI Spotlight Card ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: bmiColor.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: bmiColor.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Left: icon
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: bmiColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.monitor_weight_outlined,
                        size: 26, color: bmiColor),
                  ),
                  const SizedBox(width: 16),
                  // Middle: label + value
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Body Mass Index',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.height > 0
                              ? bmi.toStringAsFixed(1)
                              : '—',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: bmiColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right: classification badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: bmiColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: bmiColor.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      bmiCategory,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: bmiColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Stats Row (Age / Height / Weight) ────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                    child: _statCard('AGE', '${user.age}', 'yrs', isDark, cardBg, borderColor)),
                const SizedBox(width: 10),
                Expanded(
                    child: _statCard('HEIGHT',
                        user.height.toStringAsFixed(0), 'cm', isDark, cardBg, borderColor)),
                const SizedBox(width: 10),
                Expanded(
                    child: _statCard('WEIGHT',
                        user.weight.toStringAsFixed(1), 'kg', isDark, cardBg, borderColor)),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── App Settings ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'App Settings'),
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      SettingsTile(
                        icon: Icons.fingerprint,
                        iconColor: const Color(0xFF38B6FF),
                        title: 'Biometric Login',
                        subtitle: 'Fingerprint or FaceID',
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: user.biometricEnabled,
                            activeTrackColor: const Color(0xFF4CAF50),
                            onChanged: (val) async {
                              bool success =
                                  await authViewModel.toggleBiometrics(val);
                              if (!success && mounted) {
                                authViewModel.setError(authViewModel.error ?? 'Failed to toggle biometrics');
                              } else {
                                userViewModel.setUser(authViewModel.user);
                              }
                            },
                          ),
                        ),
                      ),
                      Divider(
                          height: 1,
                          color: isDark ? Colors.white10 : Colors.black12),
                      SettingsTile(
                        icon: Icons.dark_mode_outlined,
                        iconColor: const Color(0xFF9C88FF),
                        title: 'Dark Mode',
                        subtitle: 'System default applied',
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: themeViewModel.isDarkMode,
                            activeTrackColor: const Color(0xFF4CAF50),
                            onChanged: (val) => themeViewModel.toggleTheme(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Logout ────────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _showLogoutConfirmation(context, authViewModel),
                    icon: const Icon(Icons.logout_rounded,
                        color: Colors.white, size: 18),
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD84040),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Version Footer ────────────────────────────────────────
                Center(
                  child: Text(
                    'SKYFIT PRO V1.0.0  •  BUILD 2026',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.1,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  // ── Helper: BMI colour mapping ────────────────────────────────────────────
  Color _bmiColor(String category) {
    switch (category) {
      case 'Underweight':
        return const Color(0xFF38B6FF);
      case 'Normal':
        return const Color(0xFF4CAF50);
      case 'Overweight':
        return const Color(0xFFFF9800);
      default: // High BMI / No Data
        return const Color(0xFFFF5252);
    }
  }

  // ── Compact stat card ─────────────────────────────────────────────────────
  Widget _statCard(String label, String value, String unit,
      bool isDark, Color cardBg, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF38B6FF),
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}
