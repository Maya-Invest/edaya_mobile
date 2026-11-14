import 'package:flutter/widgets.dart';

String words(BuildContext context, String fr, String en) =>
    Localizations.localeOf(context).languageCode == 'fr' ? fr : en;
