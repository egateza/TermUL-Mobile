import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'release.dart';

/// Jenis kegagalan pembaruan; layar menerjemahkannya ke kalimat.
enum UpdateFailure {
  /// Tidak ada koneksi, DNS gagal, atau waktu habis.
  network,

  /// Server menjawab selain sukses (mis. batas permintaan GitHub).
  server,

  /// Rilis terbaru tidak bisa dipasang dari aplikasi (tanpa APK atau checksum, tag bukan nomor versi).
  badRelease,

  /// Isi APK yang diunduh tidak sama dengan checksum rilis.
  checksum,

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
  /// Rilis terbaru; null bila repo belum punya rilis. Melempar [UpdateException].
  Future<ReleaseInfo?> latest();

  /// Mengunduh APK [release] ke folder sementara dan mencocokkannya dengan checksum rilis. Mengembalikan path berkas
  /// yang siap dipasang. Melempar [UpdateException] atau [UpdateCancelled]; berkas setengah jadi selalu dihapus.
  Future<String> download(
    ReleaseInfo release, {
    void Function(int received, int total)? onProgress,
    UpdateCancelToken? cancel,
  });
}

/// Rilis dari GitHub Releases (`api.github.com`, tanpa token: batas 60 permintaan per jam per alamat IP).
class GitHubUpdateService implements UpdateService {
  GitHubUpdateService({
    required this.repo,
    required this.tempDir,
    Uri? apiBase,
    HttpClient Function()? clientFactory,
    this.timeout = const Duration(seconds: 20),
    this.maxApkBytes = 300 * 1024 * 1024,
  }) : _apiBase = apiBase ?? Uri.parse('https://api.github.com'),
       _clientFactory = clientFactory ?? HttpClient.new;

  /// `pemilik/nama`, mis. `egateza/TermUL-Mobile`.
  final String repo;

  /// Folder cache aplikasi.
  final Future<Directory> Function() tempDir;
  final Uri _apiBase;
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

  HttpClient _client() => _clientFactory()
    ..connectionTimeout = timeout
    ..idleTimeout = timeout
    ..userAgent = _userAgent;

  @override
  Future<ReleaseInfo?> latest() async {
    final uri = _apiBase.resolve('/repos/$repo/releases/latest');
    final client = _client();
    try {
      final res = await _get(client, uri, accept: 'application/vnd.github+json');
      if (res.statusCode == HttpStatus.notFound) {
        await res.drain<void>();
        return null;
      }
      if (res.statusCode != HttpStatus.ok) {
        await res.drain<void>();
        throw UpdateException(UpdateFailure.server, res.statusCode);
      }
      final text = await _readText(res, limit: 1024 * 1024);
      final Object? json;
      try {
        json = jsonDecode(text);
      } on FormatException {
        throw const UpdateException(UpdateFailure.badRelease, 'json');
      }
      try {
        return parseRelease(json);
      } on BadReleaseException catch (e) {
        throw UpdateException(UpdateFailure.badRelease, e.reason);
      }
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
    if (release.apk.size > maxApkBytes) throw const UpdateException(UpdateFailure.badRelease, 'terlalu besar');
    final Directory dir;
    try {
      dir = Directory('${(await tempDir()).path}${Platform.pathSeparator}$folderName');
      if (await dir.exists()) await dir.delete(recursive: true);
      await dir.create(recursive: true);
    } on FileSystemException catch (e) {
      throw UpdateException(UpdateFailure.storage, e.osError?.errorCode);
    }
    // Nama unik: unduhan yang baru dibatalkan tidak menghapus berkas unduhan berikutnya.
    final part = File('${dir.path}${Platform.pathSeparator}$apkName.${DateTime.now().microsecondsSinceEpoch}.part');
    final client = _client();
    IOSink? sink;
    try {
      final expected = await _fetchChecksum(client, release.checksum.url);
      if (cancel?.isCancelled ?? false) throw const UpdateCancelled();

      final res = await _get(client, release.apk.url, accept: 'application/octet-stream');
      if (res.statusCode != HttpStatus.ok) {
        await res.drain<void>();
        throw UpdateException(UpdateFailure.server, res.statusCode);
      }
      final total = res.contentLength > 0 ? res.contentLength : release.apk.size;
      if (total > maxApkBytes) throw const UpdateException(UpdateFailure.badRelease, 'terlalu besar');

      final digest = _DigestSink();
      final hasher = sha256.startChunkedConversion(digest);
      sink = part.openWrite();
      var received = 0;
      onProgress?.call(0, total);
      await for (final chunk in res.timeout(timeout)) {
        if (cancel?.isCancelled ?? false) throw const UpdateCancelled();
        received += chunk.length;
        if (received > maxApkBytes) throw const UpdateException(UpdateFailure.badRelease, 'terlalu besar');
        hasher.add(chunk);
        sink.add(chunk);
        onProgress?.call(received, total);
      }
      hasher.close();
      await sink.flush();
      await sink.close();
      sink = null;
      if (cancel?.isCancelled ?? false) throw const UpdateCancelled();
      if (digest.value.toString() != expected) throw const UpdateException(UpdateFailure.checksum);

      final ready = await part.rename('${dir.path}${Platform.pathSeparator}$apkName');
      return ready.path;
    } on UpdateException {
      await _discard(sink, part);
      rethrow;
    } on UpdateCancelled {
      await _discard(sink, part);
      rethrow;
    } on FileSystemException catch (e) {
      await _discard(sink, part);
      throw UpdateException(UpdateFailure.storage, e.osError?.errorCode);
    } on Object catch (e) {
      await _discard(sink, part);
      throw UpdateException(UpdateFailure.network, e.runtimeType);
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _fetchChecksum(HttpClient client, Uri url) async {
    final res = await _get(client, url, accept: 'application/octet-stream');
    if (res.statusCode != HttpStatus.ok) {
      await res.drain<void>();
      throw UpdateException(UpdateFailure.server, res.statusCode);
    }
    final hex = parseChecksum(await _readText(res, limit: 4096));
    if (hex == null) throw const UpdateException(UpdateFailure.badRelease, 'isi checksum');
    return hex;
  }

  Future<HttpClientResponse> _get(HttpClient client, Uri uri, {required String accept}) async {
    final req = await client.getUrl(uri).timeout(timeout);
    req.headers.set(HttpHeaders.acceptHeader, accept);
    // Unduhan aset dialihkan ke penyimpanan GitHub; HttpClient mengikuti pengalihan GET.
    req.followRedirects = true;
    return req.close().timeout(timeout);
  }

  Future<String> _readText(HttpClientResponse res, {required int limit}) async {
    final bytes = <int>[];
    await for (final chunk in res.timeout(timeout)) {
      bytes.addAll(chunk);
      if (bytes.length > limit) throw const UpdateException(UpdateFailure.badRelease, 'jawaban terlalu besar');
    }
    return utf8.decode(bytes, allowMalformed: true);
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
  Future<String> download(
    ReleaseInfo release, {
    void Function(int received, int total)? onProgress,
    UpdateCancelToken? cancel,
  }) async => throw const UpdateException(UpdateFailure.badRelease);
}
