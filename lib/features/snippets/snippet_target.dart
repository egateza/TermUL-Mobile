import '../../l10n/app_localizations.dart';
import '../connect/session_controller.dart';
import '../terminal/paste_analysis.dart';
import '../terminal/terminal_session.dart';

/// Sesi terminal yang bisa menerima perintah dari snippet ("Kirim ke").
class SnippetTarget {
  const SnippetTarget({required this.id, required this.label, required this.send});

  /// Pembeda antar tujuan (dan kunci uji); untuk sesi, id sesinya.
  final String id;

  /// Nama yang tampil di chip dan tombol: nama host, dengan nomor sesi bila ada beberapa sesi ke host yang sama.
  final String label;

  /// Mengirim [text] ke terminal tujuan. [run] menambahkan Enter di akhir; tanpa itu perintah hanya ditempel di prompt
  /// dan pengguna menekan Enter sendiri.
  final void Function(String text, {required bool run}) send;
}

/// Tujuan untuk [session]. Teks dibersihkan seperti tempel dari papan klip (karakter kontrol berbahaya dibuang, baris
/// baru menjadi Enter) dan dibungkus tempel aman hanya bila program di server menyalakannya.
SnippetTarget sessionTarget({required String id, required String label, required TerminalSession session}) {
  return SnippetTarget(
    id: id,
    label: label,
    send: (text, {required run}) {
      // Enter penutup ditambahkan sendiri; baris baru di ujung perintah tidak boleh menggandakannya.
      final body = run ? text.replaceFirst(RegExp(r'[\r\n]+$'), '') : text;
      final analysis = PasteAnalysis.of(body, bracketed: session.terminal.bracketedPasteMode);
      if (analysis.isEmpty) return;
      session.paste(analysis.outgoing);
      if (run) session.pressText('\r');
    },
  );
}

/// Nama sesi seperti di tab Sesi: nama host, ditambah nomor bila ada beberapa sesi ke host yang sama.
String sessionLabel(AppLocalizations l, SessionController c) =>
    c.ordinal > 1 ? '${c.profile.name} · ${l.sessionsNumber(c.ordinal)}' : c.profile.name;

/// Sesi di latar belakang yang siap menerima perintah: tersambung dan shell-nya berjalan. [onlyHostId] membatasi ke
/// satu host (snippet yang berlaku untuk satu host saja); null = semua host.
List<SnippetTarget> keptSessionTargets(AppLocalizations l, List<SessionController> sessions, {String? onlyHostId}) {
  return [
    for (final c in sessions)
      if (c.session != null &&
          c.phase == SessionPhase.connected &&
          c.session!.state == TerminalSessionState.running &&
          (onlyHostId == null || c.profile.id == onlyHostId))
        sessionTarget(id: '${c.id}', label: sessionLabel(l, c), session: c.session!),
  ];
}
