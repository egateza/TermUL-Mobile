import 'package:flutter/foundation.dart';

import 'json_fields.dart';

/// Satu sidik jari host key yang dipercaya. `dartssh2` hanya memberi tipe dan sidik jari `SHA256:...`
/// (bukan blob kunci), jadi berkas `known_hosts.json` tidak kompatibel dengan format OpenSSH.
@immutable
final class KnownHost {
  factory KnownHost({
    required String host,
    required int port,
    required String type,
    required String fingerprint,
    DateTime? addedAt,
  }) {
    final h = host.trim().toLowerCase();
    if (h.isEmpty) throw ArgumentError('Host wajib diisi');
    if (port < 1 || port > 65535) {
      throw ArgumentError('Port harus di antara 1 dan 65535: $port');
    }
    final t = type.trim();
    if (t.isEmpty) throw ArgumentError('Tipe host key wajib diisi');
    final fp = fingerprint.trim();
    if (!_fingerprint.hasMatch(fp)) {
      throw ArgumentError('Sidik jari harus berformat SHA256:...');
    }
    return KnownHost._(h, port, t, fp, addedAt?.toUtc());
  }

  const KnownHost._(
    this.host,
    this.port,
    this.type,
    this.fingerprint,
    this.addedAt,
  );

  factory KnownHost.fromJson(Map<String, Object?> json) {
    final added = optString(json, 'addedAt');
    return KnownHost(
      host: optString(json, 'host') ?? '',
      port: optInt(json, 'port') ?? 0,
      type: optString(json, 'type') ?? '',
      fingerprint: optString(json, 'fingerprint') ?? '',
      addedAt: added == null ? null : DateTime.parse(added),
    );
  }

  static final _fingerprint = RegExp(r'^SHA256:[A-Za-z0-9+/]+={0,2}$');

  /// Huruf kecil.
  final String host;
  final int port;

  /// Mis. `ssh-ed25519`.
  final String type;

  /// `SHA256:<base64>`, sama dengan keluaran `ssh-keygen -lf`.
  final String fingerprint;
  final DateTime? addedAt;

  /// Kunci pencarian `host:port`.
  String get id => idFor(host, port);

  static String idFor(String host, int port) =>
      '${host.trim().toLowerCase()}:$port';

  Map<String, Object?> toJson() => {
    'host': host,
    'port': port,
    'type': type,
    'fingerprint': fingerprint,
    'addedAt': addedAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is KnownHost &&
      other.host == host &&
      other.port == port &&
      other.type == type &&
      other.fingerprint == fingerprint &&
      other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(host, port, type, fingerprint, addedAt);
}

/// Hasil membandingkan host key yang disodorkan server dengan yang tersimpan.
enum HostKeyVerdict {
  /// Belum ada entri untuk `host:port`: tampilkan dialog host baru.
  newHost,

  /// Tipe dan sidik jari sama dengan entri tersimpan: lanjut.
  trusted,

  /// Ada entri tersimpan tetapi tidak cocok: blokir dengan peringatan "host key berubah".
  changed,
}

/// Aturan keputusan host key (docs/implementation-plan.md 3.2). Fungsi murni tanpa I/O.
///
/// Tipe asing pada host yang sudah dikenal juga dianggap [HostKeyVerdict.changed] (konservatif); dengan
/// pembatasan algoritma host key ke tipe tersimpan, kasus itu seharusnya tidak muncul.
HostKeyVerdict evaluateHostKey(
  List<KnownHost> stored, {
  required String type,
  required String fingerprint,
}) {
  if (stored.isEmpty) return HostKeyVerdict.newHost;
  for (final k in stored) {
    if (k.type == type && k.fingerprint == fingerprint) {
      return HostKeyVerdict.trusted;
    }
  }
  return HostKeyVerdict.changed;
}
