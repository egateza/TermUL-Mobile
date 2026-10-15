import 'package:flutter/foundation.dart';

import 'host_profile.dart';
import 'json_fields.dart';

/// Snapshot immutable isi `profiles.json` (skema sama dengan `ProfileSnapshot` desktop).
///
/// Aturan yang dipertahankan dari desktop: grup dinormalkan, tidak kosong, unik, terurut; id profil
/// duplikat ditolak; `favorites` dan `recent` membuang id yang tidak ada, duplikat, dan kelebihan
/// ([recentLimit] untuk `recent`).
@immutable
final class ProfileSnapshot {
  factory ProfileSnapshot({
    int version = currentVersion,
    List<String> groups = const [],
    List<HostProfile> profiles = const [],
    List<String> favorites = const [],
    List<String> recent = const [],
  }) {
    final cleanGroups = groups.map(HostProfile.normalizeGroup).where((g) => g.isNotEmpty).toSet().toList()..sort();
    final ids = <String>{};
    for (final p in profiles) {
      if (!ids.add(p.id)) throw ArgumentError('Terdapat id profil duplikat');
    }
    return ProfileSnapshot._(
      version,
      List.unmodifiable(cleanGroups),
      List.unmodifiable(profiles),
      List.unmodifiable(_existingIds(favorites, ids, null)),
      List.unmodifiable(_existingIds(recent, ids, recentLimit)),
    );
  }

  const ProfileSnapshot._(this.version, this.groups, this.profiles, this.favorites, this.recent);

  factory ProfileSnapshot.empty() => ProfileSnapshot();

  factory ProfileSnapshot.fromJson(Map<String, Object?> json) => ProfileSnapshot(
    version: optInt(json, 'version') ?? currentVersion,
    groups: stringList(json, 'groups'),
    profiles: [
      for (final p in optList(json, 'profiles'))
        if (p is Map<String, Object?>) HostProfile.fromJson(p) else throw const FormatException('Profil bukan objek'),
    ],
    favorites: stringList(json, 'favorites'),
    recent: stringList(json, 'recent'),
  );

  static const currentVersion = 1;
  static const recentLimit = 5;

  final int version;

  /// Grup eksplisit (termasuk grup kosong). Gunakan [allGroups] untuk daftar lengkap.
  final List<String> groups;
  final List<HostProfile> profiles;

  /// Id profil favorit, urut sesuai waktu ditambahkan.
  final List<String> favorites;

  /// Id profil yang terakhir dipakai, terbaru di depan.
  final List<String> recent;

  Map<String, Object?> toJson() => {
    'version': version,
    'groups': groups,
    'profiles': [for (final p in profiles) p.toJson()],
    'favorites': favorites,
    'recent': recent,
  };

  HostProfile? find(String id) {
    final key = id.toLowerCase();
    for (final p in profiles) {
      if (p.id == key) return p;
    }
    return null;
  }

  /// Semua grup: eksplisit, grup milik profil, dan semua induknya, terurut.
  List<String> get allGroups {
    final result = <String>{};
    for (final g in groups) {
      _addWithParents(result, g);
    }
    for (final p in profiles) {
      _addWithParents(result, p.group);
    }
    return (result.toList()..sort());
  }

  /// Profil tepat di grup [group] (bukan subgrup), terurut nama tanpa membedakan huruf besar kecil.
  List<HostProfile> profilesIn(String? group) {
    final g = HostProfile.normalizeGroup(group);
    return [
      for (final p in profiles)
        if (p.group == g) p,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  bool isFavorite(String id) => favorites.contains(id.toLowerCase());

  List<HostProfile> get favoriteProfiles => _resolve(favorites);
  List<HostProfile> get recentProfiles => _resolve(recent);

  ProfileSnapshot withProfile(HostProfile profile) {
    final index = profiles.indexWhere((p) => p.id == profile.id);
    final list = [...profiles];
    if (index < 0) {
      list.add(profile);
    } else {
      list[index] = profile;
    }
    return _copy(profiles: list);
  }

  ProfileSnapshot withoutProfile(String id) => _copy(
    profiles: [
      for (final p in profiles)
        if (p.id != id.toLowerCase()) p,
    ],
  );

  ProfileSnapshot withGroups(List<String> newGroups) => _copy(groups: newGroups);

  ProfileSnapshot withFavorite(String id, {required bool favorite}) {
    final key = id.toLowerCase();
    final list = [...favorites]..remove(key);
    if (favorite) list.add(key);
    return _copy(favorites: list);
  }

  /// Menaruh [id] di depan `recent` (tanpa duplikat), lalu memotong ke [recentLimit].
  ProfileSnapshot withUsed(String id) {
    final key = id.toLowerCase();
    return _copy(recent: [key, ...recent.where((r) => r != key)]);
  }

  ProfileSnapshot withoutRecent() => _copy(recent: const []);

  ProfileSnapshot _copy({
    List<String>? groups,
    List<HostProfile>? profiles,
    List<String>? favorites,
    List<String>? recent,
  }) => ProfileSnapshot(
    version: version,
    groups: groups ?? this.groups,
    profiles: profiles ?? this.profiles,
    favorites: favorites ?? this.favorites,
    recent: recent ?? this.recent,
  );

  List<HostProfile> _resolve(List<String> ids) => [for (final id in ids) ?find(id)];

  static List<String> _existingIds(List<String> list, Set<String> ids, int? limit) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in list) {
      final id = HostProfile.normalizeId(raw);
      if (ids.contains(id) && seen.add(id)) out.add(id);
      if (limit != null && out.length >= limit) break;
    }
    return out;
  }

  static void _addWithParents(Set<String> set, String group) {
    var g = group;
    while (g.isNotEmpty) {
      set.add(g);
      final idx = g.lastIndexOf('/');
      g = idx < 0 ? '' : g.substring(0, idx);
    }
  }
}
