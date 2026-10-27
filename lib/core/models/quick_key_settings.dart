/// Susunan bilah tombol cepat terminal: dua baris, masing-masing berisi id tombol dari katalog [knownIds] dengan
/// urutan pilihan pengguna. Snippet tidak termasuk; tombol itu selalu di kiri dan tidak bisa diubah.
///
/// Isi `settings.json` bagian `quickKeys`: `{"row1": ["esc", "slash", ...], "row2": ["tab", "ctrl", ...]}`.
/// Pembacaan sengaja longgar supaya satu nilai salah tidak menyisihkan seluruh pengaturan: id yang tidak dikenal
/// dan id yang sudah muncul sebelumnya (di baris mana pun) dibuang, lalu tiap baris dipotong ke [maxPerRow].
class QuickKeySettings {
  const QuickKeySettings({this.row1 = defaultRow1, this.row2 = defaultRow2});

  static const maxPerRow = 10;

  /// Bawaan mengikuti prototipe: Home, panah atas, End tepat di atas panah kiri, bawah, kanan.
  static const defaultRow1 = ['esc', 'slash', 'pipe', 'home', 'up', 'end', 'pgup', 'fn', 'ctrlc'];
  static const defaultRow2 = ['tab', 'ctrl', 'alt', 'left', 'down', 'right', 'pgdn', 'paste', 'ctrld'];

  /// Semua id yang boleh dipasang, sama dengan katalog di prototipe `QuickKeysAdd`.
  static const knownIds = {
    'esc', 'tab', 'ctrl', 'alt', 'fn', 'paste', 'bksp', 'enter', //
    'up', 'down', 'left', 'right', 'home', 'end', 'pgup', 'pgdn', 'ins', 'del', //
    'ctrlc', 'ctrld', 'ctrlz', 'ctrll', 'ctrlr', 'ctrla', 'ctrle', 'ctrlw', 'ctrlu', 'ctrlk', 'ctrlb', 'ctrlx', //
    'pipe', 'tilde', 'slash', 'dash',
  };

  final List<String> row1;
  final List<String> row2;

  List<String> row(int index) => index == 0 ? row1 : row2;

  bool get isDefault => _same(row1, defaultRow1) && _same(row2, defaultRow2);

  /// Id yang sudah dipakai di salah satu baris; tombol hanya boleh muncul sekali.
  bool uses(String id) => row1.contains(id) || row2.contains(id);

  QuickKeySettings withRow(int index, List<String> ids) => index == 0
      ? QuickKeySettings(row1: List.unmodifiable(ids), row2: row2)
      : QuickKeySettings(row1: row1, row2: List.unmodifiable(ids));

  factory QuickKeySettings.fromJson(Map<String, Object?> json) {
    final seen = <String>{};
    List<String> read(String key, List<String> fallback) {
      final raw = json[key];
      if (raw is! List) {
        final kept = fallback.where(seen.add).toList();
        return List.unmodifiable(kept);
      }
      final out = <String>[];
      for (final v in raw) {
        if (out.length >= maxPerRow) break;
        if (v is String && knownIds.contains(v) && seen.add(v)) out.add(v);
      }
      return List.unmodifiable(out);
    }

    final row1 = read('row1', defaultRow1);
    final row2 = read('row2', defaultRow2);
    return QuickKeySettings(row1: row1, row2: row2);
  }

  Map<String, Object?> toJson() => {'row1': row1, 'row2': row2};

  static bool _same(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) => other is QuickKeySettings && _same(other.row1, row1) && _same(other.row2, row2);

  @override
  int get hashCode => Object.hash(Object.hashAll(row1), Object.hashAll(row2));
}
