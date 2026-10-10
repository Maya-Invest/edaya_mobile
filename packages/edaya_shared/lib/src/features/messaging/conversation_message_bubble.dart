import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/edaya_tokens.g.dart';
import '../../l10n/l10n_extension.dart';

/// Direction belongs to the selected portal profile, never its display name.
bool isOutgoingConversationMessage({
  required String authorKind,
  required String authorId,
  required String? viewerKind,
  required String? viewerId,
}) =>
    viewerKind != null &&
    viewerId != null &&
    authorKind == viewerKind &&
    authorId == viewerId;

/// Shared, selectable conversation history for guardian and teacher portals.
class ConversationMessageBubble extends StatelessWidget {
  const ConversationMessageBubble({
    super.key,
    required this.outgoing,
    required this.author,
    required this.body,
    required this.timestamp,
  });
  final bool outgoing;
  final String author, body, timestamp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = outgoing ? colors.onPrimaryContainer : colors.onSurface;
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(16) >= 32;
        final fraction = largeText
            ? 1.0
            : constraints.maxWidth < 600
            ? .9
            : .75;
        return Padding(
          padding: const EdgeInsets.only(bottom: EdayaTokens.spaceMd),
          child: Align(
            alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.min(560, constraints.maxWidth * fraction),
              ),
              child: Semantics(
                container: true,
                label: outgoing
                    ? context.tr.messagingSentDescription(author, timestamp)
                    : context.tr.messagingReceivedDescription(
                        author,
                        timestamp,
                      ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: outgoing ? colors.primaryContainer : colors.surface,
                    borderRadius: BorderRadius.circular(
                      EdayaTokens.radiusSurface,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(EdayaTokens.spaceLg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Text(
                            author,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: foreground,
                            ),
                          ),
                        ),
                        const SizedBox(height: EdayaTokens.spaceSm),
                        SelectableText(
                          body,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: foreground,
                          ),
                        ),
                        const SizedBox(height: EdayaTokens.spaceSm),
                        ExcludeSemantics(
                          child: Text(
                            timestamp,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
