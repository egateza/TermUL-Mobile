import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/theme/termul_theme.dart';
import 'package:termul_mobile/l10n/app_localizations.dart';

/// Membungkus [child] dengan tema dan lokalisasi aplikasi. Ukuran layar ponsel desain (390x844).
Future<void> pumpApp(WidgetTester tester, Widget child, {Size size = const Size(390, 844)}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: termulTheme(),
      locale: const Locale('id'),
      supportedLocales: const [Locale('id')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}
