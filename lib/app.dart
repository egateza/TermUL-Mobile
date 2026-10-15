import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/termul_theme.dart';
import 'debug/widget_gallery.dart';
import 'l10n/app_localizations.dart';

/// Akar aplikasi. Tema token dan rute dibangun di langkah berikutnya.
class TermulApp extends StatelessWidget {
  const TermulApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('id')],
      locale: const Locale('id'),
      theme: termulTheme(),
      home: WidgetGallery.enabled ? const WidgetGallery() : const Scaffold(),
    );
  }
}
