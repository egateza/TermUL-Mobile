import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'json_fields.dart';

/// Kategori snippet buatan pengguna: bisa ditambah, diubah namanya, dan dihapus. [id] stabil (tidak berubah saat
/// nama diganti) dan itulah yang disimpan di snippet.
@immutable
final class SnippetCategory {
  const SnippetCategory({required this.id, required this.name});

  factory SnippetCategory.create(String name) => SnippetCategory(id: const Uuid().v4(), name: name.trim());

  factory SnippetCategory.fromJson(Map<String, Object?> json) {
    final id = optString(json, 'id');
    final name = optString(json, 'name');
    if (id == null || id.isEmpty) throw const FormatException('Kategori tanpa id');
    if (name == null || name.trim().isEmpty) throw const FormatException('Kategori tanpa nama');
    return SnippetCategory(id: id, name: name.trim());
  }

  /// Kategori awal saat penyimpanan belum pernah memuat daftar kategori. Id tetap supaya `snippets.json` versi 1
  /// (yang menyimpan `sistem`, `nginx`, `docker`, `database`) tetap terbaca. Setelah itu semuanya biasa: bisa diubah
  /// dan dihapus.
  static const defaults = [
    SnippetCategory(id: 'sistem', name: 'Sistem'),
    SnippetCategory(id: 'nginx', name: 'Nginx'),
    SnippetCategory(id: 'docker', name: 'Docker'),
    SnippetCategory(id: 'database', name: 'Database'),
  ];

  /// Batas panjang nama supaya chip dan kartu tetap muat.
  static const maxNameLength = 24;

  final String id;
  final String name;

  Map<String, Object?> toJson() => {'id': id, 'name': name};

  SnippetCategory copyWith({String? name}) => SnippetCategory(id: id, name: name ?? this.name);

  @override
  bool operator ==(Object other) => other is SnippetCategory && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// Perintah tersimpan. [hostId] null berarti berlaku untuk semua host. Perintah boleh beberapa baris dan memuat
/// variabel `${nama}` (huruf kecil dan garis bawah) yang diisi saat dipakai. Bukan rahasia: tidak boleh memuat
/// password atau kunci, jadi disimpan sebagai JSON biasa.
@immutable
final class Snippet {
  const Snippet({
    required this.id,
    required this.title,
    required this.command,
    this.categoryId,
    this.hostId,
    this.favorite = false,
    this.dangerous = false,
    this.defaults = const {},
  });

  factory Snippet.create({
    required String title,
    required String command,
    String? categoryId,
    String? hostId,
    bool favorite = false,
    bool dangerous = false,
    Map<String, String> defaults = const {},
  }) => Snippet(
    id: const Uuid().v4(),
    title: title.trim(),
    command: command,
    categoryId: categoryId,
    hostId: hostId,
    favorite: favorite,
    dangerous: dangerous,
    defaults: defaults,
  );

  factory Snippet.fromJson(Map<String, Object?> json) {
    final id = optString(json, 'id');
    final title = optString(json, 'title');
    final command = optString(json, 'command');
    if (id == null || id.isEmpty) throw const FormatException('Snippet tanpa id');
    if (title == null || title.trim().isEmpty) throw const FormatException('Snippet tanpa judul');
    if (command == null || command.trim().isEmpty) throw const FormatException('Snippet tanpa perintah');
    final defaultsJson = optObject(json, 'defaults') ?? const <String, Object?>{};
    return Snippet(
      id: id,
      title: title,
      command: command,
      categoryId: optString(json, 'category'),
      hostId: optString(json, 'hostId'),
      favorite: optBool(json, 'favorite') ?? false,
      dangerous: optBool(json, 'dangerous') ?? false,
      defaults: {for (final e in defaultsJson.entries) e.key: _defaultValue(e)},
    );
  }

  static String _defaultValue(MapEntry<String, Object?> e) {
    final v = e.value;
    if (v is String) return v;
    throw FormatException('Nilai bawaan "${e.key}" harus teks');
  }

  final String id;
  final String title;
  final String command;

  /// Id kategori; null = tanpa kategori.
  final String? categoryId;
  final String? hostId;
  final bool favorite;

  /// Ditandai pemilik sebagai perintah berbahaya: setiap pemakaian didahului peringatan. Terpisah dari deteksi otomatis
  /// (`rm -rf`, `dd`, dan sejenisnya) yang tetap berlaku walau penanda ini mati.
  final bool dangerous;

  /// Nilai bawaan variabel, mis. `{layanan: nginx}`.
  final Map<String, String> defaults;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'command': command,
    'category': ?categoryId,
    'hostId': ?hostId,
    'favorite': favorite,
    if (dangerous) 'dangerous': true,
    if (defaults.isNotEmpty) 'defaults': defaults,
  };

  Snippet copyWith({
    String? title,
    String? command,
    Object? categoryId = _keep,
    Object? hostId = _keep,
    bool? favorite,
    bool? dangerous,
    Map<String, String>? defaults,
  }) => Snippet(
    id: id,
    title: title ?? this.title,
    command: command ?? this.command,
    categoryId: identical(categoryId, _keep) ? this.categoryId : categoryId as String?,
    hostId: identical(hostId, _keep) ? this.hostId : hostId as String?,
    favorite: favorite ?? this.favorite,
    dangerous: dangerous ?? this.dangerous,
    defaults: defaults ?? this.defaults,
  );

  static const _keep = Object();

  static final _variable = RegExp(r'\$\{([a-z_]+)\}');

  /// Nama variabel di [command] menurut urutan kemunculan, tanpa duplikat.
  static List<String> variablesOf(String command) => [
    ...{for (final m in _variable.allMatches(command)) m.group(1)!},
  ];

  List<String> get variables => variablesOf(command);

  /// Perintah dengan variabel diganti [values]. Variabel yang belum diisi dibiarkan apa adanya (`${nama}`).
  static String fill(String command, Map<String, String> values) => command.replaceAllMapped(
    _variable,
    (m) => values[m.group(1)!]?.isNotEmpty == true ? values[m.group(1)!]! : m[0]!,
  );

  /// Baris pertama untuk kartu daftar; diberi tanda lanjut bila perintahnya beberapa baris.
  String get firstLine {
    final lines = command.split('\n');
    return lines.length > 1 ? '${lines.first} …' : lines.first;
  }

  @override
  bool operator ==(Object other) =>
      other is Snippet &&
      other.id == id &&
      other.title == title &&
      other.command == command &&
      other.categoryId == categoryId &&
      other.hostId == hostId &&
      other.favorite == favorite &&
      other.dangerous == dangerous &&
      mapEquals(other.defaults, defaults);

  @override
  int get hashCode => Object.hash(
    id,
    title,
    command,
    categoryId,
    hostId,
    favorite,
    dangerous,
    Object.hashAll(defaults.entries.map((e) => (e.key, e.value))),
  );
}
