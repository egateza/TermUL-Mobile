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

/// Pengaturan koneksi. [keepAlive]: foreground service yang menjaga proses tidak dibekukan Android selama ada sesi
/// aktif (default mati; `docs/design/android.md`). Tipe yang salah (bukan boolean) membuat berkas dianggap rusak.
class ConnectionSettings {
  const ConnectionSettings({this.keepAlive = false});

  final bool keepAlive;

  factory ConnectionSettings.fromJson(Map<String, Object?> json) =>
      ConnectionSettings(keepAlive: optBool(json, 'keepAlive') ?? false);

  Map<String, Object?> toJson() => {'keepAlive': keepAlive};

  @override
  bool operator ==(Object other) => other is ConnectionSettings && other.keepAlive == keepAlive;

  @override
  int get hashCode => keepAlive.hashCode;
}

/// Isi `settings.json`:
/// `{"version": 1, "terminal": {"fontSize": 13, "lineHeight": 1.3}, "connection": {"keepAlive": false}}`.
/// Properti yang tidak dikenal diabaikan; bagian yang hilang memakai bawaan.
class AppSettings {
  const AppSettings({this.terminal = const TerminalSettings(), this.connection = const ConnectionSettings()});

  static const currentVersion = 1;

  final TerminalSettings terminal;
  final ConnectionSettings connection;

  AppSettings copyWith({TerminalSettings? terminal, ConnectionSettings? connection}) =>
      AppSettings(terminal: terminal ?? this.terminal, connection: connection ?? this.connection);

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final t = optObject(json, 'terminal');
    final c = optObject(json, 'connection');
    return AppSettings(
      terminal: t == null ? const TerminalSettings() : TerminalSettings.fromJson(t),
      connection: c == null ? const ConnectionSettings() : ConnectionSettings.fromJson(c),
    );
  }

  Map<String, Object?> toJson() => {
    'version': currentVersion,
    'terminal': terminal.toJson(),
    'connection': connection.toJson(),
  };
}
