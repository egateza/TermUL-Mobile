import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/boot_app.dart';
import 'package:termul_mobile/bootstrap.dart';

void main() {
  testWidgets('layar pemuatan tampil segera selagi penyimpanan dibuka', (tester) async {
    final gate = Completer<AppDependencies>();
    await tester.pumpWidget(BootApp(boot: () => gate.future));
    expect(find.text('Memuat…'), findsOneWidget);
    gate.completeError(StateError('rusak'));
    await tester.pumpAndSettle();
    expect(find.text('Memuat…'), findsNothing);
    expect(find.text('Penyimpanan tidak bisa dibuka'), findsOneWidget);
  });
}
