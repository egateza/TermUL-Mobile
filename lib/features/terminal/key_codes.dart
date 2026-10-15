/// Ctrl+huruf menjadi kode kontrol (Ctrl+C = 0x03); Alt memberi awalan ESC. Hanya untuk satu karakter; urutan
/// yang lebih panjang (panah, tombol F, dan lain-lain) sudah memuat pengubahnya dari mesin terminal.
String applyModifiers(String data, {required bool ctrl, required bool alt}) {
  if (data.length != 1 || (!ctrl && !alt)) return data;
  var c = data.codeUnitAt(0);
  var out = data;
  if (ctrl) {
    if (c >= 0x61 && c <= 0x7a) c -= 0x20; // a-z menjadi A-Z
    if (c >= 0x40 && c <= 0x5f) out = String.fromCharCode(c - 0x40);
  }
  return alt ? '\x1b$out' : out;
}
