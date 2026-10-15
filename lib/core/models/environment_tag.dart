/// Tag environment server. Nilai JSON sama dengan desktop. Mobile belum memakainya untuk guard.
enum EnvironmentTag {
  prod('PROD'),
  staging('STAGING'),
  dev('DEV'),
  none('NONE');

  const EnvironmentTag(this.wire);

  final String wire;

  static EnvironmentTag parse(String value) {
    for (final t in values) {
      if (t.wire == value) return t;
    }
    throw FormatException('environment tidak dikenal: $value');
  }
}
