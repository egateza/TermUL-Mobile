import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/app_providers.dart';
import 'package:termul_mobile/core/models/auth_method.dart';
import 'package:termul_mobile/core/platform/file_sharer.dart';

import 'hosts_ui_harness.dart';

class _CaptureSharer implements FileSharer {
  final names = <String>[];
  final mimes = <String>[];
  final paths = <String>[];
  final contents = <String>[];
  bool fail = false;

  @override
  Future<void> shareFile({required String path, required String name, required String mimeType, String? title}) async {
    if (fail) throw const ShareException('share_failed');
    names.add(name);
    mimes.add(mimeType);
    paths.add(path);
    contents.add(File(path).readAsStringSync());
  }
}

/// I/O berkas tidak selesai di dalam `testWidgets`; beri waktu nyata di antara frame.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late Directory tmp;
  late _CaptureSharer sharer;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('termul_ekspor_');
    sharer = _CaptureSharer();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<Harness> open(WidgetTester tester, {bool withHosts = true}) async {
    final h = Harness();
    if (withHosts) {
      await h.seed(
        [host(id1, name: 'app-01'), host(id2, name: 'kunci-01', auth: AuthMethod.key)],
        favorites: [id1],
      );
    }
    await h.pump(
      tester,
      overrides: [fileSharerProvider.overrideWithValue(sharer), tempDirProvider.overrideWithValue(() async => tmp)],
    );
    return h;
  }

  testWidgets(
    'ekspor: panel menyebut jumlah dan profil KEY yang diubah; Bagikan membuka menu bagikan dengan berkas JSON',
    (tester) async {
      await open(tester);
      await tester.tap(find.bySemanticsLabel('Ekspor profil'));
      await tester.pumpAndSettle();
      expect(find.text('2 profil akan diekspor'), findsOneWidget);
      expect(find.textContaining('Password, passphrase, dan kunci tidak ikut'), findsOneWidget);
      expect(find.textContaining('1 profil memakai kunci'), findsOneWidget);

      await tester.tap(find.text('Bagikan'));
      await tester.pumpAndSettle();
      await settle(tester);
      expect(sharer.names, ['termul-profiles.json']);
      expect(sharer.mimes, ['application/json']);
      expect(sharer.paths.single, contains('${Platform.pathSeparator}share${Platform.pathSeparator}'));
      expect(sharer.contents.single, contains('"authMethod": "AGENT"'));
      expect(sharer.contents.single, isNot(contains('"KEY"')));
    },
  );

  testWidgets('Batal tidak membagikan apa pun', (tester) async {
    await open(tester);
    await tester.tap(find.bySemanticsLabel('Ekspor profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    await settle(tester);
    expect(sharer.names, isEmpty);
  });

  testWidgets('daftar kosong: banner, tanpa panel', (tester) async {
    await open(tester, withHosts: false);
    await tester.tap(find.bySemanticsLabel('Ekspor profil'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada profil untuk diekspor.'), findsOneWidget);
    expect(find.text('Bagikan'), findsNothing);
  });

  testWidgets('menu bagikan gagal dibuka: banner galat', (tester) async {
    sharer.fail = true;
    await open(tester);
    await tester.tap(find.bySemanticsLabel('Ekspor profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bagikan'));
    await tester.pumpAndSettle();
    await settle(tester);
    expect(find.textContaining('Ekspor gagal'), findsOneWidget);
  });
}
