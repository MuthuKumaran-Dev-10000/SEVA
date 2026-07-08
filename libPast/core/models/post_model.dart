class PostModel {
  final String id;
  final String authorId;
  final String authorName;
  final String authorImage;
  final String imageUrl;
  final String videoUrl;
  final String caption;
  final int timestamp;

  PostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorImage,
    required this.imageUrl,
    required this.videoUrl,
    required this.caption,
    required this.timestamp,
  });

  factory PostModel.fromJson(Map<dynamic, dynamic> json, String id) {
    return PostModel(
      id: id,
      authorId: json['authorId']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? '',
      authorImage: json['authorImage']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      videoUrl: json['videoUrl']?.toString() ?? '',
      caption: json['caption']?.toString() ?? '',
      timestamp: int.tryParse(json['timestamp']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorImage': authorImage,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'caption': caption,
      'timestamp': timestamp,
    };
  }
}
