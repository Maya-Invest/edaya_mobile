import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../app/formatters.dart';
import '../../app/workspace_navigation.dart';
import '../../design/components/components.dart';
import '../../design/workspace_layout.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import 'attendance_page.dart';
import 'live_session_controller.dart';
import 'logbook_page.dart';
import 'session_logbook_draft_storage.dart';

class SessionDetailPage extends StatelessWidget {
  const SessionDetailPage({
    super.key,
    required this.sessionId,
    this.logbook = false,
  });
  final String sessionId;
  final bool logbook;
  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context))
      return _SessionScope(sessionId: sessionId, logbook: logbook);
    final store = context.levit.find<MockStore>();
    return ListenableBuilder(
      listenable: store,
      builder: (_, _) {
        final s = store.sessionById(sessionId);
        if (s == null)
          return PrototypeDetailScaffold(
            title: context.tr.session,
            body: EmptyState(title: context.tr.sessionNotFound),
          );
        final book = store.getLogbook(sessionId);
        return _SessionTabs(
          sessionId: sessionId,
          logbook: logbook,
          title: s.classLabel,
          subject: s.subject,
          time:
              '${formatFullDate(s.date)} · ${formatTimeRange(s.startHour, s.endHour)}',
          report: _BookView(
            sessionId: sessionId,
            note: StructuredLogbookContent(
              content: book?.content ?? '',
              objectives: [
                if (book?.objectives.isNotEmpty ?? false) book!.objectives,
              ],
              homework: book?.homework,
              familySummary: book?.familySummary,
            ),
            programme: MockStore.programmeChapters,
            chapters: book?.chapters ?? const {},
            mock: store,
          ),
        );
      },
    );
  }
}

class _SessionScope extends LScopedView<LiveSessionController> {
  const _SessionScope({required this.sessionId, required this.logbook});
  final String sessionId;
  final bool logbook;
  @override
  LiveSessionController onConfigScope(LevitScope scope) =>
      putLiveSessionController(scope, sessionId);
  @override
  Widget buildView(BuildContext context, LiveSessionController controller) =>
      LWatch(() {
        final s = controller.session.value;
        if (s == null || controller.errorMessage.value.isNotEmpty) {
          return PrototypeDetailScaffold(
            title: context.tr.session,
            fallbackRoute: '/calendar',
            body: Center(
              child: controller.isBusy.value
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          controller.errorMessage.value.isEmpty
                              ? context.tr.sessionNotFound
                              : controller.errorMessage.value,
                        ),
                        TextButton(
                          onPressed: controller.load,
                          child: Text(context.tr.retry),
                        ),
                      ],
                    ),
            ),
          );
        }
        final start = controller.schoolTime(s.startsAt),
            end = controller.schoolTime(s.endsAt);
        final time =
            '${formatFullDate(start)} · ${formatClockRange(start, end)}';
        if (s.kind != 'lesson')
          return PrototypeDetailScaffold(
            title: s.classLabel,
            fallbackRoute: '/calendar',
            body: ListTile(title: Text(s.title), subtitle: Text(time)),
          );
        return _SessionTabs(
          sessionId: s.id,
          logbook: logbook,
          title: s.classLabel,
          subject: controller.subjectFor(s),
          lessonTitle: s.title,
          time: time,
          report: controller.isBusy.value
              ? const Center(child: CircularProgressIndicator())
              : controller.logbookError.value.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(controller.logbookError.value),
                      TextButton(
                        onPressed: controller.load,
                        child: Text(context.tr.retry),
                      ),
                    ],
                  ),
                )
              : _BookView(
                  sessionId: s.id,
                  controller: controller,
                  note:
                      controller.officialLogbook.value ??
                      const StructuredLogbookContent(content: ''),
                  programme: {
                    for (final chapter in controller.subjectMatters.value)
                      chapter.id: chapter.name,
                  },
                  chapters: controller.savedChapterProgress,
                ),
        );
      });
}

class _SessionTabs extends StatelessWidget {
  const _SessionTabs({
    required this.sessionId,
    required this.logbook,
    required this.title,
    required this.subject,
    this.lessonTitle,
    required this.time,
    required this.report,
  });
  final String sessionId, title, subject, time;
  final String? lessonTitle;
  final bool logbook;
  final Widget report;
  @override
  Widget build(BuildContext context) => PrototypeDetailScaffold(
    title: title,
    fallbackRoute: '/calendar',
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lessonTitle != null &&
                  lessonTitle != subject &&
                  lessonTitle!.isNotEmpty)
                Text(
                  lessonTitle!,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              Text(subject, style: Theme.of(context).textTheme.titleMedium),
              Text(time),
            ],
          ),
        ),
        DefaultTabController(
          key: ValueKey(logbook),
          length: 2,
          initialIndex: logbook ? 1 : 0,
          child: LayoutBuilder(
            builder: (context, box) {
              final style = Theme.of(context).textTheme.titleSmall!;
              final labels = [context.tr.rollAttendance, context.tr.logbook];
              final textWidth = (box.maxWidth / 2 - 52).clamp(
                1.0,
                double.infinity,
              );
              double height = 48;
              for (final label in labels) {
                final text = TextPainter(
                  text: TextSpan(text: label, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout(maxWidth: textWidth);
                if (text.height + 12 > height) height = text.height + 12;
                text.dispose();
              }
              return TabBar(
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                labelStyle: style,
                tabs: [
                  for (final (index, label) in labels.indexed)
                    Tab(
                      height: height,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            index == 0
                                ? Icons.how_to_reg_outlined
                                : Icons.menu_book_outlined,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(label, textAlign: TextAlign.center),
                          ),
                        ],
                      ),
                    ),
                ],
                onTap: (index) {
                  if ((index == 1) == logbook) return;
                  final uri = GoRouterState.of(context).uri;
                  Router.neglect(
                    context,
                    () => context.replace(
                      uri
                          .replace(
                            queryParameters: {if (index == 1) 'tab': 'logbook'},
                          )
                          .toString(),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: logbook ? 1 : 0,
            children: [
              AttendancePage(sessionId: sessionId),
              report,
            ],
          ),
        ),
      ],
    ),
  );
}

class _BookView extends StatelessWidget {
  const _BookView({
    required this.sessionId,
    required this.note,
    required this.programme,
    required this.chapters,
    this.controller,
    this.mock,
  });
  final String sessionId;
  final StructuredLogbookContent note;
  final Map<String, String> programme;
  final Map<String, bool> chapters;
  final LiveSessionController? controller;
  final MockStore? mock;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final t = context.tr;
    final drafts =
        c?.logbookDrafts.value ?? mock?.logbookDrafts[sessionId] ?? {};
    final pending = c?.pendingLogbook.value;
    final proposed = pending == null
        ? null
        : decodeStructuredSessionNote(pending['sessionNote'] as String?);
    final effective = c?.editableChapterProgress ?? chapters;
    final available = {
      for (final entry in programme.entries)
        if (!chapters.containsKey(entry.key) &&
            !effective.containsKey(entry.key))
          entry.key: entry.value,
    };
    final validated = c?.logbookValidated.value == true;

    LogbookEdit chapterValue(String id) =>
        c?.chapterEditorValue(id) ??
        drafts['chapter:$id'] ??
        LogbookEdit.chapter(id, chapters[id] ?? false);
    Future<void> open({
      required String title,
      required LogbookEdit? initial,
      Map<String, String> choices = const {},
    }) async {
      var saved = false;
      await showWorkspaceEditor<void>(
        context: context,
        title: title,
        builder: (_, finish) => LogbookForm(
          initial: initial,
          choices: choices,
          chapterValue: chapterValue,
          validated: validated,
          onDraft: (edit) async {
            if (c != null) {
              await c.persistDraft(edit);
            } else {
              (mock!.logbookDrafts[sessionId] ??= {})[edit.key] = edit;
            }
          },
          onSave: (edit) async {
            if (c != null) {
              if (!await c.saveLogbook(edit)) {
                return c.logbookMessage.value.isEmpty
                    ? t.logbookNotSaved
                    : c.logbookMessage.value;
              }
            } else {
              mock!.saveLogbook(sessionId, edit);
              await WidgetsBinding.instance.endOfFrame;
            }
            saved = true;
            return null;
          },
          close: () => finish(null),
        ),
      );
      // Acknowledged writes already updated the session and its saved drafts.
      if (!saved && context.mounted && c != null) await c.load();
    }

    Widget heading(String label) => Semantics(
      header: true,
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
    Widget value(String title, String official, String? proposal) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        Text(official.trim().isEmpty ? '—' : official),
        if (proposal != null && official != proposal) ...[
          Text(
            t.workflowCorrectionPending,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          Text(proposal.trim().isEmpty ? '—' : proposal),
        ],
      ],
    );
    final generalAction = validated
        ? t.rollRequestChange
        : note.isEmpty
        ? t.rollCreateBook
        : t.rollEditBook;
    return ListView(
      key: PageStorageKey('logbook-$sessionId'),
      padding: const EdgeInsets.all(16),
      children: [
        WorkspaceColumns(
          minimumSplitWidth: 672,
          sectionSpacing: 12,
          first: [
            heading(t.bookGeneral),
            if (drafts.containsKey('general')) Text(t.rollLocalDraft),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: Text(generalAction),
                onPressed: () => open(
                  title: generalAction,
                  initial:
                      c?.generalEditorValue() ??
                      drafts['general'] ??
                      LogbookEdit.general(note),
                ),
              ),
            ),
            value(t.rollContent, note.content, proposed?.content),
            value(
              t.rollObjectives,
              note.objectives.join('\n'),
              proposed?.objectives.join('\n'),
            ),
            value(
              t.rollHomework,
              note.homework ?? '',
              proposed == null ? null : proposed.homework ?? '',
            ),
            value(
              t.rollFamilySummary,
              note.familySummary ?? '',
              proposed == null ? null : proposed.familySummary ?? '',
            ),
          ],
          second: [
            heading(t.bookChapters),
            for (final entry
                in (c?.historicalChapters ?? <String, String?>{}).entries)
              ListTile(
                title: Text(programme[entry.key] ?? t.chapterFallback),
                subtitle: Text(
                  [
                    t.logbookReference,
                    if (entry.value != null) entry.value!,
                  ].join(' · '),
                ),
              ),
            for (final id in {
              ...programme.keys,
              ...chapters.keys,
              ...effective.keys,
            })
              if (chapters.containsKey(id) || effective.containsKey(id))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(programme[id] ?? t.chapterFallback),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (chapters.containsKey(id))
                        Text(
                          chapters[id]!
                              ? t.logbookFinishedHere
                              : t.logbookCovered,
                        ),
                      if (c?.officialChapterNotes(id) case final String notes)
                        Text(notes),
                      if (pending != null &&
                          c?.proposedChapterNotes(id) !=
                              c?.officialChapterNotes(id))
                        Text(
                          '${t.workflowCorrectionPending} · ${c?.proposedChapterNotes(id) ?? '—'}',
                        ),
                      if (pending != null && effective[id] != chapters[id])
                        Text(
                          '${t.workflowCorrectionPending} · ${effective[id] == null ? '—' : (effective[id]! ? t.logbookFinishedHere : t.logbookCovered)}',
                        ),
                      if (drafts.containsKey('chapter:$id'))
                        Text(t.rollLocalDraft),
                    ],
                  ),
                  trailing: IconButton(
                    tooltip: t.bookEditChapter(
                      programme[id] ?? t.chapterFallback,
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: !programme.containsKey(id)
                        ? null
                        : () => open(
                            title: t.bookEditChapter(programme[id]!),
                            initial: chapterValue(id),
                            choices: programme,
                          ),
                  ),
                ),
            if (available.isEmpty)
              Text(programme.isEmpty ? t.bookNoProgramme : t.bookAllLinked)
            else ...[
              if (available.keys.any((id) => drafts.containsKey('chapter:$id')))
                Text(t.rollLocalDraft),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(t.bookAddChapter),
                  onPressed: () => open(
                    title: t.bookAddChapter,
                    initial: null,
                    choices: available,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
