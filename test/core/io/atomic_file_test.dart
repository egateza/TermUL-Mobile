import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/io/atomic_file.dart';
import 'package:termul_mobile/core/io/storage_exception.dart';

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('termul_atomic_'));
  tearDown(() async => dir.delete(recursive: true));

  File file(String name) => File('${dir.path}${Platform.pathSeparator}$name');
  List<String> names() =>
      dir.listSync().map((e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last).toList()..sort();

  test('menulis berkas baru dan membuat folder yang belum ada', () async {
    final target = File(
      '${dir.path}${Platform.pathSeparator}a${Platform.pathSeparator}b${Platform.pathSeparator}x.json',
    );
    await writeAtomic(target, [1, 2, 3]);
    expect(await target.readAsBytes(), [1, 2, 3]);
  });

  test('menimpa berkas lama dan tidak meninggalkan berkas sementara', () async {
    final target = file('x.json');
    await writeAtomic(target, [1]);
    await writeAtomic(target, [2, 2]);
    expect(await target.readAsBytes(), [2, 2]);
    expect(names(), ['x.json']);
  });

  test('galat tepat sebelum rename: berkas lama utuh dan sisa sementara dihapus', () async {
    final target = file('x.json');
    await writeAtomic(target, [1, 1, 1]);
    await expectLater(
      writeAtomic(target, [9, 9], beforeRename: () async => throw StateError('mati daya')),
      throwsA(isA<StateError>()),
    );
    expect(await target.readAsBytes(), [1, 1, 1]);
    expect(names(), ['x.json']);
  });

  test('galat sistem berkas dibungkus StorageException tanpa memuat isi berkas', () async {
    // Target adalah folder: rename ke sana gagal.
    final blocker = Directory('${dir.path}${Platform.pathSeparator}x.json')..createSync();
    await File('${blocker.path}${Platform.pathSeparator}isi').writeAsString('rahasia');
    await expectLater(writeAtomic(file('x.json'), [1]), throwsA(isA<StorageException>()));
    expect(names(), ['x.json']);
  });
}
