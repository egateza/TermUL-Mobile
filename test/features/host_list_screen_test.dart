import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/bootstrap.dart';
import 'package:termul_mobile/core/models/auth_method.dart';
import 'package:termul_mobile/core/storage/load_result.dart';
import 'package:termul_mobile/core/storage/ui_state_repository.dart';
import 'package:termul_mobile/core/vault/secret_type.dart';
import 'package:termul_mobile/shared/widgets/host_row.dart';
import 'package:termul_mobile/shared/widgets/termul_icon.dart';

import 'hosts_ui_harness.dart';

Future<void> longPress(WidgetTester tester, String hostName) async {
  await tester.longPress(find.widgetWithText(HostRow, hostName));
  await tester.pumpAndSettle();
}

void main() {
  group('keadaan kosong', () {
    testWidgets('menampilkan judul, penjelasan, dan tombol tambah yang membuka form', (tester) async {
      final h = Harness();
      await h.pump(tester);
      expect(find.text('Belum ada host'), findsOneWidget);
      expect(find.text('Tambahkan server pertama Anda untuk menyambung lewat SSH.'), findsOneWidget);
      await tester.tap(find.text('Tambah host'));
      await tester.pumpAndSettle();
      expect(find.text('Host baru'), findsOneWidget);
    });
  });

  group('daftar', () {
    testWidgets('dikelompokkan, terurut, dengan jumlah; host tanpa grup di akhir', (tester) async {
      final h = Harness();
      await h.seed([
        host(id1, name: 'db-01', group: 'Produksi', hostName: '192.0.2.21', user: 'postgres'),
        host(id2, name: 'app-01', group: 'Produksi'),
        host(id3, name: 'lab-01', hostName: '198.51.100.9', user: 'root'),
      ]);
      await h.pump(tester);
      expect(find.text('PRODUKSI'), findsOneWidget);
      expect(find.text('TANPA GRUP'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      final names = tester.widgetList<HostRow>(find.byType(HostRow)).map((r) => r.name).toList();
      expect(names, ['app-01', 'db-01', 'lab-01']);
      expect(find.text('postgres@192.0.2.21'), findsOneWidget);
      expect(find.text('belum diperiksa'), findsNWidgets(3));
    });

    testWidgets('pencarian menyaring menurut nama, user, dan IP; tanpa hasil memberi pesan', (tester) async {
      final h = Harness();
      await h.seed([host(id1, name: 'db-01', hostName: '192.0.2.21', user: 'postgres'), host(id2, name: 'app-01')]);
      await h.pump(tester);
      await tester.enterText(inputByLabel('Cari host'), 'postgres');
      await tester.pump();
      expect(find.byType(HostRow), findsOneWidget);
      await tester.enterText(inputByLabel('Cari host'), '192.0.2.11');
      await tester.pump();
      expect(find.widgetWithText(HostRow, 'app-01'), findsOneWidget);
      await tester.enterText(inputByLabel('Cari host'), 'tidak-ada-ini');
      await tester.pump();
      expect(find.byType(HostRow), findsNothing);
      expect(find.text('Tidak ada host yang cocok. Ubah kata kunci atau filter.'), findsOneWidget);
    });

    testWidgets('filter Favorit hanya menampilkan favorit', (tester) async {
      final h = Harness();
      await h.seed(
        [host(id1, name: 'db-01'), host(id2, name: 'app-01')],
        favorites: [id2],
      );
      await h.pump(tester);
      await tester.tap(find.text('Favorit'));
      await tester.pump();
      expect(find.byType(HostRow), findsOneWidget);
      expect(find.widgetWithText(HostRow, 'app-01'), findsOneWidget);
      await tester.tap(find.text('Semua'));
      await tester.pump();
      expect(find.byType(HostRow), findsNWidgets(2));
    });

    testWidgets('grup bisa diciutkan; pencarian membukanya kembali', (tester) async {
      final h = Harness();
      await h.seed([host(id1, name: 'db-01', group: 'Produksi')]);
      await h.pump(tester);
      await tester.tap(find.text('PRODUKSI'));
      await tester.pump();
      expect(find.byType(HostRow), findsNothing);
      await tester.enterText(inputByLabel('Cari host'), 'db');
      await tester.pump();
      expect(find.byType(HostRow), findsOneWidget);
    });

    testWidgets('lipatan grup disimpan dan dipulihkan saat aplikasi dibuka lagi', (tester) async {
      final h = Harness();
      await h.seed([host(id1, name: 'db-01', group: 'Produksi'), host(id2, name: 'lab-01')]);
      await h.pump(tester);
      await tester.tap(find.text('PRODUKSI'));
      await tester.pump();
      expect(h.uiState.collapsedGroups, {'Produksi'});
      await tester.tap(find.text('TANPA GRUP'));
      await tester.pump();
      expect(h.uiState.collapsedGroups, {'Produksi', ''});
      await tester.tap(find.text('PRODUKSI'));
      await tester.pump();
      expect(h.uiState.collapsedGroups, {''});
      expect(find.widgetWithText(HostRow, 'db-01'), findsOneWidget);
      expect(find.widgetWithText(HostRow, 'lab-01'), findsNothing);
    });

    testWidgets('dibuka dengan grup tersimpan terciut; path grup yang sudah tidak ada dibuang', (tester) async {
      final h = Harness(uiState: MemoryUiStateRepository({'Produksi', 'Lama'}));
      await h.seed([host(id1, name: 'db-01', group: 'Produksi'), host(id2, name: 'lab-01')]);
      await h.pump(tester);
      expect(find.text('PRODUKSI'), findsOneWidget);
      expect(find.widgetWithText(HostRow, 'db-01'), findsNothing);
      expect(find.widgetWithText(HostRow, 'lab-01'), findsOneWidget);
      expect(h.uiState.collapsedGroups, {'Produksi'});
    });

    testWidgets('filter Online tidak ada sampai pengecekan status dibuat', (tester) async {
      final h = Harness();
      await h.seed([host(id1)]);
      await h.pump(tester);
      expect(find.text('Online'), findsNothing);
    });
  });

  group('menyambung', () {
    testWidgets('menekan host siap pakai memanggil onConnect', (tester) async {
      final h = Harness();
      await h.seed([host(id1)]);
      await h.pump(tester);
      await tester.tap(find.widgetWithText(HostRow, 'app-01'));
      await tester.pumpAndSettle();
      expect(h.connected.map((p) => p.id), [id1]);
    });

    testWidgets('profil agen SSH dari desktop: sheet "Perlu dilengkapi", lalu form dengan banner', (tester) async {
      final h = Harness();
      await h.seed([host(id1, auth: AuthMethod.agent)]);
      await h.pump(tester);
      await tester.tap(find.widgetWithText(HostRow, 'app-01'));
      await tester.pumpAndSettle();
      expect(h.connected, isEmpty);
      expect(find.text('Perlu dilengkapi'), findsOneWidget);
      await tester.tap(find.text('Lengkapi'));
      await tester.pumpAndSettle();
      expect(find.text('Ubah host'), findsOneWidget);
      expect(find.text('Perlu dilengkapi'), findsOneWidget); // banner di form
    });
  });

  group('aksi host', () {
    testWidgets('tahan lama membuka aksi; favorit bisa dinyalakan lalu dimatikan', (tester) async {
      final h = Harness();
      await h.seed([host(id1)]);
      await h.pump(tester);
      await longPress(tester, 'app-01');
      expect(find.text('Aksi untuk app-01'), findsOneWidget);
      await tester.tap(find.text('Jadikan favorit'));
      await tester.pumpAndSettle();
      expect(h.hosts.snapshot.isFavorite(id1), isTrue);
      await longPress(tester, 'app-01');
      await tester.tap(find.text('Hapus dari favorit'));
      await tester.pumpAndSettle();
      expect(h.hosts.snapshot.isFavorite(id1), isFalse);
    });

    testWidgets('hapus: konfirmasi menjelaskan akibat; rahasia dan baris terhapus', (tester) async {
      final h = Harness();
      await h.seed([host(id1)]);
      await h.vault.put(id1, SecretType.loginPassword, 'pw-uji');
      await h.pump(tester);
      await longPress(tester, 'app-01');
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus app-01?'), findsOneWidget);
      expect(find.textContaining('sidik jari servernya'), findsOneWidget);
      expect(h.hosts.snapshot.profiles, hasLength(1)); // belum terhapus sebelum dikonfirmasi
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Hapus')));
      await tester.pumpAndSettle();
      expect(h.hosts.snapshot.profiles, isEmpty);
      expect(await h.vault.has(id1, SecretType.loginPassword), isFalse);
      expect(find.text('Belum ada host'), findsOneWidget);
    });

    testWidgets('batal pada konfirmasi tidak menghapus apa pun', (tester) async {
      final h = Harness();
      await h.seed([host(id1)]);
      await h.pump(tester);
      await longPress(tester, 'app-01');
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(h.hosts.snapshot.profiles, hasLength(1));
    });

    testWidgets('gagal menghapus rahasia: host tetap ada dan banner galat tampil', (tester) async {
      final h = Harness();
      await h.seed([host(id1)]);
      await h.vault.put(id1, SecretType.loginPassword, 'pw-uji');
      h.store.failDeletes = true;
      await h.pump(tester);
      await longPress(tester, 'app-01');
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Hapus')));
      await tester.pumpAndSettle();
      expect(h.hosts.snapshot.profiles, hasLength(1));
      expect(find.text('Host belum terhapus. Penyimpanan perangkat bermasalah; coba lagi.'), findsOneWidget);
    });
  });

  group('banner penyimpanan rusak', () {
    testWidgets('profiles.json rusak: banner memuat nama berkas dan bisa ditutup', (tester) async {
      final h = Harness(
        report: const BootReport(hosts: LoadResult(quarantinedPath: r'C:\data\profiles.json.corrupt-123')),
      );
      await h.pump(tester);
      expect(find.text('Daftar host rusak'), findsOneWidget);
      expect(find.textContaining('profiles.json.corrupt-123'), findsOneWidget);
      expect(find.textContaining(r'C:\data'), findsNothing); // path penuh tidak ditampilkan
      await tester.tap(find.text('Tutup'));
      await tester.pump();
      expect(find.text('Daftar host rusak'), findsNothing);
    });

    testWidgets('known_hosts.json rusak: peringatan bahwa semua server dianggap baru', (tester) async {
      final h = Harness(
        report: const BootReport(knownHosts: LoadResult(quarantinedPath: '/data/known_hosts.json.corrupt-9')),
      );
      await h.seed([host(id1)]);
      await h.pump(tester);
      expect(find.text('Sidik jari server hilang'), findsOneWidget);
      expect(find.textContaining('dianggap host baru'), findsOneWidget);
    });
  });

  group('penanda favorit', () {
    Finder star(String hostName) => find.descendant(
      of: find.widgetWithText(HostRow, hostName),
      matching: find.byWidgetPredicate((w) => w is TermulIcon && w.name == TermulIconName.star),
    );

    testWidgets('hanya host favorit yang berbintang, dan bintang ikut hilang saat favorit dicabut', (tester) async {
      final h = Harness();
      await h.seed(
        [host(id1, name: 'app-01'), host(id2, name: 'db-01')],
        favorites: [id1],
      );
      await h.pump(tester);
      expect(star('app-01'), findsOneWidget);
      expect(star('db-01'), findsNothing);
      expect(tester.widget<HostRow>(find.widgetWithText(HostRow, 'app-01')).favorite, isTrue);

      await longPress(tester, 'app-01');
      await tester.tap(find.text('Hapus dari favorit'));
      await tester.pumpAndSettle();
      expect(star('app-01'), findsNothing);

      await longPress(tester, 'db-01');
      await tester.tap(find.text('Jadikan favorit'));
      await tester.pumpAndSettle();
      expect(star('db-01'), findsOneWidget);
    });

    testWidgets('nama panjang tetap terpotong dan bintang tetap terlihat', (tester) async {
      final h = Harness();
      await h.seed(
        [host(id1, name: 'nama-host-yang-sangat-panjang-sekali-untuk-menguji-pemotongan-teks')],
        favorites: [id1],
      );
      await h.pump(tester);
      expect(star('nama-host-yang-sangat-panjang-sekali-untuk-menguji-pemotongan-teks'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
