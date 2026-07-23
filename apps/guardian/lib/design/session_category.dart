import 'package:flutter/material.dart';

import '../mock/mock_store.dart';
import 'colors.dart';

abstract final class SessionCategoryVisuals {
  static IconData iconFor(HomeDayCategory category) {
    return switch (category) {
      HomeDayCategory.lesson => Icons.menu_book_outlined,
      HomeDayCategory.activity => Icons.sports_soccer_outlined,
      HomeDayCategory.assessment => Icons.fact_check_outlined,
    };
  }

  static Color iconColorFor(HomeDayCategory category) {
    return switch (category) {
      HomeDayCategory.lesson => Colors.blue,
      HomeDayCategory.activity => Colors.green,
      HomeDayCategory.assessment => Colors.orange,
    };
  }

  static Color backgroundFor(HomeDayCategory category) {
    return switch (category) {
      HomeDayCategory.lesson => PrototypeColors.primaryContainer,
      HomeDayCategory.activity => PrototypeColors.successContainer,
      HomeDayCategory.assessment => PrototypeColors.accentContainer,
    };
  }
}

class SessionCategoryIcon extends StatelessWidget {
  const SessionCategoryIcon({
    super.key,
    required this.category,
    this.size = 20,
    this.padding = 8,
  });

  final HomeDayCategory category;
  final double size;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: SessionCategoryVisuals.backgroundFor(category),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        SessionCategoryVisuals.iconFor(category),
        size: size,
        color: SessionCategoryVisuals.iconColorFor(category),
      ),
    );
  }
}
