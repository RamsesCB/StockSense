class UserModel {
  final int id;
  final String fullName;
  final String email;
  final String role;
  final String? studentCode;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.studentCode,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      studentCode: json['student_code'] as String?,
    );
  }

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
