import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/router.dart';
import 'design/theme.dart';
import 'mock/mock_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  final store = MockStore();
  runApp(GuardianPrototypeApp(store: store));
}

class GuardianPrototypeApp extends StatelessWidget {
  const GuardianPrototypeApp({super.key, required this.store, this.router});

  final MockStore store;
  final GoRouter? router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Edaya Guardian Prototype',
      theme: PrototypeTheme.light,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router ?? createRouter(store),
      debugShowCheckedModeBanner: false,
    );
  }
}
