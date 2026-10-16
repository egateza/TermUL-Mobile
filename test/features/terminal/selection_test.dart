import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

import 'terminal_screen_test.dart' show pumpTerminal, terminalView;

/// Papan klip palsu; mengembalikan teks yang terakhir ditulis.
class FakeClipboard {
  String? text;
}

FakeClipboard mockClipboard(WidgetTester tester) {
  final clip = FakeClipboard();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      clip.text = (call.arguments as Map)['text'] as String?;
    }
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return clip;
}

void select(WidgetTester tester, CellOffset from, CellOffset to) {
  final view = terminalView(tester);
  final buffer = view.terminal.buffer;
  view.controller!.setSelection(buffer.createAnchorFromOffset(from), buffer.createAnchorFromOffset(to));
}

void main() {
  testWidgets('tanpa seleksi: tombol cepat tampil, tanpa bilah seleksi dan gagang', (tester) async {
    await pumpTerminal(tester);
    expect(find.bySemanticsLabel('Gagang awal pilihan'), findsNothing);
    expect(find.bySemanticsLabel('Salin teks terpilih'), findsNothing);
    expect(find.bySemanticsLabel('Tempel dari papan klip'), findsOneWidget);
  });

  testWidgets('seleksi memunculkan bilah (jumlah karakter), dua gagang, dan menyembunyikan tombol cepat', (
    tester,
  ) async {
    await pumpTerminal(tester);
    terminalView(tester).terminal.write('halo dunia\r\nbaris dua');
    await tester.pump();
    select(tester, CellOffset(0, 0), CellOffset(4, 0));
    await tester.pump();
    expect(find.text('4 karakter dipilih'), findsOneWidget);
    expect(find.bySemanticsLabel('Gagang awal pilihan'), findsOneWidget);
    expect(find.bySemanticsLabel('Gagang akhir pilihan'), findsOneWidget);
    expect(find.bySemanticsLabel('Tempel dari papan klip'), findsNothing);
  });

  testWidgets('Salin mengisi papan klip, menghapus seleksi, dan menampilkan toast dengan jumlah', (tester) async {
    final clip = mockClipboard(tester);
    await pumpTerminal(tester);
    terminalView(tester).terminal.write('halo dunia\r\nbaris dua');
    await tester.pump();
    select(tester, CellOffset(0, 0), CellOffset(4, 0));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Salin teks terpilih'));
    await tester.pumpAndSettle();
    expect(clip.text, 'halo');
    expect(find.text('Disalin · 4 karakter'), findsOneWidget);
    expect(find.bySemanticsLabel('Salin teks terpilih'), findsNothing);
    expect(terminalView(tester).controller!.selection, isNull);
  });

  testWidgets('Semua memilih sampai baris terakhir yang berisi, tanpa baris kosong di bawahnya', (tester) async {
    final clip = mockClipboard(tester);
    await pumpTerminal(tester);
    terminalView(tester).terminal.write('satu\r\ndua\r\ntiga');
    await tester.pump();
    select(tester, CellOffset(0, 0), CellOffset(1, 0));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Pilih semua teks di terminal'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Salin teks terpilih'));
    await tester.pumpAndSettle();
    expect(clip.text!.trimRight(), 'satu\ndua\ntiga');
    expect(clip.text!.endsWith('\n\n'), isFalse);
  });

  testWidgets('Batal menghapus seleksi dan mengembalikan tombol cepat', (tester) async {
    await pumpTerminal(tester);
    terminalView(tester).terminal.write('halo dunia');
    await tester.pump();
    select(tester, CellOffset(0, 0), CellOffset(4, 0));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Batal'));
    await tester.pump();
    expect(terminalView(tester).controller!.selection, isNull);
    expect(find.bySemanticsLabel('Tempel dari papan klip'), findsOneWidget);
    expect(find.bySemanticsLabel('Gagang awal pilihan'), findsNothing);
  });

  testWidgets('menyeret gagang akhir ke kanan memperluas pilihan; gagang awal ke kanan menyempitkannya', (
    tester,
  ) async {
    await pumpTerminal(tester);
    terminalView(tester).terminal.write('halo dunia');
    await tester.pump();
    select(tester, CellOffset(0, 0), CellOffset(4, 0));
    await tester.pump();
    final controller = terminalView(tester).controller!;
    final cellWidth = tester.getSize(find.byType(TerminalView)).width / terminalView(tester).terminal.viewWidth;

    await tester.drag(find.bySemanticsLabel('Gagang akhir pilihan'), Offset(cellWidth * 3, 0));
    await tester.pump();
    expect(controller.selection!.normalized.end.x, greaterThan(4));
    expect(controller.selection!.normalized.begin.x, 0);

    final endBefore = controller.selection!.normalized.end;
    await tester.drag(find.bySemanticsLabel('Gagang awal pilihan'), Offset(cellWidth * 2, 0));
    await tester.pump();
    expect(controller.selection!.normalized.begin.x, greaterThan(0));
    expect(controller.selection!.normalized.end, endBefore);
  });

  testWidgets('tekan lama memilih satu kata dan memunculkan bilah', (tester) async {
    await pumpTerminal(tester);
    terminalView(tester).terminal.write('halo dunia');
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(TerminalView));
    await tester.longPressAt(origin + const Offset(20, 10));
    await tester.pump();
    expect(find.textContaining('karakter dipilih'), findsOneWidget);
    expect(find.bySemanticsLabel('Gagang awal pilihan'), findsOneWidget);
  });

  testWidgets('landscape ringkas: bilah satu baris, tombol Salin tetap bisa ditekan', (tester) async {
    final clip = mockClipboard(tester);
    await pumpTerminal(tester, size: const Size(853, 393), padding: const EdgeInsets.only(top: 24, bottom: 16));
    terminalView(tester).terminal.write('halo dunia');
    await tester.pump();
    select(tester, CellOffset(0, 0), CellOffset(4, 0));
    await tester.pump();
    expect(find.text('Seret gagang untuk mengubah pilihan'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Salin teks terpilih'));
    await tester.pumpAndSettle();
    expect(clip.text, 'halo');
  });
}
