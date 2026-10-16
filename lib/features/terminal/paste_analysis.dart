/// Satu baris teks yang akan ditempel.
class PasteLine {
  const PasteLine({required this.number, required this.text, required this.risky});

  final int number;
  final String text;
  final bool risky;
}

/// Hasil pemeriksaan teks dari papan klip sebelum ditempel ke terminal (layar 2b dan 2c di desain).
///
/// Aturan: tempel satu baris tanpa tanda bahaya langsung masuk ke prompt; selain itu (banyak baris, baris
/// berakhir dengan baris baru, ada perintah berisiko, atau ada karakter kontrol yang dibuang) pengguna
/// melihat isi dan akibatnya lebih dulu.
class PasteAnalysis {
  PasteAnalysis._({
    required this.text,
    required this.lines,
    required this.removedControls,
    required this.hasNewline,
    required this.bracketed,
  });

  /// Teks bersih yang akan dikirim: akhir baris dinormalkan ke `\n`, karakter kontrol berbahaya dibuang.
  final String text;
  final List<PasteLine> lines;

  /// Jumlah karakter kontrol yang dibuang (mis. `ESC`, yang bisa dipakai menyuntik perintah terminal).
  final int removedControls;

  /// Teks mengandung baris baru (di tengah atau di akhir).
  final bool hasNewline;

  /// Terminal sedang dalam mode tempel aman (bracketed paste): baris baru tidak langsung dijalankan.
  final bool bracketed;

  int get lineCount => lines.length;

  int get riskCount => lines.where((l) => l.risky).length;

  bool get hasRisk => riskCount > 0;

  /// Tempel banyak baris tanpa tempel aman: setiap baris dijalankan begitu ditempel (bash di bawah 5.1).
  bool get runsImmediately => hasNewline && !bracketed;

  bool get isEmpty => text.isEmpty;

  /// Perlu konfirmasi sebelum ditempel.
  bool get needsConfirm => hasNewline || hasRisk || removedControls > 0;

  /// Pilihan aman (Batal) jadi tombol utama bila ada akibat yang merugikan.
  bool get cancelIsPrimary => hasRisk || runsImmediately;

  /// Teks yang dikirim ke terminal: baris baru sebagai `\r` seperti Enter di terminal sungguhan.
  String get outgoing => text.replaceAll('\n', '\r');

  /// Batas ukuran yang masih ditempel (mencegah UI macet oleh isi papan klip yang sangat besar).
  static const maxChars = 100000;

  static final _risk = RegExp(
    r'\brm\s+-[a-z]*[rf]|\bdd\s+if=|\bmkfs|\bshutdown\b|\breboot\b|\bchmod\s+-R|\bchown\s+-R|\btruncate\b|\bdrop\s+(table|database)\b',
    caseSensitive: false,
  );

  /// Karakter kontrol C0 selain tab dan baris baru, serta DEL dan C1.
  static final _controls = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\x80-\x9F]');

  /// Memeriksa [raw] dari papan klip. [bracketed] = `terminal.bracketedPasteMode`.
  factory PasteAnalysis.of(String raw, {required bool bracketed}) {
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final removed = _controls.allMatches(normalized).length;
    final text = normalized.replaceAll(_controls, '');
    final split = text.isEmpty ? <String>[] : text.split('\n');
    // Satu baris baru di akhir tidak menambah jumlah baris yang tampak.
    if (split.length > 1 && split.last.isEmpty) split.removeLast();
    final lines = [
      for (var i = 0; i < split.length; i++) PasteLine(number: i + 1, text: split[i], risky: _risk.hasMatch(split[i])),
    ];
    return PasteAnalysis._(
      text: text,
      lines: lines,
      removedControls: removed,
      hasNewline: text.contains('\n'),
      bracketed: bracketed,
    );
  }
}
