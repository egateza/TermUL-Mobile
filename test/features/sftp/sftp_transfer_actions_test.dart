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
  final saved = <({String name, Uint8List bytes})>[];
  Object? error;

  @override
  Future<SavedDownload> save({required String path, required String name}) async {
    if (error != null) throw error!;
    saved.add((name: name, bytes: File(path).readAsBytesSync()));
    return SavedDownload(name: name == 'a.txt' ? 'a (1).txt' : name, location: 'Unduhan/TermUL');
  }
}

HostProfile profile() =>
    HostProfile(id: '11111111-1111-4111-8111-111111111111', name: 'app-01', host: 'h', port: 22, username: 'u');

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
}
