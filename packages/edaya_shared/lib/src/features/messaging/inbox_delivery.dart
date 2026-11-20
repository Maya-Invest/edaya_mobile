import '../../common/utils/date_time_parse.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_lookup.dart';

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
    this.isPreview = false,
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

  factory InboxDelivery.fromPreview(
    Map<String, dynamic> row,
    String subjectId,
  ) => InboxDelivery(
    id: row['id'] as String,
    subjectId: subjectId,
    status: InboxDeliveryStatus.fromApi(row['status'] as String),
    title: row['title'] as String,
    body: row['preview'] as String,
    sentAt: parseApiDateTime(row['at']),
    isPreview: true,
  );

  final bool isPreview;
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
      isPreview: isPreview,
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
