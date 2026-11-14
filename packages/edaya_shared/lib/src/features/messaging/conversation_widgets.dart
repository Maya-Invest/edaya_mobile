import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../access/school_client.dart';
import '../../l10n/l10n_extension.dart';
import '../auth/app_session_controller.dart';
import 'conversation_controller.dart';
import 'conversation_message_bubble.dart';

String _enquiryStatus(BuildContext context, Object? status) => switch (status) {
  'awaiting_school' => context.tr.messagingAwaitingSchool,
  'awaiting_guardian' => context.tr.messagingAwaitingGuardian,
  'resolved' => context.tr.messagingResolved,
  _ => '',
};

class MessagingNotice {
  const MessagingNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.unread,
    this.at,
  });
  final String id, title, body;
  final bool unread;
  final DateTime? at;
}

class MessagingInbox extends LScopedView<ConversationController> {
  const MessagingInbox({
    super.key,
    required this.notices,
    required this.onNotice,
    this.guardian = false,
    this.studentId,
    this.studentName,
  });
  final List<MessagingNotice> notices;
  final void Function(String id) onNotice;
  final bool guardian;
  final String? studentId, studentName;
  @override
  ConversationController onConfigScope(LevitScope scope) => scope.put(
    () => ConversationController(
      session: scope.find<AppSessionController>(),
      client: scope.find<SchoolClientFactory>(),
    ),
  );
  @override
  Widget buildView(BuildContext context, ConversationController controller) {
    controller.visible =
        TickerMode.valuesOf(context).enabled &&
        GoRouterState.of(context).uri.path == '/inbox';
    final combined =
        <({DateTime at, Map<String, dynamic>? row, MessagingNotice? notice})>[
          for (final row in controller.rows.value)
            (
              at: DateTime.parse(row['updatedAt'] as String),
              row: row,
              notice: null,
            ),
          for (final notice in notices)
            (
              at: notice.at ?? DateTime.fromMillisecondsSinceEpoch(0),
              row: null,
              notice: notice,
            ),
        ]..sort((a, b) => b.at.compareTo(a.at));
    final unread =
        controller.unreadCount.value + notices.where((n) => n.unread).length;
    return _MessagingLifecycle(
      controller: controller,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(context.tr.unreadCount(unread)),
                if (guardian)
                  FilledButton.icon(
                    onPressed: () async {
                      final id = await showLevitModalBottomSheet<String>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => _ComposeMessage(
                          key: ValueKey(
                            '${controller.identity.value}|$studentId',
                          ),
                          controller: controller,
                          studentId: studentId,
                          studentName: studentName,
                        ),
                      );
                      if (id != null && context.mounted) {
                        context.push('/inbox/conversation/$id');
                      }
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(context.tr.messagingNew),
                  ),
                IconButton(
                  tooltip: context.tr.messagingRefresh,
                  onPressed: controller.busy.value
                      ? null
                      : () => controller.refresh(),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          if (controller.busy.value) const LinearProgressIndicator(),
          if (controller.error.value.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.tr.messagingUnavailable),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (combined.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(context.tr.messagingEmpty),
                    ),
                  for (final item in combined)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          item.row != null
                              ? Icons.forum_outlined
                              : Icons.notifications_outlined,
                        ),
                        title: Text(
                          item.row?['subject'] as String? ?? item.notice!.title,
                          style: TextStyle(
                            fontWeight:
                                (item.row?['unread'] == true ||
                                    item.notice?.unread == true)
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          item.row == null
                              ? item.notice!.body
                              : '${item.row!['destination'] == 'school' ? item.row!['schoolName'] : item.row!['teacherName']} · ${item.row!['studentName'] ?? item.row!['guardianName']}\n${item.row!['lastMessage']}${item.row!['destination'] == 'school' ? '\n${_enquiryStatus(context, item.row!['status'])}' : ''}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing:
                            (item.row?['unread'] == true ||
                                item.notice?.unread == true)
                            ? Icon(
                                Icons.mark_email_unread_outlined,
                                semanticLabel: context.tr.messagingUnread,
                              )
                            : null,
                        onTap: () {
                          if (item.row != null) {
                            context.push(
                              '/inbox/conversation/${item.row!['id']}',
                            );
                          } else {
                            onNotice(item.notice!.id);
                          }
                        },
                      ),
                    ),
                  if (controller.rows.value.length < controller.total.value)
                    TextButton(
                      onPressed: () => controller.refresh(more: true),
                      child: Text(context.tr.messagingLoadMore),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConversationPage extends LScopedView<ConversationController> {
  const ConversationPage({super.key, required this.conversationId});
  final String conversationId;
  @override
  ConversationController onConfigScope(LevitScope scope) => scope.put(
    () => ConversationController(
      session: scope.find<AppSessionController>(),
      client: scope.find<SchoolClientFactory>(),
      conversationId: conversationId,
    ),
  );
  @override
  Widget buildView(BuildContext context, ConversationController controller) {
    controller.visible =
        TickerMode.valuesOf(context).enabled &&
        GoRouterState.of(context).uri.path ==
            '/inbox/conversation/$conversationId';
    final data = controller.detail.value;
    final row = data?['conversation'] as Map?;
    final messages = data?['messages'] as List? ?? const [];
    return _MessagingLifecycle(
      controller: controller,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading:
              ModalRoute.of(context) is! ModalBottomSheetRoute,
          title: Text(
            row?['subject'] as String? ?? context.tr.messagingConversations,
          ),
          actions: [
            IconButton(
              tooltip: context.tr.messagingRefresh,
              onPressed: () => controller.refresh(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.busy.value) const LinearProgressIndicator(),
            if (row != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${row['schoolName']} · ${row['guardianName']}\n${row['teacherName'] ?? context.tr.messagingSchool}${row['studentName'] == null ? '' : ' · ${row['studentName']}'}',
                ),
              ),
            if (row?['destination'] == 'school')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_enquiryStatus(context, row?['status'])),
              ),
            if (row?['destination'] == 'teacher')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  context.tr.messagingOversight,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (controller.error.value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  controller.error.value == 'CONVERSATION_CHANGED'
                      ? context.tr.messagingChanged
                      : context.tr.messagingFailed,
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (data?['hasMore'] == true)
                    TextButton(
                      onPressed: () => controller.refresh(more: true),
                      child: Text(context.tr.messagingLoadMore),
                    ),
                  for (final message in messages)
                    ConversationMessageBubble(
                      key: ValueKey(message['id']),
                      outgoing: isOutgoingConversationMessage(
                        authorKind: message['authorKind'] as String,
                        authorId: message['authorId'] as String? ?? '',
                        viewerKind: controller.session.grants.value?.kind,
                        viewerId: controller.session.grants.value?.actorId,
                      ),
                      author:
                          '${message['authorKind'] == 'staff' ? '${context.tr.messagingSchoolAuthor} · ' : ''}${message['authorName']}',
                      body: message['body'] as String,
                      timestamp:
                          '${context.formatShortDate(DateTime.parse(message['createdAt'] as String))} · ${context.formatTimeOfDay(DateTime.parse(message['createdAt'] as String))}',
                    ),
                ],
              ),
            ),
            if (row != null && (row['allowedActions'] as Map)['reply'] == true)
              _ReplyComposer(
                key: ValueKey('${controller.identity.value}|$conversationId'),
                controller: controller,
                version: (row['version'] as num).toInt(),
              )
            else if (row != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.tr.messagingHistory),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReplyComposer extends StatefulWidget {
  const _ReplyComposer({
    super.key,
    required this.controller,
    required this.version,
  });
  final ConversationController controller;
  final int version;
  @override
  State<_ReplyComposer> createState() => _ReplyComposerState();
}

class _ReplyComposerState extends State<_ReplyComposer> {
  final text = TextEditingController();
  int? draftVersion;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        children: [
          TextField(
            controller: text,
            onChanged: (value) {
              if (draftVersion == null && value.trim().isNotEmpty) {
                draftVersion = widget.version;
              }
            },
            enabled: !widget.controller.sending.value,
            minLines: 2,
            maxLines: 5,
            maxLength: 10000,
            decoration: InputDecoration(labelText: context.tr.messagingReply),
          ),
          FilledButton(
            onPressed: widget.controller.sending.value
                ? null
                : () async {
                    if (text.text.trim().isEmpty) return;
                    final id = await widget.controller.send({
                      'conversationId': widget.controller.conversationId,
                      'expectedVersion': draftVersion ?? widget.version,
                      'body': text.text.trim(),
                    });
                    if (id != null && mounted) {
                      text.clear();
                      draftVersion = null;
                    } else if (mounted &&
                        widget.controller.error.value ==
                            'CONVERSATION_CHANGED') {
                      draftVersion =
                          ((widget.controller.detail.value?['conversation']
                                      as Map?)?['version']
                                  as num?)
                              ?.toInt() ??
                          widget.version;
                    }
                  },
            child: Text(context.tr.messagingSend),
          ),
        ],
      ),
    ),
  );
}

class _ComposeMessage extends StatefulWidget {
  const _ComposeMessage({
    super.key,
    required this.controller,
    this.studentId,
    this.studentName,
  });
  final ConversationController controller;
  final String? studentId, studentName;
  @override
  State<_ComposeMessage> createState() => _ComposeMessageState();
}

class _ComposeMessageState extends State<_ComposeMessage> {
  final subject = TextEditingController(), body = TextEditingController();
  Map<String, dynamic>? recipients;
  String destination = 'school';
  bool includeChild = false, busy = false;
  String? warning;
  late final String identity;
  @override
  void initState() {
    super.initState();
    identity = widget.controller.sessionKey;
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final value = await widget.controller.recipients(widget.studentId);
      if (mounted && identity == widget.controller.sessionKey) {
        setState(() => recipients = value);
      }
    } catch (_) {
      if (mounted) setState(() => warning = 'unavailable');
    }
  }

  @override
  void dispose() {
    subject.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (identity != widget.controller.sessionKey) {
      return const SizedBox.shrink();
    }
    final teachers = recipients?['teachers'] as List? ?? const [];
    final available = destination == 'school'
        ? (recipients?['schoolAvailable'] == true)
        : true;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          24,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr.messagingNew,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (recipients == null && warning == null)
              const LinearProgressIndicator(),
            if (recipients != null)
              DropdownButtonFormField<String>(
                initialValue: destination,
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                    value: 'school',
                    child: Text(
                      '${context.tr.messagingSchool} · ${recipients!['schoolName']}',
                    ),
                  ),
                  for (final teacher in teachers)
                    DropdownMenuItem(
                      value: teacher['id'] as String,
                      child: Text(
                        '${teacher['name']} · ${(teacher['subjects'] as List).join(', ')}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            destination = value;
                            subject.clear();
                            body.clear();
                          });
                        }
                      },
              ),
            if (destination != 'school')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '${widget.studentName ?? ''}\n${context.tr.messagingOversight}',
                ),
              ),
            if (destination == 'school' && widget.studentId != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${context.tr.messagingIncludeChild} · ${widget.studentName ?? ''}',
                ),
                value: includeChild,
                onChanged: busy
                    ? null
                    : (value) => setState(() => includeChild = value),
              ),
            if (!available || warning == 'unavailable')
              Text(context.tr.messagingUnavailable),
            TextField(
              controller: subject,
              enabled: !busy,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: context.tr.messagingSubject,
              ),
            ),
            TextField(
              controller: body,
              enabled: !busy,
              minLines: 4,
              maxLines: 8,
              maxLength: 10000,
              decoration: InputDecoration(labelText: context.tr.messagingBody),
            ),
            if (warning != null && warning != 'unavailable')
              Text(
                warning == 'required'
                    ? context.tr.messagingRequired
                    : context.tr.messagingFailed,
              ),
            FilledButton(
              onPressed: busy || !available
                  ? null
                  : () async {
                      if (identity != widget.controller.sessionKey) {
                        subject.clear();
                        body.clear();
                        Navigator.of(context).pop();
                        return;
                      }
                      if (subject.text.trim().isEmpty ||
                          body.text.trim().isEmpty) {
                        setState(() => warning = 'required');
                        return;
                      }
                      setState(() {
                        busy = true;
                        warning = null;
                      });
                      final id = await widget.controller.send({
                        'destination': destination == 'school'
                            ? 'school'
                            : 'teacher',
                        if (destination != 'school') 'teacherId': destination,
                        if (destination != 'school' || includeChild)
                          'studentId': widget.studentId,
                        'subject': subject.text.trim(),
                        'body': body.text.trim(),
                      }, start: true);
                      if (!context.mounted) return;
                      if (identity != widget.controller.sessionKey) {
                        Navigator.of(context).pop();
                        return;
                      }
                      if (id != null) {
                        Navigator.of(context).pop(id);
                      } else {
                        setState(() {
                          busy = false;
                          warning = 'failed';
                        });
                      }
                    },
              child: Text(context.tr.messagingSend),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagingLifecycle extends StatefulWidget {
  const _MessagingLifecycle({required this.controller, required this.child});
  final ConversationController controller;
  final Widget child;
  @override
  State<_MessagingLifecycle> createState() => _MessagingLifecycleState();
}

class _MessagingLifecycleState extends State<_MessagingLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.controller.foreground = state == AppLifecycleState.resumed;
    if (widget.controller.foreground && widget.controller.visible) {
      unawaited(widget.controller.refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
