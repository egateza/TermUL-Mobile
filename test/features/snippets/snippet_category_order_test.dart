import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/app_providers.dart';
import 'package:termul_mobile/core/models/snippet.dart';
import 'package:termul_mobile/core/storage/snippet_repository.dart';
import 'package:termul_mobile/shared/widgets/termul_nav_bar.dart';
import 'package:termul_mobile/shared/widgets/termul_chip.dart';

import '../hosts_ui_harness.dart';
import 'snippets_screen_test.dart' show inSheet, openTab, tapVisible;

/// Menggeser pegangan baris ke-[index] sejauh [dy] (positif = ke bawah) dengan gerakan bertahap seperti jari.
Future<void> dragHandle(WidgetTester tester, int index, double dy) async {
  final handle = find.byType(ReorderableDragStartListener).at(index);
  final gesture = await tester.startGesture(tester.getCenter(handle));
  await tester.pump(const Duration(milliseconds: 50));
  const steps = 10;
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(0, dy / steps));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Urutan nama kategori di pengelola (teks nama pada baris, bukan pada chip di belakang).
List<String> managerOrder(WidgetTester tester) {
  final rows = find.descendant(of: find.byType(BottomSheet), matching: find.byType(ReorderableDragStartListener));
  final names = ['Sistem', 'Nginx', 'Docker', 'Database', 'Jaringan'];
  final found = <MapEntry<String, double>>[];
  for (final n in names) {
    final f = find.descendant(of: find.byType(BottomSheet), matching: find.text(n));
    if (f.evaluate().isNotEmpty) found.add(MapEntry(n, tester.getTopLeft(f.first).dy));
  }
  expect(rows, findsWidgets);
  found.sort((a, b) => a.value.compareTo(b.value));
  return [for (final e in found) e.key];
}

/// Maju [ms] milidetik dalam langkah 50 ms (seperti frame sungguhan); satu lompatan besar tidak menjalankan
/// animasi lepas ReorderableListView sampai tuntas.
Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Repository yang penulisannya lambat (seperti berkas sungguhan di HP): perubahan baru diumumkan setelah [delay].
class SlowRepo extends MemorySnippetRepository {
  SlowRepo(this.delay, [List<Snippet> snippets = const []]) : super(snippets);

  final Duration delay;
  int moves = 0;
  final failNext = <bool>[];

  @override
  Future<void> moveSnippet(String id, int newIndex) async {
    moves++;
    await Future<void>.delayed(delay);
    if (failNext.isNotEmpty && failNext.removeAt(0)) throw StateError('disk penuh');
    await super.moveSnippet(id, newIndex);
  }

  @override
  Future<void> moveCategory(String id, int newIndex) async {
    moves++;
    await Future<void>.delayed(delay);
    if (failNext.isNotEmpty && failNext.removeAt(0)) throw StateError('disk penuh');
    await super.moveCategory(id, newIndex);
  }
}

Future<void> release(WidgetTester tester, int index, double dy) async {
  final handle = find.byType(ReorderableDragStartListener).at(index);
  final gesture = await tester.startGesture(tester.getCenter(handle));
  await tester.pump(const Duration(milliseconds: 50));
  for (var i = 0; i < 10; i++) {
    await gesture.moveBy(Offset(0, dy / 10));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
}

Future<SlowRepo> openSlowManager(WidgetTester tester, Duration delay) async {
  final repo = SlowRepo(delay);
  await Harness().pump(tester, overrides: [snippetRepositoryProvider.overrideWithValue(repo)]);
  await tester.tap(find.descendant(of: find.byType(TermulNavBar), matching: find.text('Snippet')));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Kelola snippet'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Kelola kategori'));
  await tester.pumpAndSettle();
  return repo;
}

void glitchTests() {
  group('geser kategori terasa langsung (penulisan berkas lambat)', () {
    testWidgets('setelah dilepas urutan baru langsung tampil, tidak kembali ke posisi lama menunggu penulisan', (
      tester,
    ) async {
      final repo = await openSlowManager(tester, const Duration(milliseconds: 600));
      expect(managerOrder(tester), ['Sistem', 'Nginx', 'Docker', 'Database']);

      await release(tester, 3, -400); // Database ke paling atas
      // Animasi lepas selesai (sekitar 250 ms), penulisan (600 ms) belum selesai.
      await pumpFor(tester, 300);
      expect(repo.library.categories.first.name, 'Sistem', reason: 'penulisan memang belum selesai');
      expect(managerOrder(tester), ['Database', 'Sistem', 'Nginx', 'Docker']);

      // Sesudah penulisan selesai, tampilan tetap sama (tidak melompat).
      await pumpFor(tester, 400);
      await tester.pumpAndSettle();
      expect(repo.library.categories.first.name, 'Database');
      expect(managerOrder(tester), ['Database', 'Sistem', 'Nginx', 'Docker']);
    });

    testWidgets('dua geseran berturut-turut sebelum penulisan pertama selesai: hasil akhir konsisten', (tester) async {
      final repo = await openSlowManager(tester, const Duration(milliseconds: 500));
      await release(tester, 3, -400); // Database ke atas
      await pumpFor(tester, 300);
      await release(tester, 3, -400); // sekarang Docker (terakhir) ke atas
      await pumpFor(tester, 300);
      expect(managerOrder(tester), ['Docker', 'Database', 'Sistem', 'Nginx']);
      await pumpFor(tester, 1200); // kedua penulisan selesai (timer palsu tidak ditunggu pumpAndSettle)
      await tester.pumpAndSettle();
      expect([for (final c in repo.library.categories) c.name], ['Docker', 'Database', 'Sistem', 'Nginx']);
      expect(managerOrder(tester), ['Docker', 'Database', 'Sistem', 'Nginx']);
    });

    testWidgets('penulisan gagal: urutan kembali ke yang tersimpan dan ada pemberitahuan', (tester) async {
      final repo = await openSlowManager(tester, const Duration(milliseconds: 300));
      repo.failNext.add(true);
      await release(tester, 3, -400);
      await pumpFor(tester, 250);
      expect(managerOrder(tester), ['Database', 'Sistem', 'Nginx', 'Docker']); // sementara
      await pumpFor(tester, 600); // penulisan gagal setelah 300 ms
      await tester.pumpAndSettle();
      expect(managerOrder(tester), ['Sistem', 'Nginx', 'Docker', 'Database']);
      expect(find.text('Urutan kategori tidak bisa disimpan. Coba lagi.'), findsOneWidget);
    });
  });
}

void main() {
  glitchTests();

  Future<void> openManager(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Kelola snippet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kelola kategori'));
    await tester.pumpAndSettle();
  }

  testWidgets('pengelola menampilkan petunjuk geser dan satu pegangan per kategori', (tester) async {
    await openTab(tester);
    await openManager(tester);
    expect(find.textContaining('geser ikon titik'), findsOneWidget);
    expect(find.byType(ReorderableDragStartListener), findsNWidgets(4));
  });

  testWidgets('tanpa atau satu kategori: tidak ada petunjuk geser', (tester) async {
    await openTab(tester);
    await openManager(tester);
    for (final n in ['Nginx', 'Docker', 'Database']) {
      await tester.tap(find.byTooltip('Hapus $n'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('geser ikon titik'), findsNothing);
  });

  testWidgets('geser kategori pertama ke bawah: urutan di pengelola dan penyimpanan berubah', (tester) async {
    final repo = await openTab(tester);
    await openManager(tester);
    expect(managerOrder(tester), ['Sistem', 'Nginx', 'Docker', 'Database']);

    await dragHandle(tester, 0, 150);

    final saved = [for (final c in repo.library.categories) c.name];
    expect(saved.first, isNot('Sistem'));
    expect(saved.toSet(), {'Sistem', 'Nginx', 'Docker', 'Database'});
    expect(managerOrder(tester), saved);
  });

  testWidgets('geser kategori terakhir ke atas menjadi yang pertama', (tester) async {
    final repo = await openTab(tester);
    await openManager(tester);
    await dragHandle(tester, 3, -400);
    expect(repo.library.categories.first.name, 'Database');
    expect(managerOrder(tester), ['Database', 'Sistem', 'Nginx', 'Docker']);
  });

  testWidgets('urutan baru dipakai chip filter di daftar dan chip kategori di editor', (tester) async {
    await openTab(
      tester,
      initial: [const Snippet(id: 'a', title: 'Satu', command: 'ls')],
    );
    await openManager(tester);
    await dragHandle(tester, 3, -400); // Database ke paling atas
    await tester.tap(find.byTooltip('Tutup'));
    await tester.pumpAndSettle();

    // Chip filter di layar: Semua, Favorit, lalu kategori menurut urutan baru.
    double x(String label) => tester.getTopLeft(find.widgetWithText(FilterChipButton, label)).dx;
    await tester.ensureVisible(find.widgetWithText(FilterChipButton, 'Docker'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilterChipButton, 'Database'), findsOneWidget);
    expect(x('Database') < x('Sistem'), isTrue);
    expect(x('Sistem') < x('Nginx'), isTrue);

    // Editor: snippet baru dimulai di kategori pertama menurut urutan baru.
    await tester.tap(find.byTooltip('Snippet baru'));
    await tester.pumpAndSettle();
    final database = tester.widget<FilterChipButton>(inSheet(find.widgetWithText(FilterChipButton, 'Database')));
    expect(database.selected, isTrue);
    final yDb = tester.getTopLeft(inSheet(find.widgetWithText(FilterChipButton, 'Database'))).dx;
    final ySis = tester.getTopLeft(inSheet(find.widgetWithText(FilterChipButton, 'Sistem'))).dx;
    expect(yDb < ySis, isTrue);
  });

  testWidgets('mengurutkan dari dalam editor: editor tetap terbuka dan chip berubah urutan', (tester) async {
    await openTab(tester);
    await tester.tap(find.byTooltip('Snippet baru'));
    await tester.pumpAndSettle();
    await tester.enterText(inputByLabel('Judul'), 'Tes');
    await tester.pumpAndSettle();
    await tapVisible(tester, inSheet(find.byTooltip('Kelola kategori')));
    await dragHandle(tester, 3, -400);
    await tester.tap(find.byTooltip('Tutup'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Tes'), findsOneWidget);
    final dbX = tester.getTopLeft(inSheet(find.widgetWithText(FilterChipButton, 'Database')));
    final sisX = tester.getTopLeft(inSheet(find.widgetWithText(FilterChipButton, 'Sistem')));
    // Database kini sebelum Sistem: di baris yang sama lebih kiri, atau di baris di atasnya.
    expect(dbX.dy < sisX.dy || (dbX.dy == sisX.dy && dbX.dx < sisX.dx), isTrue);
  });
}
