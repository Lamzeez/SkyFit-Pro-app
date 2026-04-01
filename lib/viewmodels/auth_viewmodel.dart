import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:typed_data';
import '../repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../services/local_auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../utils/env_config.dart';

import 'dart:math';
import '../services/email_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  final LocalAuthService _localAuthService = LocalAuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  String? _success;
  bool _isBiometricAuthenticated = false;
  bool _isPinAuthenticated = false;
  int _biometricFailCount = 0;
  Timer? _errorTimer;
  Timer? _successTimer;

  // OTP Verification State
  String? _currentOTP;
  Map<String, dynamic>? _pendingRegistrationData;
  DateTime? _otpSentTime;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get success => _success;
  bool get isBiometricAuthenticated => _isBiometricAuthenticated;
  bool get isPinAuthenticated => _isPinAuthenticated;
  bool get biometricLockedOut => _biometricFailCount >= 3;
  bool get pinEnabled => _user?.securePin != null && _user!.securePin!.isNotEmpty;

  AuthViewModel() {
    _init();
  }

  /// Sets an error message and auto-clears it after [seconds] seconds.
  void setError(String message, {double seconds = 2.8}) {
    _errorTimer?.cancel();
    _error = message;
    _errorTimer = Timer(Duration(milliseconds: (seconds * 1000).toInt()), () {
      _error = null;
      notifyListeners();
    });
  }

  void clearError() {
    _error = null;
    _errorTimer?.cancel();
    notifyListeners();
  }

  /// Sets a success message and auto-clears it after [seconds] seconds.
  void setSuccess(String message, {double seconds = 2.8}) {
    _successTimer?.cancel();
    _success = message;
    _successTimer = Timer(Duration(milliseconds: (seconds * 1000).toInt()), () {
      _success = null;
      notifyListeners();
    });
  }

  void clearSuccess() {
    _success = null;
    _successTimer?.cancel();
    notifyListeners();
  }

  /// Generates a 6-digit OTP and sends it to the user's email.
  Future<bool> sendOTPForRegistration(String email, Map<String, dynamic> registrationData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Check if email already has a profile in Firestore
      bool isTaken = await _firestoreService.isEmailTaken(email);
      if (isTaken) {
        setError("An account already exists for this email.");
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 2. Generate 6-digit OTP
      final random = Random();
      final otp = (100000 + random.nextInt(900000)).toString();
      
      bool sent = await EmailService.sendOTP(email, otp);
      if (sent) {
        _currentOTP = otp;
        _pendingRegistrationData = registrationData;
        _otpSentTime = DateTime.now();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        setError("Failed to send verification code. Please try again.");
      }
    } catch (e) {
      setError(e.toString());
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Verifies the entered OTP and completes registration.
  Future<bool> verifyOTPAndRegister(String enteredOTP) async {
    if (_currentOTP == null || _pendingRegistrationData == null) {
      setError("Session expired. Please register again.");
      return false;
    }

    if (enteredOTP != _currentOTP) {
      setError("Invalid verification code. Please check and try again.");
      return false;
    }

    // Check expiry (e.g., 10 minutes)
    if (DateTime.now().difference(_otpSentTime!).inMinutes > 10) {
      setError("Verification code expired. Please request a new one.");
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final data = _pendingRegistrationData!;
      bool success = await register(
        data['email'],
        data['password'],
        data['fullName'],
        data['age'],
        data['weight'],
        data['height'],
        profileImageData: data['profileImageData'],
      );

      if (success) {
        _currentOTP = null;
        _pendingRegistrationData = null;
      }
      
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      setError(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Resends the OTP to the pending email.
  Future<bool> resendOTP() async {
    if (_pendingRegistrationData == null) return false;
    return sendOTPForRegistration(_pendingRegistrationData!['email'], _pendingRegistrationData!);
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();
    _user = await _authRepository.getCurrentUserModel();
    
    // Check local storage for biometric preference
    final bioEnabled = await _storageService.read('biometric_enabled');
    
    // Initially, if no user or biometrics/PIN are disabled, we don't need biometric check
    if (_user == null || (bioEnabled != 'true' && !pinEnabled)) {
      _isBiometricAuthenticated = true;
      _isPinAuthenticated = true;
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    _success = null;
    notifyListeners();
    try {
      _user = await _authRepository.login(email, password);
      if (_user != null) {
        _isBiometricAuthenticated = true;
        _isPinAuthenticated = true;
        _biometricFailCount = 0;
        setSuccess("Welcome back, ${_user!.fullName}!");
      }
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      setError(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password, String fullName, int age, double weight, double height, {Uint8List? profileImageData}) async {
    _isLoading = true;
    _error = null;
    _success = null;
    notifyListeners();
    try {
      _user = await _authRepository.register(email, password, fullName, age, weight, height, profileImageData: profileImageData);
      if (_user != null) {
        _isBiometricAuthenticated = true;
        _isPinAuthenticated = true;
        _biometricFailCount = 0;
        setSuccess("Account created successfully!");
      }
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      setError(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    _success = null;
    notifyListeners();
    try {
      _user = await _authRepository.signInWithGoogle();
      if (_user != null) {
        _isBiometricAuthenticated = true;
        _isPinAuthenticated = true;
        _biometricFailCount = 0;
        setSuccess("Signed in with Google successfully!");
      } else {
        // Handle cancellation
        setError("Sign-in with Google was cancelled. Please try again.");
      }
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      setError(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithFacebook() async {
    _isLoading = true;
    _error = null;
    _success = null;
    notifyListeners();
    try {
      _user = await _authRepository.signInWithFacebook();
      if (_user != null) {
        _isBiometricAuthenticated = true;
        _isPinAuthenticated = true;
        _biometricFailCount = 0;
        setSuccess("Signed in with Facebook successfully!");
      } else {
        // Handle cancellation
        setError("Sign-in with Facebook was cancelled. Please try again.");
      }
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      setError(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _authRepository.deleteAccount();
      _user = null;
      _isBiometricAuthenticated = false;
      _isPinAuthenticated = false;
      _biometricFailCount = 0;
      setSuccess("Your account has been permanently deleted.");
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('requires-recent-login')) {
        setError("For security, please log in again before deleting your account.");
      } else {
        setError(errorMessage);
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshUser() async {
    _user = await _authRepository.getCurrentUserModel();
    notifyListeners();
  }

  Future<void> logout({bool showSuccess = true}) async {
    await _authRepository.signOut();
    // We keep biometric_enabled in storage so the Login page knows to show the button
    _user = null;
    _isBiometricAuthenticated = false;
    _isPinAuthenticated = false;
    _biometricFailCount = 0;
    if (showSuccess) {
      setSuccess("Logged out successfully.");
    }
    notifyListeners();
  }

  Future<bool> toggleBiometrics(bool enabled, {String? password}) async {
    print("ToggleBiometrics: Start. Enabled=$enabled");
    if (_user == null) {
      print("ToggleBiometrics: No user found.");
      return false;
    }
    _error = null;
    
    if (enabled) {
      if (password == null) {
        print("ToggleBiometrics: Password null.");
        setError("Password is required to enable biometric login.");
        return false;
      }

      // 1. Check if hardware is even capable/supported
      print("ToggleBiometrics: Checking hardware availability...");
      bool available = await _localAuthService.isBiometricAvailable();
      print("ToggleBiometrics: Hardware available = $available");
      
      if (!available) {
        setError("Your device or browser does not support biometric security.");
        notifyListeners();
        return false;
      }

      try {
        print("ToggleBiometrics: Triggering biometric enrollment (CREATE)...");
        bool enrolled = await _localAuthService.enrollBiometrics(_user!.email);
        print("ToggleBiometrics: User enrolled = $enrolled");
        
        if (!enrolled) {
          setError("Failed to create passkey. Ensure your device has a fingerprint or screen lock.");
          notifyListeners();
          return false;
        }

        // Verify password first
        print("ToggleBiometrics: Verifying account password...");
        bool passwordValid = await verifyPassword(password);
        print("ToggleBiometrics: Password valid = $passwordValid");
        
        if (!passwordValid) {
          setError("Incorrect password. Could not enable biometrics.");
          return false;
        }

        // Save credentials for later login
        print("ToggleBiometrics: Saving credentials to secure storage...");
        await _storageService.save('biometric_email', _user!.email);
        await _storageService.save('biometric_password', password);
        await _storageService.save('biometric_enabled', 'true');
      } catch (e) {
        print("ToggleBiometrics: Error caught = $e");
        setError("Hardware Error: ${e.toString()}");
        notifyListeners();
        return false;
      }
    } else {
      print("ToggleBiometrics: Disabling biometrics...");
      await _storageService.delete('biometric_email');
      await _storageService.delete('biometric_password');
      await _storageService.save('biometric_enabled', 'false');
    }

    try {
      print("ToggleBiometrics: Updating Firestore status to $enabled");
      await _firestoreService.updateBiometricStatus(_user!.uid, enabled);
      _user = _user!.copyWith(biometricEnabled: enabled);
      if (!enabled) {
        _isBiometricAuthenticated = true;
      }
      print("ToggleBiometrics: Success!");
      notifyListeners();
      return true;
    } catch (e) {
      print("ToggleBiometrics: Firestore update failed = $e");
      setError(e.toString());
      return false;
    }
  }

  Future<bool> setSecurePin(String pin) async {
    if (_user == null) return false;
    _isLoading = true;
    notifyListeners();
    try {
      await _firestoreService.updateSecurePin(_user!.uid, pin);
      _user = _user!.copyWith(securePin: pin);
      // Ensure we stay authenticated after setting the PIN
      _isPinAuthenticated = true; 
      _isBiometricAuthenticated = true;
      setSuccess("Secure PIN set successfully!");
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      setError("Failed to set PIN: ${e.toString()}");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeSecurePin() async {
    if (_user == null) return false;
    _isLoading = true;
    notifyListeners();
    try {
      await _firestoreService.updateSecurePin(_user!.uid, null);
      _user = _user!.copyWith(clearPin: true);
      // We don't set this to true anymore, we let the session persist 
      // without triggering an authentication refresh.
      setSuccess("Secure PIN disabled.");
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      setError("Failed to remove PIN: ${e.toString()}");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // We check local storage as the source of truth for the device preference
      final bioEnabled = await _storageService.read('biometric_enabled');
      if (bioEnabled != 'true') {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      bool hardwareSuccess = await _localAuthService.authenticate();
      if (hardwareSuccess) {
        // Retrieve credentials
        final email = await _storageService.read('biometric_email');
        final password = await _storageService.read('biometric_password');

        if (email != null && password != null) {
          // Perform actual login
          _user = await _authRepository.login(email, password);
          if (_user != null) {
            _isBiometricAuthenticated = true;
            _isPinAuthenticated = true;
            _biometricFailCount = 0;
            setSuccess("Logged in with biometrics!");
            _isLoading = false;
            notifyListeners();
            return true;
          } else {
            setError("Biometric login failed. Please use email and password.");
          }
        } else {
          setError("Stored credentials not found. Please log in manually.");
        }
      } else {
        _biometricFailCount++;
        setError("Biometric authentication cancelled or failed.");
      }
    } catch (e) {
      setError("Biometric login error: ${e.toString()}");
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> verifyPin(String enteredPin) async {
    if (_user == null || _user!.securePin == null) return false;
    if (_user!.securePin == enteredPin) {
      _isPinAuthenticated = true;
      _isBiometricAuthenticated = true; // PIN serves as a manual override for Biometrics
      _biometricFailCount = 0;
      setSuccess("App unlocked successfully!");
      notifyListeners();
      return true;
    } else {
      _biometricFailCount++;
      setError("Incorrect PIN. Attempt $_biometricFailCount/3.");
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyPassword(String password) async {
    if (_user == null) return false;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // Re-authenticating using login repository logic
      final result = await _authRepository.login(_user!.email, password);
      if (result != null) {
        _isBiometricAuthenticated = true;
        _isPinAuthenticated = true;
        _biometricFailCount = 0;
      }
      _isLoading = false;
      notifyListeners();
      return result != null;
    } catch (e) {
      setError("Invalid password. Please try again.");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void resetBiometricAuth() {
    _isBiometricAuthenticated = false;
    _isPinAuthenticated = false;
    _biometricFailCount = 0;
    notifyListeners();
  }
}
