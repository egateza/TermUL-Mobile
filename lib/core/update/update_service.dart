import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'manifest.dart';
import 'release.dart';
import 'update_keys.dart';

/// Jenis kegagalan pembaruan; layar menerjemahkannya ke kalimat.
enum UpdateFailure {
  /// Tidak ada koneksi, DNS gagal, atau waktu habis.
  network,

  /// Server menjawab selain sukses.
  server,

  /// Rilis terbaru tidak bisa dipasang dari aplikasi (manifest tidak ada, rusak, atau formatnya tidak dikenal).
  badRelease,

  /// Tanda tangan `manifest.json` tidak sah untuk kunci publik di aplikasi.
  signature,

  /// Isi APK yang diunduh tidak sama dengan SHA-256 atau ukuran di manifest.
  checksum,

  /// APK ditandatangani sertifikat lain, nama paketnya lain, atau versinya tidak sama dengan manifest.
  signer,

  /// Berkas tidak bisa ditulis (penyimpanan penuh).
  storage,

  /// Penginstal Android tidak bisa dibuka.
  install,
}

class UpdateException implements Exception {
  const UpdateException(this.failure, [this.detail]);

  final UpdateFailure failure;

  /// Rincian singkat untuk log (tanpa isi berkas).
  final Object? detail;

  @override
  String toString() => 'UpdateException(${failure.name}${detail == null ? '' : ', $detail'})';
}

/// Dibatalkan pengguna selagi mengunduh.
class UpdateCancelled implements Exception {
  const UpdateCancelled();
}

/// Penanda batal untuk unduhan yang sedang berjalan.
class UpdateCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// Sumber rilis dan pengunduh APK.
abstract interface class UpdateService {
  /// Rilis terbaru yang tanda tangannya sah; null bila repo belum punya rilis. Melempar [UpdateException].
  Future<ReleaseInfo?> latest();

  /// Rilis versi [version] (untuk "Yang baru" setelah update); null bila tidak ada. Melempar [UpdateException].
  Future<ReleaseInfo?> release(String version);

  /// Mengunduh APK [release] ke folder sementara dan mencocokkannya dengan SHA-256 dan ukuran di manifest.
  /// Mengembalikan path berkas yang siap diperiksa dan dipasang. Melempar [UpdateException] atau [UpdateCancelled];
  /// berkas setengah jadi selalu dihapus.
  Future<String> download(
    ReleaseInfo release, {
    void Function(int received, int total)? onProgress,
    UpdateCancelToken? cancel,
  });

  /// Menyalin APK [release] yang diunduh di luar aplikasi (DownloadManager) dari [path] ke folder sementara yang sama
  /// dengan [download], sambil mencocokkan SHA-256 dan ukurannya dengan manifest. Berkas sumber tidak dipercaya dan
  /// tidak dipasang langsung. Melempar [UpdateException] (`checksum` atau `storage`) atau [UpdateCancelled].
  Future<String> adopt(ReleaseInfo release, String path, {UpdateCancelToken? cancel});
}

/// Rilis dari GitHub Releases, seperti TermUL desktop (ADR 0003): `releases/latest/download/manifest.json`, lalu
/// `manifest.json.sig` dan APK dari `releases/download/v<versi>/` supaya tidak tercampur bila ada rilis baru di tengah
/// proses. Tanpa API GitHub, jadi tanpa batas 60 permintaan per jam.
class GitHubUpdateService implements UpdateService {
  GitHubUpdateService({
    required this.repo,
    required this.tempDir,
    Uri? webBase,
    String? publicKey,
    HttpClient Function()? clientFactory,
    this.timeout = const Duration(seconds: 20),
    this.maxApkBytes = 300 * 1024 * 1024,
  }) : _webBase = webBase ?? Uri.parse('https://github.com'),
       _publicKey = publicKey ?? updatePublicKey,
       _clientFactory = clientFactory ?? HttpClient.new;

  /// `pemilik/nama`, mis. `egateza/TermUL-Mobile`.
  final String repo;

  /// Folder cache aplikasi.
  final Future<Directory> Function() tempDir;
  final Uri _webBase;
  final String _publicKey;
  final HttpClient Function() _clientFactory;

  /// Batas waktu tersambung dan jeda tanpa data.
  final Duration timeout;

  /// APK lebih besar dari ini ditolak (melindungi penyimpanan dari rilis yang keliru).
  final int maxApkBytes;

  static const _userAgent = 'TermUL-Mobile';

  /// Folder unduhan di dalam cache (`cache/update/`, dibagikan ke penginstal lewat FileProvider).
  static const folderName = 'update';

  /// Nama tetap berkas siap pasang, supaya unduhan lama selalu tertimpa.
  static const apkName = 'termul-update.apk';

  Uri get _releases => Uri.parse('$_webBase/$repo/releases');

  HttpClient _client() => _clientFactory()
    ..connectionTimeout = timeout
    ..idleTimeout = timeout
    ..userAgent = _userAgent;

  @override
  Future<ReleaseInfo?> latest() => _fetch(Uri.parse('$_releases/latest/download/${UpdateManifest.fileName}'));

  @override
  Future<ReleaseInfo?> release(String version) =>
      _fetch(Uri.parse('$_releases/download/v$version/${UpdateManifest.fileName}'));

  Future<ReleaseInfo?> _fetch(Uri manifestUri) async {
    final client = _client();
    try {
      final manifestBytes = await _getBytes(client, manifestUri, limit: 256 * 1024);
      if (manifestBytes == null) return null;
      final UpdateManifest manifest;
      try {
        manifest = UpdateManifest.parse(manifestBytes);
      } on FormatException catch (e) {
        throw UpdateException(UpdateFailure.badRelease, e.message);
      }
      final sigUri = Uri.parse('$_releases/download/v${manifest.version}/${UpdateManifest.signatureName}');
      final sig = await _getBytes(client, sigUri, limit: 4096);
      if (sig == null) throw const UpdateException(UpdateFailure.signature, 'sig tidak ada');
      final valid = verifyManifest(
        manifest: manifestBytes,
        signature: String.fromCharCodes(sig),
        publicKey: _publicKey,
      );
      if (!valid) throw const UpdateException(UpdateFailure.signature);
      return ReleaseInfo.fromManifest(manifest, base: _releases);
    } on UpdateException {
      rethrow;
    } on Object catch (e) {
      throw UpdateException(UpdateFailure.network, e.runtimeType);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<String> download(
    ReleaseInfo release, {
    void Function(int received, int total)? onProgress,
    UpdateCancelToken? cancel,
  }) async {
    _checkSize(release);
    final dir = await _freshFolder();
    final client = _client();
    try {
      final res = await _get(client, release.apk.url);
      if (res.statusCode != HttpStatus.ok) {
        await res.drain<void>();
        throw UpdateException(UpdateFailure.server, res.statusCode);
      }
      return await _writeVerified(dir, res.timeout(timeout), release, onProgress: onProgress, cancel: cancel);
    } on UpdateException {
      rethrow;
    } on UpdateCancelled {
      rethrow;
    } on Object catch (e) {
      throw UpdateException(UpdateFailure.network, e.runtimeType);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<String> adopt(ReleaseInfo release, String path, {UpdateCancelToken? cancel}) async {
    _checkSize(release);
    final dir = await _freshFolder();
    try {
      return await _writeVerified(dir, File(path).openRead(), release, cancel: cancel);
    } on UpdateException {
      rethrow;
    } on UpdateCancelled {
      rethrow;
    } on Object catch (e) {
      throw UpdateException(UpdateFailure.storage, e.runtimeType);
    }
  }

  void _checkSize(ReleaseInfo release) {
    if (release.apk.size > maxApkBytes) throw const UpdateException(UpdateFailure.badRelease, 'terlalu besar');
  }

  /// `cache/update/` dikosongkan: berkas lama selalu diganti.
  Future<Directory> _freshFolder() async {
    try {
      final dir = Directory('${(await tempDir()).path}${Platform.pathSeparator}$folderName');
      if (await dir.exists()) await dir.delete(recursive: true);
      await dir.create(recursive: true);
      return dir;
    } on FileSystemException catch (e) {
      throw UpdateException(UpdateFailure.storage, e.osError?.errorCode);
    }
  }

  /// Menulis [data] ke [dir] sambil menghitung SHA-256; berkas yang ukuran atau SHA-256-nya tidak sama dengan manifest
  /// dihapus. Mengembalikan path berkas siap pasang. Galat aliran [data] diteruskan apa adanya ke pemanggil (yang
  /// memetakannya ke jaringan atau penyimpanan); berkas setengah jadi selalu dihapus.
  Future<String> _writeVerified(
    Directory dir,
    Stream<List<int>> data,
    ReleaseInfo release, {
    void Function(int received, int total)? onProgress,
    UpdateCancelToken? cancel,
  }) async {
    final expectedSize = release.apk.size;
    // Nama unik: unduhan yang baru dibatalkan tidak menghapus berkas unduhan berikutnya.
    final part = File('${dir.path}${Platform.pathSeparator}$apkName.${DateTime.now().microsecondsSinceEpoch}.part');
    IOSink? sink;
    try {
      final digest = _DigestSink();
      final hasher = sha256.startChunkedConversion(digest);
      sink = part.openWrite();
      var received = 0;
      onProgress?.call(0, expectedSize);
      await for (final chunk in data) {
        if (cancel?.isCancelled ?? false) throw const UpdateCancelled();
        received += chunk.length;
        // Lebih besar dari manifest: pasti bukan berkas yang ditandatangani.
        if (received > expectedSize) throw const UpdateException(UpdateFailure.checksum, 'lebih besar');
        hasher.add(chunk);
        sink.add(chunk);
        onProgress?.call(received, expectedSize);
      }
      hasher.close();
      await sink.flush();
      await sink.close();
      sink = null;
      if (cancel?.isCancelled ?? false) throw const UpdateCancelled();
      if (received != expectedSize || digest.value.toString() != release.apk.sha256) {
        throw const UpdateException(UpdateFailure.checksum);
      }
      final ready = await part.rename('${dir.path}${Platform.pathSeparator}$apkName');
      return ready.path;
    } on FileSystemException catch (e) {
      await _discard(sink, part);
      throw UpdateException(UpdateFailure.storage, e.osError?.errorCode);
    } on Object {
      await _discard(sink, part);
      rethrow;
    }
  }

  /// Isi [uri] (paling banyak [limit] byte); null bila 404.
  Future<List<int>?> _getBytes(HttpClient client, Uri uri, {required int limit}) async {
    final res = await _get(client, uri);
    if (res.statusCode == HttpStatus.notFound) {
      await res.drain<void>();
      return null;
    }
    if (res.statusCode != HttpStatus.ok) {
      await res.drain<void>();
      throw UpdateException(UpdateFailure.server, res.statusCode);
    }
    final bytes = <int>[];
    await for (final chunk in res.timeout(timeout)) {
      bytes.addAll(chunk);
      if (bytes.length > limit) throw const UpdateException(UpdateFailure.badRelease, 'jawaban terlalu besar');
    }
    return bytes;
  }

  Future<HttpClientResponse> _get(HttpClient client, Uri uri) async {
    final req = await client.getUrl(uri).timeout(timeout);
    req.headers.set(HttpHeaders.acceptHeader, 'application/octet-stream');
    // Aset rilis dialihkan ke penyimpanan GitHub; HttpClient mengikuti pengalihan GET.
    req.followRedirects = true;
    return req.close().timeout(timeout);
  }

  static Future<void> _discard(IOSink? sink, File part) async {
    try {
      await sink?.close();
    } on Object {
      // Berkas tetap dihapus di bawah.
    }
    try {
      if (await part.exists()) await part.delete();
    } on Object {
      // Folder cache; Android membersihkannya bila perlu.
    }
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? _value;

  Digest get value => _value!;

  @override
  void add(Digest data) => _value = data;

  @override
  void close() {}
}

/// Tanpa jaringan (tes): repo belum punya rilis.
class NoReleaseUpdateService implements UpdateService {
  const NoReleaseUpdateService();

  @override
  Future<ReleaseInfo?> latest() async => null;

  @override
  Future<ReleaseInfo?> release(String version) async => null;

  @override
  Future<String> download(
    ReleaseInfo release, {
    void Function(int received, int total)? onProgress,
    UpdateCancelToken? cancel,
  }) async => throw const UpdateException(UpdateFailure.badRelease);

  @override
  Future<String> adopt(ReleaseInfo release, String path, {UpdateCancelToken? cancel}) async =>
      throw const UpdateException(UpdateFailure.badRelease);
}
