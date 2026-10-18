import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/app_providers.dart';
import 'package:termul_mobile/bootstrap.dart';
import 'package:termul_mobile/core/models/snippet.dart';
import 'package:termul_mobile/core/storage/load_result.dart';
import 'package:termul_mobile/core/storage/snippet_repository.dart';
import 'package:termul_mobile/shared/widgets/termul_button.dart';
import 'package:termul_mobile/shared/widgets/termul_chip.dart';
import 'package:termul_mobile/shared/widgets/termul_nav_bar.dart';

import '../hosts_ui_harness.dart';

const _nginx = Snippet(
  id: 's1',
  title: 'Cek config lalu reload Nginx',
  command: 'sudo nginx -t && sudo systemctl reload nginx',
  categoryId: 'nginx',
  favorite: true,
);
const _status = Snippet(
  id: 's2',
  title: 'Status layanan',
  command: r'systemctl status ${layanan}',
  defaults: {'layanan': 'nginx'},
);
const _risky = Snippet(
  id: 's3',
  title: 'Bersihkan cache Nginx',
  command: 'sudo rm -rf /var/cache/nginx/*',
  categoryId: 'nginx',
);

Future<void> openSnippetTab(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(TermulNavBar), matching: find.text('Snippet')));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Isian perintah di editor (dicari lewat labelnya, bukan urutan kolom).
Finder get commandField => inputByLabel(r'Perintah (boleh beberapa baris; variabel ditulis ${nama})');

Finder inSheet(Finder f) => find.descendant(of: find.byType(BottomSheet), matching: f);

Future<MemorySnippetRepository> openTab(
  WidgetTester tester, {
  List<Snippet> initial = const [],
  Harness? harness,
}) async {
  final repo = MemorySnippetRepository(initial);
  await (harness ?? Harness()).pump(tester, overrides: [snippetRepositoryProvider.overrideWithValue(repo)]);
  await openSnippetTab(tester);
  return repo;
}

void main() {
  group('daftar', () {
    testWidgets('kosong: judul, penjelasan, dan tombol Snippet baru; tanpa kolom cari', (tester) async {
      await openTab(tester);
      expect(find.text('Belum ada snippet'), findsOneWidget);
      expect(find.text('Snippet baru'), findsWidgets);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('kartu: judul, baris pertama, kategori, cakupan, jumlah variabel, tag berbahaya, bintang', (
      tester,
    ) async {
      await openTab(tester, initial: [_nginx, _status, _risky]);
      expect(find.text('Cek config lalu reload Nginx'), findsOneWidget);
      expect(find.text('sudo nginx -t && sudo systemctl reload nginx'), findsOneWidget);
      expect(find.text('1 variabel'), findsOneWidget);
      expect(find.text('berbahaya'), findsOneWidget);
      expect(find.text('Semua host'), findsNWidgets(3));
      expect(find.bySemanticsLabel('Favorit'), findsOneWidget);
    });

    testWidgets('perintah beberapa baris: kartu menampilkan baris pertama dengan tanda lanjut', (tester) async {
      await openTab(
        tester,
        initial: [const Snippet(id: 'a', title: 'Disk', command: 'df -h /\ndu -sh /var/log/*')],
      );
      expect(find.text('df -h / …'), findsOneWidget);
    });

    testWidgets('cakupan menampilkan nama host; host yang sudah dihapus tampil sebagai Semua host', (tester) async {
      final h = Harness();
      await h.seed([host(id1, name: 'db-01')]);
      await openTab(
        tester,
        harness: h,
        initial: [
          const Snippet(id: 'a', title: 'Satu', command: 'ls', hostId: id1),
          const Snippet(id: 'b', title: 'Dua', command: 'ls', hostId: id3),
        ],
      );
      expect(find.text('db-01'), findsOneWidget);
      expect(find.text('Semua host'), findsOneWidget);
    });

    testWidgets('filter Favorit dan kategori, cari, dan keadaan tidak ada yang cocok', (tester) async {
      await openTab(tester, initial: [_nginx, _status, _risky]);
      await tapVisible(tester, find.widgetWithText(FilterChipButton, 'Favorit'));
      expect(find.text('Cek config lalu reload Nginx'), findsOneWidget);
      expect(find.text('Status layanan'), findsNothing);

      await tapVisible(tester, find.widgetWithText(FilterChipButton, 'Nginx'));
      expect(find.text('Bersihkan cache Nginx'), findsOneWidget);
      expect(find.text('Status layanan'), findsNothing);

      await tapVisible(tester, find.widgetWithText(FilterChipButton, 'Semua'));
      await tester.enterText(find.byType(TextField), 'tidak-ada-ini');
      await tester.pumpAndSettle();
      expect(find.textContaining('Tidak ada snippet yang cocok'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'STATUS');
      await tester.pumpAndSettle();
      expect(find.text('Status layanan'), findsOneWidget);
      expect(find.text('Cek config lalu reload Nginx'), findsNothing);
    });

    testWidgets('tombol x di kolom cari mengosongkan pencarian dan semua snippet tampil lagi', (tester) async {
      await openTab(tester, initial: [_nginx, _status, _risky]);
      await tester.enterText(find.byType(TextField), 'tidak-ada-ini');
      await tester.pumpAndSettle();
      expect(find.textContaining('Tidak ada snippet yang cocok'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('field-clear')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tidak ada snippet yang cocok'), findsNothing);
      expect(find.text('Status layanan'), findsOneWidget);
      expect(find.byKey(const ValueKey('field-clear')), findsNothing);
    });

    testWidgets('berkas snippet rusak: banner menyebut nama berkas dan bisa ditutup', (tester) async {
      final repo = MemorySnippetRepository();
      await Harness(
        report: const BootReport(snippets: LoadResult(quarantinedPath: r'C:\data\snippets.json.corrupt-1')),
      ).pump(tester, overrides: [snippetRepositoryProvider.overrideWithValue(repo)]);
      await openSnippetTab(tester);
      expect(find.text('Daftar snippet rusak'), findsOneWidget);
      expect(find.textContaining('snippets.json.corrupt-1'), findsOneWidget);
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.text('Daftar snippet rusak'), findsNothing);
    });
  });

  group('detail', () {
    testWidgets('variabel berisi nilai bawaan; pratinjau mengikuti isian; Salin menaruh perintah di papan klip', (
      tester,
    ) async {
      String? clip;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clip = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await openTab(tester, initial: [_status]);
      await tester.tap(find.text('Status layanan'));
      await tester.pumpAndSettle();
      expect(find.text('systemctl status nginx'), findsOneWidget);

      await tester.enterText(inputByLabel('layanan'), 'sshd');
      await tester.pumpAndSettle();
      expect(find.text('systemctl status sshd'), findsOneWidget);

      await tester.tap(find.text('Salin'));
      await tester.pumpAndSettle();
      expect(clip, 'systemctl status sshd');
      expect(find.text('Disalin · 21 karakter'), findsOneWidget);
      expect(find.text('Salin'), findsNothing);
    });

    testWidgets('variabel kosong: Salin nonaktif dan ada keterangan', (tester) async {
      await openTab(
        tester,
        initial: [const Snippet(id: 'a', title: 'Log', command: r'journalctl -u ${layanan}')],
      );
      await tester.tap(find.text('Log'));
      await tester.pumpAndSettle();
      expect(find.text('Isi semua variabel untuk menempel atau menyalin.'), findsOneWidget);
      await tester.tap(find.text('Salin'));
      await tester.pumpAndSettle();
      expect(find.text('Salin'), findsOneWidget);
    });

    testWidgets('perintah terdeteksi berbahaya: peringatan tampil di detail', (tester) async {
      await openTab(tester, initial: [_risky]);
      await tester.tap(find.text('Bersihkan cache Nginx'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Perintah berbahaya'), findsOneWidget);
    });

    testWidgets('Edit membuka editor berisi data snippet', (tester) async {
      await openTab(tester, initial: [_nginx]);
      await tester.tap(find.text('Cek config lalu reload Nginx'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit snippet'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Cek config lalu reload Nginx'), findsOneWidget);
    });
  });

  group('editor', () {
    testWidgets('Simpan nonaktif sampai judul dan perintah terisi; snippet baru muncul di depan daftar', (
      tester,
    ) async {
      final repo = await openTab(tester, initial: [_nginx]);
      await tester.tap(find.byTooltip('Snippet baru'));
      await tester.pumpAndSettle();
      expect(find.text('Snippet baru'), findsWidgets);

      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(repo.library.snippets, hasLength(1));

      await tester.enterText(inputByLabel('Judul'), 'Pemakaian disk');
      await tester.enterText(commandField, 'df -h /');
      await tester.pumpAndSettle();
      await tapVisible(tester, inSheet(find.widgetWithText(FilterChipButton, 'Docker')));
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(repo.library.snippets, hasLength(2));
      expect(repo.library.snippets.first.title, 'Pemakaian disk');
      expect(repo.library.snippets.first.command, 'df -h /');
      expect(repo.library.snippets.first.categoryId, 'docker');
      expect(repo.library.snippets.first.hostId, isNull);
      expect(find.text('Snippet disimpan'), findsOneWidget);
    });

    testWidgets('edit: mengganti judul menyimpan di tempat; favorit bisa dimatikan', (tester) async {
      final repo = await openTab(tester, initial: [_nginx, _status]);
      await tester.tap(find.text('Cek config lalu reload Nginx'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(inputByLabel('Judul'), 'Reload Nginx');
      await tapVisible(tester, find.text('Tandai favorit'));
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(repo.library.snippets.map((s) => s.id), ['s1', 's2']);
      expect(repo.library.snippets.first.title, 'Reload Nginx');
      expect(repo.library.snippets.first.favorite, isFalse);
    });

    testWidgets('nilai bawaan variabel yang dihapus dari perintah ikut dibuang', (tester) async {
      final repo = await openTab(tester, initial: [_status]);
      await tester.tap(find.text('Status layanan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, r'systemctl status ${layanan}'), 'uptime');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(repo.library.snippets.single.defaults, isEmpty);
    });

    testWidgets('cakupan satu host: memilih dari daftar host lalu tersimpan', (tester) async {
      final h = Harness();
      await h.seed([host(id1, name: 'db-01'), host(id2, name: 'app-01')]);
      final repo = await openTab(tester, harness: h);
      await tester.tap(find.byTooltip('Snippet baru'));
      await tester.pumpAndSettle();
      await tester.enterText(inputByLabel('Judul'), 'Tes');
      await tester.enterText(commandField, 'ls');
      await tapVisible(tester, find.text('Satu host'));
      await tester.tap(find.text('db-01'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(repo.library.snippets.single.hostId, id1);
      expect(find.text('db-01'), findsOneWidget);
    });

    testWidgets('Hapus: konfirmasi dulu; Batal mempertahankan, Hapus menghapus', (tester) async {
      final repo = await openTab(tester, initial: [_nginx]);
      await tester.tap(find.text('Cek config lalu reload Nginx'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(find.text('Hapus'), find.byType(SingleChildScrollView).last, const Offset(0, -200));
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus Cek config lalu reload Nginx?'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(repo.library.snippets, hasLength(1));

      await tester.tap(find.text('Cek config lalu reload Nginx'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(find.text('Hapus'), find.byType(SingleChildScrollView).last, const Offset(0, -200));
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus').last);
      await tester.pumpAndSettle();
      expect(repo.library.snippets, isEmpty);
      expect(find.text('Snippet dihapus'), findsOneWidget);
    });
  });

  group('kategori', () {
    Future<void> openManager(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Kelola snippet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kelola kategori'));
      await tester.pumpAndSettle();
    }

    testWidgets('pengelola menampilkan kategori awal dengan jumlah snippet', (tester) async {
      await openTab(tester, initial: [_nginx, _risky, _status]);
      await openManager(tester);
      for (final n in ['Sistem', 'Nginx', 'Docker', 'Database']) {
        expect(
          find.descendant(of: find.byType(BottomSheet), matching: find.text(n)),
          findsOneWidget,
          reason: n,
        );
      }
      expect(find.text('2 snippet'), findsOneWidget);
      expect(find.text('0 snippet'), findsNWidgets(3));
    });

    testWidgets('tambah kategori: tersimpan, muncul sebagai chip filter, dan dipakai editor', (tester) async {
      final repo = await openTab(tester, initial: [_status]);
      await openManager(tester);
      await tester.tap(find.text('Kategori baru'));
      await tester.pumpAndSettle();
      await tester.enterText(inputByLabel('Nama kategori'), '  Jaringan ');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(repo.library.categories.last.name, 'Jaringan');
      expect(find.text('Kategori disimpan'), findsOneWidget);

      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilterChipButton, 'Jaringan'), findsOneWidget);

      await tester.tap(find.byTooltip('Snippet baru'));
      await tester.pumpAndSettle();
      await tester.enterText(inputByLabel('Judul'), 'Ping');
      await tester.enterText(commandField, 'ping -c 3 host');
      await tapVisible(tester, inSheet(find.widgetWithText(FilterChipButton, 'Jaringan')));
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(repo.library.snippets.first.categoryId, repo.library.categories.last.id);
      await tapVisible(tester, find.widgetWithText(FilterChipButton, 'Jaringan'));
      expect(find.text('Ping'), findsOneWidget);
      expect(find.text('Status layanan'), findsNothing);
    });

    testWidgets('nama kembar (tanpa membedakan huruf), terlalu panjang, atau kosong: Simpan nonaktif', (tester) async {
      final repo = await openTab(tester);
      await openManager(tester);
      await tester.tap(find.text('Kategori baru'));
      await tester.pumpAndSettle();
      await tester.enterText(inputByLabel('Nama kategori'), 'docker');
      await tester.pumpAndSettle();
      expect(find.text('Nama kategori sudah dipakai.'), findsOneWidget);
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(repo.library.categories, hasLength(4));

      await tester.enterText(inputByLabel('Nama kategori'), 'x' * 25);
      await tester.pumpAndSettle();
      expect(find.text('Nama kategori maksimal 24 karakter.'), findsOneWidget);
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(repo.library.categories, hasLength(4));

      await tester.enterText(inputByLabel('Nama kategori'), '   ');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(repo.library.categories, hasLength(4));
    });

    testWidgets('ubah nama: terisi nama lama; snippet tetap di kategorinya dan tag kartu ikut berubah', (tester) async {
      final repo = await openTab(tester, initial: [_nginx]);
      await openManager(tester);
      await tester.tap(find.byTooltip('Ubah Nginx'));
      await tester.pumpAndSettle();
      expect(find.text('Ubah kategori'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Nginx'), findsOneWidget);
      await tester.enterText(inputByLabel('Nama kategori'), 'Web');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(repo.library.categoryOf('nginx')!.name, 'Web');
      expect(repo.library.snippets.single.categoryId, 'nginx');
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TermulTag, 'Web'), findsOneWidget);
      expect(find.widgetWithText(TermulTag, 'Nginx'), findsNothing);
    });

    testWidgets('mengubah ke nama sendiri yang beda huruf besar-kecil diizinkan', (tester) async {
      final repo = await openTab(tester);
      await openManager(tester);
      await tester.tap(find.byTooltip('Ubah Nginx'));
      await tester.pumpAndSettle();
      await tester.enterText(inputByLabel('Nama kategori'), 'NGINX');
      await tester.pumpAndSettle();
      expect(find.text('Nama kategori sudah dipakai.'), findsNothing);
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(repo.library.categoryOf('nginx')!.name, 'NGINX');
    });

    testWidgets('hapus kategori berisi snippet: konfirmasi menyebut jumlah; snippet tetap ada tanpa tag', (
      tester,
    ) async {
      final repo = await openTab(tester, initial: [_nginx, _risky]);
      await openManager(tester);
      await tester.tap(find.byTooltip('Hapus Nginx'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus kategori Nginx?'), findsOneWidget);
      expect(find.textContaining('2 snippet di dalamnya dipindah ke Tanpa kategori'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(repo.library.hasCategory('nginx'), isTrue);

      await tester.tap(find.byTooltip('Hapus Nginx'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      expect(repo.library.hasCategory('nginx'), isFalse);
      expect(repo.library.snippets, hasLength(2));
      expect(repo.library.snippets.every((s) => s.categoryId == null), isTrue);
      expect(find.text('Kategori dihapus'), findsOneWidget);

      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilterChipButton, 'Nginx'), findsNothing);
      expect(find.text('Cek config lalu reload Nginx'), findsOneWidget);
      expect(find.widgetWithText(TermulTag, 'Nginx'), findsNothing);
    });

    testWidgets('hapus kategori kosong: konfirmasi tanpa jumlah', (tester) async {
      final repo = await openTab(tester);
      await openManager(tester);
      await tester.tap(find.byTooltip('Hapus Docker'));
      await tester.pumpAndSettle();
      expect(find.text('Kategori ini dihapus dari perangkat.'), findsOneWidget);
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      expect(repo.library.hasCategory('docker'), isFalse);
    });

    testWidgets('filter kategori yang lalu dihapus kembali ke Semua', (tester) async {
      await openTab(tester, initial: [_nginx, _status]);
      await tapVisible(tester, find.widgetWithText(FilterChipButton, 'Nginx'));
      expect(find.text('Status layanan'), findsNothing);
      await openManager(tester);
      await tester.tap(find.byTooltip('Hapus Nginx'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();
      expect(find.text('Status layanan'), findsOneWidget);
      expect(find.text('Cek config lalu reload Nginx'), findsOneWidget);
    });

    testWidgets('semua kategori dihapus: pengelola menjelaskan; editor hanya menawarkan Tanpa kategori', (
      tester,
    ) async {
      final repo = await openTab(tester);
      await openManager(tester);
      for (final n in ['Sistem', 'Nginx', 'Docker', 'Database']) {
        await tester.tap(find.byTooltip('Hapus $n'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hapus'));
        await tester.pumpAndSettle();
      }
      expect(repo.library.categories, isEmpty);
      expect(find.textContaining('Belum ada kategori'), findsOneWidget);
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Snippet baru'));
      await tester.pumpAndSettle();
      expect(inSheet(find.widgetWithText(FilterChipButton, 'Tanpa kategori')), findsOneWidget);
      await tester.enterText(inputByLabel('Judul'), 'Tes');
      await tester.enterText(commandField, 'ls');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(repo.library.snippets.single.categoryId, isNull);
    });
  });

  group('cincin fokus isian', () {
    void expectRingInside(WidgetTester tester) {
      final ring = tester.getRect(find.byKey(const ValueKey('field-focus-ring')));
      final viewport = tester.getRect(inSheet(find.byType(SingleChildScrollView)).first);
      expect(ring.top, greaterThanOrEqualTo(viewport.top));
      expect(ring.left, greaterThanOrEqualTo(viewport.left));
      expect(ring.right, lessThanOrEqualTo(viewport.right));
    }

    testWidgets('editor: cincin fokus judul tidak terpotong tepi area gulir', (tester) async {
      await openTab(tester);
      await tester.tap(find.byTooltip('Snippet baru'));
      await tester.pumpAndSettle();
      await tester.tap(inputByLabel('Judul'));
      await tester.pumpAndSettle();
      expectRingInside(tester);
    });

    testWidgets('detail: cincin fokus isian variabel tidak terpotong', (tester) async {
      await openTab(tester, initial: [_status]);
      await tester.tap(find.text('Status layanan'));
      await tester.pumpAndSettle();
      await tester.tap(inputByLabel('layanan'));
      await tester.pumpAndSettle();
      expectRingInside(tester);
    });

    testWidgets('editor dengan keyboard terbuka: cincin judul tetap utuh', (tester) async {
      await openTab(tester);
      await tester.tap(find.byTooltip('Snippet baru'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.tap(inputByLabel('Judul'));
      await tester.pumpAndSettle();
      expectRingInside(tester);
    });
  });

  group('kelola kategori dari editor', () {
    Finder manageInEditor() => inSheet(find.byTooltip('Kelola kategori'));

    testWidgets(
      'tambah kategori dari editor: isian tetap, kategori baru langsung terpilih, tersimpan bersama snippet',
      (tester) async {
        final repo = await openTab(tester);
        await tester.tap(find.byTooltip('Snippet baru'));
        await tester.pumpAndSettle();
        await tester.enterText(inputByLabel('Judul'), 'Ping');
        await tester.enterText(commandField, 'ping -c 3 host');
        await tester.pumpAndSettle();

        await tapVisible(tester, manageInEditor());
        expect(find.text('Kategori baru'), findsOneWidget);
        await tester.tap(find.text('Kategori baru'));
        await tester.pumpAndSettle();
        await tester.enterText(inputByLabel('Nama kategori'), 'Jaringan');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Simpan').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Tutup'));
        await tester.pumpAndSettle();

        // Editor masih terbuka dengan isiannya, dan chip baru sudah ada serta terpilih.
        expect(find.text('Snippet baru'), findsWidgets);
        expect(find.widgetWithText(TextField, 'Ping'), findsOneWidget);
        expect(find.widgetWithText(TextField, 'ping -c 3 host'), findsOneWidget);
        final chip = tester.widget<FilterChipButton>(inSheet(find.widgetWithText(FilterChipButton, 'Jaringan')));
        expect(chip.selected, isTrue);

        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();
        final jaringan = repo.library.categories.firstWhere((c) => c.name == 'Jaringan');
        expect(repo.library.snippets.single.categoryId, jaringan.id);
      },
    );

    testWidgets('menghapus kategori terpilih dari editor: kembali ke Tanpa kategori dan disimpan begitu', (
      tester,
    ) async {
      final repo = await openTab(tester);
      await tester.tap(find.byTooltip('Snippet baru'));
      await tester.pumpAndSettle();
      await tester.enterText(inputByLabel('Judul'), 'Tes');
      await tester.enterText(commandField, 'ls');
      await tester.pumpAndSettle();
      // Snippet baru dimulai di kategori pertama (Sistem).
      expect(
        tester.widget<FilterChipButton>(inSheet(find.widgetWithText(FilterChipButton, 'Sistem'))).selected,
        isTrue,
      );

      await tapVisible(tester, manageInEditor());
      await tester.tap(find.byTooltip('Hapus Sistem'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();

      expect(inSheet(find.widgetWithText(FilterChipButton, 'Sistem')), findsNothing);
      final none = tester.widget<FilterChipButton>(inSheet(find.widgetWithText(FilterChipButton, 'Tanpa kategori')));
      expect(none.selected, isTrue);
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(repo.library.snippets.single.categoryId, isNull);
    });

    testWidgets('mengubah nama kategori dari editor langsung tampil di chip', (tester) async {
      await openTab(tester);
      await tester.tap(find.byTooltip('Snippet baru'));
      await tester.pumpAndSettle();
      await tapVisible(tester, manageInEditor());
      await tester.tap(find.byTooltip('Ubah Docker'));
      await tester.pumpAndSettle();
      await tester.enterText(inputByLabel('Nama kategori'), 'Kontainer');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();
      expect(inSheet(find.widgetWithText(FilterChipButton, 'Kontainer')), findsOneWidget);
      expect(inSheet(find.widgetWithText(FilterChipButton, 'Docker')), findsNothing);
    });
  });

  group('perintah berbahaya', () {
    String? clip;

    void mockClipboard(WidgetTester tester) {
      clip = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clip = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    }

    const marked = Snippet(id: 'm', title: 'Restart layanan', command: 'sudo systemctl restart nginx', dangerous: true);
    const plain = Snippet(id: 'p', title: 'Cek disk', command: 'df -h /');

    testWidgets('editor: saklar penanda berbahaya (baris merah dengan kata "berbahaya") tersimpan bersama snippet', (
      tester,
    ) async {
      final repo = await openTab(tester);
      await tester.tap(find.byTooltip('Snippet baru'));
      await tester.pumpAndSettle();
      await tester.enterText(inputByLabel('Judul'), 'Restart');
      await tester.enterText(commandField, 'sudo systemctl restart nginx');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Tandai sebagai perintah berbahaya'));
      expect(find.text('berbahaya'), findsWidgets);
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(repo.library.snippets.single.dangerous, isTrue);
      // Kartu menandainya dengan kata.
      expect(find.widgetWithText(TermulTag, 'berbahaya'), findsOneWidget);
    });

    testWidgets('editor: perintah yang terdeteksi otomatis diberi tahu di keterangan saklar', (tester) async {
      await openTab(tester);
      await tester.tap(find.byTooltip('Snippet baru'));
      await tester.pumpAndSettle();
      await tester.enterText(commandField, 'sudo rm -rf /var/cache/nginx/*');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tandai sebagai perintah berbahaya'));
      await tester.pumpAndSettle();
      expect(find.textContaining('terdeteksi berbahaya'), findsOneWidget);
      await tester.enterText(commandField, 'ls');
      await tester.pumpAndSettle();
      expect(find.textContaining('terdeteksi berbahaya'), findsNothing);
    });

    testWidgets('edit: penanda terisi dan bisa dimatikan', (tester) async {
      final repo = await openTab(tester, initial: [marked]);
      await tester.tap(find.text('Restart layanan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Tandai sebagai perintah berbahaya'));
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(repo.library.snippets.single.dangerous, isFalse);
    });

    testWidgets('Salin snippet berbahaya: peringatan dulu dengan isi perintah; Batal tidak menyalin', (tester) async {
      mockClipboard(tester);
      await openTab(tester, initial: [marked]);
      await tester.tap(find.text('Restart layanan'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Perintah berbahaya.'), findsOneWidget); // banner di detail
      await tester.tap(find.text('Salin'));
      await tester.pumpAndSettle();

      expect(find.text('Perintah berbahaya'), findsOneWidget); // judul peringatan
      expect(find.textContaining('bisa merusak data atau layanan'), findsOneWidget);
      expect(find.text('sudo systemctl restart nginx'), findsWidgets);
      expect(clip, isNull);
      // Pilihan aman (Batal) adalah tombol utama; konfirmasi memakai varian bahaya.
      final cancel = tester.widget<TermulButton>(find.widgetWithText(TermulButton, 'Batal'));
      final confirm = tester.widget<TermulButton>(find.widgetWithText(TermulButton, 'Tetap salin'));
      expect(cancel.variant, TermulButtonVariant.primary);
      expect(confirm.variant, TermulButtonVariant.danger);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(clip, isNull);
      expect(find.text('Salin'), findsOneWidget); // detail masih terbuka
    });

    testWidgets('Tetap salin: menyalin, menutup detail, dan menampilkan toast', (tester) async {
      mockClipboard(tester);
      await openTab(tester, initial: [marked]);
      await tester.tap(find.text('Restart layanan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tetap salin'));
      await tester.pumpAndSettle();
      expect(clip, 'sudo systemctl restart nginx');
      expect(find.text('Salin'), findsNothing);
      expect(find.textContaining('Disalin'), findsOneWidget);
    });

    testWidgets('perintah terdeteksi otomatis (rm -rf) juga diperingatkan walau tidak ditandai', (tester) async {
      mockClipboard(tester);
      await openTab(
        tester,
        initial: [const Snippet(id: 'r', title: 'Bersihkan', command: 'sudo rm -rf /tmp/x')],
      );
      await tester.tap(find.text('Bersihkan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salin'));
      await tester.pumpAndSettle();
      expect(find.text('Perintah berbahaya'), findsOneWidget);
      expect(clip, isNull);
    });

    testWidgets('variabel yang diisi menjadi perintah berbahaya: peringatan muncul setelah diisi', (tester) async {
      mockClipboard(tester);
      await openTab(
        tester,
        initial: [const Snippet(id: 'v', title: 'Hapus', command: r'rm -rf ${path}')],
      );
      await tester.tap(find.text('Hapus').first);
      await tester.pumpAndSettle();
      await tester.enterText(inputByLabel('path'), '/tmp/x');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salin'));
      await tester.pumpAndSettle();
      expect(find.text('Perintah berbahaya'), findsOneWidget);
      expect(find.text('rm -rf /tmp/x'), findsWidgets);
    });

    testWidgets('snippet aman: Salin langsung menyalin tanpa peringatan', (tester) async {
      mockClipboard(tester);
      await openTab(tester, initial: [plain]);
      await tester.tap(find.text('Cek disk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salin'));
      await tester.pumpAndSettle();
      expect(find.text('Perintah berbahaya'), findsNothing);
      expect(clip, 'df -h /');
    });
  });

  group('hapus snippet dari detail dan mode urut', () {
    const a = Snippet(id: 'a', title: 'Satu', command: 'ls a');
    const b = Snippet(id: 'b', title: 'Dua', command: 'ls b');
    const c = Snippet(id: 'c', title: 'Tiga', command: 'ls c');

    testWidgets('detail punya tombol Hapus; konfirmasi menyebut judul; Batal mempertahankan', (tester) async {
      final repo = await openTab(tester, initial: [a, b]);
      await tester.tap(find.text('Satu'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hapus'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus Satu?'), findsOneWidget);
      expect(find.text('Snippet ini dihapus permanen dari perangkat.'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(repo.library.snippets, hasLength(2));
    });

    testWidgets('Hapus di konfirmasi menghapus snippet, menutup detail, dan menampilkan toast', (tester) async {
      final repo = await openTab(tester, initial: [a, b]);
      await tester.tap(find.text('Satu'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hapus'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      expect(repo.library.snippets.map((s) => s.id), ['b']);
      expect(find.text('Satu'), findsNothing);
      expect(find.text('Dua'), findsOneWidget);
      expect(find.text('Snippet dihapus'), findsOneWidget);
      expect(find.byTooltip('Hapus'), findsNothing); // detail sudah tertutup
    });

    testWidgets('mode urut: tiap baris punya tombol Hapus dengan nama snippet; menghapus tidak keluar dari mode', (
      tester,
    ) async {
      final repo = await openTab(tester, initial: [a, b, c]);
      await tester.tap(find.byTooltip('Kelola snippet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Urutkan snippet'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hapus Satu'), findsOneWidget);
      expect(find.byTooltip('Hapus Dua'), findsOneWidget);
      expect(find.byTooltip('Hapus Tiga'), findsOneWidget);

      await tester.tap(find.byTooltip('Hapus Dua'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus Dua?'), findsOneWidget);
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      expect(repo.library.snippets.map((s) => s.id), ['a', 'c']);
      // Masih di mode urut dengan dua snippet.
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));
      await tester.tap(find.byTooltip('Kelola snippet'));
      await tester.pumpAndSettle();
      expect(find.text('Selesai mengurutkan'), findsOneWidget);
    });

    testWidgets('mode urut: menghapus sampai tinggal satu mengakhiri mode', (tester) async {
      final repo = await openTab(tester, initial: [a, b]);
      await tester.tap(find.byTooltip('Kelola snippet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Urutkan snippet'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hapus Satu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      expect(repo.library.snippets.map((s) => s.id), ['b']);
      expect(find.byType(ReorderableDragStartListener), findsNothing);
      expect(find.byTooltip('Urutkan snippet'), findsNothing);
      expect(find.text('Dua'), findsOneWidget);
    });

    testWidgets('menghapus snippet terakhir menampilkan keadaan kosong', (tester) async {
      final repo = await openTab(tester, initial: [a]);
      await tester.tap(find.text('Satu'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hapus'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      expect(repo.library.snippets, isEmpty);
      expect(find.text('Belum ada snippet'), findsOneWidget);
    });
  });
}
