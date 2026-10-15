import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/app.dart';
import 'package:termul_mobile/l10n/app_localizations.dart';

void main() {
  testWidgets('aplikasi menyala dengan bahasa Indonesia dan judul dari ARB', (tester) async {
    await tester.pumpWidget(const TermulApp());
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.supportedLocales, const [Locale('id')]);
    final context = tester.element(find.byType(Scaffold));
    expect(AppLocalizations.of(context).appTitle, 'TermUL');
  });
}
