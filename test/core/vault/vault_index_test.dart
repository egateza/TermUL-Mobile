import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/io/storage_exception.dart';
import 'package:termul_mobile/core/vault/vault_index.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('termul_vidx_');
    file = File('${dir.path}${Platform.pathSeparator}vault_index.json');
  });
  tearDown(() async => dir.delete(recursive: true));

  test('add dan remove bertahan antar instans; berisi hanya nama, versi, dan tanpa rahasia', () async {
    final a = JsonVaultIndex(file);
    await a.load();
    await a.add('termul.secret.bbb');
    await a.add('termul.secret.aaa');
    await a.add('termul.secret.aaa'); // tidak menggandakan
    final b = JsonVaultIndex(file);
    await b.load();
    expect(b.names, {'termul.secret.aaa', 'termul.secret.bbb'});
    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    expect(json, {
      'version': 1,
      'keys': ['termul.secret.aaa', 'termul.secret.bbb'],
    });
    await b.remove('termul.secret.aaa');
    final c = JsonVaultIndex(file);
    await c.load();
    expect(c.names, {'termul.secret.bbb'});
  });

  test('berkas rusak dikarantina dan dilaporkan', () async {
    await file.writeAsString('{rusak');
    final r = JsonVaultIndex(file);
    final result = await r.load();
    expect(result.hadCorruptFile, isTrue);
    expect(r.names, isEmpty);
  });

  test('penulisan gagal: indeks tidak berubah', () async {
    final r = JsonVaultIndex(file, writer: (f, b) async => throw const StorageException('disk penuh'));
    await r.load();
    await expectLater(r.add('termul.secret.x'), throwsA(isA<StorageException>()));
    expect(r.names, isEmpty);
  });
}
