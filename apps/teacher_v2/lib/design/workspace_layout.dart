import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'spacing.dart';

const workspaceMaxWidth = 1168.0;

double workspaceGutter(double width) =>
    math.max(PrototypeSpacing.md, (width - workspaceMaxWidth) / 2);

bool useComparisonRows(BuildContext context, double width) =>
    width >= 600 && MediaQuery.textScalerOf(context).scale(14) < 22;

/// Both sections keep their elements (including focused fields) as the Wrap
/// changes between one run and two runs.
class WorkspaceColumns extends StatelessWidget {
  const WorkspaceColumns({
    super.key,
    required this.first,
    required this.second,
    this.firstFraction = .5,
    this.sectionSpacing = 0,
  });

  final List<Widget> first, second;
  final double firstFraction;
  final double sectionSpacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = PrototypeSpacing.lg;
      final split =
          box.maxWidth >= 840 &&
          MediaQuery.textScalerOf(context).scale(14) < 22;
      final usable = box.maxWidth - gap;
      final left = split
          ? (usable * firstFraction).clamp(320.0, usable - 320).toDouble()
          : box.maxWidth;
      Widget section(double width, List<Widget> children) => SizedBox(
        width: width,
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: sectionSpacing,
            children: children,
          ),
        ),
      );
      return Wrap(
        spacing: gap,
        runSpacing: PrototypeSpacing.md,
        children: [
          if (first.isNotEmpty)
            section(second.isEmpty ? box.maxWidth : left, first),
          if (second.isNotEmpty)
            section(
              split && first.isNotEmpty ? usable - left : box.maxWidth,
              second,
            ),
        ],
      );
    },
  );
}

/// The same column widths are used by a roster's heading and all its rows.
class ComparisonRow extends StatelessWidget {
  const ComparisonRow({
    super.key,
    required this.cells,
    this.onTap,
    this.heading = false,
  });
  final List<String> cells;
  final VoidCallback? onTap;
  final bool heading;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          for (int i = 0; i < cells.length; i++)
            Expanded(
              flex: i == 0 ? 3 : 2,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  cells[i],
                  style: heading
                      ? theme.textTheme.labelLarge
                      : i == 0
                      ? theme.textTheme.titleSmall
                      : theme.textTheme.bodyMedium,
                ),
              ),
            ),
          SizedBox(
            width: 24,
            child: onTap == null ? null : const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
    if (heading) return Semantics(header: true, child: row);
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: row,
        ),
      ),
    );
  }
}

class ResponsiveRosterTile extends StatelessWidget {
  const ResponsiveRosterTile({
    super.key,
    required this.cells,
    required this.compact,
  });
  final List<String> cells;
  final ListTile compact;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => useComparisonRows(context, box.maxWidth)
        ? ComparisonRow(cells: cells, onTap: compact.onTap)
        : compact,
  );
}

class AttendanceLayout extends StatelessWidget {
  const AttendanceLayout({
    super.key,
    required this.controls,
    required this.roster,
  });
  final List<Widget> controls;
  final Widget roster;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide =
          box.maxWidth >= 840 &&
          MediaQuery.textScalerOf(context).scale(14) < 22;
      return Flex(
        direction: wide ? Axis.horizontal : Axis.vertical,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: wide
                ? BoxConstraints.tightFor(width: 320)
                : BoxConstraints(maxHeight: box.maxHeight * .48),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: controls,
              ),
            ),
          ),
          Expanded(child: roster),
        ],
      );
    },
  );
}

class ComparisonHeading extends StatelessWidget {
  const ComparisonHeading(this.labels, {super.key});
  final List<String> labels;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => useComparisonRows(context, box.maxWidth)
        ? ComparisonRow(cells: labels, heading: true)
        : const SizedBox.shrink(),
  );
}
