import 'manifest.dart';

/// Versi aplikasi yang terpasang (`versionName` dan `versionCode` Android). Sejak rilis lewat `tool/release.ps1`,
/// `versionName` = `major.minor.<jumlah commit>` dan `versionCode` = jumlah commit.
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

/// Berkas APK rilis: alamat unduhan dan isi yang diharapkan (dari manifest bertanda tangan).
class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.url, required this.size, required this.sha256});

  final String name;
  final Uri url;
  final int size;

  /// Heksadesimal huruf kecil.
  final String sha256;
}

/// Rilis terbaru yang tanda tangan manifest-nya sudah diverifikasi.
class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.versionCode,
    required this.notes,
    required this.page,
    required this.apk,
  });

  /// Dari manifest bertanda tangan; [base] adalah `https://github.com/<repo>/releases`.
  factory ReleaseInfo.fromManifest(UpdateManifest m, {required Uri base}) => ReleaseInfo(
    version: m.version,
    versionCode: m.versionCode,
    notes: m.notes,
    page: Uri.parse('$base/tag/v${m.version}'),
    apk: ReleaseAsset(
      name: m.apk.name,
      url: Uri.parse('$base/download/v${m.version}/${m.apk.name}'),
      size: m.apk.size,
      sha256: m.apk.sha256,
    ),
  );

  final String version;
  final int versionCode;

  /// Catatan rilis (ikut ditandatangani).
  final String notes;

  /// Halaman rilis di GitHub.
  final Uri page;
  final ReleaseAsset apk;

  String get tag => 'v$version';

  /// Lebih baru dari versi terpasang. Seperti desktop, tidak pernah menawarkan downgrade.
  bool isNewerThan(AppVersion installed) => versionCode > installed.build;
}
