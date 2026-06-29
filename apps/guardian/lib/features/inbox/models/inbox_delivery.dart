import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_shared/src/l10n/app_localizations.dart';
import 'package:edaya_shared/src/l10n/l10n_lookup.dart';

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

  String label(AppLocalizations l10n) => switch (this) {
    InboxDeliveryStatus.pending => l10n.inboxStatusPending,
    InboxDeliveryStatus.sent => l10n.inboxStatusNew,
    InboxDeliveryStatus.failed => l10n.inboxStatusFailed,
    InboxDeliveryStatus.read => l10n.inboxStatusRead,
    InboxDeliveryStatus.cancelled => l10n.inboxStatusCancelled,
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
      title: json['title'] as String? ?? systemL10n().messageDefaultTitle,
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
