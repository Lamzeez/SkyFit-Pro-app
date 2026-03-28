import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:image/image.dart' as img;
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../utils/env_config.dart';

class AuthRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FacebookAuth _facebookAuth = FacebookAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  AuthRepository() {
    // Initialize Facebook Auth for Web
    _facebookAuth.webAndDesktopInitialize(
      appId: EnvConfig.facebookAppId,
      cookie: true,
      xfbml: true,
      version: "v19.0",
    );
  }

  Stream<User?> get authStateChanges => EnvConfig.isFirebaseConfigured ? _auth.authStateChanges() : const Stream.empty();

  Future<UserModel?> register(String email, String password, String fullName, int age, double weight, double height, {Uint8List? profileImageData}) async {
    if (!EnvConfig.isFirebaseConfigured) {
      return UserModel(uid: "mock_uid", email: email, fullName: fullName, age: age, weight: weight, height: height);
    }
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;
      if (user != null) {
        String? profileUrl;
        
        // Crop and Resize to 500x500 square to avoid squishing
        if (profileImageData != null) {
          try {
            img.Image? decodedImage = img.decodeImage(profileImageData);
            if (decodedImage != null) {
              // This crops the image to a square from the center and resizes it
              decodedImage = img.copyResizeCropSquare(decodedImage, size: 500);
              
              final compressedData = img.encodeJpg(decodedImage, quality: 75);
              final base64String = base64Encode(compressedData);
              profileUrl = "data:image/jpeg;base64,$base64String";
            }
          } catch (e) {
            print("Failed to process profile picture: $e");
          }
        }

        UserModel userModel = UserModel(
          uid: user.uid,
          email: email,
          fullName: fullName,
          age: age,
          weight: weight,
          height: height,
          profilePictureUrl: profileUrl,
        );
        await _firestoreService.createUser(userModel);
        return userModel;
      }
    } catch (e) {
      print("Error in register: $e");
      rethrow;
    }
    return null;
  }

  Future<UserModel?> login(String email, String password) async {
    if (!EnvConfig.isFirebaseConfigured) {
      // Mock login for local testing
      return UserModel(
        uid: "mock_uid",
        email: email,
        fullName: "Mock User",
        age: 25,
        weight: 70.0,
        height: 170.0,
      );
    }
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      if (result.user != null) {
        return await _firestoreService.getUser(result.user!.uid);
      }
    } catch (e) {
      print("Error in login: $e");
      rethrow;
    }
    return null;
  }

  Future<UserModel?> signInWithGoogle() async {
    if (!EnvConfig.isFirebaseConfigured) {
      return UserModel(uid: "mock_google_uid", email: "google@mock.com", fullName: "Google Mock User", age: 0, weight: 0.0, height: 170.0);
    }
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        UserModel? userModel = await _firestoreService.getUser(user.uid);
        if (userModel == null) {
          // New user from Google
          userModel = UserModel(
            uid: user.uid,
            email: user.email ?? '',
            fullName: user.displayName ?? '',
            age: 0,
            weight: 0.0,
            height: 170.0,
          );
          await _firestoreService.createUser(userModel);
        }
        return userModel;
      }
    } catch (e) {
      print("Error in Google SSO: $e");
      rethrow;
    }
    return null;
  }

  Future<UserModel?> signInWithFacebook() async {
    print("Facebook SSO started...");
    if (!EnvConfig.isFirebaseConfigured) {
      print("Firebase NOT configured - returning Mock User");
      return UserModel(uid: "mock_facebook_uid", email: "facebook@mock.com", fullName: "Facebook Mock User", age: 0, weight: 0.0, height: 170.0);
    }
    try {
      print("Calling FacebookAuth.instance.login() with explicit permissions...");
      final LoginResult result = await _facebookAuth.login(
        permissions: ['public_profile', 'email'],
      );
      print("Facebook Login Status: ${result.status}");
      
      if (result.status == LoginStatus.success) {
        print("Facebook Login Success - Access Token: ${result.accessToken?.tokenString}");
        final AuthCredential credential = FacebookAuthProvider.credential(result.accessToken!.tokenString);
        
        print("Authenticating with Firebase...");
        final UserCredential userCredential = await _auth.signInWithCredential(credential);
        final User? user = userCredential.user;

        if (user != null) {
          print("Firebase Auth Success - UID: ${user.uid}");
          UserModel? userModel = await _firestoreService.getUser(user.uid);
          if (userModel == null) {
            print("Creating new Firestore user...");
            userModel = UserModel(
              uid: user.uid,
              email: user.email ?? '',
              fullName: user.displayName ?? '',
              age: 0,
              weight: 0.0,
              height: 170.0,
            );
            await _firestoreService.createUser(userModel);
          }
          return userModel;
        }
      } else if (result.status == LoginStatus.cancelled) {
        print("Facebook Login Cancelled by user.");
      } else if (result.status == LoginStatus.failed) {
        print("Facebook Login Failed: ${result.message}");
        throw result.message ?? "Facebook login failed without a message.";
      }
    } catch (e) {
      print("Error in Facebook SSO Catch Block: $e");
      rethrow;
    }
    print("Facebook SSO finished with null result (likely cancelled or failed).");
    return null;
  }

  Future<void> signOut() async {
    if (!EnvConfig.isFirebaseConfigured) return;
    try {
      await _googleSignIn.signOut();
      
      // Only call logOut if we actually have an active Facebook session
      final accessToken = await _facebookAuth.accessToken;
      if (accessToken != null) {
        await _facebookAuth.logOut();
      }
      
      await _auth.signOut();
    } catch (e) {
      print("Error during signOut: $e");
      // Ensure we at least sign out of Firebase
      await _auth.signOut();
    }
  }

  Future<void> deleteAccount() async {
    if (!EnvConfig.isFirebaseConfigured) return;
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // First delete from Firestore
        await _firestoreService.deleteUser(user.uid);
        // Then delete from Firebase Auth
        await user.delete();
      }
    } catch (e) {
      print("Error in deleteAccount: $e");
      rethrow;
    }
  }

  Future<UserModel?> getCurrentUserModel() async {
    if (!EnvConfig.isFirebaseConfigured) return null;
    User? user = _auth.currentUser;
    if (user != null) {
      return await _firestoreService.getUser(user.uid);
    }
    return null;
  }
}
