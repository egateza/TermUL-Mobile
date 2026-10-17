import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/import/profile_import.dart';

import 'hosts_ui_harness.dart';

String entry(String id, String name, {String auth = 'AGENT'}) => jsonEncode({
  'id': id,
  'name': name,
  'group': 'Production',
  'host': '192.0.2.50',
  'port': 22,
  'username': 'ega',
  'authMethod': auth,
});

String file(List<String> entries) =>
    '{"version":1,"groups":[],"profiles":[${entries.join(',')}],"favorites":[],"recent":[]}';

void main() {
  testWidgets('impor menggabungkan: profil lama tetap, profil baru masuk, toast menyebut jumlahnya', (tester) async {
    final h = Harness();
    await h.seed([host(id1, name: 'lama-01')]);
    h.profilePicker.next = file([entry(id2, 'baru-01'), entry(id3, 'baru-02')]);
    await h.pump(tester);

    await tester.tap(find.bySemanticsLabel('Impor profil'));
    await tester.pumpAndSettle();
    expect(find.text('2 profil baru ditambahkan'), findsOneWidget);
    expect(find.textContaining('tidak dihapus'), findsOneWidget);
    expect(find.textContaining('2 profil memakai agen SSH'), findsOneWidget);

    await tester.tap(find.text('Impor'));
    await tester.pumpAndSettle();
    expect(h.hosts.snapshot.profiles.map((p) => p.name), containsAll(['lama-01', 'baru-01', 'baru-02']));
    expect(h.hosts.snapshot.profiles, hasLength(3));
    expect(find.text('Diimpor · 2 profil'), findsOneWidget);
  });

  testWidgets('id sama: pilihan Lewati, Perbarui, Salinan mengubah pratinjau', (tester) async {
    final h = Harness();
    await h.seed([host(id1, name: 'lama-01')]);
    h.profilePicker.next = file([entry(id1, 'dari-berkas')]);
    await h.pump(tester);

    await tester.tap(find.bySemanticsLabel('Impor profil'));
    await tester.pumpAndSettle();
    expect(find.text('1 profil dilewati karena sudah ada'), findsOneWidget);
    await tester.tap(find.text('Perbarui'));
    await tester.pumpAndSettle();
    expect(find.text('1 profil diperbarui'), findsOneWidget);
    await tester.tap(find.text('Salinan'));
    await tester.pumpAndSettle();
    expect(find.text('1 profil disimpan sebagai salinan'), findsOneWidget);

    await tester.tap(find.text('Impor'));
    await tester.pumpAndSettle();
    expect(h.hosts.snapshot.profiles, hasLength(2));
    expect(h.hosts.snapshot.find(id1)!.name, 'lama-01');
  });

  testWidgets('Batal tidak mengubah apa pun', (tester) async {
    final h = Harness();
    await h.seed([host(id1, name: 'lama-01')]);
    h.profilePicker.next = file([entry(id2, 'baru-01')]);
    await h.pump(tester);
    await tester.tap(find.bySemanticsLabel('Impor profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(h.hosts.snapshot.profiles, hasLength(1));
  });

  testWidgets('pemilih dibatalkan: tidak ada panel dan tidak ada galat', (tester) async {
    final h = Harness();
    await h.pump(tester);
    await tester.tap(find.bySemanticsLabel('Impor profil'));
    await tester.pumpAndSettle();
    expect(find.text('Impor'), findsNothing);
  });

  testWidgets('berkas bukan JSON: banner galat, daftar tidak berubah', (tester) async {
    final h = Harness();
    h.profilePicker.next = 'bukan json';
    await h.pump(tester);
    await tester.tap(find.bySemanticsLabel('Impor profil'));
    await tester.pumpAndSettle();
    expect(find.text('Berkas bukan JSON yang valid'), findsOneWidget);
    expect(h.hosts.snapshot.profiles, isEmpty);
  });

  testWidgets('berkas tanpa profil valid: banner, tanpa panel', (tester) async {
    final h = Harness();
    h.profilePicker.next = file([]);
    await h.pump(tester);
    await tester.tap(find.bySemanticsLabel('Impor profil'));
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada profil yang bisa diimpor dari berkas ini.'), findsOneWidget);
  });

  testWidgets('pemilih melempar ImportFormatException: pesannya tampil', (tester) async {
    final h = Harness();
    h.profilePicker.error = const ImportFormatException('Berkas terlalu besar untuk daftar profil.');
    await h.pump(tester);
    await tester.tap(find.bySemanticsLabel('Impor profil'));
    await tester.pumpAndSettle();
    expect(find.text('Berkas terlalu besar untuk daftar profil.'), findsOneWidget);
  });

  testWidgets('profil agen hasil impor membuka panel "Perlu dilengkapi" saat diketuk', (tester) async {
    final h = Harness();
    h.profilePicker.next = file([entry(id2, 'baru-01')]);
    await h.pump(tester);
    await tester.tap(find.bySemanticsLabel('Impor profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Impor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('baru-01'));
    await tester.pumpAndSettle();
    expect(find.text('Perlu dilengkapi'), findsOneWidget);
  });
}
