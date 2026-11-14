import 'package:edaya_shared/edaya_shared.dart' hide PersonAvatar;
import 'package:flutter/material.dart';
import '../../app/workspace_navigation.dart';
import '../../design/components/components.dart';
import '../../design/workspace_layout.dart';
import '../../mock/mock_store.dart';
import 'live_session_controller.dart';

typedef SaveRollEntry =
    Future<bool> Function(
      LiveSessionStudent row,
      AttendanceStatus status,
      String? comment,
      String? correctionReason,
    );

class RollCall extends StatefulWidget {
  const RollCall({
    super.key,
    required this.rows,
    required this.submitted,
    required this.busy,
    this.savingDraft = false,
    required this.pending,
    this.conflict = false,
    required this.message,
    required this.onSave,
    required this.onFinish,
    required this.onBulk,
    required this.onSync,
    required this.onMove,
    required this.windowOpen,
    required this.schoolTime,
    this.dateControl,
  });
  final List<LiveSessionStudent> rows;
  final bool submitted, busy, savingDraft, pending, conflict, windowOpen;
  final String message;
  final DateTime Function(DateTime) schoolTime;
  final SaveRollEntry onSave;
  final Future<void> Function() onFinish, onBulk, onSync;
  final Future<bool> Function(LiveSessionStudent row, bool departure) onMove;
  final Widget? dateControl;
  @override
  State<RollCall> createState() => _RollCallState();
}

class _RollCallState extends State<RollCall> {
  String? pupil;
  bool writing = false;
  bool photoWriting = false;
  DateTime? lastPhotoTap;
  final scroll = ScrollController();
  // Show the latest tap immediately, including while an earlier revision saves.
  final _choices = <String, ({AttendanceStatus status, Object token})>{};
  final _rowWrites = <Future<bool>>{};
  final _cards = <String, ({Record inputs, Widget card})>{};

  AttendanceStatus? visibleStatus(LiveSessionStudent row) =>
      _choices[row.studentId]?.status ?? row.status;

  Future<void> markInRoster(
    LiveSessionStudent row,
    AttendanceStatus status,
  ) async {
    if (writing ||
        widget.busy ||
        widget.submitted ||
        visibleStatus(row) == status) {
      return;
    }
    final token = Object();
    setState(() => _choices[row.studentId] = (status: status, token: token));
    final write = Future.sync(
      () => widget.onSave(row, status, row.reason, null),
    );
    _rowWrites.add(write);
    try {
      await write;
    } finally {
      _rowWrites.remove(write);
      if (mounted && _choices[row.studentId]?.token == token) {
        setState(() => _choices.remove(row.studentId));
      }
    }
  }

  Future<void> afterRowWrites(Future<void> Function() action) async {
    await Future.wait(_rowWrites.toList());
    if (mounted) await action();
  }

  @override
  void didUpdateWidget(covariant RollCall oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.rows, oldWidget.rows)) {
      final ids = widget.rows.map((row) => row.studentId).toSet();
      _cards.removeWhere((id, _) => !ids.contains(id));
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> perform(Future<void> Function() action) async {
    if (writing || widget.busy) return;
    setState(() => writing = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => writing = false);
    }
  }

  Future<void> markInPhoto(
    LiveSessionStudent row,
    AttendanceStatus status,
  ) async {
    if (photoWriting ||
        writing ||
        widget.busy ||
        widget.savingDraft ||
        (lastPhotoTap != null &&
            DateTime.now().difference(lastPhotoTap!) <
                const Duration(milliseconds: 300))) {
      return;
    }
    photoWriting = true;
    try {
      final saved = await widget.onSave(row, status, row.reason, null);
      if (!saved || !mounted || pupil != row.studentId) return;
      final index = widget.rows.indexWhere((r) => r.studentId == row.studentId);
      lastPhotoTap = DateTime.now();
      setState(
        () => pupil = index >= 0 && index + 1 < widget.rows.length
            ? widget.rows[index + 1].studentId
            : null,
      );
    } finally {
      photoWriting = false;
    }
  }

  Future<void> details(LiveSessionStudent row) async {
    await showWorkspaceEditor<void>(
      context: context,
      title: row.fullName,
      builder: (ctx, close) => _PupilDetails(
        row: row,
        submitted: widget.submitted,
        windowOpen: widget.windowOpen,
        schoolTime: widget.schoolTime,
        onSave: widget.onSave,
        onMove: widget.onMove,
        close: () => close(null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final count = rows.where((r) => visibleStatus(r) != null).length;
    final index = rows.indexWhere((r) => r.studentId == pupil);
    final photo = !widget.submitted && index >= 0;
    final enabled = !widget.busy && !writing;
    if (rows.isEmpty && widget.busy)
      return const Center(child: CircularProgressIndicator());
    final progress = Text(context.tr.rollRosterCount(rows.length, count));
    final showRetry =
        widget.pending || (widget.message.isNotEmpty && rows.isEmpty);
    final notice = showRetry
        ? TextButton.icon(
            onPressed: enabled
                ? () => perform(() => afterRowWrites(widget.onSync))
                : null,
            icon: const Icon(Icons.sync),
            label: Text(
              widget.conflict || !widget.pending
                  ? [
                      widget.message,
                      context.tr.retry,
                    ].where((s) => s.isNotEmpty).join(' · ')
                  : context.tr.rollToSend,
            ),
          )
        : widget.message.isNotEmpty
        ? Text(widget.message)
        : null;
    final toggle = TextButton.icon(
      onPressed: enabled && rows.isNotEmpty
          ? () => setState(() {
              pupil = photo
                  ? null
                  : (rows.where((r) => visibleStatus(r) == null).firstOrNull ??
                            rows.first)
                        .studentId;
            })
          : null,
      icon: Icon(photo ? Icons.list : Icons.portrait_outlined),
      label: Text(photo ? context.tr.rollList : context.tr.rollOneByOne),
    );
    if (photo) {
      final row = rows[index];
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [progress, toggle],
          ),
          const SizedBox(height: 16),
          Center(
            child: PersonAvatar(
              key: ValueKey(row.studentId),
              initials: row.initials,
              photoUrl: row.photoUrl,
              radius: 68,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            row.fullName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: MaterialLocalizations.of(context).previousPageTooltip,
                onPressed: enabled && index > 0
                    ? () => setState(() => pupil = rows[index - 1].studentId)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(context.tr.rollPosition(index + 1, rows.length)),
              IconButton(
                tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                onPressed: enabled && index + 1 < rows.length
                    ? () => setState(() => pupil = rows[index + 1].studentId)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: _PhotoStatusButtons(
              current: visibleStatus(row),
              onSelect: enabled ? (s) => markInPhoto(row, s) : null,
            ),
          ),
          if (notice != null) Center(child: notice),
        ],
      );
    }
    return AttendanceLayout(
      controls: [
        if (widget.dateControl != null) widget.dateControl!,
        Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (_, box) {
              final actions = [
                toggle,
                TextButton.icon(
                  key: const ValueKey('roll-mark-remaining'),
                  onPressed: enabled && count < rows.length
                      ? () => perform(() => afterRowWrites(widget.onBulk))
                      : null,
                  icon: const Icon(Icons.done_all),
                  label: Text(context.tr.rollMarkRemaining),
                ),
                FilledButton(
                  onPressed:
                      enabled &&
                          count == rows.length &&
                          !widget.pending &&
                          !widget.savingDraft &&
                          _rowWrites.isEmpty
                      ? () => perform(widget.onFinish)
                      : null,
                  child: Text(context.tr.attendanceFinish),
                ),
              ];
              if (widget.submitted || rows.isEmpty) return progress;
              final buttons = Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: actions,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  progress,
                  Align(alignment: Alignment.centerRight, child: buttons),
                ],
              );
            },
          ),
        ),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: notice,
          ),
      ],
      roster: rows.isEmpty
          ? Center(child: Text(context.tr.noStudentsToRecord))
          : ListView.separated(
              controller: scroll,
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => rosterCard(rows[i], enabled),
            ),
    );
  }

  Widget rosterCard(LiveSessionStudent row, bool enabled) {
    final status = visibleStatus(row);
    final departure = row.departedAt == null
        ? null
        : widget.schoolTime(row.departedAt!);
    // Daily attendance can supply fresh row objects on every notification.
    // Reuse unchanged cards by their visible inputs, not by object identity.
    final inputs = (
      row.fullName,
      row.initials,
      row.photoUrl,
      status,
      row.reason,
      departure,
      row.pendingCorrection != null,
      widget.submitted,
      enabled,
    );
    final cached = _cards[row.studentId];
    if (cached != null && cached.inputs == inputs) return cached.card;
    final id = row.studentId;
    LiveSessionStudent currentRow() =>
        widget.rows.firstWhere((r) => r.studentId == id);
    final card = Builder(
      key: ValueKey(id),
      builder: (context) {
        final name = Row(
          children: [
            PersonAvatar(
              initials: row.initials,
              photoUrl: row.photoUrl,
              radius: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.fullName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (row.reason?.isNotEmpty ?? false) Text(row.reason!),
                  if (departure != null)
                    Text(_departureLabel(context, departure)),
                  if (row.pendingCorrection != null)
                    Text(context.tr.workflowCorrectionPending),
                ],
              ),
            ),
            IconButton(
              tooltip: row.fullName,
              onPressed: enabled
                  ? () => afterRowWrites(() => details(currentRow()))
                  : null,
              icon: const Icon(Icons.more_horiz),
            ),
          ],
        );
        final control = widget.submitted
            ? _StatusLabel(status: status, text: _statusText(context, status))
            : AttendanceStatusPicker(
                current: status,
                onSelect: enabled ? (s) => markInRoster(currentRow(), s) : null,
              );
        return SurfaceCard(
          child: LayoutBuilder(
            builder: (_, constraints) {
              if (constraints.maxWidth >= 470 &&
                  MediaQuery.textScalerOf(context).scale(14) < 22) {
                return Row(
                  children: [
                    Expanded(child: name),
                    const SizedBox(width: 12),
                    control,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [name, const SizedBox(height: 8), control],
              );
            },
          ),
        );
      },
    );
    _cards[id] = (inputs: inputs, card: card);
    return card;
  }
}

String _statusText(BuildContext context, AttendanceStatus? s) => switch (s) {
  AttendanceStatus.present => context.tr.attendancePresent,
  AttendanceStatus.absent => context.tr.attendanceAbsent,
  AttendanceStatus.late => context.tr.attendanceLate,
  AttendanceStatus.excused => context.tr.rollExcused,
  null => context.tr.rollUnmarked,
};

String _departureLabel(BuildContext context, DateTime time) =>
    context.tr.rollLeftAt(
      MaterialLocalizations.of(
        context,
      ).formatTimeOfDay(TimeOfDay.fromDateTime(time)),
    );

(Color, Color) _colors(BuildContext context, AttendanceStatus? status) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (status) {
    AttendanceStatus.present =>
      dark
          ? (EdayaTokens.darkSuccessSoft, EdayaTokens.darkSuccess)
          : (EdayaTokens.lightSuccessSoft, const Color(0xff166534)),
    AttendanceStatus.absent =>
      dark
          ? (EdayaTokens.darkDestructiveSoft, EdayaTokens.darkDestructive)
          : (EdayaTokens.lightDestructiveSoft, const Color(0xff991b1b)),
    AttendanceStatus.late =>
      dark
          ? (const Color(0xff482b18), const Color(0xffffcf9e))
          : (const Color(0xffffedd5), const Color(0xff9a3412)),
    _ => (
      Theme.of(context).colorScheme.surfaceContainerHighest,
      Theme.of(context).colorScheme.onSurface,
    ),
  };
}

class _PhotoStatusButtons extends StatelessWidget {
  const _PhotoStatusButtons({required this.current, required this.onSelect});
  final AttendanceStatus? current;
  final ValueChanged<AttendanceStatus>? onSelect;
  @override
  Widget build(BuildContext context) {
    const choices = [AttendanceStatus.present, AttendanceStatus.absent];
    String label(AttendanceStatus s) => s == AttendanceStatus.present
        ? context.tr.attendancePresent
        : context.tr.attendanceAbsent;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final s in choices)
          Semantics(
            selected: current == s,
            child: FilledButton.icon(
              onPressed: onSelect == null ? null : () => onSelect!(s),
              style: FilledButton.styleFrom(
                minimumSize: const Size(128, 64),
                backgroundColor: _colors(context, s).$1,
                foregroundColor: _colors(context, s).$2,
              ),
              icon: Icon(
                current == s ? Icons.check_circle : Icons.circle_outlined,
              ),
              label: Text(label(s)),
            ),
          ),
      ],
    );
  }
}

class AttendanceStatusPicker extends StatelessWidget {
  const AttendanceStatusPicker({
    super.key,
    required this.current,
    required this.onSelect,
    this.includeLate = false,
  });
  final AttendanceStatus? current;
  final ValueChanged<AttendanceStatus>? onSelect;
  final bool includeLate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in [
          AttendanceStatus.present,
          AttendanceStatus.absent,
          if (includeLate) AttendanceStatus.late,
        ])
          Builder(
            builder: (_) {
              final (background, foreground) = _colors(context, status);
              final selected = status == current;
              return ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: ChoiceChip(
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  visualDensity: VisualDensity.standard,
                  label: Text(switch (status) {
                    AttendanceStatus.present => context.tr.attendancePresent,
                    AttendanceStatus.absent => context.tr.attendanceAbsent,
                    _ => context.tr.attendanceLate,
                  }),
                  selected: selected,
                  showCheckmark: true,
                  checkmarkColor: foreground,
                  selectedColor: background,
                  labelStyle: TextStyle(
                    color: selected ? foreground : scheme.onSurface,
                  ),
                  side: BorderSide(
                    color: selected ? background : scheme.outlineVariant,
                  ),
                  onSelected: onSelect == null
                      ? null
                      : (_) {
                          if (!selected) onSelect!(status);
                        },
                ),
              );
            },
          ),
      ],
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status, required this.text});
  final AttendanceStatus? status;
  final String text;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(context, status);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(text, style: TextStyle(color: fg)),
      ),
    );
  }
}

class _PupilDetails extends StatefulWidget {
  const _PupilDetails({
    required this.row,
    required this.submitted,
    required this.windowOpen,
    required this.schoolTime,
    required this.onSave,
    required this.onMove,
    required this.close,
  });
  final LiveSessionStudent row;
  final bool submitted, windowOpen;
  final DateTime Function(DateTime) schoolTime;
  final SaveRollEntry onSave;
  final Future<bool> Function(LiveSessionStudent, bool) onMove;
  final VoidCallback close;
  @override
  State<_PupilDetails> createState() => _PupilDetailsState();
}

class _PupilDetailsState extends State<_PupilDetails> {
  Map? get proposal => widget.row.pendingCorrection?['proposal'] as Map?;
  late AttendanceStatus? selected =
      AttendanceStatus.values
          .where((s) => s.name == proposal?['status'])
          .firstOrNull ??
      widget.row.status;
  late String comment =
      proposal?['teacherExplanation'] as String? ?? widget.row.reason ?? '';
  late String reason = widget.row.pendingCorrection?['reason'] as String? ?? '';
  bool saving = false;
  bool rejected = false;
  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    Future<void> save(Future<bool> Function() action) async {
      if (saving) return;
      setState(() => saving = true);
      try {
        final accepted = await action();
        if (!mounted) return;
        if (accepted) {
          widget.close();
        } else {
          setState(() => rejected = true);
        }
      } finally {
        if (mounted) setState(() => saving = false);
      }
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      children: [
        if (row.departedAt != null)
          Text(_departureLabel(context, widget.schoolTime(row.departedAt!))),
        if (rejected) Text(context.tr.rollWriteRejected),
        if (row.justification == 'excused') Text(context.tr.rollExcused),
        if (row.pendingCorrection != null)
          Text(context.tr.workflowCorrectionPending),
        if (widget.submitted &&
            widget.windowOpen &&
            row.departedAt == null &&
            row.status != null)
          OutlinedButton(
            onPressed: saving
                ? null
                : () => save(() async {
                    return widget.onMove(
                      row,
                      row.status != AttendanceStatus.absent,
                    );
                  }),
            child: Text(
              row.status == AttendanceStatus.absent
                  ? context.tr.attendanceArrival
                  : context.tr.rollDeparture,
            ),
          ),
        AttendanceStatusPicker(
          current: selected,
          includeLate: widget.submitted,
          onSelect: saving
              ? null
              : (status) => setState(() => selected = status),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: comment,
          decoration: InputDecoration(
            labelText: context.tr.workflowTeacherExplanation,
          ),
          onChanged: (v) => setState(() => comment = v),
        ),
        if (widget.submitted)
          TextFormField(
            initialValue: reason,
            decoration: InputDecoration(
              labelText: context.tr.marksCorrectionReason,
            ),
            onChanged: (v) => setState(() => reason = v),
          ),
        FilledButton(
          onPressed:
              saving ||
                  selected == null ||
                  (widget.submitted && reason.trim().isEmpty)
              ? null
              : () => save(
                  () => widget.onSave(
                    row,
                    selected!,
                    comment.trim(),
                    widget.submitted ? reason.trim() : null,
                  ),
                ),
          child: Text(
            widget.submitted
                ? context.tr.workflowRequestCorrection
                : context.tr.save,
          ),
        ),
      ],
    );
  }
}
