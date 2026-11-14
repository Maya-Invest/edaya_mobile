import 'package:flutter/material.dart';

class AcademicYearPicker extends StatelessWidget {
  const AcademicYearPicker({
    super.key,
    required this.selectedYear,
    required this.years,
    required this.onSelected,
  });

  final String selectedYear;
  final List<String> years;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        maximumSize: WidgetStateProperty.all(const Size(280, 320)),
      ),
      builder: (context, controller, child) {
        return TextButton.icon(
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: const Icon(Icons.expand_more, size: 18),
          iconAlignment: IconAlignment.end,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          label: Text(selectedYear),
        );
      },
      menuChildren: [
        for (final year in years)
          MenuItemButton(
            onPressed: () => onSelected(year),
            trailingIcon: year == selectedYear
                ? Icon(
                    Icons.check,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            child: Text(year),
          ),
      ],
    );
  }
}
