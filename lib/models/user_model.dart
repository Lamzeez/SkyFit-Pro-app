class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final int age;
  final double weight;
  final double height; // Height in cm
  final bool biometricEnabled;
  final String? profilePictureUrl;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.age,
    required this.weight,
    required this.height,
    this.biometricEnabled = false,
    this.profilePictureUrl,
  });

  // Calculate BMI: weight (kg) / [height (m)]^2
  double get bmi {
    if (height <= 0) return 0;
    double heightInMeters = height / 100;
    return weight / (heightInMeters * heightInMeters);
  }

  String get weightCategory {
    double val = bmi;
    if (val <= 0) return 'No Data';
    if (val < 18.5) return 'Underweight';
    if (val < 25) return 'Normal';
    if (val < 30) return 'Overweight';
    return 'High BMI';
  }

  bool get isProfileComplete {
    return fullName.isNotEmpty && age > 0 && weight > 0;
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      age: map['age'] ?? 0,
      weight: (map['weight'] as num?)?.toDouble() ?? 0.0,
      height: (map['height'] as num?)?.toDouble() ?? 170.0, // Default 170cm
      biometricEnabled: map['biometricEnabled'] ?? false,
      profilePictureUrl: map['profilePictureUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'fullName': fullName,
      'age': age,
      'weight': weight,
      'height': height,
      'biometricEnabled': biometricEnabled,
      'profilePictureUrl': profilePictureUrl,
    };
  }

  UserModel copyWith({
    String? fullName,
    int? age,
    double? weight,
    double? height,
    bool? biometricEnabled,
    String? profilePictureUrl,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      fullName: fullName ?? this.fullName,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
    );
  }
}
