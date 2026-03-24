import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/user_viewmodel.dart';
import '../viewmodels/theme_viewmodel.dart';
import 'widgets/custom_widgets.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final user = context.watch<AuthViewModel>().user;
      if (user != null) {
        _fullNameController.text = user.fullName;
        _ageController.text = user.age.toString();
        _weightController.text = user.weight.toString();
        _initialized = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final userViewModel = context.watch<UserViewModel>();
    final themeViewModel = context.watch<ThemeViewModel>();
    final user = authViewModel.user;

    if (user == null) return const Scaffold(body: Center(child: Text("Not logged in")));

    return Scaffold(
      appBar: AppBar(title: const Text("Profile"), backgroundColor: Theme.of(context).appBarTheme.backgroundColor),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.lightBlue,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(user.email, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            CustomTextField(controller: _fullNameController, label: "Full Name"),
            const SizedBox(height: 20),
            CustomTextField(controller: _ageController, label: "Age", keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            CustomTextField(controller: _weightController, label: "Weight (kg)", keyboardType: TextInputType.number),
            const SizedBox(height: 30),
            CustomButton(
              text: "Update Profile",
              isLoading: userViewModel.isLoading,
              onPressed: () async {
                bool success = await userViewModel.updateProfile(
                  fullName: _fullNameController.text,
                  age: int.tryParse(_ageController.text) ?? 0,
                  weight: double.tryParse(_weightController.text) ?? 0.0,
                );
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Profile updated successfully")),
                  );
                }
              },
            ),
            const SizedBox(height: 40),
            const Divider(),
            SwitchListTile(
              title: const Text("Dark Mode"),
              subtitle: const Text("Toggle between light and dark themes"),
              value: themeViewModel.isDarkMode,
              onChanged: (val) => themeViewModel.toggleTheme(),
            ),
            SwitchListTile(
              title: const Text("Enable Biometric Login"),
              subtitle: const Text("Use Fingerprint/FaceID to unlock"),
              value: user.biometricEnabled,
              onChanged: (val) async {
                bool success = await authViewModel.toggleBiometrics(val);
                if (!success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Failed to toggle biometrics")),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
