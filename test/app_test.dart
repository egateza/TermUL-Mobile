import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/app.dart';
import 'package:termul_mobile/app_providers.dart';
import 'package:termul_mobile/l10n/app_localizations.dart';

import 'features/hosts_ui_harness.dart';

void main() {
  testWidgets('aplikasi menyala dengan bahasa Indonesia, judul dari ARB, dan layar daftar host', (tester) async {
    final h = Harness();
    await tester.pumpWidget(ProviderScope(overrides: h.deps.overrides, child: const TermulApp()));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.supportedLocales, const [Locale('id')]);
    final context = tester.element(find.byType(Scaffold).first);
    expect(AppLocalizations.of(context).appTitle, 'TermUL');
    expect(find.text('Host'), findsOneWidget);
  });
}
