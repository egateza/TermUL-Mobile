import 'json_fields.dart';

/// Bentuk gagang seleksi teks di terminal. Tambahan di luar desain (desain hanya menggambar satu bentuk).
enum SelectionHandleStyle {
  /// Tetesan air: bulatan dengan ujung runcing di atas (bawaan).
  drop,

  /// Bulatan dengan segitiga terpisah di atasnya; sisi bawah segitiga melengkung mengikuti bulatan.
  triangle,

  /// Bulatan polos.
  dot;

  static SelectionHandleStyle parse(String? name) =>
      values.firstWhere((s) => s.name == name, orElse: () => SelectionHandleStyle.drop);
}

/// Pengaturan tampilan terminal. Nilai di luar batas dijepit ke batas terdekat (bukan dianggap rusak); tipe yang
/// salah (bukan angka) membuat berkas dianggap rusak.
class TerminalSettings {
  const TerminalSettings({
    this.fontSize = defaultFontSize,
    this.lineHeight = defaultLineHeight,
    this.handleStyle = SelectionHandleStyle.drop,
    this.confirmSingleLinePaste = true,
  });

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

  /// Bentuk gagang seleksi teks.
  final SelectionHandleStyle handleStyle;

  /// Tempel satu baris pendek yang aman ditampilkan di popover dulu (nyala) atau langsung masuk ke prompt (mati).
  /// Teks panjang, banyak baris, atau berisiko selalu lewat dialog konfirmasi, apa pun nilainya.
  final bool confirmSingleLinePaste;

  TerminalSettings copyWith({
    double? fontSize,
    double? lineHeight,
    SelectionHandleStyle? handleStyle,
    bool? confirmSingleLinePaste,
  }) => TerminalSettings(
    fontSize: fontSize ?? this.fontSize,
    lineHeight: lineHeight ?? this.lineHeight,
    handleStyle: handleStyle ?? this.handleStyle,
    confirmSingleLinePaste: confirmSingleLinePaste ?? this.confirmSingleLinePaste,
  );

  factory TerminalSettings.fromJson(Map<String, Object?> json) => TerminalSettings(
    fontSize: _clamp(optNum(json, 'fontSize'), defaultFontSize, minFontSize, maxFontSize),
    lineHeight: _clamp(optNum(json, 'lineHeight'), defaultLineHeight, minLineHeight, maxLineHeight),
    handleStyle: SelectionHandleStyle.parse(optString(json, 'handleStyle')),
    confirmSingleLinePaste: optBool(json, 'confirmSingleLinePaste') ?? true,
  );

  static double _clamp(double? v, double fallback, double min, double max) {
    if (v == null || v.isNaN) return fallback;
    return v.clamp(min, max);
  }

  Map<String, Object?> toJson() => {
    'fontSize': fontSize,
    'lineHeight': lineHeight,
    'handleStyle': handleStyle.name,
    'confirmSingleLinePaste': confirmSingleLinePaste,
  };

  @override
  bool operator ==(Object other) =>
      other is TerminalSettings &&
      other.fontSize == fontSize &&
      other.lineHeight == lineHeight &&
      other.handleStyle == handleStyle &&
      other.confirmSingleLinePaste == confirmSingleLinePaste;

  @override
  int get hashCode => Object.hash(fontSize, lineHeight, handleStyle, confirmSingleLinePaste);
}

/// Pengaturan koneksi. [keepAlive]: foreground service yang menjaga proses tidak dibekukan Android selama ada sesi
/// aktif (default mati; `docs/design/android.md`). Tipe yang salah (bukan boolean) membuat berkas dianggap rusak.
class ConnectionSettings {
  const ConnectionSettings({this.keepAlive = false, this.autoReconnect = true});

  final bool keepAlive;

  /// Sambung ulang otomatis saat sambungan putus. Mati: sesi menampilkan "Terputus" dan menunggu "Sambung sekarang".
  final bool autoReconnect;

  ConnectionSettings copyWith({bool? keepAlive, bool? autoReconnect}) =>
      ConnectionSettings(keepAlive: keepAlive ?? this.keepAlive, autoReconnect: autoReconnect ?? this.autoReconnect);

  factory ConnectionSettings.fromJson(Map<String, Object?> json) => ConnectionSettings(
    keepAlive: optBool(json, 'keepAlive') ?? false,
    autoReconnect: optBool(json, 'autoReconnect') ?? true,
  );

  Map<String, Object?> toJson() => {'keepAlive': keepAlive, 'autoReconnect': autoReconnect};

  @override
  bool operator ==(Object other) =>
      other is ConnectionSettings && other.keepAlive == keepAlive && other.autoReconnect == autoReconnect;

  @override
  int get hashCode => Object.hash(keepAlive, autoReconnect);
}

/// Pengaturan keamanan. [vaultAlwaysOpen]: rahasia dibaca untuk sambung tanpa prompt autentikasi perangkat
/// (default mati; keputusan pemilik 2026-10-17, melonggarkan gerbang biometrik).
class SecuritySettings {
  const SecuritySettings({this.vaultAlwaysOpen = false});

  final bool vaultAlwaysOpen;

  SecuritySettings copyWith({bool? vaultAlwaysOpen}) =>
      SecuritySettings(vaultAlwaysOpen: vaultAlwaysOpen ?? this.vaultAlwaysOpen);

  factory SecuritySettings.fromJson(Map<String, Object?> json) =>
      SecuritySettings(vaultAlwaysOpen: optBool(json, 'vaultAlwaysOpen') ?? false);

  Map<String, Object?> toJson() => {'vaultAlwaysOpen': vaultAlwaysOpen};

  @override
  bool operator ==(Object other) => other is SecuritySettings && other.vaultAlwaysOpen == vaultAlwaysOpen;

  @override
  int get hashCode => vaultAlwaysOpen.hashCode;
}

/// Isi `settings.json`:
/// `{"version": 1, "terminal": {"fontSize": 13, "lineHeight": 1.3, "handleStyle": "drop"}, "connection": {"keepAlive": false, "autoReconnect": true}}`.
/// Properti yang tidak dikenal diabaikan; bagian yang hilang memakai bawaan.
class AppSettings {
  const AppSettings({
    this.terminal = const TerminalSettings(),
    this.connection = const ConnectionSettings(),
    this.security = const SecuritySettings(),
  });

  static const currentVersion = 1;

  final TerminalSettings terminal;
  final ConnectionSettings connection;
  final SecuritySettings security;

  AppSettings copyWith({TerminalSettings? terminal, ConnectionSettings? connection, SecuritySettings? security}) =>
      AppSettings(
        terminal: terminal ?? this.terminal,
        connection: connection ?? this.connection,
        security: security ?? this.security,
      );

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final t = optObject(json, 'terminal');
    final c = optObject(json, 'connection');
    final s = optObject(json, 'security');
    return AppSettings(
      terminal: t == null ? const TerminalSettings() : TerminalSettings.fromJson(t),
      connection: c == null ? const ConnectionSettings() : ConnectionSettings.fromJson(c),
      security: s == null ? const SecuritySettings() : SecuritySettings.fromJson(s),
    );
  }

  Map<String, Object?> toJson() => {
    'version': currentVersion,
    'terminal': terminal.toJson(),
    'connection': connection.toJson(),
    'security': security.toJson(),
  };
}
