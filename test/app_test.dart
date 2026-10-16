import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/app.dart';
import 'package:termul_mobile/app_providers.dart';
import 'package:termul_mobile/l10n/app_localizations.dart';
import 'package:termul_mobile/shared/widgets/termul_nav_bar.dart';

import 'features/hosts_ui_harness.dart';

void main() {
  testWidgets('aplikasi menyala dengan bahasa Indonesia, judul dari ARB, dan layar daftar host', (tester) async {
    final h = Harness();
    // Potret (bar bawah); ukuran bawaan flutter test 800 x 600 adalah landscape (rel di kiri).
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(overrides: h.deps.overrides, child: const TermulApp()));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.supportedLocales, const [Locale('id')]);
    final context = tester.element(find.byType(Scaffold).first);
    expect(AppLocalizations.of(context).appTitle, 'TermUL');
    expect(find.byType(TermulNavBar), findsOneWidget);
    for (final tab in ['Host', 'Sesi', 'SFTP', 'Snippet', 'Pengaturan']) {
      expect(
        find.descendant(of: find.byType(TermulNavBar), matching: find.text(tab)),
        findsOneWidget,
        reason: tab,
      );
    }
    expect(find.text('Host'), findsNWidgets(2)); // judul layar dan tab
  });
}
