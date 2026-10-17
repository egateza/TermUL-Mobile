import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/models/host_profile.dart';
import 'package:termul_mobile/core/platform/downloads_saver.dart';
import 'package:termul_mobile/core/sftp/sftp_service.dart';
import 'package:termul_mobile/features/sftp/sftp_link.dart';
import 'package:termul_mobile/features/sftp/sftp_transfer_actions.dart';

import 'sftp_browser_test.dart' show FakeFiles, file;

class FakeSaver implements DownloadsSaver {
  final saved = <({String name, String? folder, Uint8List bytes, bool overwrite})>[];
  final existing = <String>{};
  final existingFolders = <String>{};
  Object? error;

  @override
  Future<bool> exists(String name, {String? folder}) async => existing.contains(name);

  @override
  Future<bool> folderExists(String name) async => existingFolders.contains(name);

  @override
  Future<SavedDownload> save({
    required String path,
    required String name,
    String? folder,
    bool overwrite = false,
  }) async {
    if (error != null) throw error!;
    saved.add((name: name, folder: folder, bytes: File(path).readAsBytesSync(), overwrite: overwrite));
    return SavedDownload(
      name: name == 'a.txt' && !overwrite ? 'a (1).txt' : name,
      location: 'Unduhan/TermUL',
      overwritten: overwrite,
    );
  }
}

HostProfile profile() =>
    HostProfile(id: '11111111-1111-4111-8111-111111111111', name: 'app-01', host: 'h', port: 22, username: 'u');

SftpTree treeOf(List<String> relatives, {int skipped = 0, int size = 1000}) => SftpTree(
  files: [for (final r in relatives) SftpTreeFile(remotePath: '/src/$r', relativePath: r, size: size)],
  skipped: skipped,
);

void main() {
  late Directory tmp;
  late FakeFiles server;
  late FakeSaver saver;
  late SftpLink link;
  late SftpTransferActions actions;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('termul_aksi_');
    server = FakeFiles({'/': []});
    saver = FakeSaver();
    link = SftpLink.ready(profile: profile(), service: server);
    actions = SftpTransferActions(link: link, saver: saver, tempDir: () async => tmp, progressInterval: Duration.zero);
  });
  tearDown(() async {
    link.dispose();
    await tmp.delete(recursive: true);
  });

  int tempFiles() => tmp.listSync().length;

  test(
    'unduh berhasil: berkas disimpan ke Unduhan dengan isi utuh, berkas sementara dan transfer dibersihkan',
    () async {
      final out = await actions.download(file('/', 'a.txt', size: 1000));
      expect(out, isA<TransferDone>());
      out as TransferDone;
      expect(out.location, 'Unduhan/TermUL');
      expect(out.savedName, 'a (1).txt', reason: 'nama akhir dari MediaStore dipakai');
      expect(saver.saved.single.bytes, server.downloadBytes);
      expect(tempFiles(), 0);
      expect(link.transfers.isBusy, isFalse);
    },
  );

  test('unduh dibatalkan: tidak ada yang disimpan, berkas sementara hilang', () async {
    server.hold = Completer<void>();
    final run = actions.download(file('/', 'a.txt', size: 1000));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(link.transfers.isBusy, isTrue);
    expect(link.transfers.active.single.percent, 50);
    link.transfers.cancelAll();
    server.hold!.complete();
    final out = await run;
    expect(out, isA<TransferCancelled>());
    expect(saver.saved, isEmpty);
    expect(tempFiles(), 0);
    expect(link.transfers.isBusy, isFalse);
  });

  test('unduh gagal di server: dipetakan, tidak disimpan', () async {
    server.downloadFailure = const SftpFailure(SftpFailureKind.permissionDenied, 'ditolak');
    final out = await actions.download(file('/', 'rahasia'));
    expect(out, isA<TransferFailed>().having((o) => o.kind, 'kind', SftpFailureKind.permissionDenied));
    expect(saver.saved, isEmpty);
    expect(tempFiles(), 0);
  });

  test('penyimpanan ke Unduhan gagal: dilaporkan terpisah, berkas sementara tetap dihapus', () async {
    saver.error = const DownloadSaveException('penuh');
    final out = await actions.download(file('/', 'b.bin'));
    expect(out, isA<TransferFailed>().having((o) => o.saveFailed, 'saveFailed', isTrue));
    expect(tempFiles(), 0);
  });

  test('unggah berhasil: seluruh isi terkirim ke jalur folder/nama', () async {
    final f = XFile(
      (File('${tmp.path}${Platform.pathSeparator}laporan.csv')..writeAsBytesSync(List.filled(3000, 1))).path,
    );
    final out = await actions.upload(f, '/data');
    expect(out, isA<TransferDone>());
    expect(server.uploaded, {'/data/laporan.csv': 3000});
    expect(link.transfers.isBusy, isFalse);
  });

  test('unggah dibatalkan dan unggah gagal', () async {
    server.hold = Completer<void>();
    final f = XFile((File('${tmp.path}${Platform.pathSeparator}x.bin')..writeAsBytesSync(List.filled(10, 1))).path);
    final run = actions.upload(f, '/');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    link.transfers.cancelAll();
    server.hold!.complete();
    expect(await run, isA<TransferCancelled>());
    expect(server.uploaded, isEmpty);

    server.hold = null;
    server.uploadFailure = const SftpFailure(SftpFailureKind.connectionLost, 'putus');
    final out = await actions.upload(f, '/');
    expect(out, isA<TransferFailed>().having((o) => o.kind, 'kind', SftpFailureKind.connectionLost));
  });

  test('unduh dengan nama lain dan menimpa: nama dan tanda timpa diteruskan ke penyimpan', () async {
    final renamed = await actions.download(file('/', 'b.bin', size: 1000), saveAs: 'b (2).bin');
    expect(saver.saved.last.name, 'b (2).bin');
    expect(saver.saved.last.overwrite, isFalse);
    expect((renamed as TransferDone).savedName, 'b (2).bin');

    final over = await actions.download(file('/', 'b.bin', size: 1000), overwrite: true);
    expect(saver.saved.last.name, 'b.bin');
    expect(saver.saved.last.overwrite, isTrue);
    expect((over as TransferDone).overwritten, isTrue);
  });

  test('unggah dengan nama lain: jalur memakai nama baru', () async {
    final f = XFile((File('${tmp.path}${Platform.pathSeparator}c.txt')..writeAsBytesSync(List.filled(10, 1))).path);
    final out = await actions.upload(f, '/data', remoteName: 'c (1).txt');
    expect(out.name, 'c (1).txt');
    expect(server.uploaded, {'/data/c (1).txt': 10});
  });

  test('progres dibatasi lajunya; yang pertama dan nilai akhir selalu sampai', () async {
    server.burst = 20;
    final slow = SftpTransferActions(
      link: link,
      saver: saver,
      tempDir: () async => tmp,
      progressInterval: const Duration(hours: 1),
    );
    var updates = 0;
    link.transfers.addListener(() => updates++);
    await slow.download(file('/', 'a.txt', size: 1000));
    // mulai + progres pertama + akhir (100%) + selesai; 19 pembaruan beruntun dan titik tengah tidak diteruskan
    expect(updates, 4);

    updates = 0;
    final fast = SftpTransferActions(
      link: link,
      saver: saver,
      tempDir: () async => tmp,
      progressInterval: Duration.zero,
    );
    await fast.download(file('/', 'a.txt', size: 1000));
    expect(updates, greaterThan(20), reason: 'tanpa pembatas semuanya diteruskan');
  });

  group('unduh folder', () {
    final folder = SftpEntry(name: 'proyek', path: '/src', kind: SftpEntryKind.directory);

    test('struktur subfolder dipertahankan; satu transfer dengan total dari penelusuran', () async {
      server.trees['/src'] = treeOf(['a.txt', 'sub/b.txt', 'sub/dalam/c.txt'], skipped: 2);
      final percents = <int?>[];
      link.transfers.addListener(() {
        if (link.transfers.active.isNotEmpty) percents.add(link.transfers.active.single.percent);
      });
      final out = await actions.downloadFolder(folder);
      expect(out, isA<TransferDone>());
      out as TransferDone;
      expect(out.isFolder, isTrue);
      expect(out.fileCount, 3);
      expect(out.skipped, 2);
      expect(out.failedCount, 0);
      expect(out.location, 'Unduhan/TermUL/proyek');
      expect(
        [for (final s in saver.saved) '${s.folder}/${s.name}'],
        ['proyek/a.txt', 'proyek/sub/b.txt', 'proyek/sub/dalam/c.txt'],
      );
      expect(percents.whereType<int>().last, 100);
      expect(percents.whereType<int>(), orderedEquals([...percents.whereType<int>()]..sort()), reason: 'persen naik');
      expect(tempFiles(), 0);
      expect(link.transfers.isBusy, isFalse);
    });

    test('nama lain (saveAs) dan menimpa diteruskan ke penyimpan', () async {
      server.trees['/src'] = treeOf(['a.txt', 'sub/b.txt']);
      final out = await actions.downloadFolder(folder, saveAs: 'proyek (1)', overwrite: true);
      expect((out as TransferDone).location, 'Unduhan/TermUL/proyek (1)');
      expect(saver.saved.map((s) => s.folder), ['proyek (1)', 'proyek (1)/sub']);
      expect(saver.saved.every((s) => s.overwrite), isTrue);
    });

    test('satu berkas gagal (izin): dilewati dan dihitung, sisanya tetap diunduh', () async {
      server.trees['/src'] = treeOf(['a.txt', 'rahasia.txt', 'c.txt']);
      server.downloadFailures['/src/rahasia.txt'] = const SftpFailure(SftpFailureKind.permissionDenied, 'ditolak');
      final out = await actions.downloadFolder(folder) as TransferDone;
      expect(out.fileCount, 2);
      expect(out.failedCount, 1);
      expect(saver.saved.map((s) => s.name), ['a.txt', 'c.txt']);
      expect(tempFiles(), 0);
    });

    test('semua berkas gagal: TransferFailed', () async {
      server.trees['/src'] = treeOf(['a.txt', 'b.txt']);
      server.downloadFailure = const SftpFailure(SftpFailureKind.permissionDenied, 'ditolak');
      final out = await actions.downloadFolder(folder);
      expect(out, isA<TransferFailed>());
      expect((out as TransferFailed).kind, SftpFailureKind.permissionDenied);
    });

    test('sambungan putus di tengah: menghentikan sisanya, berkas yang sudah tersimpan dibiarkan', () async {
      server.trees['/src'] = treeOf(['a.txt', 'b.txt', 'c.txt']);
      server.downloadFailures['/src/b.txt'] = const SftpFailure(SftpFailureKind.connectionLost, 'putus');
      final out = await actions.downloadFolder(folder);
      expect(out, isA<TransferFailed>());
      expect((out as TransferFailed).kind, SftpFailureKind.connectionLost);
      expect(saver.saved.map((s) => s.name), ['a.txt']);
      expect(server.downloaded, ['/src/a.txt', '/src/b.txt'], reason: 'c.txt tidak dimulai');
      expect(link.transfers.isBusy, isFalse);
    });

    test('dibatalkan di tengah: sisanya tidak dimulai, yang sudah tersimpan tidak dihapus', () async {
      server.trees['/src'] = treeOf(['a.txt', 'b.txt', 'c.txt']);
      server.hold = Completer<void>();
      final run = actions.downloadFolder(folder);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(link.transfers.active.single.total, 3000);
      link.transfers.cancelAll();
      server.hold!.complete();
      expect(await run, isA<TransferCancelled>());
      expect(saver.saved, isEmpty, reason: 'berkas pertama dibatalkan sebelum selesai');
      expect(server.downloaded, ['/src/a.txt']);
      expect(tempFiles(), 0);
      expect(link.transfers.isBusy, isFalse);
    });

    test('folder tanpa berkas: selesai dengan nol berkas; penelusuran gagal: TransferFailed', () async {
      server.trees['/src'] = treeOf([]);
      final empty = await actions.downloadFolder(folder) as TransferDone;
      expect(empty.fileCount, 0);
      expect(saver.saved, isEmpty);

      final out = await actions.downloadFolder(
        SftpEntry(name: 'hilang', path: '/hilang', kind: SftpEntryKind.directory),
      );
      expect(out, isA<TransferFailed>());
      expect((out as TransferFailed).kind, SftpFailureKind.notFound);
      expect(link.transfers.isBusy, isFalse);
    });
  });
}
