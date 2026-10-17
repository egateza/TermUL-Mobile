import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/io/storage_exception.dart';
import 'package:termul_mobile/core/storage/json/json_ui_state_repository.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('termul_ui_state_');
    file = File('${dir.path}${Platform.pathSeparator}ui_state.json');
  });
  tearDown(() async => dir.delete(recursive: true));

  test('berkas belum ada: semua grup terbuka, tanpa karantina, berkas belum dibuat', () async {
    final r = JsonUiStateRepository(file);
    final result = await r.load();
    expect(result.hadCorruptFile, isFalse);
    expect(r.collapsedGroups, isEmpty);
    expect(await file.exists(), isFalse);
  });

  test('simpan lalu muat di instans baru; path terurut di berkas, properti tak dikenal diabaikan', () async {
    final a = JsonUiStateRepository(file);
    await a.load();
    await a.saveCollapsedGroups({'Produksi/DB', '', 'Lab'});
    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    expect(json, {
      'version': 1,
      'collapsedGroups': ['', 'Lab', 'Produksi/DB'],
    });
    await file.writeAsString(jsonEncode({...json, 'fitur_masa_depan': 1}));
    final b = JsonUiStateRepository(file);
    await b.load();
    expect(b.collapsedGroups, {'', 'Lab', 'Produksi/DB'});
  });

  test('simpan beruntun ditulis sesuai urutan', () async {
    final r = JsonUiStateRepository(file);
    await r.load();
    await Future.wait([
      r.saveCollapsedGroups({'A'}),
      r.saveCollapsedGroups({'A', 'B'}),
      r.saveCollapsedGroups({'B'}),
    ]);
    final b = JsonUiStateRepository(file);
    await b.load();
    expect(b.collapsedGroups, {'B'});
  });

  test('berkas rusak atau tipe salah disisihkan dan semua grup terbuka', () async {
    for (final isi in ['{bukan json', '{"collapsedGroups": "Produksi"}', '{"collapsedGroups": [1]}']) {
      await file.writeAsString(isi);
      final r = JsonUiStateRepository(file);
      final result = await r.load();
      expect(result.hadCorruptFile, isTrue, reason: isi);
      expect(r.collapsedGroups, isEmpty);
      expect(await File(result.quarantinedPath!).readAsString(), isi);
    }
  });

  test('gagal menulis: melempar dan nilai terkini tidak berubah', () async {
    final r = JsonUiStateRepository(
      file,
      writer: (f, b) async => throw StorageException('Penuh', const FileSystemException('disk penuh')),
    );
    await r.load();
    await expectLater(r.saveCollapsedGroups({'Produksi'}), throwsA(isA<StorageException>()));
    expect(r.collapsedGroups, isEmpty);
  });
}
