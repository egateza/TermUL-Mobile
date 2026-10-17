/// Nama berkas yang belum dipakai: [name] bila bebas, selain itu `nama (1).ext`, `nama (2).ext`, dan seterusnya
/// (nomor pertama yang bebas menurut [taken]). Gaya yang sama dengan Android untuk unduhan, dipakai juga untuk
/// unggahan.
///
/// Ekstensi dipisah di titik terakhir; `.tar.gz`, `.tar.bz2`, `.tar.xz`, dan `.tar.zst` dianggap satu ekstensi, dan
/// nama berawalan titik tanpa ekstensi lain (`.bashrc`) diberi nomor di belakangnya (`.bashrc (1)`).
String uniqueName(String name, bool Function(String candidate) taken) {
  if (!taken(name)) return name;
  final (stem, ext) = _split(name);
  for (var n = 1; ; n++) {
    final candidate = '$stem ($n)$ext';
    if (!taken(candidate)) return candidate;
  }
}

/// Seperti [uniqueName] untuk nama folder: nomor selalu di belakang (`proyek (1)`, `v1.2 (1)`), titik tidak dianggap
/// ekstensi.
String uniqueFolderName(String name, bool Function(String candidate) taken) {
  if (!taken(name)) return name;
  for (var n = 1; ; n++) {
    final candidate = '$name ($n)';
    if (!taken(candidate)) return candidate;
  }
}

(String, String) _split(String name) {
  final lower = name.toLowerCase();
  for (final tar in const ['.tar.gz', '.tar.bz2', '.tar.xz', '.tar.zst']) {
    if (lower.endsWith(tar) && name.length > tar.length) {
      return (name.substring(0, name.length - tar.length), name.substring(name.length - tar.length));
    }
  }
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return (name, '');
  return (name.substring(0, dot), name.substring(dot));
}
