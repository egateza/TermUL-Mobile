/// Pembaca field JSON yang ketat tentang tipe. Tipe salah melempar [FormatException]
/// (berkas dianggap rusak), field hilang atau `null` menghasilkan `null`.
library;

String? optString(Map<String, Object?> json, String key) {
  final v = json[key];
  if (v == null) return null;
  if (v is String) return v;
  throw FormatException('Field "$key" harus teks');
}

int? optInt(Map<String, Object?> json, String key) {
  final v = json[key];
  if (v == null) return null;
  if (v is int) return v;
  throw FormatException('Field "$key" harus bilangan bulat');
}

double? optNum(Map<String, Object?> json, String key) {
  final v = json[key];
  if (v == null) return null;
  if (v is num) return v.toDouble();
  throw FormatException('Field "$key" harus angka');
}

bool? optBool(Map<String, Object?> json, String key) {
  final v = json[key];
  if (v == null) return null;
  if (v is bool) return v;
  throw FormatException('Field "$key" harus true atau false');
}

Map<String, Object?>? optObject(Map<String, Object?> json, String key) {
  final v = json[key];
  if (v == null) return null;
  if (v is Map<String, Object?>) return v;
  throw FormatException('Field "$key" harus objek');
}

List<Object?> optList(Map<String, Object?> json, String key) {
  final v = json[key];
  if (v == null) return const [];
  if (v is List<Object?>) return v;
  throw FormatException('Field "$key" harus daftar');
}

List<String> stringList(Map<String, Object?> json, String key) => [
  for (final e in optList(json, key))
    if (e is String) e else throw FormatException('Isi "$key" harus teks'),
];
