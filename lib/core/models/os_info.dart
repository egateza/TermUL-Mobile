import 'package:flutter/foundation.dart';

import 'json_fields.dart';

/// OS server yang terdeteksi dari `/etc/os-release` (di desktop). Isinya berasal dari server dan tidak
/// tepercaya, jadi divalidasi seperti desktop: id hanya `[a-z0-9._-]`, teks dipotong 80, karakter kontrol dibuang.
@immutable
final class OsInfo {
  factory OsInfo({required String? id, String? versionId, String? prettyName}) {
    final cleanId = id?.trim().toLowerCase();
    if (cleanId == null || !_safeId.hasMatch(cleanId)) {
      throw ArgumentError('ID OS tidak valid');
    }
    return OsInfo._(cleanId, _clean(versionId), _clean(prettyName));
  }

  const OsInfo._(this.id, this.versionId, this.prettyName);

  factory OsInfo.fromJson(Map<String, Object?> json) => OsInfo(
    id: optString(json, 'id'),
    versionId: optString(json, 'versionId'),
    prettyName: optString(json, 'prettyName'),
  );

  static final _safeId = RegExp(r'^[a-z0-9._-]{1,32}$');
  static const _maxText = 80;

  final String id;
  final String? versionId;
  final String? prettyName;

  Map<String, Object?> toJson() => {
    'id': id,
    'versionId': versionId,
    'prettyName': prettyName,
  };

  static String? _clean(String? s) {
    if (s == null) return null;
    final t = String.fromCharCodes(
      s.runes.where((c) => c >= 0x20 && !(c >= 0x7f && c <= 0x9f)),
    ).trim();
    if (t.isEmpty) return null;
    return t.length > _maxText ? t.substring(0, _maxText) : t;
  }

  @override
  bool operator ==(Object other) =>
      other is OsInfo &&
      other.id == id &&
      other.versionId == versionId &&
      other.prettyName == prettyName;

  @override
  int get hashCode => Object.hash(id, versionId, prettyName);
}
