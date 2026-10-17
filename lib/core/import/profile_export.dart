import 'dart:convert';

import '../models/auth_method.dart';
import '../models/profile_snapshot.dart';

/// Isi berkas ekspor: teks `profiles.json` (skema desktop), jumlah profil, dan berapa profil `KEY` yang diubah.
class ProfileExport {
  const ProfileExport({required this.text, required this.count, required this.keyConverted});

  final String text;
  final int count;

  /// Profil `KEY` (kunci di vault HP, tanpa path) yang ditulis sebagai `AGENT`.
  final int keyConverted;
}

/// Mengubah [ProfileSnapshot] menjadi berkas `profiles.json` untuk desktop. Tidak ada rahasia di dalamnya (model
/// profil memang tidak membawanya). Desktop menolak seluruh berkas bila ada `KEY` tanpa `privateKeyPath`, jadi profil
/// `KEY` ditulis sebagai `AGENT` (keputusan pemilik 2026-10-17); metode asli di HP tidak berubah.
class ProfileExporter {
  const ProfileExporter();

  static const fileName = 'termul-profiles.json';

  ProfileExport export(ProfileSnapshot snapshot) {
    var converted = 0;
    final profiles = [
      for (final p in snapshot.profiles)
        if (p.authMethod == AuthMethod.key) p.withAuthMethod(AuthMethod.agent).withoutPrivateKeyPath() else p,
    ];
    for (final p in snapshot.profiles) {
      if (p.authMethod == AuthMethod.key) converted++;
    }
    final out = ProfileSnapshot(
      version: snapshot.version,
      groups: snapshot.groups,
      profiles: profiles,
      favorites: snapshot.favorites,
      recent: snapshot.recent,
    );
    const encoder = JsonEncoder.withIndent('  ');
    return ProfileExport(text: encoder.convert(out.toJson()), count: profiles.length, keyConverted: converted);
  }
}
