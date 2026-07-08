class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // booking_created, booking_accepted, priest_assigned, invitation_received, payment_success, live_session
  final bool read;
  final int timestamp;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    required this.timestamp,
  });

  factory NotificationModel.fromJson(Map<dynamic, dynamic> json, String id) {
    return NotificationModel(
      id: id,
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? 'booking_created',
      read: json['read'] == true,
      timestamp: int.tryParse(json['timestamp']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'read': read,
      'timestamp': timestamp,
    };
  }
}
