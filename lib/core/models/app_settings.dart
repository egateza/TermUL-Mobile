import 'json_fields.dart';
import 'quick_key_settings.dart';

export 'quick_key_settings.dart';

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

/// Pengaturan streak api. [show]: chip dan splash tampil (hari tetap dihitung walau mati). [reminder]: notifikasi
/// pukul 20.00 bila hari itu aplikasi belum dibuka. Keduanya bawaan menyala (prototipe `Settings`).
class StreakSettings {
  const StreakSettings({this.show = true, this.reminder = true});

  final bool show;
  final bool reminder;

  StreakSettings copyWith({bool? show, bool? reminder}) =>
      StreakSettings(show: show ?? this.show, reminder: reminder ?? this.reminder);

  factory StreakSettings.fromJson(Map<String, Object?> json) =>
      StreakSettings(show: optBool(json, 'show') ?? true, reminder: optBool(json, 'reminder') ?? true);

  Map<String, Object?> toJson() => {'show': show, 'reminder': reminder};

  @override
  bool operator ==(Object other) => other is StreakSettings && other.show == show && other.reminder == reminder;

  @override
  int get hashCode => Object.hash(show, reminder);
}

/// Pembaruan dari GitHub Releases. [autoCheck]: periksa saat aplikasi dibuka dan tiap 12 jam selama terbuka (seperti
/// desktop "Periksa update otomatis"); bawaan menyala. Memasang selalu manual.
class UpdateSettings {
  const UpdateSettings({this.autoCheck = true});

  final bool autoCheck;

  UpdateSettings copyWith({bool? autoCheck}) => UpdateSettings(autoCheck: autoCheck ?? this.autoCheck);

  factory UpdateSettings.fromJson(Map<String, Object?> json) =>
      UpdateSettings(autoCheck: optBool(json, 'autoCheck') ?? true);

  Map<String, Object?> toJson() => {'autoCheck': autoCheck};

  @override
  bool operator ==(Object other) => other is UpdateSettings && other.autoCheck == autoCheck;

  @override
  int get hashCode => autoCheck.hashCode;
}

/// Pengaturan editor file di SFTP. Editor aktif secara bawaan; pola ekstensi awal mengikuti prototipe SFTP.
class SftpEditorSettings {
  const SftpEditorSettings({this.enabled = true, this.extensions = defaultExtensions});

  static const defaultExtensions = ['*.conf', '*.txt', '*.log', '*.json', '*.yml'];

  final bool enabled;
  final List<String> extensions;

  SftpEditorSettings copyWith({bool? enabled, List<String>? extensions}) => SftpEditorSettings(
    enabled: enabled ?? this.enabled,
    extensions: extensions == null ? this.extensions : List.unmodifiable(extensions),
  );

  /// Menormalkan masukan menjadi pola ekstensi sederhana, misalnya `.yaml` atau `yaml` menjadi `*.yaml`.
  /// Wildcard lain, pemisah jalur, dan nama kosong ditolak.
  static String? normalizePattern(String input) {
    var value = input.trim().toLowerCase();
    if (value.startsWith('*.')) {
      value = value.substring(2);
    } else if (value.startsWith('.')) {
      value = value.substring(1);
    }
    if (value.isEmpty ||
        value.contains('*') ||
        value.contains('?') ||
        value.contains('/') ||
        value.contains('\\') ||
        value.contains(RegExp(r'\s')) ||
        !RegExp(r'^[a-z0-9][a-z0-9._+-]*$').hasMatch(value)) {
      return null;
    }
    return '*.$value';
  }

  bool allows(String fileName) {
    final name = fileName.toLowerCase();
    return extensions.any((pattern) {
      final normalized = normalizePattern(pattern);
      return normalized != null && name.endsWith(normalized.substring(1));
    });
  }

  factory SftpEditorSettings.fromJson(Map<String, Object?> json) {
    final extensions = json.containsKey('extensions') ? stringList(json, 'extensions') : defaultExtensions;
    for (final pattern in extensions) {
      if (normalizePattern(pattern) != pattern.toLowerCase()) {
        throw const FormatException('Pola ekstensi editor SFTP tidak valid');
      }
    }
    return SftpEditorSettings(enabled: optBool(json, 'enabled') ?? true, extensions: List.unmodifiable(extensions));
  }

  Map<String, Object?> toJson() => {'enabled': enabled, 'extensions': extensions};

  @override
  bool operator ==(Object other) =>
      other is SftpEditorSettings &&
      other.enabled == enabled &&
      other.extensions.length == extensions.length &&
      other.extensions.asMap().entries.every((entry) => extensions[entry.key] == entry.value);

  @override
  int get hashCode => Object.hash(enabled, Object.hashAll(extensions));
}

/// Isi `settings.json`:
/// `{"version": 1, "terminal": {"fontSize": 13, "lineHeight": 1.3, "handleStyle": "drop"}, "connection": {"keepAlive": false, "autoReconnect": true}}`.
/// Properti yang tidak dikenal diabaikan; bagian yang hilang memakai bawaan.
class AppSettings {
  const AppSettings({
    this.terminal = const TerminalSettings(),
    this.connection = const ConnectionSettings(),
    this.security = const SecuritySettings(),
    this.streak = const StreakSettings(),
    this.update = const UpdateSettings(),
    this.sftpEditor = const SftpEditorSettings(),
    this.quickKeys = const QuickKeySettings(),
  });

  static const currentVersion = 1;

  final TerminalSettings terminal;
  final ConnectionSettings connection;
  final SecuritySettings security;
  final StreakSettings streak;
  final UpdateSettings update;
  final SftpEditorSettings sftpEditor;
  final QuickKeySettings quickKeys;

  AppSettings copyWith({
    TerminalSettings? terminal,
    ConnectionSettings? connection,
    SecuritySettings? security,
    StreakSettings? streak,
    UpdateSettings? update,
    SftpEditorSettings? sftpEditor,
    QuickKeySettings? quickKeys,
  }) => AppSettings(
    terminal: terminal ?? this.terminal,
    connection: connection ?? this.connection,
    security: security ?? this.security,
    streak: streak ?? this.streak,
    update: update ?? this.update,
    sftpEditor: sftpEditor ?? this.sftpEditor,
    quickKeys: quickKeys ?? this.quickKeys,
  );

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final t = optObject(json, 'terminal');
    final c = optObject(json, 'connection');
    final s = optObject(json, 'security');
    final k = optObject(json, 'streak');
    final u = optObject(json, 'update');
    final e = optObject(json, 'sftpEditor');
    final q = optObject(json, 'quickKeys');
    return AppSettings(
      terminal: t == null ? const TerminalSettings() : TerminalSettings.fromJson(t),
      connection: c == null ? const ConnectionSettings() : ConnectionSettings.fromJson(c),
      security: s == null ? const SecuritySettings() : SecuritySettings.fromJson(s),
      streak: k == null ? const StreakSettings() : StreakSettings.fromJson(k),
      update: u == null ? const UpdateSettings() : UpdateSettings.fromJson(u),
      sftpEditor: e == null ? const SftpEditorSettings() : SftpEditorSettings.fromJson(e),
      quickKeys: q == null ? const QuickKeySettings() : QuickKeySettings.fromJson(q),
    );
  }

  Map<String, Object?> toJson() => {
    'version': currentVersion,
    'terminal': terminal.toJson(),
    'connection': connection.toJson(),
    'security': security.toJson(),
    'streak': streak.toJson(),
    'update': update.toJson(),
    'sftpEditor': sftpEditor.toJson(),
    'quickKeys': quickKeys.toJson(),
  };
}
