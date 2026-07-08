class PaymentModel {
  final String paymentId;
  final String orderId;
  final String signature;
  final double amount;
  final String userId;
  final int timestamp;

  PaymentModel({
    required this.paymentId,
    required this.orderId,
    required this.signature,
    required this.amount,
    required this.userId,
    required this.timestamp,
  });

  factory PaymentModel.fromJson(Map<dynamic, dynamic> json, String paymentId) {
    return PaymentModel(
      paymentId: paymentId,
      orderId: json['orderId']?.toString() ?? '',
      signature: json['signature']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      userId: json['userId']?.toString() ?? '',
      timestamp: int.tryParse(json['timestamp']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'signature': signature,
      'amount': amount,
      'userId': userId,
      'timestamp': timestamp,
    };
  }
}
