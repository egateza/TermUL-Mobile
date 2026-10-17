import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/auth_method.dart';
import '../models/host_profile.dart';
import '../models/profile_snapshot.dart';

/// Yang dilakukan pada profil dari berkas yang id-nya sudah ada di HP.
enum ImportConflictPolicy {
  /// Profil di HP tidak disentuh.
  skip,

  /// Isi profil di HP diganti isi berkas. Rahasia di vault tetap (terkait id).
  update,

  /// Profil berkas masuk sebagai profil baru dengan id baru.
  copy,
}

/// Berkas tidak bisa dibaca sebagai daftar profil sama sekali (bukan JSON, atau bentuknya salah).
class ImportFormatException implements Exception {
  const ImportFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Satu entri profil di berkas yang dilewati karena tidak valid. Entri lain tetap bisa diimpor.
class ImportRejection {
  const ImportRejection({required this.index, required this.reason, this.name});

  /// Urutan entri di berkas, mulai dari 1.
  final int index;
  final String? name;
  final String reason;
}

enum ImportWarningKind {
  /// `jumpHostId` menunjuk profil yang tidak ada di berkas maupun di HP; jump host dikosongkan.
  jumpHostMissing,

  /// Profil memakai kunci dengan path di perangkat asal; path dibuang, kunci perlu diimpor lagi di HP.
  keyPathDropped,
}

class ImportWarning {
  const ImportWarning(this.kind, this.profileName);

  final ImportWarningKind kind;
  final String profileName;
}

/// Isi berkas impor yang sudah dibaca. Belum dibandingkan dengan profil di HP; lihat [plan].
class ProfileImportSource {
  ProfileImportSource._({
    required this.profiles,
    required this.groups,
    required this.favorites,
    required this.recent,
    required this.rejections,
  });

  /// Membaca teks `profiles.json` desktop (objek dengan `profiles`, atau langsung daftar profil).
  /// Entri yang tidak valid masuk [rejections]; sisanya tetap dibaca.
  factory ProfileImportSource.parse(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const ImportFormatException('Berkas bukan JSON yang valid');
    }
    final Object? rawProfiles;
    var groups = <String>[];
    var favorites = <String>[];
    var recent = <String>[];
    if (decoded is List<Object?>) {
      rawProfiles = decoded;
    } else if (decoded is Map<String, Object?>) {
      rawProfiles = decoded['profiles'];
      groups = _strings(decoded['groups']);
      favorites = _ids(decoded['favorites']);
      recent = _ids(decoded['recent']);
    } else {
      throw const ImportFormatException('Berkas bukan daftar profil TermUL');
    }
    if (rawProfiles is! List<Object?>) {
      throw const ImportFormatException('Berkas tidak berisi daftar "profiles"');
    }

    final profiles = <HostProfile>[];
    final rejections = <ImportRejection>[];
    final seen = <String>{};
    for (var i = 0; i < rawProfiles.length; i++) {
      final raw = rawProfiles[i];
      final index = i + 1;
      if (raw is! Map<String, Object?>) {
        rejections.add(ImportRejection(index: index, reason: 'Entri bukan objek'));
        continue;
      }
      final name = raw['name'] is String ? raw['name']! as String : null;
      try {
        final profile = HostProfile.fromJson(raw);
        if (!seen.add(profile.id)) {
          rejections.add(ImportRejection(index: index, name: name, reason: 'Id ganda di dalam berkas'));
          continue;
        }
        profiles.add(profile);
      } on FormatException catch (e) {
        rejections.add(ImportRejection(index: index, name: name, reason: e.message));
      } on ArgumentError catch (e) {
        rejections.add(ImportRejection(index: index, name: name, reason: '${e.message}'));
      }
    }
    return ProfileImportSource._(
      profiles: List.unmodifiable(profiles),
      groups: List.unmodifiable(groups),
      favorites: List.unmodifiable(favorites),
      recent: List.unmodifiable(recent),
      rejections: List.unmodifiable(rejections),
    );
  }

  final List<HostProfile> profiles;
  final List<String> groups;
  final List<String> favorites;
  final List<String> recent;
  final List<ImportRejection> rejections;

  /// Menggabungkan berkas ke [existing] tanpa pernah membuang apa pun dari [existing]. Hasilnya murni
  /// (tidak menulis apa-apa) sehingga aman dipakai untuk pratinjau dan dihitung ulang saat pilihan berubah.
  ProfileImportPlan plan(ProfileSnapshot existing, ImportConflictPolicy policy) {
    // id di berkas -> id akhir di HP, untuk profil yang masuk atau diganti.
    final idMap = <String, String>{};
    final imported = <HostProfile>[];
    var added = 0;
    var updated = 0;
    var copied = 0;
    var skipped = 0;

    for (final p in profiles) {
      if (existing.find(p.id) == null) {
        idMap[p.id] = p.id;
        imported.add(p);
        added++;
        continue;
      }
      switch (policy) {
        case ImportConflictPolicy.skip:
          skipped++;
        case ImportConflictPolicy.update:
          idMap[p.id] = p.id;
          imported.add(p);
          updated++;
        case ImportConflictPolicy.copy:
          final newId = const Uuid().v4();
          idMap[p.id] = newId;
          imported.add(p.withId(newId).withName('${p.name} (salinan)'));
          copied++;
      }
    }

    final warnings = <ImportWarning>[];
    var result = existing;
    for (var p in imported) {
      if (p.authMethod == AuthMethod.key && p.privateKeyPath != null) {
        p = p.withoutPrivateKeyPath();
        warnings.add(ImportWarning(ImportWarningKind.keyPathDropped, p.name));
      }
      final jump = p.jumpHostId;
      if (jump != null) {
        final target = idMap[jump] ?? (existing.find(jump) != null ? jump : null);
        if (target == null) warnings.add(ImportWarning(ImportWarningKind.jumpHostMissing, p.name));
        if (target != jump) p = p.withJumpHostId(target);
      }
      result = result.withProfile(p);
    }

    List<String> mapUsage(List<String> ids) => [
      for (final id in ids)
        if (idMap[id] != null) idMap[id]!,
    ];
    result = ProfileSnapshot(
      version: result.version,
      groups: [...result.groups, ...groups],
      profiles: result.profiles,
      favorites: {...result.favorites, ...mapUsage(favorites)}.toList(),
      recent: {...result.recent, ...mapUsage(recent)}.toList(),
    );

    return ProfileImportPlan._(
      merged: result,
      added: added,
      updated: updated,
      copied: copied,
      skipped: skipped,
      rejections: rejections,
      warnings: warnings,
      importedCount: imported.length,
      agentCount: imported.where((p) => p.authMethod == AuthMethod.agent).length,
    );
  }

  static List<String> _strings(Object? v) => [
    if (v is List<Object?>)
      for (final e in v)
        if (e is String) e,
  ];

  /// Id yang bukan UUID dibuang diam-diam: favorit dan recent hanya petunjuk, bukan data profil.
  static List<String> _ids(Object? v) => [for (final s in _strings(v)) ?_tryNormalize(s)];

  static String? _tryNormalize(String s) {
    try {
      return HostProfile.normalizeId(s);
    } on ArgumentError {
      return null;
    }
  }
}

/// Hasil penggabungan yang belum ditulis. [merged] adalah snapshot lengkap (isi HP + hasil impor).
class ProfileImportPlan {
  const ProfileImportPlan._({
    required this.merged,
    required this.added,
    required this.updated,
    required this.copied,
    required this.skipped,
    required this.rejections,
    required this.warnings,
    required this.importedCount,
    required this.agentCount,
  });

  final ProfileSnapshot merged;
  final int added;
  final int updated;
  final int copied;

  /// Profil berkas yang dilewati karena id-nya sudah ada dan pilihannya [ImportConflictPolicy.skip].
  final int skipped;
  final List<ImportRejection> rejections;
  final List<ImportWarning> warnings;
  final int importedCount;

  /// Profil impor bermetode agen SSH: tersimpan, tetapi harus dilengkapi di HP sebelum bisa tersambung.
  final int agentCount;

  /// Tidak ada yang berubah di HP bila dijalankan.
  bool get isEmpty => importedCount == 0;
}
