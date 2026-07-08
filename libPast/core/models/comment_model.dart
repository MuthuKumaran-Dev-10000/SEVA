class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String content;
  final int timestamp;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.timestamp,
  });

  factory CommentModel.fromJson(Map<dynamic, dynamic> json, String id) {
    return CommentModel(
      id: id,
      postId: json['postId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      timestamp: int.tryParse(json['timestamp']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'content': content,
      'timestamp': timestamp,
    };
  }
}
