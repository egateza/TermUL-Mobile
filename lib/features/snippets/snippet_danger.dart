import '../../core/models/snippet.dart';
import '../terminal/paste_analysis.dart';

/// Perintah [command] (satu atau beberapa baris) memuat pola yang merusak bila salah jalan, mis. `rm -rf`, `dd`,
/// `mkfs`. Memakai deteksi yang sama dengan peringatan tempel di terminal.
bool commandLooksDangerous(String command) => command.split('\n').any(PasteAnalysis.isRisky);

/// Snippet dianggap berbahaya bila ditandai pemilik atau terdeteksi otomatis.
bool snippetIsDangerous(Snippet s) => s.dangerous || commandLooksDangerous(s.command);
