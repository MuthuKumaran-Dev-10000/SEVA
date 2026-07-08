class PriestModel {
  final String id;
  final String name;
  final String dob;
  final int age;
  final String gender;
  final String mobile;
  final String email;
  final String address;
  final String experience;
  final String rasi;
  final String nakshatra;
  final String lagnam;
  final String bio;
  final String photo;

  PriestModel({
    required this.id,
    required this.name,
    required this.dob,
    required this.age,
    required this.gender,
    required this.mobile,
    required this.email,
    required this.address,
    required this.experience,
    required this.rasi,
    required this.nakshatra,
    required this.lagnam,
    required this.bio,
    required this.photo,
  });

  factory PriestModel.fromJson(Map<dynamic, dynamic> json, String id) {
    return PriestModel(
      id: id,
      name: json['name']?.toString() ?? '',
      dob: json['dob']?.toString() ?? '',
      age: int.tryParse(json['age']?.toString() ?? '0') ?? 0,
      gender: json['gender']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      experience: json['experience']?.toString() ?? '',
      rasi: json['rasi']?.toString() ?? '',
      nakshatra: json['nakshatra']?.toString() ?? '',
      lagnam: json['lagnam']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      photo: json['photo']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dob': dob,
      'age': age,
      'gender': gender,
      'mobile': mobile,
      'email': email,
      'address': address,
      'experience': experience,
      'rasi': rasi,
      'nakshatra': nakshatra,
      'lagnam': lagnam,
      'bio': bio,
      'photo': photo,
    };
  }
}
