import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../utils/env_config.dart';

class FirestoreService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<void> createUser(UserModel user) async {
    if (!EnvConfig.isFirebaseConfigured) return;
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    if (!EnvConfig.isFirebaseConfigured) {
      // Return a mock user for local testing if not configured
      return UserModel(
        uid: uid,
        email: "test@example.com",
        fullName: "Mock User",
        age: 25,
        weight: 70.0,
        height: 170.0,
      );
    }
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!, uid);
    }
    return null;
  }

  Future<void> updateUser(UserModel user) async {
    if (!EnvConfig.isFirebaseConfigured) return;
    await _db.collection('users').doc(user.uid).update(user.toMap());
  }

  Future<void> updateBiometricStatus(String uid, bool isEnabled) async {
    if (!EnvConfig.isFirebaseConfigured) return;
    await _db.collection('users').doc(uid).update({'biometricEnabled': isEnabled});
  }

  Future<void> updateSecurePin(String uid, String? pin) async {
    if (!EnvConfig.isFirebaseConfigured) return;
    await _db.collection('users').doc(uid).update({'securePin': pin});
  }

  Future<UserModel?> getUserByEmail(String email) async {
    if (!EnvConfig.isFirebaseConfigured) return null;
    final query = await _db.collection('users').where('email', isEqualTo: email).limit(1).get();
    if (query.docs.isNotEmpty) {
      return UserModel.fromMap(query.docs.first.data(), query.docs.first.id);
    }
    return null;
  }

  Future<bool> isEmailTaken(String email) async {
    if (!EnvConfig.isFirebaseConfigured) return false;
    final query = await _db.collection('users').where('email', isEqualTo: email).limit(1).get();
    return query.docs.isNotEmpty;
  }

  Future<void> deleteUser(String uid) async {
    if (!EnvConfig.isFirebaseConfigured) return;
    await _db.collection('users').doc(uid).delete();
  }
}
