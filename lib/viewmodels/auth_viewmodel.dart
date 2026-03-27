import 'package:flutter/material.dart';
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
  bool get biometricLockedOut => _biometricFailCount >= 3;

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
      // Generate 6-digit OTP
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
    
    // Initially, if no user or biometrics are disabled, we don't need biometric check
    if (_user == null || bioEnabled != 'true') {
      _isBiometricAuthenticated = true;
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
        _biometricFailCount = 0;
        setSuccess("Signed in with Google successfully!");
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
        _biometricFailCount = 0;
        setSuccess("Signed in with Facebook successfully!");
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

  Future<void> refreshUser() async {
    _user = await _authRepository.getCurrentUserModel();
    notifyListeners();
  }

  Future<void> logout({bool showSuccess = true}) async {
    await _authRepository.signOut();
    await _storageService.delete('biometric_enabled');
    _user = null;
    _isBiometricAuthenticated = false;
    _biometricFailCount = 0;
    if (showSuccess) {
      setSuccess("Logged out successfully.");
    }
    notifyListeners();
  }

  Future<bool> toggleBiometrics(bool enabled) async {
    if (_user == null) return false;
    _error = null;
    
    if (enabled) {
      try {
        debugPrint("Attempting to toggle biometrics ON. Authenticating...");
        bool success = await _localAuthService.authenticate();
        if (!success) {
          setError("Authentication failed. Ensure you have a PIN/Fingerprint set up.");
          notifyListeners();
          return false;
        }
      } catch (e) {
        setError("Hardware Error: ${e.toString()}");
        notifyListeners();
        return false;
      }
    }

    try {
      debugPrint("Saving biometric status to Firestore/Storage: $enabled");
      await _firestoreService.updateBiometricStatus(_user!.uid, enabled);
      await _storageService.save('biometric_enabled', enabled.toString());
      _user = _user!.copyWith(biometricEnabled: enabled);
      if (!enabled) {
        _isBiometricAuthenticated = true;
      }
      notifyListeners();
      return true;
    } catch (e) {
      setError(e.toString());
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    // If we don't have a user in memory yet (e.g. fresh refresh), try to get it
    if (_user == null) {
      _user = await _authRepository.getCurrentUserModel();
    }
    
    // We still check local storage as the source of truth for the device preference
    final bioEnabled = await _storageService.read('biometric_enabled');
    if (bioEnabled != 'true') return false;
    
    bool success = await _localAuthService.authenticate();
    if (success) {
      _isBiometricAuthenticated = true;
      _biometricFailCount = 0;
    } else {
      _biometricFailCount++;
    }
    notifyListeners();
    return success;
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
    _biometricFailCount = 0;
    notifyListeners();
  }
}
