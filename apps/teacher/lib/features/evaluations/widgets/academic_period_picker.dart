import 'package:flutter/material.dart';

import '../../../common/utils/academic_period.dart';

class AcademicPeriodPicker extends StatelessWidget {
  const AcademicPeriodPicker({
    super.key,
    required this.periods,
    required this.selectedPeriodId,
    required this.onPeriodSelected,
  });

  final List<Map<String, dynamic>> periods;
  final String? selectedPeriodId;
  final ValueChanged<String> onPeriodSelected;

  @override
  Widget build(BuildContext context) {
    if (periods.isEmpty) {
      return const SizedBox.shrink();
    }

    if (periods.length <= 4) {
      return SegmentedButton<String>(
        segments: [
          for (final period in periods)
            ButtonSegment<String>(
              value: period['id'] as String,
              label: Text(academicPeriodLabel(period)),
            ),
        ],
        selected: selectedPeriodId == null ? {} : {selectedPeriodId!},
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) {
            onPeriodSelected(selection.first);
          }
        },
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: selectedPeriodId,
      decoration: const InputDecoration(
        labelText: 'Period',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final period in periods)
          DropdownMenuItem(
            value: period['id'] as String,
            child: Text(academicPeriodLabel(period)),
          ),
      ],
      onChanged: (value) {
        if (value != null) {
          onPeriodSelected(value);
        }
      },
    );
  }
}
