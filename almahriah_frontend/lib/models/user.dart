// almahriah_frontend/lib/models/user.dart

class User {
  final int id;
  final String fullName;
  final String username;
  final String role;
  final String department;
  final String? profilePictureUrl; // this for the profile picture
  final int isActive;
  final String token;

  User({
    required this.id,
    required this.fullName,
    required this.username,
    required this.role,
    required this.department,
    required this.profilePictureUrl,
    required this.isActive,
    required this.token,
  });

  factory User.fromJson(Map<String, dynamic> json, String token) {
    return User(
      id: json['id'] as int,
      fullName: json['fullName'] as String,
      username: json['username'] as String,
      role: json['role'] as String,
      department: json['department'] as String,
      profilePictureUrl: json['profilePictureUrl'] as String?,
      isActive: json['isActive'] as int,
      token: token,
    );
  }

  // --- أضف هذه الدالة الجديدة ---
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'username': username,
      'role': role,
      'department': department,
      'profilePictureUrl': profilePictureUrl,
      'isActive': isActive,
      'token': token,
    };
  }
}