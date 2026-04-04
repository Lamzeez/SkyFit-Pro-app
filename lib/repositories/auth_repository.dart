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
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
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
        
        if (profileImageData != null) {
          try {
            img.Image? decodedImage = img.decodeImage(profileImageData);
            if (decodedImage != null) {
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
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw "An account already exists for this email.";
      }
      rethrow;
    } catch (e) {
      print("Error in register: $e");
      rethrow;
    }
    return null;
  }

  Future<UserModel?> login(String email, String password) async {
    if (!EnvConfig.isFirebaseConfigured) {
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
          userModel = UserModel(
            uid: user.uid,
            email: user.email ?? '',
            fullName: user.displayName ?? '',
            age: 0,
            weight: 0.0,
            height: 170.0,
            authMethod: 'google',
          );
          await _firestoreService.createUser(userModel);
        } else {
          // Self-healing: Update missing email or authMethod if needed
          bool needsUpdate = false;
          if (userModel.email.isEmpty && user.email != null && user.email!.isNotEmpty) {
            userModel = userModel.copyWith(email: user.email);
            needsUpdate = true;
          }
          if (userModel.authMethod != 'google') {
            userModel = userModel.copyWith(authMethod: 'google');
            needsUpdate = true;
          }
          if (needsUpdate) {
            await _firestoreService.updateUser(userModel);
          }
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
    if (!EnvConfig.isFirebaseConfigured) {
      return UserModel(uid: "mock_facebook_uid", email: "facebook@mock.com", fullName: "Facebook Mock User", age: 0, weight: 0.0, height: 170.0);
    }
    try {
      final LoginResult result = await _facebookAuth.login(
        permissions: ['public_profile', 'email'],
      );
      if (result.status == LoginStatus.success) {
        final AuthCredential credential = FacebookAuthProvider.credential(result.accessToken!.tokenString);
        final UserCredential userCredential = await _auth.signInWithCredential(credential);
        final User? user = userCredential.user;

        if (user != null) {
          UserModel? userModel = await _firestoreService.getUser(user.uid);
          if (userModel == null) {
            userModel = UserModel(
              uid: user.uid,
              email: user.email ?? '',
              fullName: user.displayName ?? '',
              age: 0,
              weight: 0.0,
              height: 170.0,
              authMethod: 'facebook',
            );
            await _firestoreService.createUser(userModel);
          } else {
            // Self-healing: Update missing email or authMethod if needed
            bool needsUpdate = false;
            if (userModel.email.isEmpty && user.email != null && user.email!.isNotEmpty) {
              userModel = userModel.copyWith(email: user.email);
              needsUpdate = true;
            }
            if (userModel.authMethod != 'facebook') {
              userModel = userModel.copyWith(authMethod: 'facebook');
              needsUpdate = true;
            }
            if (needsUpdate) {
              await _firestoreService.updateUser(userModel);
            }
          }
          return userModel;
        }
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }

  Future<void> signOut() async {
    if (!EnvConfig.isFirebaseConfigured) return;
    try {
      await _googleSignIn.signOut();
      final accessToken = await _facebookAuth.accessToken;
      if (accessToken != null) {
        await _facebookAuth.logOut();
      }
      await _auth.signOut();
    } catch (e) {
      await _auth.signOut();
    }
  }

  Future<void> deleteAccount() async {
    if (!EnvConfig.isFirebaseConfigured) return;
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestoreService.deleteUser(user.uid);
        await user.delete();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel?> getCurrentUserModel() async {
    if (!EnvConfig.isFirebaseConfigured) return null;
    User? user = _auth.currentUser;
    if (user != null) {
      UserModel? userModel = await _firestoreService.getUser(user.uid);
      if (userModel != null) {
        bool needsUpdate = false;
        
        // 1. Self-healing: Email (Aggressive detection)
        String? firebaseEmail = user.email;
        if (firebaseEmail == null || firebaseEmail.isEmpty) {
          for (final info in user.providerData) {
            if (info.email != null && info.email!.isNotEmpty) {
              firebaseEmail = info.email;
              break;
            }
          }
        }

        if (userModel.email.isEmpty && firebaseEmail != null && firebaseEmail.isNotEmpty) {
          userModel = userModel.copyWith(email: firebaseEmail);
          needsUpdate = true;
        }

        // 2. Self-healing: Auth Method (Detect Google/Facebook)
        String detectedMethod = 'email';
        for (final info in user.providerData) {
          if (info.providerId == 'google.com') {
            detectedMethod = 'google';
            break;
          } else if (info.providerId == 'facebook.com') {
            detectedMethod = 'facebook';
            break;
          }
        }

        if (userModel.authMethod != detectedMethod) {
          userModel = userModel.copyWith(authMethod: detectedMethod);
          needsUpdate = true;
        }

        if (needsUpdate) {
          await _firestoreService.updateUser(userModel);
        }
      }
      return userModel;
    }
    return null;
  }

  Future<void> updateFirestoreUser(UserModel user) async {
    await _firestoreService.updateUser(user);
  }
}
