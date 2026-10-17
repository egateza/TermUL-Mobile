/// Catatan rilis versi yang sedang dipasang, disimpan sebelum penginstal dibuka supaya "Yang baru" bisa tampil setelah
/// update tanpa jaringan.
class PendingNotes {
  const PendingNotes({required this.versionCode, required this.version, required this.notes});

  final int versionCode;
  final String version;
  final String notes;

  @override
  bool operator ==(Object other) =>
      other is PendingNotes && other.versionCode == versionCode && other.version == version && other.notes == notes;

  @override
  int get hashCode => Object.hash(versionCode, version, notes);
}

/// Keadaan tampilan yang diingat antar-pembukaan aplikasi (`ui_state.json`). Bukan pengaturan dan tanpa rahasia:
/// isinya boleh hilang (berkas rusak atau gagal ditulis) tanpa memberi tahu pengguna.
abstract interface class UiStateRepository {
  /// Path grup host yang diciutkan; `''` berarti grup "Tanpa grup".
  Set<String> get collapsedGroups;

  /// Menyimpan [paths] sebagai grup yang diciutkan. Melempar bila gagal menulis; nilai terkini tidak berubah.
  Future<void> saveCollapsedGroups(Set<String> paths);

  /// `versionCode` terakhir yang sudah dibuka pengguna; null sebelum pertama kali dicatat (pemasangan baru).
  int? get seenVersionCode;

  /// Catatan rilis update yang sedang dipasang; null bila tidak ada.
  PendingNotes? get pendingNotes;

  /// Menyimpan versi yang sudah dilihat dan catatan tertunda sekaligus. Melempar bila gagal menulis.
  Future<void> saveUpdateState({required int? seenVersionCode, required PendingNotes? pendingNotes});
}

/// Salinan di memori untuk tes dan nilai bawaan provider; tidak menyentuh disk.
class MemoryUiStateRepository implements UiStateRepository {
  MemoryUiStateRepository([Set<String> collapsedGroups = const {}, this.seenVersionCode, this.pendingNotes])
    : _collapsed = {...collapsedGroups};

  Set<String> _collapsed;

  @override
  int? seenVersionCode;

  @override
  PendingNotes? pendingNotes;

  @override
  Set<String> get collapsedGroups => Set.unmodifiable(_collapsed);

  @override
  Future<void> saveCollapsedGroups(Set<String> paths) async => _collapsed = {...paths};

  @override
  Future<void> saveUpdateState({required int? seenVersionCode, required PendingNotes? pendingNotes}) async {
    this.seenVersionCode = seenVersionCode;
    this.pendingNotes = pendingNotes;
  }
}
