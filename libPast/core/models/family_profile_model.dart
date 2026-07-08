class FamilyProfileModel {
  final String id;
  final String name;
  final String dob;
  final int age;
  final String gender;
  final String rasi;
  final String nakshatra;
  final String lagnam;
  final String gothram;
  final String relationship;
  final String profilePhoto;

  FamilyProfileModel({
    required this.id,
    required this.name,
    required this.dob,
    required this.age,
    required this.gender,
    required this.rasi,
    required this.nakshatra,
    required this.lagnam,
    required this.gothram,
    required this.relationship,
    required this.profilePhoto,
  });

  factory FamilyProfileModel.fromJson(Map<dynamic, dynamic> json, String id) {
    return FamilyProfileModel(
      id: id,
      name: json['name']?.toString() ?? '',
      dob: json['dob']?.toString() ?? '',
      age: int.tryParse(json['age']?.toString() ?? '0') ?? 0,
      gender: json['gender']?.toString() ?? '',
      rasi: json['rasi']?.toString() ?? '',
      nakshatra: json['nakshatra']?.toString() ?? '',
      lagnam: json['lagnam']?.toString() ?? '',
      gothram: json['gothram']?.toString() ?? '',
      relationship: json['relationship']?.toString() ?? '',
      profilePhoto: json['profilePhoto']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dob': dob,
      'age': age,
      'gender': gender,
      'rasi': rasi,
      'nakshatra': nakshatra,
      'lagnam': lagnam,
      'gothram': gothram,
      'relationship': relationship,
      'profilePhoto': profilePhoto,
    };
  }
}
