class NotificationModel {
  final String id;
  final String notificationId;
  final String userId;
  final String title;
  final String message;
  final String type; // 'complaint', 'order', 'wallet', 'general'
  final String referenceId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.referenceId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id']?.toString() ?? '',
      notificationId: json['notificationId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? 'general',
      referenceId: json['referenceId']?.toString() ?? '',
      isRead: json['isRead'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      notificationId: notificationId,
      userId: userId,
      title: title,
      message: message,
      type: type,
      referenceId: referenceId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
