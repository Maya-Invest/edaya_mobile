import 'package:edaya_shared/edaya_shared.dart';

enum InboxDeliveryStatus {
  pending,
  sent,
  failed,
  read,
  cancelled;

  static InboxDeliveryStatus fromApi(String? value) {
    return switch (value) {
      'sent' => InboxDeliveryStatus.sent,
      'failed' => InboxDeliveryStatus.failed,
      'read' => InboxDeliveryStatus.read,
      'cancelled' => InboxDeliveryStatus.cancelled,
      _ => InboxDeliveryStatus.pending,
    };
  }

  String get label => switch (this) {
    InboxDeliveryStatus.pending => 'Pending',
    InboxDeliveryStatus.sent => 'New',
    InboxDeliveryStatus.failed => 'Failed',
    InboxDeliveryStatus.read => 'Read',
    InboxDeliveryStatus.cancelled => 'Cancelled',
  };
}

class InboxDelivery {
  const InboxDelivery({
    required this.id,
    required this.subjectId,
    required this.status,
    required this.title,
    required this.body,
    this.announcementId,
    this.eventKey,
    this.sentAt,
    this.readAt,
    this.createdAt,
  });

  factory InboxDelivery.fromJson(Map<String, dynamic> json) {
    return InboxDelivery(
      id: json['id'] as String,
      announcementId: json['announcementId'] as String?,
      eventKey: json['eventKey'] as String?,
      subjectId: json['subjectId'] as String,
      status: InboxDeliveryStatus.fromApi(json['status'] as String?),
      title: json['title'] as String? ?? 'Message',
      body: json['body'] as String? ?? '',
      sentAt: parseApiDateTime(json['sentAt']),
      readAt: parseApiDateTime(json['readAt']),
      createdAt: parseApiDateTime(json['createdAt']),
    );
  }

  final String id;
  final String? announcementId;
  final String? eventKey;
  final String subjectId;
  final InboxDeliveryStatus status;
  final String title;
  final String body;
  final DateTime? sentAt;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isUnread => status != InboxDeliveryStatus.read;

  DateTime? get sortDate => sentAt ?? createdAt;

  InboxDelivery copyWith({
    InboxDeliveryStatus? status,
    DateTime? readAt,
    DateTime? sentAt,
  }) {
    return InboxDelivery(
      id: id,
      announcementId: announcementId,
      eventKey: eventKey,
      subjectId: subjectId,
      status: status ?? this.status,
      title: title,
      body: body,
      sentAt: sentAt ?? this.sentAt,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }
}
