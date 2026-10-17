/// Versi aplikasi yang terpasang (`versionName` dan `versionCode` Android, dari `version` di `pubspec.yaml`).
class AppVersion {
  const AppVersion(this.name, this.build);

  final String name;
  final int build;

  @override
  bool operator ==(Object other) => other is AppVersion && other.name == name && other.build == build;

  @override
  int get hashCode => Object.hash(name, build);

  @override
  String toString() => '$name+$build';
}

/// Nomor versi `X.Y.Z` dari tag rilis (`v0.2.0`, `0.2.0`, atau `v0.2.0+5`). Bagian `+N` opsional dan dibandingkan
/// dengan `versionCode` bila nomor versinya sama.
class ReleaseVersion implements Comparable<ReleaseVersion> {
  const ReleaseVersion(this.parts, {this.build});

  final List<int> parts;
  final int? build;

  static final _pattern = RegExp(r'^[vV]?(\d+(?:\.\d+){0,3})(?:\+(\d+))?$');

  /// Null bila [text] bukan nomor versi (mis. tag `nightly`).
  static ReleaseVersion? tryParse(String text) {
    final m = _pattern.firstMatch(text.trim());
    if (m == null) return null;
    final parts = m.group(1)!.split('.').map(int.parse).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    final build = m.group(2);
    return ReleaseVersion(List.unmodifiable(parts), build: build == null ? null : int.parse(build));
  }

  String get name => parts.join('.');

  @override
  int compareTo(ReleaseVersion other) {
    final n = parts.length > other.parts.length ? parts.length : other.parts.length;
    for (var i = 0; i < n; i++) {
      final a = i < parts.length ? parts[i] : 0;
      final b = i < other.parts.length ? other.parts[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }

  /// Lebih baru dari versi terpasang: nomor versi lebih tinggi, atau sama dengan `+N` di atas `versionCode`.
  bool isNewerThan(AppVersion installed) {
    final current = tryParse(installed.name);
    if (current == null) return true;
    final c = compareTo(current);
    if (c != 0) return c > 0;
    return build != null && build! > installed.build;
  }

  @override
  String toString() => build == null ? name : '$name+$build';
}

/// Satu berkas di rilis GitHub.
class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.url, required this.size});

  final String name;
  final Uri url;
  final int size;
}

/// Rilis terbaru di GitHub yang bisa dipasang: punya tepat satu APK dan berkas checksum `<apk>.sha256`.
class ReleaseInfo {
  const ReleaseInfo({
    required this.tag,
    required this.version,
    required this.notes,
    required this.page,
    required this.apk,
    required this.checksum,
  });

  final String tag;
  final ReleaseVersion version;

  /// Catatan rilis (badan rilis GitHub, Markdown mentah).
  final String notes;

  /// Halaman rilis di GitHub.
  final Uri? page;
  final ReleaseAsset apk;
  final ReleaseAsset checksum;
}

/// Isi rilis tidak sesuai aturan (tag bukan nomor versi, APK tidak ada atau lebih dari satu, checksum tidak ada).
class BadReleaseException implements Exception {
  const BadReleaseException(this.reason);

  final String reason;

  @override
  String toString() => 'BadReleaseException: $reason';
}

/// Membaca jawaban `GET /repos/{owner}/{repo}/releases/latest`. Melempar [BadReleaseException] bila rilisnya tidak
/// bisa dipasang dari aplikasi.
ReleaseInfo parseRelease(Object? json) {
  if (json is! Map<String, Object?>) throw const BadReleaseException('bukan objek');
  final tag = json['tag_name'];
  if (tag is! String) throw const BadReleaseException('tag_name');
  final version = ReleaseVersion.tryParse(tag);
  if (version == null) throw const BadReleaseException('tag bukan nomor versi');
  final assets = <ReleaseAsset>[];
  final rawAssets = json['assets'];
  if (rawAssets is List) {
    for (final a in rawAssets) {
      if (a is! Map<String, Object?>) continue;
      final name = a['name'];
      final url = a['browser_download_url'];
      final size = a['size'];
      if (name is! String || url is! String || size is! int) continue;
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https') continue;
      assets.add(ReleaseAsset(name: name, url: uri, size: size));
    }
  }
  final apks = assets.where((a) => a.name.toLowerCase().endsWith('.apk')).toList();
  if (apks.length != 1) throw BadReleaseException('APK: ${apks.length}');
  final apk = apks.single;
  final checksum = assets.where((a) => a.name == '${apk.name}.sha256').firstOrNull;
  if (checksum == null) throw const BadReleaseException('checksum');
  final body = json['body'];
  final page = json['html_url'];
  return ReleaseInfo(
    tag: tag,
    version: version,
    notes: body is String ? body.trim() : '',
    page: page is String ? Uri.tryParse(page) : null,
    apk: apk,
    checksum: checksum,
  );
}

/// SHA-256 heksadesimal dari isi berkas `.sha256` (`<hex>  <nama>` keluaran `sha256sum`, atau hex saja). Null bila
/// tidak ada 64 digit hex di awal.
String? parseChecksum(String text) {
  final m = RegExp(r'^\s*([0-9a-fA-F]{64})(?:\s|$)').firstMatch(text);
  return m?.group(1)!.toLowerCase();
}
