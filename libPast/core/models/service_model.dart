class ServiceModel {
  final String id;
  final String templeId; // Nullable if private priest service
  final String priestId; // Nullable if temple service
  final String name;
  final String description;
  final double amount;
  final int maxParticipants;
  final String duration;
  final String image;
  final bool isVideoCall;

  ServiceModel({
    required this.id,
    required this.templeId,
    required this.priestId,
    required this.name,
    required this.description,
    required this.amount,
    required this.maxParticipants,
    required this.duration,
    required this.image,
    this.isVideoCall = false,
  });

  factory ServiceModel.fromJson(Map<dynamic, dynamic> json, String id) {
    return ServiceModel(
      id: id,
      templeId: json['templeId']?.toString() ?? '',
      priestId: json['priestId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      maxParticipants: int.tryParse(json['maxParticipants']?.toString() ?? '0') ?? 1,
      duration: json['duration']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      isVideoCall: json['isVideoCall'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'templeId': templeId,
      'priestId': priestId,
      'name': name,
      'description': description,
      'amount': amount,
      'maxParticipants': maxParticipants,
      'duration': duration,
      'image': image,
      'isVideoCall': isVideoCall,
    };
  }
}
