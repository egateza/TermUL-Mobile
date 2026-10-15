import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/models/host_profile.dart';
import 'package:termul_mobile/core/models/profile_snapshot.dart';

String uid(int n) => '${n.toString().padLeft(8, '0')}-0000-4000-8000-000000000000';

HostProfile p(int n, {String? group, String? name}) =>
    HostProfile(id: uid(n), name: name ?? 'host-$n', group: group, host: 'h$n', username: 'u');

void main() {
  test('id profil duplikat ditolak', () {
    expect(() => ProfileSnapshot(profiles: [p(1), p(1)]), throwsArgumentError);
  });

  test('grup eksplisit dinormalkan, unik, terurut, kosong dibuang', () {
    final s = ProfileSnapshot(groups: ['Sewa', ' Production ', 'Sewa', '', 'A\\B']);
    expect(s.groups, ['A/B', 'Production', 'Sewa']);
  });

  test('allGroups = eksplisit + grup milik profil + semua induknya, terurut', () {
    final s = ProfileSnapshot(groups: ['Production'], profiles: [p(1, group: 'Development'), p(2, group: 'Sewa/Lama/Rak1'), p(3)]);
    expect(s.allGroups, ['Development', 'Production', 'Sewa', 'Sewa/Lama', 'Sewa/Lama/Rak1']);
  });

  test('profilesIn: tepat di grup itu, urut nama tanpa membedakan huruf besar kecil', () {
    final s = ProfileSnapshot(profiles: [
      p(1, group: 'G', name: 'beta'), p(2, group: 'G', name: 'Alfa'), p(3, group: 'G/Sub', name: 'x'), p(4, group: 'H', name: 'y'),
    ]);
    expect(s.profilesIn('G').map((e) => e.name), ['Alfa', 'beta']);
    expect(s.profilesIn(' G / Sub ').map((e) => e.name), ['x']);
  });

  test('favorites dan recent membuang id yang tidak ada dan duplikat; recent maksimal 5', () {
    final s = ProfileSnapshot(
      profiles: [for (var i = 1; i <= 8; i++) p(i)],
      favorites: [uid(2), uid(99), uid(2), uid(3)],
      recent: [for (var i = 1; i <= 8; i++) uid(i)],
    );
    expect(s.favorites, [uid(2), uid(3)]);
    expect(s.recent, [for (var i = 1; i <= 5; i++) uid(i)]);
  });

  test('menghapus profil membersihkan favorites dan recent', () {
    final s = ProfileSnapshot(profiles: [p(1), p(2)], favorites: [uid(1)], recent: [uid(1), uid(2)]).withoutProfile(uid(1));
    expect(s.favorites, isEmpty);
    expect(s.recent, [uid(2)]);
  });

  test('withUsed menaruh di depan tanpa duplikat; withFavorite menambah di akhir', () {
    var s = ProfileSnapshot(profiles: [p(1), p(2), p(3)]);
    s = s.withUsed(uid(1)).withUsed(uid(2)).withUsed(uid(1));
    expect(s.recent, [uid(1), uid(2)]);
    s = s.withFavorite(uid(2), favorite: true).withFavorite(uid(1), favorite: true);
    expect(s.favorites, [uid(2), uid(1)]);
    expect(s.withFavorite(uid(2), favorite: false).favorites, [uid(1)]);
  });

  test('withProfile mengganti profil dengan id sama tanpa mengubah urutan, atau menambah di akhir', () {
    final s = ProfileSnapshot(profiles: [p(1), p(2)]);
    final renamed = s.withProfile(p(1, name: 'baru'));
    expect(renamed.profiles.map((e) => e.name), ['baru', 'host-2']);
    expect(s.withProfile(p(3)).profiles.map((e) => e.id), [uid(1), uid(2), uid(3)]);
  });

  test('versi dari berkas dipertahankan', () {
    expect(ProfileSnapshot.fromJson({'version': 7}).version, 7);
    expect(ProfileSnapshot.fromJson({}).version, 1);
  });

  test('profil bukan objek ditolak sebagai FormatException', () {
    expect(() => ProfileSnapshot.fromJson({'profiles': [1]}), throwsFormatException);
  });
}
