import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/features/sftp/unique_name.dart';

void main() {
  test('nama bebas dipakai apa adanya', () {
    expect(uniqueName('a.txt', (_) => false), 'a.txt');
  });

  test('nama terpakai diberi nomor pertama yang bebas', () {
    expect(uniqueName('a.txt', {'a.txt'}.contains), 'a (1).txt');
    expect(uniqueName('a.txt', {'a.txt', 'a (1).txt'}.contains), 'a (2).txt');
    expect(uniqueName('a.txt', {'a.txt', 'a (2).txt'}.contains), 'a (1).txt', reason: 'celah diisi dulu');
    expect(uniqueName('a.txt', {for (var i = 0; i < 12; i++) i == 0 ? 'a.txt' : 'a ($i).txt'}.contains), 'a (12).txt');
  });

  test('ekstensi: titik terakhir, .tar.gz utuh, tanpa ekstensi, berkas tersembunyi', () {
    expect(uniqueName('arsip.tar.gz', {'arsip.tar.gz'}.contains), 'arsip (1).tar.gz');
    expect(uniqueName('Arsip.TAR.GZ', {'Arsip.TAR.GZ'}.contains), 'Arsip (1).TAR.GZ');
    expect(uniqueName('laporan', {'laporan'}.contains), 'laporan (1)');
    expect(uniqueName('.bashrc', {'.bashrc'}.contains), '.bashrc (1)');
    expect(uniqueName('a.b.c', {'a.b.c'}.contains), 'a.b (1).c');
    expect(uniqueName('akhir.', {'akhir.'}.contains), 'akhir. (1)');
  });
}
