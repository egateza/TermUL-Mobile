import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/app_providers.dart';
import 'package:termul_mobile/core/models/snippet.dart';
import 'package:termul_mobile/shared/widgets/termul_chip.dart';
import 'package:termul_mobile/shared/widgets/termul_nav_bar.dart';

import '../hosts_ui_harness.dart';
import 'snippet_category_order_test.dart' show SlowRepo, pumpFor, release;
import 'snippets_screen_test.dart' show openTab;

const _a = Snippet(id: 'a', title: 'Satu', command: 'ls a');
const _b = Snippet(id: 'b', title: 'Dua', command: 'ls b', favorite: true);
const _c = Snippet(id: 'c', title: 'Tiga', command: 'ls c');

/// Judul snippet menurut urutan vertikalnya di layar.
List<String> titlesTopToBottom(WidgetTester tester, List<String> titles) {
  final found = <MapEntry<String, double>>[];
  for (final t in titles) {
    final f = find.text(t);
    if (f.evaluate().isNotEmpty) found.add(MapEntry(t, tester.getTopLeft(f.first).dy));
  }
  found.sort((x, y) => x.value.compareTo(y.value));
  return [for (final e in found) e.key];
}

Future<void> enterSort(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Urutkan snippet'));
  await tester.pumpAndSettle();
}

Future<SlowRepo> openSlowSort(WidgetTester tester, Duration delay) async {
  final repo = SlowRepo(delay, [_a, _b, _c]);
  await Harness().pump(tester, overrides: [snippetRepositoryProvider.overrideWithValue(repo)]);
  await tester.tap(find.descendant(of: find.byType(TermulNavBar), matching: find.text('Snippet')));
  await tester.pumpAndSettle();
  await enterSort(tester);
  return repo;
}

void main() {
  const names = ['Satu', 'Dua', 'Tiga'];

  group('tombol urutkan', () {
    testWidgets('tidak ada bila snippet kurang dari dua', (tester) async {
      await openTab(tester);
      expect(find.byTooltip('Urutkan snippet'), findsNothing);
    });

    testWidgets('satu snippet: tidak ada tombol', (tester) async {
      await openTab(tester, initial: [_a]);
      expect(find.byTooltip('Urutkan snippet'), findsNothing);
    });

    testWidgets('dua snippet atau lebih: ada tombol', (tester) async {
      await openTab(tester, initial: [_a, _b]);
      expect(find.byTooltip('Urutkan snippet'), findsOneWidget);
    });
  });

  group('mode mengurutkan', () {
    testWidgets('menyembunyikan pencarian dan filter, menampilkan petunjuk dan satu pegangan per snippet', (
      tester,
    ) async {
      await openTab(tester, initial: [_a, _b, _c]);
      expect(find.byType(TextField), findsOneWidget);
      await enterSort(tester);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(FilterChipButton), findsNothing);
      expect(find.textContaining('geser ikon titik'), findsOneWidget);
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(3));
      expect(find.byTooltip('Selesai mengurutkan'), findsOneWidget);
      expect(titlesTopToBottom(tester, names), ['Satu', 'Dua', 'Tiga']);
    });

    testWidgets('semua snippet tampil walau ada filter; filter dan pencarian kembali seperti semula setelah selesai', (
      tester,
    ) async {
      await openTab(tester, initial: [_a, _b, _c]);
      await tester.tap(find.widgetWithText(FilterChipButton, 'Favorit'));
      await tester.pumpAndSettle();
      expect(find.text('Satu'), findsNothing); // difilter

      await enterSort(tester);
      expect(titlesTopToBottom(tester, names), ['Satu', 'Dua', 'Tiga']); // semua tampil

      await tester.tap(find.byTooltip('Selesai mengurutkan'));
      await tester.pumpAndSettle();
      expect(find.byType(FilterChipButton), findsWidgets);
      expect(tester.widget<FilterChipButton>(find.widgetWithText(FilterChipButton, 'Favorit')).selected, isTrue);
      expect(find.text('Satu'), findsNothing); // filter Favorit masih berlaku
      expect(find.text('Dua'), findsOneWidget);
    });

    testWidgets('menggeser mengubah urutan di penyimpanan dan di daftar sesudah selesai', (tester) async {
      final repo = await openTab(tester, initial: [_a, _b, _c]);
      await enterSort(tester);
      await release(tester, 2, -400); // Tiga ke paling atas
      await pumpFor(tester, 400);
      expect([for (final s in repo.library.snippets) s.title], ['Tiga', 'Satu', 'Dua']);
      expect(titlesTopToBottom(tester, names), ['Tiga', 'Satu', 'Dua']);

      await tester.tap(find.byTooltip('Selesai mengurutkan'));
      await tester.pumpAndSettle();
      expect(titlesTopToBottom(tester, names), ['Tiga', 'Satu', 'Dua']);
    });

    testWidgets('tinggal satu snippet (yang lain dihapus): mode berakhir sendiri', (tester) async {
      final repo = await openTab(tester, initial: [_a, _b]);
      await enterSort(tester);
      await repo.delete('a');
      await tester.pumpAndSettle();
      expect(find.byType(ReorderableDragStartListener), findsNothing);
      expect(find.byTooltip('Urutkan snippet'), findsNothing);
      expect(find.text('Dua'), findsOneWidget);
    });
  });

  group('terasa langsung (penulisan berkas lambat)', () {
    testWidgets('urutan baru tampil sejak dilepas, jauh sebelum penulisan selesai, tanpa melompat', (tester) async {
      final repo = await openSlowSort(tester, const Duration(milliseconds: 600));
      await release(tester, 2, -400);
      await pumpFor(tester, 300);
      expect([for (final s in repo.library.snippets) s.title], ['Satu', 'Dua', 'Tiga'], reason: 'belum tertulis');
      expect(titlesTopToBottom(tester, names), ['Tiga', 'Satu', 'Dua']);
      final before = tester.getTopLeft(find.text('Tiga')).dy;

      await pumpFor(tester, 500);
      await tester.pumpAndSettle();
      expect([for (final s in repo.library.snippets) s.title], ['Tiga', 'Satu', 'Dua']);
      expect(titlesTopToBottom(tester, names), ['Tiga', 'Satu', 'Dua']);
      expect(tester.getTopLeft(find.text('Tiga')).dy, before, reason: 'tidak bergeser saat penulisan selesai');
    });

    testWidgets('penulisan gagal: kembali ke urutan tersimpan dan ada pemberitahuan', (tester) async {
      final repo = await openSlowSort(tester, const Duration(milliseconds: 300));
      repo.failNext.add(true);
      await release(tester, 2, -400);
      await pumpFor(tester, 250);
      expect(titlesTopToBottom(tester, names), ['Tiga', 'Satu', 'Dua']);
      await pumpFor(tester, 600);
      await tester.pumpAndSettle();
      expect(titlesTopToBottom(tester, names), ['Satu', 'Dua', 'Tiga']);
      expect(find.text('Urutan snippet tidak bisa disimpan. Coba lagi.'), findsOneWidget);
    });
  });
}
