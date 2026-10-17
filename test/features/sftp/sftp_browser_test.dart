import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/models/host_profile.dart';
import 'package:termul_mobile/core/sftp/sftp_service.dart';
import 'package:termul_mobile/features/sftp/sftp_browser_controller.dart';
import 'package:termul_mobile/features/sftp/sftp_format.dart';
import 'package:termul_mobile/features/sftp/sftp_link.dart';
import 'package:termul_mobile/l10n/app_localizations_id.dart';

SftpEntry dir(String parent, String name) =>
    SftpEntry(name: name, path: joinRemote(parent, name), kind: SftpEntryKind.directory);
SftpEntry file(String parent, String name, {int size = 10}) =>
    SftpEntry(name: name, path: joinRemote(parent, name), kind: SftpEntryKind.file, size: size);

/// Pohon folder palsu; `gate` menahan muatan sampai dilepas (untuk menguji balapan).
class FakeBrowsing implements SftpBrowsing {
  FakeBrowsing(this.tree);

  final Map<String, List<SftpEntry>> tree;
  final failures = <String, SftpFailure>{};
  final gates = <String, Completer<void>>{};
  final listed = <String>[];

  @override
  Future<String> home() async => '/home/u';

  @override
  Future<List<SftpEntry>> list(String d) async {
    listed.add(d);
    await gates[d]?.future;
    final f = failures[d];
    if (f != null) throw f;
    final t = tree[d];
    if (t == null) throw const SftpFailure(SftpFailureKind.notFound, 'tidak ada');
    return t;
  }
}

/// Tiruan server dengan transfer: unduhan menulis [downloadBytes] (menunggu [hold] di tengah bila diisi), unggahan
/// membaca seluruh aliran dan mencatatnya di [uploaded].
class FakeFiles extends FakeBrowsing implements SftpFileOps {
  FakeFiles(super.tree);

  Uint8List downloadBytes = Uint8List.fromList(List.filled(1000, 7));
  SftpFailure? downloadFailure;
  SftpFailure? uploadFailure;
  Completer<void>? hold;

  /// Hasil penelusuran per folder (kunci: jalur folder) dan galat per jalur berkas jarak jauh untuk unduhan.
  final trees = <String, SftpTree>{};
  final downloadFailures = <String, SftpFailure>{};
  final downloaded = <String>[];

  /// Jumlah pemanggilan progres beruntun sebelum unduhan mulai (untuk menguji pembatasan laju).
  int burst = 0;
  final uploaded = <String, int>{};

  @override
  Future<SftpTree> walk(String dir, {SftpCancelToken? cancel}) async {
    final t = trees[dir];
    if (t == null) throw const SftpFailure(SftpFailureKind.notFound, 'tidak ada');
    return t;
  }

  @override
  Future<int> download(
    String remotePath,
    StreamSink<List<int>> sink, {
    void Function(int bytes)? onProgress,
    SftpCancelToken? cancel,
  }) async {
    downloaded.add(remotePath);
    if (downloadFailures[remotePath] != null) throw downloadFailures[remotePath]!;
    if (downloadFailure != null) throw downloadFailure!;
    for (var i = 1; i <= burst; i++) {
      onProgress?.call(i);
    }
    final half = downloadBytes.length ~/ 2;
    sink.add(downloadBytes.sublist(0, half));
    onProgress?.call(half);
    if (hold != null) await hold!.future;
    if (cancel?.isCancelled ?? false) throw const SftpFailure(SftpFailureKind.cancelled, 'Dibatalkan');
    sink.add(downloadBytes.sublist(half));
    onProgress?.call(downloadBytes.length);
    return downloadBytes.length;
  }

  @override
  Future<void> upload(
    String remotePath,
    Stream<Uint8List> data, {
    void Function(int bytes)? onProgress,
    SftpCancelToken? cancel,
  }) async {
    if (uploadFailure != null) throw uploadFailure!;
    var n = 0;
    await for (final c in data) {
      n += c.length;
      onProgress?.call(n);
      if (hold != null) await hold!.future;
      if (cancel?.isCancelled ?? false) throw const SftpFailure(SftpFailureKind.cancelled, 'Dibatalkan');
    }
    uploaded[remotePath] = n;
  }
}

void main() {
  late FakeBrowsing fake;
  late SftpBrowserController c;

  setUp(() {
    fake = FakeBrowsing({
      '/': [dir('/', 'home'), dir('/', 'etc')],
      '/home': [dir('/home', 'u')],
      '/home/u': [dir('/home/u', 'proyek'), file('/home/u', 'catatan.txt')],
      '/home/u/proyek': [],
    });
    c = SftpBrowserController(fake);
  });
  tearDown(() => c.dispose());

  test('start membuka folder rumah', () async {
    await c.start();
    expect(c.path, '/home/u');
    expect([for (final e in c.entries) e.name], ['proyek', 'catatan.txt']);
    expect(c.loading, isFalse);
    expect(c.failure, isNull);
  });

  test('open, up, dan crumbs', () async {
    await c.start();
    await c.open('/home/u/proyek');
    expect(c.crumbs, [('/', '/'), ('home', '/home'), ('u', '/home/u'), ('proyek', '/home/u/proyek')]);
    await c.up();
    expect(c.path, '/home/u');
    await c.open('/');
    expect(c.atRoot, isTrue);
    expect(c.crumbs, [('/', '/')]);
    await c.up();
    expect(c.path, '/');
  });

  test('back: kembali ke folder sebelumnya, bukan folder induk; tanpa riwayat mengembalikan false', () async {
    await c.start();
    expect(c.canGoBack, isFalse);
    expect(await c.back(), isFalse);

    await c.open('/home/u/proyek');
    expect(c.canGoBack, isTrue);
    expect(await c.back(), isTrue);
    expect(c.path, '/home/u');
    expect(c.canGoBack, isFalse, reason: 'folder awal: tidak ada lagi riwayat');

    // Melompat lewat breadcrumb: kembali ke asal lompatan, bukan induknya.
    await c.open('/home/u/proyek');
    await c.open('/');
    expect(c.history, ['/home/u', '/home/u/proyek']);
    await c.back();
    expect(c.path, '/home/u/proyek');
    await c.back();
    expect(c.path, '/home/u');
  });

  test('riwayat: muat ulang tidak menambah, galat membuka folder tidak mengubah, restore membawa riwayat', () async {
    await c.start();
    await c.refresh();
    expect(c.canGoBack, isFalse);

    fake.failures['/home/u/proyek'] = const SftpFailure(SftpFailureKind.permissionDenied, 'ditolak');
    await c.open('/home/u/proyek');
    expect(c.canGoBack, isFalse, reason: 'gagal dibuka: riwayat tetap');
    fake.failures.clear();

    await c.open('/home/u/proyek');
    final saved = c.history;
    final fresh = SftpBrowserController(fake);
    addTearDown(fresh.dispose);
    await fresh.start(restore: '/home/u/proyek', history: saved);
    expect(fresh.path, '/home/u/proyek');
    expect(await fresh.back(), isTrue);
    expect(fresh.path, '/home/u');
  });

  test('back yang gagal membuka folder: riwayat tidak berkurang', () async {
    await c.start();
    await c.open('/home/u/proyek');
    fake.failures['/home/u'] = const SftpFailure(SftpFailureKind.permissionDenied, 'ditolak');
    await c.back();
    expect(c.path, '/home/u/proyek');
    expect(c.failure, isNotNull);
    expect(c.canGoBack, isTrue);
  });

  test('galat membuka folder: folder aktif tidak berubah dan galat dicatat', () async {
    await c.start();
    fake.failures['/home'] = const SftpFailure(SftpFailureKind.permissionDenied, 'ditolak');
    await c.open('/home');
    expect(c.path, '/home/u');
    expect(c.failure?.kind, SftpFailureKind.permissionDenied);
    expect(c.loading, isFalse);
    fake.failures.clear();
    await c.open('/home');
    expect(c.failure, isNull);
    expect(c.path, '/home');
  });

  test('clearSelection melepas pilihan dan tidak apa-apa bila tidak ada', () async {
    await c.start();
    c.clearSelection();
    c.toggle(c.entries.last);
    expect(c.hasSelection, isTrue);
    c.clearSelection();
    expect(c.hasSelection, isFalse);
  });

  test('pilihan: ketuk lagi membatalkan, pindah folder menghapusnya', () async {
    await c.start();
    final f = c.entries.last;
    c.toggle(f);
    expect(c.selection, [f]);
    c.toggle(f);
    expect(c.hasSelection, isFalse);
    c.toggle(f);
    await c.open('/home/u/proyek');
    expect(c.hasSelection, isFalse);
  });

  test('seleksi ganda: berkas dan folder, urut seperti daftar, jumlah dan total ukuran tanpa folder', () async {
    await c.start();
    final entries = c.entries;
    final folders = entries.where((e) => e.isDirectory).toList();
    final files = entries.where((e) => !e.isDirectory).toList();
    expect(folders, isNotEmpty);
    expect(files, isNotEmpty);
    // Dipilih dalam urutan terbalik; hasilnya tetap urut daftar.
    c.toggle(files.last);
    c.toggle(folders.first);
    expect(c.selection, [folders.first, files.last]);
    expect(c.selectionCount, 2);
    expect(c.selectionBytes, files.last.size, reason: 'folder tidak dihitung ke ukuran');
    expect(c.isSelected(folders.first), isTrue);
  });

  test('pilih semua memilih seluruh isi folder; muat ulang melepas pilihan', () async {
    await c.start();
    c.selectAll();
    expect(c.selectionCount, c.entries.length);
    expect(c.allSelected, isTrue);
    await c.refresh();
    expect(c.hasSelection, isFalse);
  });

  test('hasil muatan lama dibuang bila pengguna sudah membuka folder lain', () async {
    await c.start();
    fake.gates['/home'] = Completer<void>();
    final slow = c.open('/home');
    await c.open('/');
    fake.gates['/home']!.complete();
    await slow;
    expect(c.path, '/');
  });

  test('muat ulang memuat folder yang sama', () async {
    await c.start();
    fake.listed.clear();
    await c.refresh();
    expect(fake.listed, ['/home/u']);
  });

  group('format', () {
    final l = AppLocalizationsId();
    final now = DateTime(2026, 10, 17, 12, 0);

    test('ukuran memakai koma desimal', () {
      expect(formatSize(512), '512 B');
      expect(formatSize(1229), '1,2 KB');
      expect(formatSize(3 * 1024 * 1024 + 400 * 1024), '3,4 MB');
      expect(formatSize(250 * 1024), '250 KB');
    });

    test('waktu ubah', () {
      expect(formatModified(l, now.subtract(const Duration(seconds: 20)), now), 'baru saja');
      expect(
        formatModified(l, now.add(const Duration(seconds: 40)), now),
        'baru saja',
        reason: 'jam server sedikit maju',
      );
      expect(formatModified(l, now.subtract(const Duration(minutes: 5)), now), '5 menit lalu');
      expect(formatModified(l, now.subtract(const Duration(hours: 2)), now), '2 jam lalu');
      expect(formatModified(l, DateTime(2026, 10, 16, 23, 0), now), 'kemarin');
      expect(formatModified(l, DateTime(2026, 9, 12), now), '12 Sep');
      expect(formatModified(l, DateTime(2024, 9, 12), now), '12 Sep 2024');
    });
  });

  test('SftpLink.ready langsung punya layanan', () {
    final link = SftpLink.ready(
      profile: HostProfile(id: '11111111-1111-4111-8111-111111111111', name: 'x', host: 'h', port: 22, username: 'u'),
      service: fake,
    );
    expect(link.service, same(fake));
    expect(link.lost, isFalse);
    link.dispose();
  });
}
