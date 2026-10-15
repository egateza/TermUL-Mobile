import 'dart:io';
import 'dart:math';

import 'storage_exception.dart';

/// Fungsi penulis berkas; bisa diganti di test untuk menyuntik kegagalan.
typedef AtomicWriter = Future<void> Function(File target, List<int> bytes);

final _random = Random.secure();

/// Menulis [bytes] ke [target] secara atomik: tulis ke berkas sementara di folder yang sama,
/// `flush`, lalu `rename`. Bila gagal di tengah, berkas lama tetap utuh dan berkas sementara dihapus.
///
/// [beforeRename] hanya untuk test (menyuntik galat tepat sebelum rename).
///
/// Belum diverifikasi di Android: apakah `flush` melakukan `fsync`; Dart tidak punya `fsync` untuk folder.
Future<void> writeAtomic(
  File target,
  List<int> bytes, {
  Future<void> Function()? beforeRename,
}) async {
  final dir = target.absolute.parent;
  final name = target.uri.pathSegments.last;
  final tmp = File('${dir.path}${Platform.pathSeparator}.$name.${_random.nextInt(1 << 32).toRadixString(16)}.tmp');
  try {
    await dir.create(recursive: true);
    final raf = await tmp.open(mode: FileMode.write);
    try {
      await raf.writeFrom(bytes);
      await raf.flush();
    } finally {
      await raf.close();
    }
    if (beforeRename != null) await beforeRename();
    await tmp.rename(target.path);
  } on FileSystemException catch (e) {
    await _deleteQuietly(tmp);
    throw StorageException('Gagal menyimpan berkas $name', e);
  } catch (_) {
    await _deleteQuietly(tmp);
    rethrow;
  }
}

Future<void> _deleteQuietly(File f) async {
  try {
    if (await f.exists()) await f.delete();
  } on FileSystemException {
    // Sisa berkas sementara tidak berbahaya; berkas utama tidak tersentuh.
  }
}
