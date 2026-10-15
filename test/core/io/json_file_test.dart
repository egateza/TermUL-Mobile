import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/io/async_lock.dart';
import 'package:termul_mobile/core/io/json_file.dart';
import 'package:termul_mobile/core/io/storage_exception.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('termul_json_');
    file = File('${dir.path}${Platform.pathSeparator}data.json');
  });
  tearDown(() async => dir.delete(recursive: true));

  Future<JsonLoad<int>> load() => loadJsonOrQuarantine<int>(file, parse: (j) => j['n']! as int, empty: -1);

  List<File> corrupt() =>
      dir.listSync().whereType<File>().where((f) => RegExp(r'data\.json\.corrupt-\d+').hasMatch(f.path)).toList();

  test('berkas belum ada: nilai kosong tanpa karantina', () async {
    final r = await load();
    expect(r.value, -1);
    expect(r.quarantinedPath, isNull);
  });

  test('berkas valid: dibaca', () async {
    await file.writeAsString('{"n": 5, "tak_dikenal": true}');
    final r = await load();
    expect(r.value, 5);
    expect(r.quarantinedPath, isNull);
  });

  for (final entry in {
    'bukan JSON': '{rusak',
    'bukan objek': '[1, 2]',
    'tipe salah': '{"n": "lima"}',
    'field wajib hilang': '{}',
  }.entries) {
    test('${entry.key}: dipindah ke .corrupt-<waktu> dengan isi utuh', () async {
      await file.writeAsString(entry.value);
      final r = await load();
      expect(r.value, -1);
      expect(r.quarantinedPath, isNotNull);
      expect(await file.exists(), isFalse);
      expect(corrupt(), hasLength(1));
      expect(await corrupt().single.readAsString(), entry.value);
    });
  }

  test('UTF-8 tidak sah dianggap rusak', () async {
    await file.writeAsBytes([0xff, 0xfe, 0x7b]);
    final r = await load();
    expect(r.quarantinedPath, isNotNull);
  });

  test('dua karantina berurutan tidak saling menimpa', () async {
    await file.writeAsString('{rusak1');
    await load();
    await file.writeAsString('{rusak2');
    await load();
    expect(corrupt(), hasLength(2));
  });

  test('AsyncLock menjalankan tugas satu per satu sesuai urutan', () async {
    final lock = AsyncLock();
    final log = <int>[];
    final futures = [
      for (var i = 0; i < 5; i++)
        lock.run(() async {
          log.add(i);
          await Future<void>.delayed(Duration(milliseconds: 5 * (5 - i)));
          log.add(-i);
        }),
    ];
    await Future.wait(futures);
    // Tiap tugas selesai penuh (masuk lalu keluar) sebelum tugas berikutnya mulai.
    expect(log, [0, 0, 1, -1, 2, -2, 3, -3, 4, -4]);
  });

  test('AsyncLock tetap jalan setelah satu tugas gagal', () async {
    final lock = AsyncLock();
    await expectLater(lock.run<void>(() async => throw const StorageException('x')), throwsA(isA<StorageException>()));
    expect(await lock.run(() async => 7), 7);
  });
}
