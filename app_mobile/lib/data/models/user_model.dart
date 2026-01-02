class UserModel {
  final int id;
  final String fullName;
  final String email;
  final String role; // 'admin' or 'student'
  final String? studentCode;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.studentCode,
  });

  // Factory constructor for creating a new UserModel instance from a map.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      studentCode: json['student_code'] as String?,
    );
  }

  // Method for converting a UserModel instance to a map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'role': role,
      'student_code': studentCode,
    };
  }
}
