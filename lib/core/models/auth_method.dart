/// Metode autentikasi. Nilai JSON sama dengan desktop (`KEY`, `AGENT`, `PASSWORD`).
///
/// Mobile membaca ketiganya supaya `profiles.json` dari desktop tetap termuat, tetapi UI mobile hanya
/// menawarkan [key] dan [password]; profil [agent] tidak bisa disambung di HP (tidak ada agen SSH).
enum AuthMethod {
  key('KEY'),
  agent('AGENT'),
  password('PASSWORD');

  const AuthMethod(this.wire);

  final String wire;

  static AuthMethod parse(String value) {
    for (final m in values) {
      if (m.wire == value) return m;
    }
    throw FormatException('authMethod tidak dikenal: $value');
  }
}
