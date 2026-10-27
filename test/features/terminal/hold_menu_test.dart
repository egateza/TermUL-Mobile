import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/models/snippet.dart';
import 'package:termul_mobile/core/platform/downloads_saver.dart';
import 'package:termul_mobile/core/platform/file_sharer.dart';
import 'package:termul_mobile/core/platform/screen_awake.dart';
import 'package:termul_mobile/features/snippets/snippet_panel.dart';
import 'package:termul_mobile/features/terminal/terminal_transcript.dart';
import 'package:xterm/xterm.dart';

import 'terminal_screen_test.dart' show TermRig, pumpTerminal, terminalView;

/// Papan klip palsu: isi untuk dibaca, dan catatan teks yang disalin.
class _Clip {
  String? read;
  String? written;
}

_Clip _mockClipboard(WidgetTester tester, String? text) {
  final clip = _Clip()..read = text;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') return clip.read == null ? null : <String, Object?>{'text': clip.read};
    if (call.method == 'Clipboard.setData') clip.written = (call.arguments as Map)['text'] as String?;
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return clip;
}

class _Exporter implements TranscriptExporter {
  final saved = <(String, String)>[];
  final shared = <(String, String)>[];
  bool fail = false;

  @override
  Future<SavedDownload> save(String name, String text) async {
    if (fail) throw const DownloadSaveException();
    saved.add((name, text));
    return SavedDownload(name: name, location: 'Unduhan/TermUL');
  }

  @override
  Future<void> share(String name, String text, {String? title}) async {
    if (fail) throw const ShareException();
    shared.add((name, text));
  }

  @override
  Future<Directory> Function() get tempDir => throw UnimplementedError();
  @override
  DownloadsSaver get saver => throw UnimplementedError();
  @override
  FileSharer get sharer => throw UnimplementedError();
}

class _RecordingSaver implements DownloadsSaver {
  _RecordingSaver(this.onSave);

  final void Function(String path) onSave;

  @override
  Future<bool> exists(String name, {String? folder}) async => false;

  @override
  Future<bool> folderExists(String name) async => false;

  @override
  Future<SavedDownload> save({
    required String path,
    required String name,
    String? folder,
    bool overwrite = false,
  }) async {
    onSave(path);
    return SavedDownload(name: name, location: 'Unduhan/TermUL');
  }
}

class _RecordingSharer implements FileSharer {
  _RecordingSharer(this.onShare);

  final void Function(String path) onShare;

  @override
  Future<void> shareFile({required String path, required String name, required String mimeType, String? title}) async =>
      onShare(path);
}

class _Awake implements ScreenAwake {
  final owners = <Object>{};

  @override
  void acquire(Object owner) => owners.add(owner);

  @override
  void release(Object owner) => owners.remove(owner);
}

final _menuTitle = find.text('Terminal');

Future<TermRig> _open(
  WidgetTester tester, {
  TranscriptExporter? transcripts,
  ScreenAwake? screenAwake,
  List<Snippet>? snippets,
}) async {
  final rig = await pumpTerminal(tester, transcripts: transcripts, screenAwake: screenAwake, snippets: snippets);
  terminalView(tester).terminal.write('halo dunia\r\nbaris dua\r\nuser@host:~\$ ');
  await tester.pump();
  return rig;
}

Offset _cellAt(WidgetTester tester, int col, int row) {
  final view = tester.state<TerminalViewState>(find.byType(TerminalView));
  final render = view.renderTerminal;
  final local = render.getOffset(CellOffset(col, row)) + Offset(render.cellSize.width / 2, render.cellSize.height / 2);
  return render.localToGlobal(local);
}

Future<void> _hold(WidgetTester tester, Offset at) async {
  await tester.longPressAt(at);
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, Pattern label) async {
  await tester.tap(find.bySemanticsLabel(label));
  await tester.pumpAndSettle();
}

void main() {
  group('menu tekan-tahan terminal', () {
    testWidgets('tekan-tahan di atas teks membuka menu, bukan seleksi kata', (tester) async {
      _mockClipboard(tester, 'ls');
      await _open(tester);
      await _hold(tester, _cellAt(tester, 1, 0));
      expect(_menuTitle, findsOneWidget);
      expect(find.textContaining('· 3 baris'), findsOneWidget);
      expect(terminalView(tester).controller!.selection, isNull, reason: 'seleksi kata xterm dibuang');
      for (final label in ['Pilih teks', 'Salin semua', 'Tempel']) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      expect(find.text('ls'), findsOneWidget, reason: 'pratinjau papan klip');
    });

    testWidgets('tekan-tahan di area kosong juga membuka menu (popover tempel tidak dipakai lagi)', (tester) async {
      _mockClipboard(tester, 'ls');
      await _open(tester);
      await _hold(tester, const Offset(14, 500));
      expect(_menuTitle, findsOneWidget);
      expect(find.byKey(const ValueKey('paste-popover')), findsNothing);
    });

    testWidgets('layar alternatif dan mouse mode: menu tetap terbuka; Bersihkan layar nonaktif di layar alternatif', (
      tester,
    ) async {
      _mockClipboard(tester, null);
      await _open(tester);
      terminalView(tester).terminal.write('\x1b[?1049h\x1b[?1000h\x1b[?1006h');
      await tester.pump();
      await _hold(tester, const Offset(14, 400));
      expect(_menuTitle, findsOneWidget);
      expect(find.textContaining('Tidak tersedia selagi program layar penuh'), findsOneWidget);
    });

    testWidgets('Tempel: satu baris aman langsung masuk ke prompt', (tester) async {
      _mockClipboard(tester, 'uptime');
      final rig = await _open(tester);
      await _hold(tester, const Offset(14, 500));
      await _pick(tester, 'Tempel');
      expect(_menuTitle, findsNothing);
      expect(rig.shell.sent, contains('uptime'));
    });

    testWidgets('papan klip kosong: Tempel nonaktif dan pratinjau tidak tampil', (tester) async {
      _mockClipboard(tester, null);
      final rig = await _open(tester);
      await _hold(tester, const Offset(14, 500));
      await tester.tap(find.bySemanticsLabel('Tempel, papan klip kosong'));
      await tester.pumpAndSettle();
      expect(_menuTitle, findsOneWidget, reason: 'ubin nonaktif tidak menutup menu');
      expect(find.text('Papan klip:'), findsNothing);
      expect(rig.shell.sent, isEmpty);
    });

    testWidgets('Pilih teks: kata di bawah jari terpilih, panduan 1/2 lalu 2/2 setelah gagang diseret', (tester) async {
      _mockClipboard(tester, null);
      await _open(tester);
      await _hold(tester, _cellAt(tester, 6, 0));
      await _pick(tester, 'Pilih teks');
      final view = terminalView(tester);
      final range = view.controller!.selection!.normalized;
      expect(view.terminal.buffer.getText(range), 'dunia');
      expect(find.text('5 karakter dipilih'), findsOneWidget);
      expect(find.textContaining('Seret gagang ke awal pilihan'), findsOneWidget);

      await tester.drag(find.bySemanticsLabel('Gagang awal pilihan'), const Offset(-60, 0));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sekarang seret ke akhir pilihan'), findsOneWidget);

      await tester.drag(find.bySemanticsLabel('Gagang akhir pilihan'), const Offset(0, 20));
      await tester.pumpAndSettle();
      expect(find.text('Seret gagang untuk mengubah pilihan'), findsOneWidget);
    });

    testWidgets('Batal di bilah seleksi menghapus panduan', (tester) async {
      _mockClipboard(tester, null);
      await _open(tester);
      await _hold(tester, _cellAt(tester, 1, 0));
      await _pick(tester, 'Pilih teks');
      await _pick(tester, 'Batal');
      expect(terminalView(tester).controller!.selection, isNull);
      expect(find.textContaining('Seret gagang ke awal pilihan'), findsNothing);
    });

    testWidgets('Salin semua: seluruh teks masuk papan klip, toast menyebut jumlah baris', (tester) async {
      final clip = _mockClipboard(tester, null);
      await _open(tester);
      await _hold(tester, const Offset(14, 500));
      await _pick(tester, 'Salin semua');
      expect(clip.written, 'halo dunia\nbaris dua\nuser@host:~\$');
      expect(find.text('Disalin · 3 baris'), findsOneWidget);
    });

    testWidgets('Simpan dan Bagikan transkrip memakai nama host-tanggal.txt; gagal menampilkan toast', (tester) async {
      _mockClipboard(tester, null);
      final exporter = _Exporter();
      await _open(tester, transcripts: exporter);
      await _hold(tester, const Offset(14, 500));
      await _pick(tester, RegExp('^Simpan transkrip'));
      expect(exporter.saved.single.$1, matches(RegExp(r'^app-01-\d{8}-\d{4}\.txt$')));
      expect(exporter.saved.single.$2, startsWith('halo dunia\n'));
      expect(find.textContaining('Disimpan ke Unduhan/TermUL · app-01-'), findsOneWidget);

      await _hold(tester, const Offset(14, 500));
      await _pick(tester, RegExp('^Bagikan transkrip'));
      expect(exporter.shared, hasLength(1));

      exporter.fail = true;
      await _hold(tester, const Offset(14, 500));
      await _pick(tester, RegExp('^Simpan transkrip'));
      expect(find.text('Transkrip gagal disimpan'), findsOneWidget);
    });

    testWidgets('Layar tetap menyala: saklar memegang bendera, chip di header, dilepas saat layar ditutup', (
      tester,
    ) async {
      _mockClipboard(tester, null);
      final awake = _Awake();
      await _open(tester, screenAwake: awake);
      await _hold(tester, const Offset(14, 500));
      await _pick(tester, RegExp('^Layar tetap menyala'));
      expect(awake.owners, hasLength(1));
      expect(_menuTitle, findsOneWidget, reason: 'saklar tidak menutup menu');
      expect(find.textContaining('Nyala selama terminal ini terbuka'), findsOneWidget);
      await tester.tapAt(const Offset(200, 60)); // scrim menutup menu
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Layar tetap menyala'), findsOneWidget, reason: 'chip menyala di header');

      await tester.pumpWidget(const SizedBox());
      expect(awake.owners, isEmpty);
    });

    testWidgets('Bersihkan layar: scrollback hilang, prompt naik ke baris pertama, tidak ada yang dikirim', (
      tester,
    ) async {
      _mockClipboard(tester, null);
      final rig = await _open(tester);
      final terminal = terminalView(tester).terminal;
      terminal.write('\r\n${List.generate(80, (i) => 'baris $i').join('\r\n')}\r\nuser@host:~\$ ');
      await tester.pump();
      await _hold(tester, const Offset(14, 300));
      await _pick(tester, RegExp('^Bersihkan layar'));
      expect(terminal.buffer.scrollBack, 0);
      expect(terminal.buffer.lines[0].getText().trimRight(), 'user@host:~\$');
      expect(terminal.buffer.cursorY, 0);
      expect(terminal.buffer.cursorX, 'user@host:~\$ '.length);
      expect(find.text('Layar dibersihkan'), findsOneWidget);
      expect(rig.shell.sent, isEmpty);
    });

    testWidgets('Snippet: membuka panel snippet', (tester) async {
      _mockClipboard(tester, null);
      await _open(
        tester,
        snippets: const [Snippet(id: 'a', title: 'Cek disk', command: 'df -h /')],
      );
      await _hold(tester, const Offset(14, 500));
      await _pick(tester, 'Snippet');
      expect(find.byType(SnippetPanel), findsOneWidget);
    });

    testWidgets('keempat ubin sama lebar', (tester) async {
      _mockClipboard(tester, 'ls');
      await _open(
        tester,
        snippets: const [Snippet(id: 'a', title: 'Cek disk', command: 'df -h /')],
      );
      await _hold(tester, const Offset(14, 500));
      final widths = [
        for (final l in ['Pilih teks', 'Salin semua', 'Tempel', 'Snippet'])
          tester.getSize(find.bySemanticsLabel(l)).width,
      ];
      expect(widths.toSet(), hasLength(1), reason: '$widths');
    });

    testWidgets('tanpa snippet: ubin Snippet tidak tampil', (tester) async {
      _mockClipboard(tester, null);
      await _open(tester);
      await _hold(tester, const Offset(14, 500));
      expect(find.bySemanticsLabel('Snippet'), findsNothing);
    });
  });

  group('TerminalTranscript', () {
    test('spasi ujung baris dan baris kosong di bawah dibuang; baris terbungkus disambung', () {
      final t = Terminal(maxLines: 100)..resize(10, 5);
      t.write('abcdefghijKLM\r\n  x   \r\n\r\n');
      final tr = TerminalTranscript.of(t);
      expect(tr.text, 'abcdefghijKLM\n  x');
      expect(tr.lineCount, 2);
      expect(TerminalTranscript.of(Terminal()).isEmpty, isTrue);
    });

    test('TranscriptExporter: berkas sementara di share/, isi berakhir baris baru, dihapus setelah disimpan', () async {
      final tmp = Directory.systemTemp.createTempSync('termul-transcript');
      addTearDown(() => tmp.deleteSync(recursive: true));
      String? content;
      String? sharedPath;
      final saver = _RecordingSaver((path) => content = File(path).readAsStringSync());
      final sharer = _RecordingSharer((path) => sharedPath = path);
      final ex = TranscriptExporter(tempDir: () async => tmp, saver: saver, sharer: sharer);
      final saved = await ex.save('a.txt', 'halo');
      expect(saved.name, 'a.txt');
      expect(content, 'halo\n');
      expect(File('${tmp.path}${Platform.pathSeparator}share${Platform.pathSeparator}a.txt').existsSync(), isFalse);
      await ex.share('b.txt', 'x\n');
      expect(sharedPath, endsWith('share${Platform.pathSeparator}b.txt'));
      expect(File(sharedPath!).readAsStringSync(), 'x\n');
    });

    test('nama berkas aman', () {
      final at = DateTime(2026, 10, 27, 7, 5);
      expect(TerminalTranscript.fileName('app-01', at), 'app-01-20261027-0705.txt');
      expect(TerminalTranscript.fileName('db utama/01', at), 'db_utama_01-20261027-0705.txt');
      expect(TerminalTranscript.fileName('  ', at), 'terminal-20261027-0705.txt');
    });
  });
}
