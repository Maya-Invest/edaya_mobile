import 'package:flutter/material.dart';

import '../mock/mock_store.dart';
import 'package:edaya_shared/edaya_shared.dart';

abstract final class SessionCategoryVisuals {
  static IconData iconFor(HomeDayCategory category) {
    return switch (category) {
      HomeDayCategory.lesson => Icons.menu_book_outlined,
      HomeDayCategory.activity => Icons.sports_soccer_outlined,
      HomeDayCategory.assessment => Icons.fact_check_outlined,
    };
  }

  static Color iconColorFor(HomeDayCategory category, ColorScheme scheme) {
    return switch (category) {
      HomeDayCategory.lesson => scheme.primary,
      HomeDayCategory.activity =>
        scheme.brightness == Brightness.dark
            ? EdayaTokens.darkSuccess
            : EdayaTokens.lightSuccess,
      HomeDayCategory.assessment => scheme.onTertiaryContainer,
    };
  }

  static Color backgroundFor(HomeDayCategory category, ColorScheme scheme) {
    return switch (category) {
      HomeDayCategory.lesson => scheme.primaryContainer,
      HomeDayCategory.activity =>
        scheme.brightness == Brightness.dark
            ? EdayaTokens.darkSuccessSoft
            : EdayaTokens.lightSuccessSoft,
      HomeDayCategory.assessment => scheme.tertiaryContainer,
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
        color: SessionCategoryVisuals.backgroundFor(
          category,
          Theme.of(context).colorScheme,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        SessionCategoryVisuals.iconFor(category),
        size: size,
        color: SessionCategoryVisuals.iconColorFor(
          category,
          Theme.of(context).colorScheme,
        ),
      ),
    );
  }
}
