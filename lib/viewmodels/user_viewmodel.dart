import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class UserViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setUser(UserModel? user) {
    _user = user;
    notifyListeners();
  }

  Future<bool> updateProfile({String? fullName, int? age, double? weight, double? height, String? profilePictureUrl}) async {
    if (_user == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedUser = _user!.copyWith(
        fullName: fullName,
        age: age,
        weight: weight,
        height: height,
        profilePictureUrl: profilePictureUrl,
      );
      await _firestoreService.updateUser(updatedUser);
      _user = updatedUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<String?> uploadProfilePicture(Uint8List fileData) async {
    if (_user == null) return null;

    _isLoading = true;
    notifyListeners();

    try {
      // Decode the image for processing
      img.Image? decodedImage = img.decodeImage(fileData);
      if (decodedImage == null) throw Exception("Failed to decode image");

      // Crop to a square from center and Resize to 500x500
      decodedImage = img.copyResizeCropSquare(decodedImage, size: 500);

      // Encode as JPG with 75% quality (Very small file size, good quality)
      final compressedData = img.encodeJpg(decodedImage, quality: 75);
      
      // Convert image to Base64 data URL
      final base64String = base64Encode(compressedData);
      final dataUrl = "data:image/jpeg;base64,$base64String";
      
      await updateProfile(profilePictureUrl: dataUrl);
      
      _isLoading = false;
      notifyListeners();
      return dataUrl;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
}
