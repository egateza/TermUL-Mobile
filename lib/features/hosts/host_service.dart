import '../../core/import/profile_import.dart';
import '../../core/models/auth_method.dart';
import '../../core/models/host_profile.dart';
import '../../core/storage/host_repository.dart';
import '../../core/storage/known_hosts_repository.dart';
import '../../core/vault/credential_vault.dart';
import '../../core/vault/secret_type.dart';

/// Rahasia yang diisi pengguna di form. `null` berarti tidak diubah (rahasia lama tetap dipakai).
/// Nilai tidak pernah dicatat atau dimasukkan ke pesan galat.
class HostSecretsInput {
  const HostSecretsInput({this.password, this.privateKeyPem, this.passphrase});

  final String? password;
  final String? privateKeyPem;
  final String? passphrase;

  bool get isEmpty => password == null && privateKeyPem == null && passphrase == null;
}

/// Operasi tingkat host yang melibatkan beberapa penyimpanan sekaligus (daftar host, sidik jari, vault), dengan
/// urutan yang menjaga kegagalan di tengah tetap aman (docs/implementation-plan.md 3.4).
class HostService {
  HostService({required this.hosts, required this.knownHosts, required this.vault});

  final HostRepository hosts;
  final KnownHostsRepository knownHosts;
  final CredentialVault vault;

  /// Menyimpan host baru atau perubahan. Urutan: (1) rahasia baru ke vault, (2) baris host, (3) membuang rahasia
  /// yang tidak lagi relevan untuk metode login, (4) sidik jari milik alamat lama bila alamat berubah.
  ///
  /// Gagal di (2) pada host baru: rahasia yang baru ditulis dibuang kembali. Pada ubahan, rahasia lama sudah
  /// tertimpa (baris host tidak memuat rahasia, jadi tetap konsisten).
  Future<void> saveHost(HostProfile profile, {HostSecretsInput secrets = const HostSecretsInput()}) async {
    final previous = hosts.snapshot.find(profile.id);
    final written = <SecretType>[];
    try {
      if (secrets.password != null) {
        await vault.put(profile.id, SecretType.loginPassword, secrets.password!);
        written.add(SecretType.loginPassword);
      }
      if (secrets.privateKeyPem != null) {
        await vault.put(profile.id, SecretType.privateKeyPem, secrets.privateKeyPem!);
        written.add(SecretType.privateKeyPem);
        // Kunci baru tanpa passphrase: passphrase lama tidak berlaku lagi.
        if (secrets.passphrase == null) await vault.remove(profile.id, SecretType.keyPassphrase);
      }
      if (secrets.passphrase != null) {
        await vault.put(profile.id, SecretType.keyPassphrase, secrets.passphrase!);
        written.add(SecretType.keyPassphrase);
      }
      await hosts.save(profile);
    } on Object {
      if (previous == null) {
        for (final t in written) {
          try {
            await vault.remove(profile.id, t);
          } on Object {
            // Sisa rahasia yatim dibersihkan saat aplikasi mulai.
          }
        }
      }
      rethrow;
    }

    switch (profile.authMethod) {
      case AuthMethod.password:
        await _removeQuietly(profile.id, SecretType.privateKeyPem);
        await _removeQuietly(profile.id, SecretType.keyPassphrase);
      case AuthMethod.key:
        await _removeQuietly(profile.id, SecretType.loginPassword);
      case AuthMethod.agent:
        break;
    }

    if (previous != null &&
        (previous.host.toLowerCase() != profile.host.toLowerCase() || previous.port != profile.port)) {
      await _removeKnownHostIfUnused(previous.host, previous.port);
    }
  }

  /// Menghapus host. Urutan: (1) semua rahasia, (2) baris host, (3) sidik jari `host:port` bila tidak ada
  /// profil lain yang memakainya. Gagal di (1) membatalkan semuanya (host tetap ada, bisa dicoba lagi). Gagal
  /// sesudahnya meninggalkan keadaan aman: baris tanpa rahasia ("Rahasia hilang") atau sidik jari yatim.
  Future<void> deleteHost(String id) async {
    final profile = hosts.snapshot.find(id);
    if (profile == null) return;
    await vault.removeProfile(profile.id);
    await hosts.delete(profile.id);
    await _removeKnownHostIfUnused(profile.host, profile.port);
  }

  /// Menggabungkan hasil baca berkas impor ke daftar host. Tidak ada profil yang dibuang; penggabungan dihitung
  /// dari keadaan terkini dan ditulis sekali (atomik). Tidak menyentuh vault: profil impor tidak membawa rahasia,
  /// dan rahasia profil yang diperbarui tetap terkait id-nya. Mengembalikan rencana yang benar-benar ditulis.
  Future<ProfileImportPlan> importProfiles(ProfileImportSource source, ImportConflictPolicy policy) async {
    late ProfileImportPlan applied;
    await hosts.update((current) {
      applied = source.plan(current, policy);
      return applied.isEmpty ? current : applied.merged;
    });
    return applied;
  }

  /// Perawatan saat aplikasi mulai: membuang rahasia yatim. Dilewati bila `profiles.json` dikarantina pada start
  /// ini (semua rahasia akan tampak yatim padahal berkas rusak mungkin bisa dipulihkan). Mengembalikan jumlah
  /// yang dibuang; kegagalan tidak boleh menghentikan aplikasi.
  Future<int> runStartupMaintenance({required bool profilesWereQuarantined}) async {
    if (profilesWereQuarantined) return 0;
    try {
      return await vault.sweepOrphans(liveProfileIds: {for (final p in hosts.snapshot.profiles) p.id});
    } on Object {
      return 0;
    }
  }

  Future<void> _removeQuietly(String id, SecretType type) async {
    try {
      await vault.remove(id, type);
    } on Object {
      // Rahasia usang yang tersisa tidak dipakai dan dibersihkan saat host dihapus.
    }
  }

  Future<void> _removeKnownHostIfUnused(String host, int port) async {
    final h = host.toLowerCase();
    final stillUsed = hosts.snapshot.profiles.any((p) => p.host.toLowerCase() == h && p.port == port);
    if (!stillUsed) await knownHosts.removeFor(host, port);
  }
}
