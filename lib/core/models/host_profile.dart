import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'auth_method.dart';
import 'environment_tag.dart';
import 'json_fields.dart';
import 'os_info.dart';

/// Profil koneksi SSH ke satu server. Tidak pernah berisi rahasia: password, passphrase, dan isi kunci
/// disimpan di vault dengan kunci [id]. Skema JSON sama dengan `HostProfile` desktop (TermUL, `profiles.json`).
///
/// Perbedaan dengan desktop:
/// - `authMethod: KEY` tanpa `privateKeyPath` **diizinkan**: di HP isi kunci ada di vault, bukan berkas.
///   Akibatnya desktop (yang mewajibkan path untuk `KEY`) menolak berkas itu; lihat docs/implementation-plan.md 3.2.
/// - `wslDistro` hanya disimpan apa adanya, tidak divalidasi.
@immutable
final class HostProfile {
  factory HostProfile({
    required String id,
    required String name,
    String? group,
    required String host,
    int port = defaultPort,
    required String username,
    AuthMethod? authMethod,
    String? privateKeyPath,
    String? jumpHostId,
    EnvironmentTag? environment,
    String? initialDirectory,
    String? notes,
    bool autoSudo = false,
    OsInfo? os,
    String? terminalTheme,
    String? wslDistro,
  }) {
    final cleanId = normalizeId(id);
    final cleanJump = jumpHostId == null ? null : normalizeId(jumpHostId);
    if (port < 1 || port > 65535) {
      throw ArgumentError('Port harus di antara 1 dan 65535: $port');
    }
    if (cleanId == cleanJump) {
      throw ArgumentError('Jump host tidak boleh profil itu sendiri');
    }
    return HostProfile._(
      id: cleanId,
      name: _requireText(name, 'Nama profil'),
      group: normalizeGroup(group),
      host: _requireText(host, 'Host'),
      port: port,
      username: _requireText(username, 'Username'),
      authMethod: authMethod ?? AuthMethod.agent,
      privateKeyPath: _blankToNull(privateKeyPath),
      jumpHostId: cleanJump,
      environment: environment ?? EnvironmentTag.none,
      initialDirectory: _blankToNull(initialDirectory),
      notes: _blankToNull(notes),
      autoSudo: autoSudo,
      os: os,
      terminalTheme: _blankToNull(terminalTheme),
      wslDistro: _blankToNull(wslDistro),
    );
  }

  const HostProfile._({
    required this.id,
    required this.name,
    required this.group,
    required this.host,
    required this.port,
    required this.username,
    required this.authMethod,
    required this.privateKeyPath,
    required this.jumpHostId,
    required this.environment,
    required this.initialDirectory,
    required this.notes,
    required this.autoSudo,
    required this.os,
    required this.terminalTheme,
    required this.wslDistro,
  });

  /// Profil baru dengan id acak (UUID v4) dan nilai bawaan. Metode awal [AuthMethod.password].
  factory HostProfile.create({required String name, required String host, required String username}) =>
      HostProfile(id: const Uuid().v4(), name: name, host: host, username: username, authMethod: AuthMethod.password);

  factory HostProfile.fromJson(Map<String, Object?> json) {
    final auth = optString(json, 'authMethod');
    final env = optString(json, 'environment');
    final os = optObject(json, 'os');
    return HostProfile(
      id: optString(json, 'id') ?? (throw const FormatException('Profil tanpa id')),
      name: optString(json, 'name') ?? '',
      group: optString(json, 'group'),
      host: optString(json, 'host') ?? '',
      port: optInt(json, 'port') ?? defaultPort,
      username: optString(json, 'username') ?? '',
      authMethod: auth == null ? null : AuthMethod.parse(auth),
      privateKeyPath: optString(json, 'privateKeyPath'),
      jumpHostId: optString(json, 'jumpHostId'),
      environment: env == null ? null : EnvironmentTag.parse(env),
      initialDirectory: optString(json, 'initialDirectory'),
      notes: optString(json, 'notes'),
      autoSudo: optBool(json, 'autoSudo') ?? false,
      os: os == null ? null : OsInfo.fromJson(os),
      terminalTheme: optString(json, 'terminalTheme'),
      wslDistro: optString(json, 'wslDistro'),
    );
  }

  static const defaultPort = 22;
  static final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  /// Identitas stabil profil; juga kunci rahasia di vault. Huruf kecil.
  final String id;
  final String name;

  /// Path grup dipisah `/`, mis. `Production/Backend`; kosong = root.
  final String group;
  final String host;
  final int port;
  final String username;
  final AuthMethod authMethod;
  final String? privateKeyPath;
  final String? jumpHostId;
  final EnvironmentTag environment;
  final String? initialDirectory;
  final String? notes;
  final bool autoSudo;
  final OsInfo? os;
  final String? terminalTheme;
  final String? wslDistro;

  /// Urutan field sama dengan desktop. Semua field ditulis, termasuk yang `null`.
  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'group': group,
        'host': host,
        'port': port,
        'username': username,
        'authMethod': authMethod.wire,
        'privateKeyPath': privateKeyPath,
        'jumpHostId': jumpHostId,
        'environment': environment.wire,
        'initialDirectory': initialDirectory,
        'notes': notes,
        'autoSudo': autoSudo,
        'os': os?.toJson(),
        'terminalTheme': terminalTheme,
        'wslDistro': wslDistro,
      };

  /// Label singkat `user@host[:port]`.
  String get address => port == defaultPort ? '$username@$host' : '$username@$host:$port';

  /// Salinan dengan id baru dan nama "(salinan)".
  HostProfile duplicate() => _with(id: const Uuid().v4(), name: '$name (salinan)');

  HostProfile withGroup(String? newGroup) => _with(group: normalizeGroup(newGroup));
  HostProfile withOs(OsInfo? newOs) => _with(os: () => newOs);
  HostProfile withJumpHostId(String? newJumpHostId) => _with(jumpHostId: () => newJumpHostId);

  HostProfile _with({
    String? id,
    String? name,
    String? group,
    ValueGetter<OsInfo?>? os,
    ValueGetter<String?>? jumpHostId,
  }) =>
      HostProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        group: group ?? this.group,
        host: host,
        port: port,
        username: username,
        authMethod: authMethod,
        privateKeyPath: privateKeyPath,
        jumpHostId: jumpHostId != null ? jumpHostId() : this.jumpHostId,
        environment: environment,
        initialDirectory: initialDirectory,
        notes: notes,
        autoSudo: autoSudo,
        os: os != null ? os() : this.os,
        terminalTheme: terminalTheme,
        wslDistro: wslDistro,
      );

  /// Menormalkan id: harus UUID, hasilnya huruf kecil.
  static String normalizeId(String id) {
    final t = id.trim();
    if (!_uuid.hasMatch(t)) throw ArgumentError('Id profil bukan UUID: $id');
    return t.toLowerCase();
  }

  /// Menormalkan path grup: pemisah `\` menjadi `/`, tiap segmen di-trim, segmen kosong dibuang.
  static String normalizeGroup(String? group) {
    if (group == null || group.trim().isEmpty) return '';
    return group.replaceAll(r'\', '/').split('/').map((p) => p.trim()).where((p) => p.isNotEmpty).join('/');
  }

  static String _requireText(String value, String field) {
    final t = value.trim();
    if (t.isEmpty) throw ArgumentError('$field wajib diisi');
    return t;
  }

  static String? _blankToNull(String? v) {
    final t = v?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  @override
  bool operator ==(Object other) =>
      other is HostProfile &&
      other.id == id &&
      other.name == name &&
      other.group == group &&
      other.host == host &&
      other.port == port &&
      other.username == username &&
      other.authMethod == authMethod &&
      other.privateKeyPath == privateKeyPath &&
      other.jumpHostId == jumpHostId &&
      other.environment == environment &&
      other.initialDirectory == initialDirectory &&
      other.notes == notes &&
      other.autoSudo == autoSudo &&
      other.os == os &&
      other.terminalTheme == terminalTheme &&
      other.wslDistro == wslDistro;

  @override
  int get hashCode => Object.hash(id, name, group, host, port, username, authMethod, privateKeyPath, jumpHostId,
      environment, initialDirectory, notes, autoSudo, os, terminalTheme, wslDistro);
}
