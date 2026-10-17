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

  @override
  Future<SavedDownload> save({required String path, required String name}) async {
    saved.add(name);
    return SavedDownload(name: name, location: 'Unduhan/TermUL');
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

Future<FakeFiles> pumpBrowser(WidgetTester tester, {Size size = const Size(390, 844)}) async {
  _tmp = Directory.systemTemp.createTempSync('termul_layar_');
  addTearDown(() {
    try {
      _tmp.deleteSync(recursive: true);
    } on Object {
      // berkas sementara masih terbuka bila tes gagal di tengah transfer
    }
  });
  _saver.saved.clear();
  _picker.next = [];
  final fake = FakeFiles({
    '/home/u': [dir('/home/u', 'proyek'), file('/home/u', 'catatan.txt', size: 1229)],
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
    await tester.pump(const Duration(seconds: 3));
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

    testWidgets('Unggah: nama yang sudah ada ditanyakan; Batal melewati, Timpa mengunggah', (tester) async {
      final fake = await pumpBrowser(tester);
      final f = File('${_tmp.path}${Platform.pathSeparator}catatan.txt')..writeAsBytesSync(List.filled(500, 3));
      _picker.next = [XFile(f.path)];

      await tester.tap(find.bySemanticsLabel('Unggah berkas'));
      await tester.pumpAndSettle();
      expect(find.text('Timpa catatan.txt?'), findsOneWidget);
      expect(find.textContaining('sudah ada di /home/u'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(fake.uploaded, isEmpty);

      await tester.tap(find.bySemanticsLabel('Unggah berkas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Timpa'));
      await settle(tester);
      expect(fake.uploaded, {'/home/u/catatan.txt': 500});
      expect(find.text('Diunggah · catatan.txt'), findsOneWidget);
      expect(fake.listed.where((d) => d == '/home/u').length, greaterThanOrEqualTo(2), reason: 'daftar dimuat ulang');
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
