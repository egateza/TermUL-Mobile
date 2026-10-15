import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../../core/models/host_profile.dart';
import '../../core/ssh/ssh_connector.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/status_dot.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_icon_button.dart';
import '../../shared/widgets/termul_sheet.dart';
import 'quick_key_bar.dart';
import 'shell_channel.dart';
import 'terminal_palette.dart';
import 'terminal_session.dart';

/// Layar terminal satu host. [connection] dimiliki pemanggil (yang menutupnya); layar ini hanya menutup shell-nya.
/// Layar yang tingginya (di luar keyboard) kurang dari 480 dp memakai mode ringkas: tanpa header, satu baris
/// status, dan tombol cepat 36 dp (landscape).
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key, required this.profile, required this.connection, this.openShell});

  final HostProfile profile;
  final SshConnection connection;

  /// Hanya untuk tes: pengganti pembuka shell.
  final ShellOpener? openShell;

  static const compactBelowDp = 480.0;

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final TerminalSession _session = TerminalSession(
    open:
        widget.openShell ??
        ({required columns, required rows}) => SshShellChannel.open(widget.connection, columns: columns, rows: rows),
  );
  final _controller = TerminalController();

  @override
  void initState() {
    super.initState();
    // Buka shell setelah layout pertama supaya PTY langsung berukuran layar sebenarnya, bukan 80x24.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _session.start();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _session.dispose();
    super.dispose();
  }

  bool get _alive =>
      !widget.connection.isClosed &&
      (_session.state == TerminalSessionState.opening || _session.state == TerminalSessionState.running);

  Future<void> _confirmLeave() async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    await showTermulSheet<void>(
      context,
      title: l.terminalLeaveTitle,
      child: Text(l.terminalLeaveBody, style: TermulText.body.copyWith(color: TermulPalette.inkSoft)),
      cancelLabel: l.actionCancel,
      confirmLabel: l.actionDisconnect,
      confirmIsDanger: true,
      onConfirm: navigator.pop,
    );
  }

  (HostStatus, String) _status(AppLocalizations l) => switch (_session.state) {
    TerminalSessionState.opening => (HostStatus.busy, l.terminalStatusOpening),
    TerminalSessionState.running => (HostStatus.online, l.terminalStatusConnected),
    TerminalSessionState.ended => (HostStatus.offline, l.terminalStatusEnded),
    TerminalSessionState.failed => (HostStatus.offline, l.terminalStatusFailed),
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mq = MediaQuery.of(context);
    final compact = mq.size.height - mq.viewInsets.bottom < TerminalScreen.compactBelowDp;
    final keyboardOpen = mq.viewInsets.bottom > 0;
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final (status, word) = _status(l);
        return PopScope(
          canPop: !_alive,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmLeave();
          },
          child: Scaffold(
            backgroundColor: TermulPalette.ground,
            body: Column(
              children: [
                if (compact)
                  _CompactBar(
                    profile: widget.profile,
                    status: status,
                    word: word,
                    showBack: !keyboardOpen,
                    onBack: Navigator.of(context).maybePop,
                  )
                else
                  _Header(profile: widget.profile, status: status, word: word, onBack: Navigator.of(context).maybePop),
                Expanded(
                  // TerminalView mengurangi MediaQuery.padding dari tinggi barisnya; buang padding atas dan bawah
                  // supaya tidak terpotong dua kali (spike K5). Sisi kiri-kanan tetap dijaga (lekukan layar).
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      removeBottom: true,
                      child: TerminalView(
                        _session.terminal,
                        controller: _controller,
                        theme: termulTerminalTheme,
                        textStyle: termulTerminalStyle,
                        padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space2),
                        autofocus: true,
                        backgroundOpacity: 1,
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: QuickKeyBar(session: _session, compact: compact),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.status, required this.word, required this.onBack});

  final HostProfile profile;
  final HostStatus status;
  final String word;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TermulSpacing.space3,
          TermulSpacing.space5,
          TermulSpacing.space8,
          TermulSpacing.space3,
        ),
        child: Row(
          children: [
            TermulIconButton(icon: TermulIconName.chevronLeft, label: l.actionBack, onPressed: onBack),
            const SizedBox(width: TermulSpacing.space3),
            Expanded(
              child: Semantics(
                container: true,
                label: l.terminalHostLabel(profile.name, word),
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TermulText.title.copyWith(color: TermulPalette.ink),
                    ),
                    const SizedBox(height: 2),
                    StatusDot(status: status, label: word),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pengganti header di landscape: satu baris 20 dp (keyboard terbuka) atau 32 dp dengan tombol kembali.
class _CompactBar extends StatelessWidget {
  const _CompactBar({
    required this.profile,
    required this.status,
    required this.word,
    required this.showBack,
    required this.onBack,
  });

  final HostProfile profile;
  final HostStatus status;
  final String word;
  final bool showBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: showBack ? 32 : 20,
        child: Row(
          children: [
            if (showBack)
              Pressable(
                onPressed: onBack,
                semanticLabel: l.actionBack,
                minWidth: 32,
                minHeight: 32,
                builder: (context, pressed) => SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(
                    child: TermulIcon(
                      TermulIconName.chevronLeft,
                      size: 18,
                      color: pressed ? TermulPalette.accent : TermulPalette.ink,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: TermulSpacing.space5),
            Expanded(
              child: Text(
                profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TermulText.caption.copyWith(color: TermulPalette.inkSoft),
              ),
            ),
            StatusDot(status: status, label: word),
            const SizedBox(width: TermulSpacing.space5),
          ],
        ),
      ),
    );
  }
}
