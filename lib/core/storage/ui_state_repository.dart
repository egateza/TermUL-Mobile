/// Keadaan tampilan yang diingat antar-pembukaan aplikasi (`ui_state.json`). Bukan pengaturan dan tanpa rahasia:
/// isinya boleh hilang (berkas rusak atau gagal ditulis) tanpa memberi tahu pengguna.
abstract interface class UiStateRepository {
  /// Path grup host yang diciutkan; `''` berarti grup "Tanpa grup".
  Set<String> get collapsedGroups;

  /// Menyimpan [paths] sebagai grup yang diciutkan. Melempar bila gagal menulis; nilai terkini tidak berubah.
  Future<void> saveCollapsedGroups(Set<String> paths);
}

/// Salinan di memori untuk tes dan nilai bawaan provider; tidak menyentuh disk.
class MemoryUiStateRepository implements UiStateRepository {
  MemoryUiStateRepository([Set<String> collapsedGroups = const {}]) : _collapsed = {...collapsedGroups};

  Set<String> _collapsed;

  @override
  Set<String> get collapsedGroups => Set.unmodifiable(_collapsed);

  @override
  Future<void> saveCollapsedGroups(Set<String> paths) async => _collapsed = {...paths};
}
