import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

import 'package:termul_mobile/features/terminal/terminal_palette.dart';

import 'package:termul_mobile/features/terminal/selection_overlay.dart';

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

  testWidgets('gagang di kolom pertama dan kolom terakhir menjauh dari tepi layar (zona gestur kembali)', (
    tester,
  ) async {
    await pumpTerminal(tester);
    final view = terminalView(tester);
    view.terminal.write('halo dunia');
    await tester.pump();
    select(tester, CellOffset(0, 0), CellOffset(view.terminal.viewWidth, 0));
    await tester.pump();
    final width = tester.view.physicalSize.width;
    expect(tester.getCenter(find.bySemanticsLabel('Gagang awal pilihan')).dx, greaterThanOrEqualTo(36));
    expect(tester.getCenter(find.bySemanticsLabel('Gagang akhir pilihan')).dx, lessThanOrEqualTo(width - 36));
  });

  testWidgets('seleksi di baris paling bawah: gagang tetap di dalam area terminal dan bisa diseret', (tester) async {
    await pumpTerminal(tester);
    final view = terminalView(tester);
    final rows = view.terminal.viewHeight;
    view.terminal.write(List.generate(rows, (i) => 'baris $i').join('\r\n'));
    await tester.pump();
    final last = view.terminal.buffer.lines.length - 1;
    select(tester, CellOffset(0, last), CellOffset(5, last));
    await tester.pump();
    final area = tester.getRect(find.byType(SelectionHandles));
    final end = find.bySemanticsLabel('Gagang akhir pilihan');
    expect(end, findsOneWidget);
    expect(area.contains(tester.getCenter(end)), isTrue);
    await tester.drag(end, const Offset(40, 0));
    await tester.pump();
    expect(view.controller!.selection!.normalized.end.y, last);
    expect(view.controller!.selection!.normalized.end.x, greaterThan(5));
  });

  testWidgets('kaca pembesar muncul selama gagang diseret dan hilang saat dilepas', (tester) async {
    await pumpTerminal(tester);
    terminalView(tester).terminal.write('halo dunia');
    await tester.pump();
    select(tester, CellOffset(0, 0), CellOffset(4, 0));
    await tester.pump();
    expect(find.byKey(const ValueKey('selection-lens')), findsNothing);
    final gesture = await tester.startGesture(tester.getCenter(find.bySemanticsLabel('Gagang akhir pilihan')));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(find.byKey(const ValueKey('selection-lens')), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(find.byKey(const ValueKey('selection-lens')), findsNothing);
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

  test('warna seleksi tembus pandang supaya teks di bawahnya tetap terlihat', () {
    expect(termulTerminalTheme.selection.a, lessThan(1));
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

  test('warna seleksi tembus pandang supaya teks di bawahnya tetap terlihat', () {
    expect(termulTerminalTheme.selection.a, lessThan(1));
  });
}
