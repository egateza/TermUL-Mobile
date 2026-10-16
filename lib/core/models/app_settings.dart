import 'json_fields.dart';

/// Pengaturan tampilan terminal. Nilai di luar batas dijepit ke batas terdekat (bukan dianggap rusak); tipe yang
/// salah (bukan angka) membuat berkas dianggap rusak.
class TerminalSettings {
  const TerminalSettings({this.fontSize = defaultFontSize, this.lineHeight = defaultLineHeight});

  static const defaultFontSize = 13.0;
  static const minFontSize = 8.0;
  static const maxFontSize = 24.0;

  static const defaultLineHeight = 1.3;
  static const minLineHeight = 1.0;
  static const maxLineHeight = 2.0;

  /// Ukuran huruf dalam sp.
  final double fontSize;

  /// Tinggi baris sebagai kelipatan ukuran huruf.
  final double lineHeight;

  factory TerminalSettings.fromJson(Map<String, Object?> json) => TerminalSettings(
    fontSize: _clamp(optNum(json, 'fontSize'), defaultFontSize, minFontSize, maxFontSize),
    lineHeight: _clamp(optNum(json, 'lineHeight'), defaultLineHeight, minLineHeight, maxLineHeight),
  );

  static double _clamp(double? v, double fallback, double min, double max) {
    if (v == null || v.isNaN) return fallback;
    return v.clamp(min, max);
  }

  Map<String, Object?> toJson() => {'fontSize': fontSize, 'lineHeight': lineHeight};

  @override
  bool operator ==(Object other) =>
      other is TerminalSettings && other.fontSize == fontSize && other.lineHeight == lineHeight;

  @override
  int get hashCode => Object.hash(fontSize, lineHeight);
}

/// Isi `settings.json`: `{"version": 1, "terminal": {"fontSize": 13, "lineHeight": 1.3}}`. Properti yang tidak
/// dikenal diabaikan. Untuk sekarang berkas ini diubah dengan tangan; layar pengaturan menyusul.
class AppSettings {
  const AppSettings({this.terminal = const TerminalSettings()});

  static const currentVersion = 1;

  final TerminalSettings terminal;

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final t = optObject(json, 'terminal');
    return AppSettings(terminal: t == null ? const TerminalSettings() : TerminalSettings.fromJson(t));
  }

  Map<String, Object?> toJson() => {'version': currentVersion, 'terminal': terminal.toJson()};
}
