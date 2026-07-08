enum UserRole { user, temple, priest }

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String passwordHash;
  final String securityQuestion;
  final String securityAnswer;
  final String profilePic;
  final String bio;
  final UserRole role;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.passwordHash,
    required this.securityQuestion,
    required this.securityAnswer,
    required this.profilePic,
    required this.bio,
    required this.role,
  });

  factory UserModel.fromJson(Map<dynamic, dynamic> json, String uid) {
    return UserModel(
      uid: uid,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      passwordHash: json['passwordHash']?.toString() ?? '',
      securityQuestion: json['securityQuestion']?.toString() ?? '',
      securityAnswer: json['securityAnswer']?.toString() ?? '',
      profilePic: json['profilePic']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role']?.toString(),
        orElse: () => UserRole.user,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'passwordHash': passwordHash,
      'securityQuestion': securityQuestion,
      'securityAnswer': securityAnswer,
      'profilePic': profilePic,
      'bio': bio,
      'role': role.name,
    };
  }
}
