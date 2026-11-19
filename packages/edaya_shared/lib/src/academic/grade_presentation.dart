import 'package:flutter/material.dart';
import '../l10n/l10n_extension.dart';
import 'grading_policy.dart';

String officialMarkLabel(BuildContext context, Map mark) {
  if (mark['designation'] == 'absent') return context.tr.marksAbsent;
  if (mark['designation'] == 'exempt') return context.tr.marksExempt;
  final original = mark['originalEntry'];
  if (original is Map && original['kind'] == 'mention')
    return '${original['code'] ?? original['label'] ?? '—'}';
  final grading = mark['grading'] ?? mark['calculation'];
  if (grading is Map && grading['reportedValue'] is num) {
    return formatCalculatedGrade(
      (grading['reportedValue'] as num).toDouble(),
      grading.cast<String, dynamic>(),
    );
  }
  return mark['score'] == null
      ? '—'
      : '${formatGradeNumber(mark['score'] as num)} / ${formatGradeNumber(mark['maxScore'] as num?)}';
}

/// The rank and scale interpretation belong to this official value.
class GradeValue extends StatelessWidget {
  const GradeValue(
    this.value,
    this.result, {
    super.key,
    this.style,
    this.showRank = true,
    this.allowHistoricalOverallRank = false,
  });
  final String value;
  final Map result;
  final TextStyle? style;
  final bool showRank, allowHistoricalOverallRank;
  @override
  Widget build(BuildContext context) {
    final rank = result['rank'],
        count = result['participantCount'] ?? result['classSize'];
    final grading = result['grading'] ?? result['calculation'];
    final mention = grading is Map ? grading['mention'] : null;
    final original = result['originalEntry'];
    final interpretation = mention is Map
        ? mention['label']
        : original is Map && original['kind'] == 'mention'
        ? original['label']
        : null;
    final code = mention is Map ? mention['code'] : null;
    final suffix = ' · $code';
    final label =
        interpretation is String &&
            interpretation.trim().isNotEmpty &&
            code is String &&
            value.endsWith(suffix)
        ? value.substring(0, value.length - suffix.length)
        : value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: style),
        if (showRank &&
            rank is int &&
            count is int &&
            rank > 0 &&
            rank <= count)
          Text(context.tr.rankLabel(rank, count))
        else if (allowHistoricalOverallRank &&
            rank is int &&
            rank > 0 &&
            count == null)
          Text(context.tr.reportRankOnly(rank)),
        if (interpretation is String && interpretation.trim().isNotEmpty)
          Text(interpretation, softWrap: true),
      ],
    );
  }
}

/// Compact ordinal for the French and English school workspaces.
String compactRank(int rank, int participants, String language) {
  if (language == 'fr') return '${rank}${rank == 1 ? 'er' : 'e'}/$participants';
  final suffix = switch (rank % 100) {
    11 || 12 || 13 => 'th',
    _ => switch (rank % 10) {
      1 => 'st',
      2 => 'nd',
      3 => 'rd',
      _ => 'th',
    },
  };
  return '$rank$suffix/$participants';
}

({String visual, String spoken}) compactGradeSummary(
  BuildContext context,
  Map result,
) {
  final tr = context.tr;
  final locale = Localizations.localeOf(context);
  final grade = result['grading'] ?? result['calculation'];
  final original = result['originalEntry'];
  final mention = grade is Map ? grade['mention'] : null;
  final wording =
      (mention is Map ? mention['label'] as String? : null) ??
      (original is Map && original['kind'] == 'mention'
          ? original['label'] as String?
          : null);
  final word = wording?.trim().isNotEmpty == true
      ? wording
      : (mention is Map ? mention['code'] as String? : null);
  final mentionGrade = original is Map && original['kind'] == 'mention';
  final score =
      (grade is Map ? grade['reportedValue'] : null) ??
      result['average'] ??
      result['score'];
  final maximum =
      (grade is Map ? grade['maximum'] : null) ??
      result['maxScore'] ??
      (result.containsKey('average') ? 20 : null);
  final String? mark;
  if (result['designation'] == 'absent')
    return (visual: tr.marksAbsent, spoken: tr.marksAbsent);
  if (result['designation'] == 'exempt')
    return (visual: tr.marksExempt, spoken: tr.marksExempt);
  if (mentionGrade) {
    mark = original['code'] as String? ?? word;
  } else if (score is num) {
    final precision = grade is Map
        ? ((grade['decimalPlaces'] as num?)?.toInt() ?? 2)
        : result.containsKey('average')
        ? 2
        : null;
    final points = formatGradeNumber(
      score,
      precision: precision,
      locale: locale.languageCode,
    );
    mark = maximum is num
        ? '$points/${formatGradeNumber(maximum, locale: locale.languageCode)}'
        : points;
  } else {
    mark = null;
  }
  final rank = result['rank'];
  final count = result['participantCount'] ?? result['classSize'];
  final ranked = rank is int && count is int && rank > 0 && rank <= count;
  final words = [
    if (mark != null) mark,
    if (word != null && word.trim().isNotEmpty && word != mark) word,
  ];
  final visual = [...words], spoken = [...words];
  if (ranked) {
    final position = mark == null ? 0 : 1;
    visual.insert(position, compactRank(rank, count, locale.languageCode));
    spoken.insert(position, tr.rankLabel(rank, count));
  }
  return (visual: visual.join(' · '), spoken: spoken.join(', '));
}

/// A two-line result with either local expandable details or a routed detail page.
class GradeRecordRow extends StatefulWidget {
  const GradeRecordRow({
    super.key,
    required this.title,
    required this.result,
    this.onDetails,
    this.details,
    this.initiallyExpanded = false,
    this.editLabel,
    this.onEdit,
  }) : assert((onDetails == null) != (details == null)),
       assert((editLabel == null) == (onEdit == null));
  final String title;
  final Map result;
  final VoidCallback? onDetails, onEdit;
  final Widget? details;
  final String? editLabel;
  final bool initiallyExpanded;
  @override
  State<GradeRecordRow> createState() => _GradeRecordRowState();
}

class _GradeRecordRowState extends State<GradeRecordRow> {
  late bool expanded = widget.initiallyExpanded;
  @override
  void didUpdateWidget(GradeRecordRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded != oldWidget.initiallyExpanded) {
      expanded = widget.initiallyExpanded;
    }
  }

  void open({bool toggle = false}) {
    if (widget.onDetails != null) {
      widget.onDetails!();
    } else {
      setState(() => expanded = toggle ? !expanded : true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final summary = compactGradeSummary(context, widget.result);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => open(toggle: true),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (summary.visual.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            summary.visual,
                            semanticsLabel: summary.spoken,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: PopupMenuButton<String>(
                tooltip: tr.gradebookOptions,
                icon: const Icon(Icons.more_horiz),
                onSelected: (value) {
                  if (value == 'edit') {
                    widget.onEdit?.call();
                  } else {
                    open();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'details',
                    child: Text(tr.gradeViewDetails),
                  ),
                  if (widget.onEdit != null)
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(widget.editLabel!),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (expanded && widget.details != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: widget.details,
          ),
      ],
    );
  }
}
