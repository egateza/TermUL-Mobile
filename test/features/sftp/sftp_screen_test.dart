import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/app_providers.dart';
import 'package:termul_mobile/core/platform/downloads_saver.dart';
import 'package:termul_mobile/core/models/host_profile.dart';
import 'package:termul_mobile/core/sftp/sftp_service.dart';
import 'package:termul_mobile/core/theme/termul_theme.dart';
import 'package:termul_mobile/features/sftp/sftp_link.dart';
import 'package:termul_mobile/features/sftp/sftp_screen.dart';
import 'package:termul_mobile/features/sftp/upload_picker.dart';
import 'package:termul_mobile/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../hosts_ui_harness.dart';
import 'sftp_browser_test.dart' show FakeFiles, dir, file;

HostProfile profile() =>
    HostProfile(id: '11111111-1111-4111-8111-111111111111', name: 'app-01', host: 'h', port: 22, username: 'u');

late SftpLink lastLink;

class _Saver implements DownloadsSaver {
  final saved = <String>[];
  final folders = <String?>[];
  final overwrites = <bool>[];
  final existing = <String>{};
  final existingFolders = <String>{};

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
    saved.add(name);
    folders.add(folder);
    overwrites.add(overwrite);
    return SavedDownload(name: name, location: 'Unduhan/TermUL', overwritten: overwrite);
  }
}

class _Picker implements UploadPicker {
  List<XFile> next = [];

  @override
  Future<List<XFile>> pick() async => next;
}

final _saver = _Saver();
final _picker = _Picker();
late Directory _tmp;

/// Memberi waktu nyata untuk I/O berkas (yang tidak selesai di dalam `testWidgets`) di antara pembaruan frame.
Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<FakeFiles> pumpBrowser(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  List<SftpEntry> extra = const [],
}) async {
  _tmp = Directory.systemTemp.createTempSync('termul_layar_');
  addTearDown(() {
    try {
      _tmp.deleteSync(recursive: true);
    } on Object {
      // berkas sementara masih terbuka bila tes gagal di tengah transfer
    }
  });
  _saver.saved.clear();
  _saver.folders.clear();
  _saver.existingFolders.clear();
  _saver.overwrites.clear();
  _saver.existing.clear();
  _picker.next = [];
  final fake = FakeFiles({
    '/home/u': [dir('/home/u', 'proyek'), file('/home/u', 'catatan.txt', size: 1229), ...extra],
    '/home/u/proyek': [file('/home/u/proyek', 'a.conf')],
    '/home': [dir('/home', 'u')],
    '/': [dir('/', 'home')],
  });
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        downloadsSaverProvider.overrideWithValue(_saver),
        uploadPickerProvider.overrideWithValue(_picker),
        tempDirProvider.overrideWithValue(() async => _tmp),
      ],
      child: MaterialApp(
        theme: termulTheme(),
        locale: const Locale('id'),
        supportedLocales: const [Locale('id')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: Text('akar')),
      ),
    ),
  );
  lastLink = SftpLink.ready(profile: profile(), service: fake);
  tester
      .state<NavigatorState>(find.byType(Navigator))
      .push<void>(MaterialPageRoute(builder: (_) => SftpBrowserScreen(link: lastLink)));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('daftar folder: folder dulu, ukuran, buka folder, naik, dan breadcrumb', (tester) async {
    final fake = await pumpBrowser(tester);
    expect(find.text('app-01 · terhubung'), findsOneWidget);
    expect(find.text('proyek'), findsOneWidget);
    expect(find.text('catatan.txt'), findsOneWidget);
    expect(find.text('1,2 KB'), findsOneWidget);
    expect(find.text('Folder'), findsOneWidget);
    expect(fake.listed, ['/home/u']);

    await tester.tap(find.text('proyek'));
    await tester.pumpAndSettle();
    expect(find.text('a.conf'), findsOneWidget);
    expect(find.text('..'), findsOneWidget);

    await tester.tap(find.text('..'));
    await tester.pumpAndSettle();
    expect(find.text('catatan.txt'), findsOneWidget);

    // Breadcrumb: ketuk "home" membuka /home.
    await tester.tap(find.bySemanticsLabel('/home'));
    await tester.pumpAndSettle();
    expect(fake.listed.last, '/home');
  });

  testWidgets('memilih berkas menampilkan bar aksi; Salin path mengisi papan klip', (tester) async {
    String? clip;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clip = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpBrowser(tester);
    await tester.tap(find.text('catatan.txt'));
    await tester.pump();
    expect(find.text('catatan.txt dipilih'), findsOneWidget);
    await tester.tap(find.text('Salin path'));
    await tester.pump();
    expect(clip, '/home/u/catatan.txt');
    expect(find.text('Path disalin'), findsOneWidget);
    expect(find.text('catatan.txt dipilih'), findsNothing, reason: 'pilihan dilepas setelah aksi');
    await tester.pump(const Duration(seconds: 3));
  });

  group('seleksi ganda', () {
    String? clip;
    setUp(() => clip = null);

    Future<FakeFiles> pumpSelectable(WidgetTester tester) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clip = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      return pumpBrowser(tester, extra: [file('/home/u', 'log.txt', size: 2048)]);
    }

    testWidgets('tekan lama pada folder memilihnya tanpa membukanya; jumlah dan ukuran tanpa folder', (tester) async {
      final fake = await pumpSelectable(tester);
      await tester.longPress(find.text('proyek'));
      await tester.pump();
      expect(find.text('proyek dipilih'), findsOneWidget);
      expect(fake.listed, ['/home/u'], reason: 'folder tidak dibuka');
      expect(find.text('0 B'), findsNothing, reason: 'folder saja: tidak ada total ukuran');
      expect(find.text('Unduh'), findsOneWidget, reason: 'folder juga bisa diunduh');

      // Dalam mode seleksi, ketukan menambah pilihan (juga folder), bukan membuka.
      await tester.tap(find.text('catatan.txt'));
      await tester.pump();
      expect(find.text('2 dipilih'), findsOneWidget);
      expect(find.text('1,2 KB'), findsNWidgets(2), reason: 'baris dan total');
      await tester.tap(find.text('log.txt'));
      await tester.pump();
      expect(find.text('3 dipilih'), findsOneWidget);
      expect(find.text('3,2 KB'), findsOneWidget, reason: '1229 + 2048 byte, folder tidak dihitung');
      expect(find.text('Pilih semua'), findsNothing, reason: 'semua sudah dipilih');
    });

    testWidgets('Salin path banyak: satu path per baris; kembali dan Batal pilih melepas pilihan', (tester) async {
      await pumpSelectable(tester);
      await tester.longPress(find.text('catatan.txt'));
      await tester.pump();
      await tester.tap(find.text('log.txt'));
      await tester.pump();
      await tester.tap(find.text('Salin path'));
      await tester.pump();
      expect(clip, '/home/u/catatan.txt\n/home/u/log.txt');
      expect(find.text('2 path disalin'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));

      await tester.longPress(find.text('log.txt'));
      await tester.pump();
      expect(find.text('log.txt dipilih'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Batal pilih'));
      await tester.pump();
      expect(find.text('log.txt dipilih'), findsNothing);

      await tester.longPress(find.text('log.txt'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Kembali'));
      await tester.pump();
      expect(find.text('log.txt dipilih'), findsNothing, reason: 'kembali hanya melepas pilihan');
      expect(find.text('log.txt'), findsOneWidget, reason: 'tetap di layar SFTP');
    });

    testWidgets('Unduh beberapa berkas: satu toast ringkasan', (tester) async {
      await pumpSelectable(tester);
      await tester.longPress(find.text('catatan.txt'));
      await tester.pump();
      await tester.tap(find.text('log.txt'));
      await tester.pump();
      await tester.tap(find.text('Unduh'));
      await settle(tester, rounds: 14);
      expect(_saver.saved, ['catatan.txt', 'log.txt']);
      expect(find.text('2 berkas diunduh ke Unduhan/TermUL'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('beberapa nama sudah ada: satu pertanyaan untuk semuanya', (tester) async {
      await pumpSelectable(tester);
      _saver.existing.addAll({'catatan.txt', 'log.txt'});
      await tester.longPress(find.text('catatan.txt'));
      await tester.pump();
      await tester.tap(find.text('log.txt'));
      await tester.pump();
      await tester.tap(find.text('Unduh'));
      await tester.pumpAndSettle();
      expect(find.text('2 item sudah ada'), findsOneWidget);
      await tester.tap(find.text('Simpan dengan nama bernomor'));
      await settle(tester, rounds: 14);
      expect(_saver.saved, ['catatan (1).txt', 'log (1).txt']);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('unduh folder', () {
    Future<FakeFiles> pumpFolders(WidgetTester tester) async {
      final fake = await pumpBrowser(tester, extra: [file('/home/u', 'log.txt', size: 2048)]);
      fake.trees['/home/u/proyek'] = SftpTree(
        files: [
          const SftpTreeFile(remotePath: '/home/u/proyek/a.conf', relativePath: 'a.conf', size: 1000),
          const SftpTreeFile(remotePath: '/home/u/proyek/sub/b.conf', relativePath: 'sub/b.conf', size: 1000),
        ],
        skipped: 1,
      );
      return fake;
    }

    testWidgets(
      'folder dipilih dengan tekan lama lalu Unduh: disimpan bersubfolder, toast menyebut jumlah dan dilewati',
      (tester) async {
        await pumpFolders(tester);
        await tester.longPress(find.text('proyek'));
        await tester.pump();
        await tester.tap(find.text('Unduh'));
        await settle(tester, rounds: 14);
        expect(_saver.saved, ['a.conf', 'b.conf']);
        expect(_saver.folders, ['proyek', 'proyek/sub']);
        expect(find.text('2 berkas diunduh ke Unduhan/TermUL/proyek · 1 dilewati'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets('nama folder sudah ada di Unduhan: folder bernomor, tanpa mengubah ekstensi', (tester) async {
      await pumpFolders(tester);
      _saver.existingFolders.add('proyek');
      await tester.longPress(find.text('proyek'));
      await tester.pump();
      await tester.tap(find.text('Unduh'));
      await tester.pumpAndSettle();
      expect(find.text('proyek sudah ada'), findsOneWidget);
      await tester.tap(find.text('Simpan sebagai proyek (1)'));
      await settle(tester, rounds: 14);
      expect(_saver.folders, ['proyek (1)', 'proyek (1)/sub']);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('folder dan berkas sekaligus: satu toast ringkasan menjumlah semua berkas', (tester) async {
      await pumpFolders(tester);
      await tester.longPress(find.text('proyek'));
      await tester.pump();
      await tester.tap(find.text('log.txt'));
      await tester.pump();
      await tester.tap(find.text('Unduh'));
      await settle(tester, rounds: 20);
      expect(_saver.saved, ['a.conf', 'b.conf', 'log.txt']);
      expect(find.text('3 berkas diunduh ke Unduhan/TermUL · 1 dilewati'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  testWidgets('muat ulang (tombol dan tarik ke bawah): toast bila berhasil, tanpa toast bila gagal', (tester) async {
    final fake = await pumpBrowser(tester);
    await tester.tap(find.bySemanticsLabel('Muat ulang'));
    await tester.pumpAndSettle();
    expect(find.text('Daftar file diperbarui'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Daftar file diperbarui'), findsNothing);

    await tester.fling(find.text('catatan.txt'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Daftar file diperbarui'), findsOneWidget, reason: 'tarik ke bawah');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    fake.failures['/home/u'] = const SftpFailure(SftpFailureKind.permissionDenied, 'ditolak');
    await tester.tap(find.bySemanticsLabel('Muat ulang'));
    await tester.pumpAndSettle();
    expect(find.text('Daftar file diperbarui'), findsNothing, reason: 'gagal: galat tampil di banner');
  });

  testWidgets('tautan simbolik: lencana tautan dan kata "Tautan" hanya di entri tautan', (tester) async {
    await pumpBrowser(
      tester,
      extra: [file('/home/u', 'pintasan.txt', size: 2048, link: true), dir('/home/u', 'jalan', link: true)],
    );
    expect(find.byKey(const ValueKey('lencana-tautan')), findsNWidgets(2));
    expect(find.text('2,0 KB · Tautan'), findsOneWidget);
    expect(find.text('Folder · Tautan'), findsOneWidget);
    expect(find.textContaining('Tautan'), findsNWidgets(2));
    expect(find.text('Folder'), findsOneWidget, reason: 'folder biasa tanpa penanda');
  });

  testWidgets('landscape pendek: daftar tidak meluap', (tester) async {
    await pumpBrowser(tester, size: const Size(844, 390));
    expect(tester.takeException(), isNull);
    expect(find.text('proyek'), findsOneWidget);
  });

  testWidgets('tab SFTP: host tersimpan tampil sebagai sumber koneksi sendiri', (tester) async {
    final h = Harness();
    await h.seed([host('11111111-1111-4111-8111-111111111111', name: 'app-01')]);
    await h.pump(tester);
    await tester.tap(find.descendant(of: find.byType(Navigator), matching: find.text('SFTP')).last);
    await tester.pumpAndSettle();
    expect(find.text('Koneksi sendiri'), findsOneWidget);
    expect(find.text('app-01'), findsOneWidget);
    expect(find.text('Sesi terbuka'), findsNothing);
  });

  group('transfer', () {
    testWidgets('Unduh: berkas disimpan ke Unduhan/TermUL dan toast menyebut tempatnya', (tester) async {
      await pumpBrowser(tester);
      await tester.tap(find.text('catatan.txt'));
      await tester.pump();
      await tester.tap(find.text('Unduh'));
      await settle(tester);
      expect(_saver.saved, ['catatan.txt']);
      expect(find.text('Diunduh ke Unduhan/TermUL · catatan.txt'), findsOneWidget);
      expect(lastLink.transfers.isBusy, isFalse);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Unduh melepas pilihan: tombol tidak bisa ditekan berulang untuk berkas yang sama', (tester) async {
      final fake = await pumpBrowser(tester);
      fake.hold = Completer<void>();
      await tester.tap(find.text('catatan.txt'));
      await tester.pump();
      await tester.tap(find.text('Unduh'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('catatan.txt dipilih'), findsNothing);
      expect(find.text('Unduh'), findsNothing, reason: 'bar pilihan hilang');
      await settle(tester, rounds: 2);
      expect(lastLink.transfers.active, hasLength(1));

      fake.hold!.complete();
      await settle(tester);
      expect(_saver.saved, ['catatan.txt'], reason: 'satu unduhan saja');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('selama berjalan tampil panel dengan persen; Batalkan membatalkan tanpa menyimpan', (tester) async {
      final fake = await pumpBrowser(tester);
      fake.hold = Completer<void>();
      await tester.tap(find.text('catatan.txt'));
      await tester.pump();
      await tester.tap(find.text('Unduh'));
      await settle(tester, rounds: 2);
      expect(find.text('Unduh catatan.txt'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget, reason: '500 dari 1229 byte');

      await tester.tap(find.bySemanticsLabel('Batalkan transfer'));
      fake.hold!.complete();
      await settle(tester);
      expect(find.text('Dibatalkan · catatan.txt'), findsOneWidget);
      expect(_saver.saved, isEmpty);
      expect(find.text('Unduh catatan.txt'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Unggah, nama sudah ada: Batal melewati, nama lain bernomor, Timpa mengganti', (tester) async {
      final fake = await pumpBrowser(tester);
      final f = File('${_tmp.path}${Platform.pathSeparator}catatan.txt')..writeAsBytesSync(List.filled(500, 3));
      _picker.next = [XFile(f.path)];

      await tester.tap(find.bySemanticsLabel('Unggah berkas'));
      await settle(tester);
      expect(find.text('catatan.txt sudah ada'), findsOneWidget);
      expect(find.text('Simpan sebagai catatan (1).txt'), findsOneWidget);
      expect(find.text('Timpa berkas lama'), findsOneWidget);
      expect(find.textContaining('Di /home/u di server'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await settle(tester);
      expect(fake.uploaded, isEmpty);

      await tester.tap(find.bySemanticsLabel('Unggah berkas'));
      await settle(tester);
      await tester.tap(find.text('Simpan sebagai catatan (1).txt'));
      await settle(tester);
      expect(fake.uploaded, {'/home/u/catatan (1).txt': 500});
      expect(find.text('Diunggah · catatan (1).txt'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));

      fake.uploaded.clear();
      await tester.tap(find.bySemanticsLabel('Unggah berkas'));
      await settle(tester);
      await tester.tap(find.text('Timpa berkas lama'));
      await settle(tester);
      expect(fake.uploaded, {'/home/u/catatan.txt': 500});
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Unggah, nama bernomor juga ada: nomor berikutnya yang bebas', (tester) async {
      final fake = await pumpBrowser(tester);
      fake.tree['/home/u']!.add(file('/home/u', 'catatan (1).txt'));
      await tester.tap(find.bySemanticsLabel('Muat ulang'));
      await settle(tester);
      final f = File('${_tmp.path}${Platform.pathSeparator}catatan.txt')..writeAsBytesSync(List.filled(20, 3));
      _picker.next = [XFile(f.path)];
      await tester.tap(find.bySemanticsLabel('Unggah berkas'));
      await settle(tester);
      expect(find.text('Simpan sebagai catatan (2).txt'), findsOneWidget);
      await tester.tap(find.text('Simpan sebagai catatan (2).txt'));
      await settle(tester);
      expect(fake.uploaded, {'/home/u/catatan (2).txt': 20});
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Unduh, nama sudah ada di Unduhan/TermUL: nama lain, timpa, atau batal', (tester) async {
      await pumpBrowser(tester);
      _saver.existing.addAll({'catatan.txt', 'catatan (1).txt'});
      await tester.tap(find.text('catatan.txt'));
      await tester.pump();

      await tester.tap(find.text('Unduh'));
      await settle(tester);
      expect(find.text('catatan.txt sudah ada'), findsOneWidget);
      expect(find.text('Simpan sebagai catatan (2).txt'), findsOneWidget, reason: 'melewati (1) yang sudah ada');
      expect(find.textContaining('Unduhan/TermUL'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await settle(tester);
      expect(_saver.saved, isEmpty);

      await tester.tap(find.text('catatan.txt'));
      await tester.pump();
      await tester.tap(find.text('Unduh'));
      await settle(tester);
      await tester.tap(find.text('Simpan sebagai catatan (2).txt'));
      await settle(tester);
      expect(_saver.saved, ['catatan (2).txt']);
      expect(_saver.overwrites, [false]);
      expect(find.text('Diunduh ke Unduhan/TermUL · catatan (2).txt'), findsOneWidget);
      // Toast menutupi tombol Unduh; tutup dulu.
      tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      await tester.tap(find.text('catatan.txt'));
      await tester.pump();
      await tester.tap(find.text('Unduh'));
      await settle(tester);
      await tester.tap(find.text('Timpa berkas lama'));
      await settle(tester);
      expect(_saver.saved.last, 'catatan.txt');
      expect(_saver.overwrites.last, isTrue);
      expect(find.text('Ditimpa di Unduhan/TermUL · catatan.txt'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Unggah nama baru: langsung berjalan tanpa tanya; pilihan dibatalkan tidak melakukan apa pun', (
      tester,
    ) async {
      final fake = await pumpBrowser(tester);
      await tester.tap(find.bySemanticsLabel('Unggah berkas'));
      await settle(tester);
      expect(fake.uploaded, isEmpty);

      final f = File('${_tmp.path}${Platform.pathSeparator}baru.log')..writeAsBytesSync(List.filled(40, 1));
      _picker.next = [XFile(f.path)];
      await tester.tap(find.bySemanticsLabel('Unggah berkas'));
      await settle(tester);
      expect(find.textContaining('Timpa'), findsNothing);
      expect(fake.uploaded, {'/home/u/baru.log': 40});
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('tombol kembali', () {
    testWidgets('di dalam folder: sistem dan header kembali ke folder sebelumnya, tanpa konfirmasi keluar', (
      tester,
    ) async {
      final fake = await pumpBrowser(tester);
      await tester.tap(find.text('proyek'));
      await tester.pumpAndSettle();
      expect(find.text('a.conf'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Keluar dari SFTP?'), findsNothing);
      expect(find.text('catatan.txt'), findsOneWidget, reason: 'kembali ke /home/u');
      expect(fake.listed.last, '/home/u');

      await tester.tap(find.text('proyek'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Kembali'));
      await tester.pumpAndSettle();
      expect(find.text('Keluar dari SFTP?'), findsNothing);
      expect(find.text('catatan.txt'), findsOneWidget);
    });

    testWidgets('di folder awal: kembali menanyakan keluar', (tester) async {
      await pumpBrowser(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Keluar dari SFTP?'), findsOneWidget);
    });

    testWidgets('beberapa tingkat: kembali satu per satu sampai folder awal, lalu konfirmasi keluar', (tester) async {
      final fake = await pumpBrowser(tester);
      fake.tree['/home/u/proyek']!.add(dir('/home/u/proyek', 'dalam'));
      fake.tree['/home/u/proyek/dalam'] = [file('/home/u/proyek/dalam', 'x.txt')];
      await tester.tap(find.text('proyek'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('dalam'));
      await tester.pumpAndSettle();
      expect(find.text('x.txt'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('a.conf'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('catatan.txt'), findsOneWidget);
      expect(find.text('Keluar dari SFTP?'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Keluar dari SFTP?'), findsOneWidget);
    });
  });

  group('konfirmasi keluar', () {
    testWidgets('selalu muncul; Batal tetap di layar, Keluar menutup', (tester) async {
      await pumpBrowser(tester);
      await tester.tap(find.bySemanticsLabel('Kembali'));
      await tester.pumpAndSettle();
      expect(find.text('Keluar dari SFTP?'), findsOneWidget);
      expect(find.textContaining('Sesi terminal app-01 tetap berjalan'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Keluar dari SFTP?'), findsNothing);
      expect(find.byType(SftpBrowserScreen), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Kembali'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();
      expect(find.byType(SftpBrowserScreen), findsNothing);
      expect(find.text('akar'), findsOneWidget);
    });

    testWidgets('tombol kembali sistem juga meminta konfirmasi', (tester) async {
      await pumpBrowser(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Keluar dari SFTP?'), findsOneWidget);
      expect(find.byType(SftpBrowserScreen), findsOneWidget);
    });

    testWidgets('ada transfer: isi menyebut transfer, Batal jadi tombol utama, Keluar membatalkan semuanya', (
      tester,
    ) async {
      await pumpBrowser(tester);
      final up = lastLink.transfers.start(name: 'besar.iso', upload: true, total: 200);
      final down = lastLink.transfers.start(name: 'log.txt', upload: false, total: 100);
      lastLink.transfers.progress(up, 50);
      await tester.tap(find.bySemanticsLabel('Kembali'));
      await tester.pumpAndSettle();
      expect(find.text('Transfer masih berjalan'), findsOneWidget);
      expect(find.textContaining('2 transfer belum selesai'), findsOneWidget);
      Finder inSheet(String t) => find.descendant(of: find.byType(BottomSheet), matching: find.text(t));
      expect(inSheet('Unggah besar.iso'), findsOneWidget);
      expect(inSheet('25%'), findsOneWidget);
      expect(inSheet('Unduh log.txt'), findsOneWidget);
      expect(find.textContaining('dihapus dari server'), findsOneWidget);
      expect(find.textContaining('dihapus dari perangkat'), findsOneWidget);

      await tester.tap(find.text('Batalkan transfer dan keluar'));
      await tester.pumpAndSettle();
      expect(up.cancel.isCancelled, isTrue);
      expect(down.cancel.isCancelled, isTrue);
      expect(find.byType(SftpBrowserScreen), findsNothing);
    });
  });

  testWidgets('sambungan putus: subjudul "terputus" berwarna bad dan banner dengan penjelasan', (tester) async {
    await pumpBrowser(tester);
    lastLink.markLost();
    await tester.pump();
    final subtitle = tester.widget<Text>(find.text('app-01 · terputus'));
    expect(subtitle.style?.color, TermulPalette.bad);
    expect(find.text('Sambungan SFTP terputus'), findsOneWidget);
    expect(find.textContaining('Sesi terminalnya terputus'), findsOneWidget);
    expect(find.text('app-01 · terhubung'), findsNothing);
  });
}
