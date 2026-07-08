class OrderModel {
  final String id;
  final String userId;
  final String userName;
  final String templeId; // Empty if private priest booking
  final String templeName;
  final String priestId; // Empty if temple booking (or populated if pre-assigned)
  final String serviceId;
  final String serviceName;
  final String assignedPriest;
  final String assignedPriestName;
  final String bookingDate;
  final String bookingTime;
  final double amount;
  final String status; // pending, accepted, completed, cancelled, declined
  final String paymentStatus; // pending, success
  final String paymentReference;
  final String jitsiLink;
  final int createdAt;
  final List<String> participants;

  OrderModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.templeId,
    required this.templeName,
    required this.priestId,
    required this.serviceId,
    required this.serviceName,
    required this.assignedPriest,
    required this.assignedPriestName,
    required this.bookingDate,
    required this.bookingTime,
    required this.amount,
    required this.status,
    required this.paymentStatus,
    required this.paymentReference,
    required this.jitsiLink,
    required this.createdAt,
    this.participants = const [],
  });

  factory OrderModel.fromJson(Map<dynamic, dynamic> json, String id) {
    return OrderModel(
      id: id,
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      templeId: json['templeId']?.toString() ?? '',
      templeName: json['templeName']?.toString() ?? '',
      priestId: json['priestId']?.toString() ?? '',
      serviceId: json['serviceId']?.toString() ?? '',
      serviceName: json['serviceName']?.toString() ?? '',
      assignedPriest: json['assignedPriest']?.toString() ?? '',
      assignedPriestName: json['assignedPriestName']?.toString() ?? '',
      bookingDate: json['bookingDate']?.toString() ?? '',
      bookingTime: json['bookingTime']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      status: json['status']?.toString() ?? 'pending',
      paymentStatus: json['paymentStatus']?.toString() ?? 'pending',
      paymentReference: json['paymentReference']?.toString() ?? '',
      jitsiLink: json['jitsiLink']?.toString() ?? '',
      createdAt: int.tryParse(json['createdAt']?.toString() ?? '0') ?? 0,
      participants: (json['participants'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'templeId': templeId,
      'templeName': templeName,
      'priestId': priestId,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'assignedPriest': assignedPriest,
      'assignedPriestName': assignedPriestName,
      'bookingDate': bookingDate,
      'bookingTime': bookingTime,
      'amount': amount,
      'status': status,
      'paymentStatus': paymentStatus,
      'paymentReference': paymentReference,
      'jitsiLink': jitsiLink,
      'createdAt': createdAt,
      'participants': participants,
    };
  }

  OrderModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? templeId,
    String? templeName,
    String? priestId,
    String? serviceId,
    String? serviceName,
    String? assignedPriest,
    String? assignedPriestName,
    String? bookingDate,
    String? bookingTime,
    double? amount,
    String? status,
    String? paymentStatus,
    String? paymentReference,
    String? jitsiLink,
    int? createdAt,
    List<String>? participants,
  }) {
    return OrderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      templeId: templeId ?? this.templeId,
      templeName: templeName ?? this.templeName,
      priestId: priestId ?? this.priestId,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      assignedPriest: assignedPriest ?? this.assignedPriest,
      assignedPriestName: assignedPriestName ?? this.assignedPriestName,
      bookingDate: bookingDate ?? this.bookingDate,
      bookingTime: bookingTime ?? this.bookingTime,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentReference: paymentReference ?? this.paymentReference,
      jitsiLink: jitsiLink ?? this.jitsiLink,
      createdAt: createdAt ?? this.createdAt,
      participants: participants ?? this.participants,
    );
  }
}
