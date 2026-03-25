import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../widgets/custom_widgets.dart';
import '../home_view.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Uint8List? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final Uint8List imageData = await image.readAsBytes();
        setState(() {
          _selectedImage = imageData;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error picking image: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text("Register"), backgroundColor: Colors.lightBlue),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.lightBlue[100],
                  backgroundImage: _selectedImage != null ? MemoryImage(_selectedImage!) : null,
                  child: _selectedImage == null
                      ? const Icon(Icons.add_a_photo, size: 50, color: Colors.lightBlue)
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              const Text("Add Profile Picture", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              CustomTextField(
                controller: _fullNameController,
                label: "Full Name",
                validator: (v) => v!.isEmpty ? "Enter full name" : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _ageController,
                      label: "Age",
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? "Enter age" : null,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: CustomTextField(
                      controller: _heightController,
                      label: "Height (cm)",
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? "Enter height" : null,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: CustomTextField(
                      controller: _weightController,
                      label: "Weight (kg)",
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? "Enter weight" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _emailController,
                label: "Email",
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v!.isEmpty ? "Enter email" : null,
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _passwordController,
                label: "Password",
                isPassword: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return "Enter password";
                  if (v.length < 8) return "Must be at least 8 characters";
                  if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]').hasMatch(v)) {
                    return "Need: Upper, Lower, Number, Special Char";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _confirmPasswordController,
                label: "Confirm Password",
                isPassword: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return "Confirm your password";
                  if (v != _passwordController.text) return "Passwords do not match";
                  return null;
                },
              ),
              const SizedBox(height: 30),
              CustomButton(
                text: "Register",
                isLoading: authViewModel.isLoading,
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    bool success = await authViewModel.register(
                      _emailController.text,
                      _passwordController.text,
                      _fullNameController.text,
                      int.parse(_ageController.text),
                      double.parse(_weightController.text),
                      double.parse(_heightController.text),
                      profileImageData: _selectedImage,
                    );
                    if (success && mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const HomeView()),
                        (route) => false,
                      );
                    }
                  }
                },
              ),
              if (authViewModel.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(authViewModel.error!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
