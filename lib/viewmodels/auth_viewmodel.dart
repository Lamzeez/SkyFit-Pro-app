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
  Timer? _errorTimer;
  Timer? _successTimer;

  // Persistent lockout tracking
  Map<String, int> _emailFailCounts = {};

  Map<String, int> get emailFailCounts => _emailFailCounts;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get success => _success;
  bool get isBiometricAuthenticated => _isBiometricAuthenticated;
  bool get isPinAuthenticated => _isPinAuthenticated;
  
  bool isEmailLockedOut(String email) {
    return (_emailFailCounts[email] ?? 0) >= 3;
  }

  Future<bool> isDeviceBiometricLocked({String? email}) async {
    final targetEmail = (email != null && email.isNotEmpty) 
        ? email.trim() 
        : await _storageService.read('biometric_email');
        
    if (targetEmail == null) return false;
    return isEmailLockedOut(targetEmail);
  }

  bool get biometricLockedOut {
    if (_user != null) return isEmailLockedOut(_user!.email);
    return false;
  }

  bool get pinEnabled => _user?.securePin != null && _user!.securePin!.isNotEmpty;

  AuthViewModel() {
    _init();
  }

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

  // OTP Verification State
  String? _currentOTP;
  Map<String, dynamic>? _pendingRegistrationData;
  DateTime? _otpSentTime;

  Future<bool> sendOTPForRegistration(String email, Map<String, dynamic> registrationData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      bool isTaken = await _firestoreService.isEmailTaken(email);
      if (isTaken) {
        setError("An account already exists for this email.");
        _isLoading = false;
        notifyListeners();
        return false;
      }
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

  Future<bool> verifyOTPAndRegister(String enteredOTP) async {
    if (_currentOTP == null || _pendingRegistrationData == null) {
      setError("Session expired. Please register again.");
      return false;
    }
    if (enteredOTP != _currentOTP) {
      setError("Invalid verification code. Please check and try again.");
      return false;
    }
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
    final bioEmail = await _storageService.read('biometric_email');
    
    if (bioEmail != null) {
      final storedFailCount = await _storageService.read('fail_count_$bioEmail');
      if (storedFailCount != null) {
        _emailFailCounts[bioEmail] = int.tryParse(storedFailCount) ?? 0;
      }
    }

    if (_user != null) {
      final storedFailCount = await _storageService.read('fail_count_${_user!.email}');
      if (storedFailCount != null) {
        _emailFailCounts[_user!.email] = int.tryParse(storedFailCount) ?? 0;
      }
    }

    // Check if security should be active
    bool shouldLock = false;
    if (_user != null) {
      if (bioEnabled == 'true' || pinEnabled) {
        shouldLock = true;
      }
    }

    if (_user == null || !shouldLock) {
      _isBiometricAuthenticated = true;
      _isPinAuthenticated = true;
    } else {
      // If it should lock, ensure flags are false (reset)
      _isBiometricAuthenticated = false;
      _isPinAuthenticated = false;
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
        _resetFailCount(_user!.email);
        // Important: Update primary biometric user on successful login
        await _storageService.save('biometric_email', _user!.email);
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
        _resetFailCount(_user!.email);
        await _storageService.save('biometric_email', _user!.email);
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
        _resetFailCount(_user!.email);
        await _storageService.save('biometric_email', _user!.email);
        setSuccess("Signed in with Google successfully!");
      } else {
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
        _resetFailCount(_user!.email);
        await _storageService.save('biometric_email', _user!.email);
        setSuccess("Signed in with Facebook successfully!");
      } else {
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
    _user = null;
    _isBiometricAuthenticated = false;
    _isPinAuthenticated = false;
    if (showSuccess) {
      setSuccess("Logged out successfully.");
    }
    notifyListeners();
  }

  Future<bool> toggleBiometrics(bool enabled, {String? password}) async {
    if (_user == null) return false;
    _error = null;
    if (enabled) {
      if (password == null) {
        setError("Password is required to enable biometric login.");
        return false;
      }
      bool available = await _localAuthService.isBiometricAvailable();
      if (!available) {
        setError("Your device or browser does not support biometric security.");
        notifyListeners();
        return false;
      }
      try {
        bool enrolled = await _localAuthService.enrollBiometrics(_user!.email);
        if (!enrolled) {
          setError("Failed to create passkey. Ensure your device has a fingerprint or screen lock.");
          notifyListeners();
          return false;
        }
        bool passwordValid = await verifyPassword(password);
        if (!passwordValid) {
          setError("Incorrect password. Could not enable biometrics.");
          return false;
        }
        // Save to specific account vault
        await _storageService.save('bio_pwd_${_user!.email}', password);
        await _storageService.save('biometric_email', _user!.email); // Track primary
        await _storageService.save('biometric_enabled', 'true');
        setSuccess("Biometric login enabled successfully!");
      } catch (e) {
        setError("Hardware Error: ${e.toString()}");
        notifyListeners();
        return false;
      }
    } else {
      await _storageService.delete('bio_pwd_${_user!.email}');
      await _storageService.save('biometric_enabled', 'false');
      setSuccess("Biometric login disabled.");
    }
    try {
      await _firestoreService.updateBiometricStatus(_user!.uid, enabled);
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

  Future<bool> setSecurePin(String pin) async {
    if (_user == null) return false;
    _isLoading = true;
    notifyListeners();
    try {
      await _firestoreService.updateSecurePin(_user!.uid, pin);
      _user = _user!.copyWith(securePin: pin);
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

  Future<bool> authenticateWithBiometrics({String? enteredEmail}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Trigger the browser prompt to see WHO touched the sensor
      final String? selectedEmail = await _localAuthService.authenticate();
      
      if (selectedEmail != null) {
        // 2. Validate if the user selected in the browser matches what they typed (if any)
        if (enteredEmail != null && enteredEmail.isNotEmpty && enteredEmail.trim() != selectedEmail) {
          setError("You selected the passkey for $selectedEmail, but typed $enteredEmail.");
          _isLoading = false;
          notifyListeners();
          return false;
        }

        // 3. Check for lockouts on the selected account
        if (isEmailLockedOut(selectedEmail)) {
          setError("Biometrics locked for $selectedEmail. Use password.");
          _isLoading = false;
          notifyListeners();
          return false;
        }

        // 4. Retrieve password from the vault for THIS specific email
        final password = await _storageService.read('bio_pwd_$selectedEmail');
        if (password != null) {
          _user = await _authRepository.login(selectedEmail, password);
          if (_user != null) {
            _isBiometricAuthenticated = true;
            _isPinAuthenticated = true;
            _resetFailCount(selectedEmail);
            // Important: Update primary biometric user on success
            await _storageService.save('biometric_email', selectedEmail);
            setSuccess("Logged in as $selectedEmail!");
            _isLoading = false;
            notifyListeners();
            return true;
          } else {
            setError("Login failed. Stored credentials might be outdated.");
          }
        } else {
          setError("No stored password found for $selectedEmail. Please log in manually once.");
        }
      } else {
        // If we don't have a selectedEmail, it means verification failed or was cancelled
        // We increment the strike for the 'enrolledEmail' if one was typed, or the primary one
        final primaryEmail = await _storageService.read('biometric_email');
        final emailToStrike = (enteredEmail != null && enteredEmail.isNotEmpty) ? enteredEmail : primaryEmail;
        
        if (emailToStrike != null) {
          _incrementFailCount(emailToStrike);
          if (isEmailLockedOut(emailToStrike)) {
            setError("Biometrics locked for $emailToStrike. Use password.");
          } else {
            setError("Verification failed. Attempt ${_emailFailCounts[emailToStrike]}/3.");
          }
        } else {
          setError("Biometric verification cancelled.");
        }
      }
    } catch (e) {
      setError("Biometric error: ${e.toString()}");
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> verifyPin(String enteredPin) async {
    if (_user == null || _user!.securePin == null) return false;
    if (_user!.securePin == enteredPin) {
      _isPinAuthenticated = true;
      _isBiometricAuthenticated = true; 
      _resetFailCount(_user!.email);
      setSuccess("App unlocked successfully!");
      notifyListeners();
      return true;
    } else {
      _incrementFailCount(_user!.email);
      setError("Incorrect PIN. Attempt ${_emailFailCounts[_user!.email]}/3.");
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
      final result = await _authRepository.login(_user!.email, password);
      if (result != null) {
        _isBiometricAuthenticated = true;
        _isPinAuthenticated = true;
        _resetFailCount(_user!.email);
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

  void _incrementFailCount(String email) async {
    _emailFailCounts[email] = (_emailFailCounts[email] ?? 0) + 1;
    await _storageService.save('fail_count_$email', _emailFailCounts[email].toString());
    notifyListeners();
  }

  void _resetFailCount(String email) async {
    _emailFailCounts[email] = 0;
    await _storageService.delete('fail_count_$email');
    notifyListeners();
  }

  void resetBiometricAuth() {
    _isBiometricAuthenticated = false;
    _isPinAuthenticated = false;
    notifyListeners();
  }
}
