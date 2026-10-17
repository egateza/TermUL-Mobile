import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

/// Jenis entri di daftar folder jarak jauh.
enum SftpEntryKind { directory, file, symlink, other }

/// Satu baris di daftar folder. [size] dan [modified] bisa `null` bila server tidak melaporkannya.
class SftpEntry {
  const SftpEntry({
    required this.name,
    required this.path,
    required this.kind,
    this.size,
    this.modified,
    this.permissions,
  });

  final String name;
  final String path;
  final SftpEntryKind kind;
  final int? size;
  final DateTime? modified;

  /// Mode Unix 9 bit (mis. `0o644`), bila dilaporkan.
  final int? permissions;

  bool get isDirectory => kind == SftpEntryKind.directory;
}

/// Kegagalan operasi SFTP, sudah dipetakan dari galat paket supaya UI tidak bergantung pada tipe `dartssh2`.
enum SftpFailureKind { notFound, permissionDenied, connectionLost, cancelled, other }

class SftpFailure implements Exception {
  const SftpFailure(this.kind, this.message, [this.cause]);

  final SftpFailureKind kind;
  final String message;
  final Object? cause;

  @override
  String toString() => 'SftpFailure(${kind.name}): $message';
}

/// Tanda pembatalan untuk transfer. Memanggil [cancel] menghentikan transfer secepatnya.
class SftpCancelToken {
  bool _cancelled = false;
  final _listeners = <void Function()>[];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  void _onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }
}

/// Menggabungkan jalur jarak jauh (selalu `/`, bukan pemisah platform).
String joinRemote(String dir, String name) {
  if (dir.isEmpty) return name;
  return dir.endsWith('/') ? '$dir$name' : '$dir/$name';
}

/// Jalur induk; induk dari `/` adalah `/`.
String parentRemote(String path) {
  if (path == '/' || path.isEmpty) return '/';
  final trimmed = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
  final i = trimmed.lastIndexOf('/');
  if (i <= 0) return i == 0 ? '/' : '.';
  return trimmed.substring(0, i);
}

/// Urutan daftar: folder dulu, lalu berkas, masing-masing urut nama tanpa membedakan huruf besar kecil.
int compareEntries(SftpEntry a, SftpEntry b) {
  if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

/// Satu berkas hasil penelusuran folder: jalur di server, jalur relatif terhadap folder yang diunduh (pemisah `/`,
/// termasuk nama berkas), dan ukurannya.
class SftpTreeFile {
  const SftpTreeFile({required this.remotePath, required this.relativePath, required this.size});

  final String remotePath;
  final String relativePath;
  final int size;
}

/// Hasil menelusuri folder: berkas yang bisa diunduh dan jumlah entri yang dilewati (tautan simbolik rusak,
/// tautan yang menunjuk ke folder induknya sendiri, folder yang tidak boleh dibaca, soket dan sejenisnya).
/// Folder kosong tidak dicatat: Unduhan Android tidak bisa membuat folder tanpa berkas.
class SftpTree {
  const SftpTree({required this.files, this.skipped = 0});

  final List<SftpTreeFile> files;
  final int skipped;

  int get totalBytes => files.fold(0, (sum, f) => sum + f.size);
}

/// Bagian SFTP yang dipakai penjelajah folder; dipisah supaya penjelajah bisa dites tanpa server.
abstract interface class SftpBrowsing {
  Future<String> home();

  Future<List<SftpEntry>> list(String dir);
}

/// Transfer berkas; dipisah dari [SftpBrowsing] supaya orkestrasi transfer bisa dites tanpa server.
abstract interface class SftpFileOps {
  /// Menelusuri [dir] beserta seluruh isinya untuk unduhan folder. Tautan simbolik diikuti ke sumbernya.
  Future<SftpTree> walk(String dir, {SftpCancelToken? cancel});

  Future<int> download(
    String remotePath,
    StreamSink<List<int>> sink, {
    void Function(int bytes)? onProgress,
    SftpCancelToken? cancel,
  });

  Future<void> upload(
    String remotePath,
    Stream<Uint8List> data, {
    void Function(int bytes)? onProgress,
    SftpCancelToken? cancel,
  });
}

/// Operasi SFTP di atas satu [SftpClient]. Tidak memegang kredensial dan tidak menyambung sendiri; pemanggil
/// yang membuka dan menutup sambungan SSH-nya (lihat `SftpSession` bila dipakai UI).
class SftpService implements SftpBrowsing, SftpFileOps {
  SftpService(this._client);

  final SftpClient _client;

  /// Folder awal (biasanya folder rumah), jalur mutlak.
  @override
  Future<String> home() => _guard(() => _client.absolute('.'));

  /// Isi folder, folder dulu. Entri `.` dan `..` dibuang. Tautan simbolik diperiksa: bila menunjuk ke folder
  /// ia dihitung folder supaya bisa dibuka.
  @override
  Future<List<SftpEntry>> list(String dir) => _guard(() async {
    final names = await _client.listdir(dir);
    final entries = <SftpEntry>[];
    for (final n in names) {
      if (n.filename == '.' || n.filename == '..') continue;
      final path = joinRemote(dir, n.filename);
      var kind = _kindOf(n.attr);
      var attr = n.attr;
      if (kind == SftpEntryKind.symlink) {
        try {
          attr = await _client.stat(path);
          kind = attr.isDirectory ? SftpEntryKind.directory : SftpEntryKind.symlink;
        } on Object {
          // tautan putus: tetap ditampilkan sebagai tautan
        }
      }
      entries.add(
        SftpEntry(
          name: n.filename,
          path: path,
          kind: kind,
          size: attr.size,
          modified: attr.modifyTime == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(attr.modifyTime! * 1000, isUtc: true).toLocal(),
          permissions: attr.mode == null ? null : attr.mode!.value & 0x1FF,
        ),
      );
    }
    entries.sort(compareEntries);
    return entries;
  });

  /// Menelusuri [dir] rekursif. Tautan simbolik ke berkas atau folder diikuti dan diunduh dari sumbernya; yang rusak
  /// atau menunjuk ke folder yang sedang ditelusuri (putaran) dilewati dan dihitung. Folder anak yang tidak bisa
  /// dibaca dilewati; hanya galat di [dir] sendiri yang menggagalkan penelusuran.
  @override
  Future<SftpTree> walk(String dir, {SftpCancelToken? cancel}) => _guard(() async {
    final files = <SftpTreeFile>[];
    var skipped = 0;
    String? rootReal;

    Future<void> visit(String path, String relative, Set<String> ancestors, {required bool root}) async {
      if (cancel?.isCancelled ?? false) throw const SftpFailure(SftpFailureKind.cancelled, 'Dibatalkan');
      final real = await _client.absolute(path);
      final top = rootReal ??= real;
      // Putaran: folder yang sedang ditelusuri, atau folder yang memuat folder awal (mis. tautan ke `..`; kalau diikuti,
      // seluruh isi di luar folder yang dipilih ikut terunduh).
      if (!root && (ancestors.contains(real) || _isSameOrAncestor(real, top))) {
        skipped++;
        return;
      }
      final List<SftpName> names;
      try {
        names = await _client.listdir(path);
      } on Object {
        if (root) rethrow;
        skipped++;
        return;
      }
      final chain = {...ancestors, real};
      for (final n in names) {
        if (n.filename == '.' || n.filename == '..') continue;
        final child = joinRemote(path, n.filename);
        final rel = relative.isEmpty ? n.filename : '$relative/${n.filename}';
        var attr = n.attr;
        if (_kindOf(attr) == SftpEntryKind.symlink) {
          try {
            attr = await _client.stat(child);
          } on Object {
            skipped++;
            continue;
          }
        }
        switch (_kindOf(attr)) {
          case SftpEntryKind.directory:
            await visit(child, rel, chain, root: false);
          case SftpEntryKind.file:
            files.add(SftpTreeFile(remotePath: child, relativePath: rel, size: attr.size ?? 0));
          case SftpEntryKind.symlink || SftpEntryKind.other:
            skipped++;
        }
      }
    }

    await visit(dir, '', const {}, root: true);
    return SftpTree(files: files, skipped: skipped);
  });

  Future<void> mkdir(String path) => _guard(() => _client.mkdir(path));

  Future<void> rename(String from, String to) => _guard(() => _client.rename(from, to));

  Future<void> deleteFile(String path) => _guard(() => _client.remove(path));

  /// Menghapus folder beserta isinya (rekursif). Tautan simbolik dihapus sebagai berkas, tidak diikuti.
  Future<void> deleteTree(String path) => _guard(() async {
    for (final e in await _listRaw(path)) {
      if (e.kind == SftpEntryKind.directory) {
        await deleteTree(e.path);
      } else {
        await _client.remove(e.path);
      }
    }
    await _client.rmdir(path);
  });

  /// Daftar tanpa mengikuti tautan simbolik (untuk penghapusan rekursif).
  Future<List<SftpEntry>> _listRaw(String dir) async {
    final names = await _client.listdir(dir);
    return [
      for (final n in names)
        if (n.filename != '.' && n.filename != '..')
          SftpEntry(name: n.filename, path: joinRemote(dir, n.filename), kind: _kindOf(n.attr), size: n.attr.size),
    ];
  }

  /// Mengunduh [remotePath] ke [sink]. [onProgress] menerima jumlah byte yang sudah diterima. Bila dibatalkan,
  /// melempar [SftpFailure] bertipe `cancelled`; menutup/menghapus berkas lokal adalah tugas pemanggil.
  @override
  Future<int> download(
    String remotePath,
    StreamSink<List<int>> sink, {
    void Function(int bytes)? onProgress,
    SftpCancelToken? cancel,
  }) => _guard(() async {
    final file = await _client.open(remotePath);
    var cancelled = false;
    cancel?._onCancel(() {
      cancelled = true;
      unawaited(file.close().catchError((Object _) {}));
    });
    try {
      return await file.downloadTo(sink, onProgress: onProgress);
    } on Object {
      if (cancelled) throw const SftpFailure(SftpFailureKind.cancelled, 'Dibatalkan');
      rethrow;
    } finally {
      if (!file.isClosed) await file.close();
    }
  });

  /// Akhiran nama berkas sementara unggahan di server.
  static const partialSuffix = '.termul-part';

  /// Mengunggah [data] ke [remotePath] (menimpa bila sudah ada). Data ditulis ke `<nama>.termul-part` dulu, lalu
  /// diganti namanya setelah selesai, jadi berkas lama tetap utuh bila unggahan dibatalkan atau gagal di tengah
  /// (spike K14: `abort` meninggalkan berkas parsial; menulis langsung ke nama tujuan memotong berkas lama lebih
  /// dulu). Berkas sementara dihapus bila gagal. SFTP v3 menolak mengganti nama ke berkas yang sudah ada (OpenSSH),
  /// jadi berkas lama dihapus tepat sebelum penggantian nama; bila penggantian nama gagal berkas sementara dibiarkan
  /// supaya hasil unggahan tidak hilang, dan galatnya dilaporkan.
  @override
  Future<void> upload(
    String remotePath,
    Stream<Uint8List> data, {
    void Function(int bytes)? onProgress,
    SftpCancelToken? cancel,
  }) => _guard(() async {
    final partial = '$remotePath$partialSuffix';
    final file = await _client.open(
      partial,
      mode: SftpFileOpenMode.create | SftpFileOpenMode.truncate | SftpFileOpenMode.write,
    );
    final writer = file.write(data, onProgress: onProgress);
    var cancelled = false;
    cancel?._onCancel(() {
      cancelled = true;
      unawaited(writer.abort());
    });
    var written = false;
    try {
      await writer.done;
      // `abort` menyelesaikan `done` secara normal, jadi pembatalan harus diperiksa di sini.
      if (cancelled) throw const SftpFailure(SftpFailureKind.cancelled, 'Dibatalkan');
      written = true;
    } on SftpFailure {
      rethrow;
    } on Object {
      if (cancelled) throw const SftpFailure(SftpFailureKind.cancelled, 'Dibatalkan');
      rethrow;
    } finally {
      try {
        await file.close();
      } on Object {
        // sambungan mungkin sudah putus
      }
      if (!written) {
        try {
          await _client.remove(partial);
        } on Object {
          // pembersihan terbaik-usaha; galat aslinya yang dilaporkan
        }
      }
    }
    try {
      await _client.rename(partial, remotePath);
    } on Object {
      // Target sudah ada (OpenSSH menolak): hapus berkas lama lalu ganti nama.
      await _client.remove(remotePath);
      await _client.rename(partial, remotePath);
    }
  });

  /// [dir] sama dengan [of] atau memuatnya (jalur mutlak hasil realpath).
  static bool _isSameOrAncestor(String dir, String of) => of == dir || of.startsWith(dir.endsWith('/') ? dir : '$dir/');

  void close() => _client.close();

  static SftpEntryKind _kindOf(SftpFileAttrs a) {
    if (a.isDirectory) return SftpEntryKind.directory;
    if (a.isFile) return SftpEntryKind.file;
    if (a.isSymbolicLink) return SftpEntryKind.symlink;
    return SftpEntryKind.other;
  }

  static Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on SftpFailure {
      rethrow;
    } on SftpStatusError catch (e) {
      throw SftpFailure(
        switch (e.code) {
          SftpStatusCode.noSuchFile => SftpFailureKind.notFound,
          SftpStatusCode.permissionDenied => SftpFailureKind.permissionDenied,
          SftpStatusCode.noConnection || SftpStatusCode.connectionLost => SftpFailureKind.connectionLost,
          _ => SftpFailureKind.other,
        },
        e.message,
        e,
      );
    } on SSHError catch (e) {
      throw SftpFailure(SftpFailureKind.connectionLost, 'Sambungan terputus', e);
    } on Object catch (e) {
      throw SftpFailure(SftpFailureKind.other, 'Operasi SFTP gagal', e);
    }
  }
}
