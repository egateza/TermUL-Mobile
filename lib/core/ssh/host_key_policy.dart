import 'package:dartssh2/dartssh2.dart';

import '../models/known_host.dart';

/// `dartssh2` melaporkan nama algoritma host key yang dinegosiasikan (`rsa-sha2-512`, `rsa-sha2-256`, `ssh-rsa`
/// untuk kunci RSA yang sama), padahal sidik jarinya milik kunci, bukan algoritma tanda tangan. Disimpan dan
/// dibandingkan sebagai satu keluarga kunci supaya perubahan negosiasi tidak dianggap kunci berubah.
String hostKeyFamily(String algorithm) => switch (algorithm) {
  'ssh-rsa' || 'rsa-sha2-256' || 'rsa-sha2-512' => 'ssh-rsa',
  _ => algorithm,
};

/// Urutan preferensi bawaan (sama dengan bawaan `dartssh2` 4.1.0, tanpa `ssh-rsa` SHA-1).
const defaultHostKeyTypes = [
  SSHHostkeyType.ed25519,
  SSHHostkeyType.rsaSha512,
  SSHHostkeyType.rsaSha256,
  SSHHostkeyType.ecdsa521,
  SSHHostkeyType.ecdsa384,
  SSHHostkeyType.ecdsa256,
];

List<SSHHostkeyType> _typesOf(String family) => switch (family) {
  'ssh-ed25519' => [SSHHostkeyType.ed25519],
  'ssh-rsa' => [SSHHostkeyType.rsaSha512, SSHHostkeyType.rsaSha256],
  'ecdsa-sha2-nistp521' => [SSHHostkeyType.ecdsa521],
  'ecdsa-sha2-nistp384' => [SSHHostkeyType.ecdsa384],
  'ecdsa-sha2-nistp256' => [SSHHostkeyType.ecdsa256],
  _ => const [],
};

/// Algoritma host key yang diminta untuk satu server. Host yang sudah dikenal dibatasi ke keluarga kunci yang
/// tersimpan sehingga server tidak bisa menyodorkan tipe lain (yang akan dianggap host key berubah). Host baru
/// memakai bawaan. Bila tidak ada pemetaan untuk tipe tersimpan, kembali ke bawaan (verifikasi tetap menolak
/// kunci yang tidak cocok).
List<SSHHostkeyType> hostKeyAlgorithmsFor(List<KnownHost> stored) {
  if (stored.isEmpty) return defaultHostKeyTypes;
  final result = <SSHHostkeyType>[];
  for (final k in stored) {
    for (final t in _typesOf(hostKeyFamily(k.type))) {
      if (!result.contains(t)) result.add(t);
    }
  }
  return result.isEmpty ? defaultHostKeyTypes : result;
}
