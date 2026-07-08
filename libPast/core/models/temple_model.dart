class TempleModel {
  final String id;
  final String name;
  final String description;
  final String address;
  final String contact;
  final String profileImage;
  final String coverImage;
  final List<String> galleryImages;
  final String ownerUid;
  final Map<String, String> activePriests; // priestId -> status (pending, accepted, rejected)

  TempleModel({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.contact,
    required this.profileImage,
    required this.coverImage,
    required this.galleryImages,
    required this.ownerUid,
    required this.activePriests,
  });

  factory TempleModel.fromJson(Map<dynamic, dynamic> json, String id) {
    var priests = json['activePriests'];
    Map<String, String> priestMap = {};
    if (priests is Map) {
      priests.forEach((k, v) {
        priestMap[k.toString()] = v.toString();
      });
    }

    var gallery = json['galleryImages'];
    List<String> galleryList = [];
    if (gallery is List) {
      galleryList = gallery.map((e) => e.toString()).toList();
    }

    return TempleModel(
      id: id,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      contact: json['contact']?.toString() ?? '',
      profileImage: json['profileImage']?.toString() ?? '',
      coverImage: json['coverImage']?.toString() ?? '',
      galleryImages: galleryList,
      ownerUid: json['ownerUid']?.toString() ?? '',
      activePriests: priestMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'address': address,
      'contact': contact,
      'profileImage': profileImage,
      'coverImage': coverImage,
      'galleryImages': galleryImages,
      'ownerUid': ownerUid,
      'activePriests': activePriests,
    };
  }

  TempleModel copyWith({
    String? id,
    String? name,
    String? description,
    String? address,
    String? contact,
    String? profileImage,
    String? coverImage,
    List<String>? galleryImages,
    String? ownerUid,
    Map<String, String>? activePriests,
  }) {
    return TempleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      contact: contact ?? this.contact,
      profileImage: profileImage ?? this.profileImage,
      coverImage: coverImage ?? this.coverImage,
      galleryImages: galleryImages ?? this.galleryImages,
      ownerUid: ownerUid ?? this.ownerUid,
      activePriests: activePriests ?? this.activePriests,
    );
  }
}
