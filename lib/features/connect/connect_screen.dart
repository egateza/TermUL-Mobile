import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/keys/private_key_inspector.dart';
import '../../core/models/auth_method.dart';
import '../../core/models/host_profile.dart';
import '../../core/ssh/ssh_failure.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/key_import_text.dart';
import '../../shared/widgets/status_dot.dart';
import '../../shared/widgets/termul_banner.dart';
import '../../shared/widgets/termul_button.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_icon_button.dart';
import '../../shared/widgets/termul_text_field.dart';
import '../terminal/terminal_palette.dart';
import '../terminal/terminal_screen.dart';
import '../settings/settings_screen.dart';
import '../sftp/sftp_screen.dart' show openSftpFromSession;
import 'connect_flow.dart';
import 'host_key_prompt.dart';
import 'session_controller.dart';
import 'session_manager.dart';

/// Layar alur sambung ke satu host: membuka rahasia, menyambung, meminta keputusan host key, dan menampilkan
/// kegagalan. Setelah tersambung, layar ini menampilkan [TerminalScreen]. Sesinya dimiliki [SessionController]:
/// layar yang ditutup biasa menutup sesinya, tetapi lewat "Tetap terhubung" sesi dibiarkan hidup di latar belakang
/// dan dibuka lagi dengan [controller].
class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key, required this.profile, this.controller});

  final HostProfile profile;

  /// Sesi yang sudah ada (dibuka lagi dari "Sesi aktif"); kosong = sesi baru.
  final SessionController? controller;

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  late final SessionManager _manager;
  SessionController? _c;

  /// Pengguna memilih "Tetap terhubung": sesi dibiarkan hidup saat layar ditutup.
  bool _keep = false;

  @override
  void initState() {
    super.initState();
    _manager = ref.read(sessionManagerProvider.notifier);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null) return;
    final existing = widget.controller;
    final SessionController controller;
    if (existing != null) {
      controller = existing;
      _manager.take(existing);
    } else {
      final l = AppLocalizations.of(context);
      controller = _manager.create(
        widget.profile,
        unlockReason: l.unlockReason(widget.profile.name),
        reconnectedMarker: l.reconnectedMarker,
      );
    }
    _c = controller;
    controller.addListener(_onController);
    controller.attach();
    // Sesi yang putus di latar belakang disambung ulang setelah frame ini, bukan di tengah penyusunan widget
    // (pendengar lain, mis. daftar sesi aktif, tidak boleh dibangun ulang saat itu).
    if (existing != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.reconnect();
      });
    }
    unawaited(_reloadSettings());
    if (existing == null) unawaited(controller.start());
  }

  /// Sesi ditutup dari luar (mis. "Putuskan semua" di notifikasi) selagi layar ini tampil: tutup layar.
  void _onController() {
    final c = _c;
    if (c == null || !c.ended || !mounted) return;
    final route = ModalRoute.of(context);
    if (route != null) Navigator.of(context).removeRoute(route);
  }

  @override
  void dispose() {
    final c = _c;
    if (c != null) {
      c.removeListener(_onController);
      c.detach();
      if (_keep && !c.ended && c.session != null) {
        _manager.keep(c);
      } else {
        _manager.release(c);
      }
    }
    super.dispose();
  }

  Future<void> _reloadSettings() async {
    try {
      final fresh = await ref.read(settingsLoaderProvider)();
      if (mounted) ref.read(appSettingsProvider.notifier).replace(fresh);
    } on Object {
      // Berkas tak terbaca: tetap memakai pengaturan yang sudah ada.
    }
  }

  void _leave() => Navigator.of(context).pop();

  /// "Tetap terhubung": tutup layar tanpa menutup sesi.
  void _keepInBackground() {
    _keep = true;
    Navigator.of(context).pop();
  }

  void _openSettings() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

  @override
  Widget build(BuildContext context) {
    final c = _c!;
    final flow = c.flow;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final state = flow.state;
        final session = c.session;
        final l = AppLocalizations.of(context);
        final settings = ref.watch(appSettingsProvider);
        final style = terminalStyleFor(settings.terminal);
        final handle = settings.terminal.handleStyle;
        final confirmPaste = settings.terminal.confirmSingleLinePaste;
        final keepAlive = settings.connection.keepAlive;
        if (session != null) {
          if (state is ConnectDone) {
            return TerminalScreen(
              profile: widget.profile,
              session: session,
              link: c.lost ? (c.probing ? TerminalLink.reconnecting : TerminalLink.lost) : TerminalLink.up,
              onReconnect: () => c.reconnect(manual: true),
              retryInSeconds: c.secondsUntilRetry,
              needsAuth: c.needsAuth,
              textStyle: style,
              handleStyle: handle,
              confirmSingleLinePaste: confirmPaste,
              onKeepInBackground: _keepInBackground,
              keepAliveEnabled: keepAlive,
              onOpenSettings: _openSettings,
              onOpenSftp: () => openSftpFromSession(context, c, confirmLeave: false),
            );
          }
          if (state is ConnectPreparing || state is ConnectConnecting) {
            return TerminalScreen(
              profile: widget.profile,
              session: session,
              link: TerminalLink.reconnecting,
              textStyle: style,
              handleStyle: handle,
              confirmSingleLinePaste: confirmPaste,
            );
          }
          if (state is ConnectFailed || state is ConnectAuthDenied) {
            return TerminalScreen(
              profile: widget.profile,
              session: session,
              link: TerminalLink.lost,
              failureText: _failureSummary(l, state),
              onReconnect: () => c.reconnect(manual: true),
              retryInSeconds: c.secondsUntilRetry,
              needsAuth: c.needsAuth,
              textStyle: style,
              handleStyle: handle,
              confirmSingleLinePaste: confirmPaste,
            );
          }
        }
        if (state is ConnectNeedsHostKey) {
          return HostKeyPrompt(profile: widget.profile, challenge: state.challenge, onChoice: flow.answerHostKey);
        }
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _Header(profile: widget.profile, onBack: _leave),
                Expanded(child: _body(context, flow, state)),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _failureSummary(AppLocalizations l, ConnectState state) => switch (state) {
    ConnectAuthDenied(:final cancelled) => cancelled ? l.authDeniedTitle : l.authUnavailableTitle,
    ConnectFailed(:final failure) => _failureText(l, failure).$1,
    _ => l.failUnknownTitle,
  };

  Widget _body(BuildContext context, ConnectFlow flow, ConnectState state) {
    final l = AppLocalizations.of(context);
    final name = widget.profile.name;
    switch (state) {
      case ConnectPreparing():
        return _Progress(label: l.connectPreparing, abortLabel: l.actionAbort, onAbort: _leave);
      case ConnectConnecting():
        return _Progress(label: l.connectConnecting(name), abortLabel: l.actionAbort, onAbort: _leave);
      case ConnectNeedsHostKey():
        return const SizedBox.shrink(); // ditangani di build
      case ConnectAuthDenied(:final cancelled):
        return _Message(
          title: cancelled ? l.authDeniedTitle : l.authUnavailableTitle,
          body: cancelled ? l.authDeniedBody : l.authUnavailableBody,
          icon: TermulIconName.lock,
          actions: [
            TermulButton(
              label: l.actionRetry,
              variant: TermulButtonVariant.primary,
              size: TermulButtonSize.lg,
              onPressed: () => unawaited(_c!.start()),
            ),
            TermulButton(label: l.actionBack, variant: TermulButtonVariant.ghost, onPressed: _leave),
          ],
        );
      case ConnectNeedsSecret():
        return _SecretForm(profile: widget.profile, state: state, flow: flow, onBack: _leave);
      case ConnectFailed(:final failure):
        final (title, body) = _failureText(l, failure);
        return _Message(
          title: title,
          body: body,
          icon: TermulIconName.warning,
          risk: true,
          actions: [
            TermulButton(
              label: l.actionRetry,
              variant: TermulButtonVariant.primary,
              size: TermulButtonSize.lg,
              onPressed: () => unawaited(_c!.start()),
            ),
            TermulButton(label: l.actionBack, variant: TermulButtonVariant.ghost, onPressed: _leave),
          ],
        );
      case ConnectDone():
        return const SizedBox.shrink(); // ditangani di build
    }
  }

  static (String, String) _failureText(AppLocalizations l, SshFailure f) => connectFailureText(l, f);
}

/// Judul dan keterangan untuk kegagalan menyambung; dipakai juga oleh layar SFTP.
(String, String) connectFailureText(AppLocalizations l, SshFailure f) => switch (f) {
  SshNetworkFailure() => (l.failNetworkTitle, l.failNetworkBody),
  SshHandshakeFailure() => (l.failHandshakeTitle, l.failHandshakeBody),
  SshAuthFailure() => (l.failAuthTitle, l.failAuthBody),
  SshHostKeyRejected(changed: true) => (l.failRejectedChangedTitle, l.failRejectedChangedBody),
  SshHostKeyRejected() => (l.failRejectedTitle, l.failRejectedBody),
  SshHostKeyStoreFailure() => (l.failStoreTitle, l.failStoreBody),
  SshKeyUnusable() || SshUnknownFailure() => (l.failUnknownTitle, l.failUnknownBody),
};

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.onBack});

  final HostProfile profile;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
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
            child: Text(
              '${profile.name} · ${profile.username}@${profile.host}:${profile.port}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TermulText.terminalSm.copyWith(color: TermulPalette.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.label, required this.abortLabel, required this.onAbort});

  final String label;
  final String abortLabel;
  final VoidCallback onAbort;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TermulSpacing.space8),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Semantics(
                liveRegion: true,
                child: StatusDot(status: HostStatus.busy, label: label),
              ),
            ),
          ),
          TermulButton(label: abortLabel, onPressed: onAbort),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.body,
    required this.icon,
    required this.actions,
    this.risk = false,
  });

  final String title;
  final String body;
  final TermulIconName icon;
  final List<Widget> actions;
  final bool risk;

  @override
  Widget build(BuildContext context) {
    final tone = risk ? TermulPalette.bad : TermulPalette.accent;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              TermulSpacing.space8,
              TermulSpacing.space5,
              TermulSpacing.space8,
              TermulSpacing.space9,
            ),
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: risk ? TermulPalette.badBg : TermulPalette.accentBg,
                  borderRadius: BorderRadius.circular(TermulRadius.radiusXl),
                  border: Border.all(color: risk ? TermulPalette.badLine : TermulPalette.accentLine),
                ),
                child: TermulIcon(icon, size: 28, color: tone),
              ),
              const SizedBox(height: TermulSpacing.space7),
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(title, style: TermulText.h1.copyWith(color: TermulPalette.ink)),
              ),
              const SizedBox(height: TermulSpacing.space3),
              Text(body, style: TermulText.body.copyWith(color: TermulPalette.inkSoft)),
            ],
          ),
        ),
        _Footer(children: actions),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        TermulSpacing.space8,
        TermulSpacing.space5,
        TermulSpacing.space8,
        TermulSpacing.space8,
      ),
      decoration: const BoxDecoration(
        color: TermulPalette.ground,
        border: Border(top: BorderSide(color: TermulPalette.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: TermulSpacing.space3),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Layar "Rahasia hilang": memasukkan ulang password, atau mengimpor ulang kunci beserta passphrase-nya.
/// Hasilnya langsung ke vault lewat [ConnectFlow.submitSecret] lalu sambungan diulang.
class _SecretForm extends ConsumerStatefulWidget {
  const _SecretForm({required this.profile, required this.state, required this.flow, required this.onBack});

  final HostProfile profile;
  final ConnectNeedsSecret state;
  final ConnectFlow flow;
  final VoidCallback onBack;

  @override
  ConsumerState<_SecretForm> createState() => _SecretFormState();
}

class _SecretFormState extends ConsumerState<_SecretForm> {
  final _password = TextEditingController();
  final _passphrase = TextEditingController();
  InspectedKey? _picked;
  String? _keyError;
  String? _fieldError;
  bool _busy = false;

  bool get _isKey => widget.state.method == AuthMethod.key;

  @override
  void dispose() {
    _password.dispose();
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _pickKey() async {
    try {
      final bytes = await ref.read(keyFilePickerProvider).pick();
      if (bytes == null) return;
      final key = PrivateKeyInspector.inspect(bytes);
      setState(() {
        _picked = key;
        _keyError = null;
        _fieldError = null;
        _passphrase.clear();
      });
    } on KeyImportException catch (e) {
      setState(() {
        _picked = null;
        _keyError = keyErrorText(AppLocalizations.of(context), e);
      });
    }
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    if (_isKey) {
      final key = _picked;
      if (key == null) {
        setState(() => _fieldError = l.errKeyRequired);
        return;
      }
      if (key.encrypted) {
        setState(() => _busy = true);
        await Future<void>.delayed(const Duration(milliseconds: 16)); // beri layar kesempatan menggambar
        try {
          PrivateKeyInspector.verifyPassphrase(key.pem, _passphrase.text);
        } on KeyImportException {
          if (mounted) {
            setState(() {
              _busy = false;
              _fieldError = l.errPassphraseWrong;
            });
          }
          return;
        }
      }
      setState(() => _busy = true);
      await widget.flow.submitSecret(privateKeyPem: key.pem, passphrase: _passphrase.text);
    } else {
      if (_password.text.isEmpty) {
        setState(() => _fieldError = l.errPasswordRequired);
        return;
      }
      setState(() => _busy = true);
      await widget.flow.submitSecret(password: _password.text);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = widget.profile.name;
    final picked = _picked;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              TermulSpacing.space8,
              TermulSpacing.space5,
              TermulSpacing.space8,
              TermulSpacing.space9,
            ),
            children: [
              Semantics(
                header: true,
                child: Text(l.secretMissingTitle, style: TermulText.h1.copyWith(color: TermulPalette.ink)),
              ),
              const SizedBox(height: TermulSpacing.space3),
              Text(
                widget.state.wrongPassphrase
                    ? l.secretWrongPassphraseBody
                    : (_isKey ? l.secretMissingKeyBody(name) : l.secretMissingPasswordBody(name)),
                style: TermulText.body.copyWith(color: TermulPalette.inkSoft),
              ),
              const SizedBox(height: TermulSpacing.space8),
              if (!_isKey)
                TermulTextField(
                  label: l.fieldPassword,
                  controller: _password,
                  obscure: true,
                  mono: true,
                  autofocus: true,
                  error: _fieldError,
                  enabled: !_busy,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                )
              else ...[
                TermulButton(
                  label: picked == null ? l.keyImport : l.keyReplace,
                  icon: TermulIconName.key,
                  onPressed: _busy ? null : _pickKey,
                ),
                if (picked != null)
                  Padding(
                    padding: const EdgeInsets.only(top: TermulSpacing.space3),
                    child: Text(
                      l.keyReady(keyTypeLabel(picked.type)),
                      style: TermulText.caption.copyWith(color: TermulPalette.ok),
                    ),
                  ),
                if (_fieldError != null && (picked == null || !picked.encrypted))
                  Padding(
                    padding: const EdgeInsets.only(top: TermulSpacing.space3),
                    child: Text(_fieldError!, style: TermulText.caption.copyWith(color: TermulPalette.bad)),
                  ),
                if (_keyError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: TermulSpacing.space5),
                    child: TermulBanner(tone: BannerTone.risk, child: Text(_keyError!)),
                  ),
                if (picked != null && picked.encrypted) ...[
                  const SizedBox(height: TermulSpacing.space6),
                  Text(l.keyPassphraseEncrypted, style: TermulText.bodySm.copyWith(color: TermulPalette.inkSoft)),
                  const SizedBox(height: TermulSpacing.space3),
                  TermulTextField(
                    label: l.fieldPassphrase,
                    controller: _passphrase,
                    obscure: true,
                    mono: true,
                    error: _fieldError,
                    enabled: !_busy,
                  ),
                ],
              ],
            ],
          ),
        ),
        _Footer(
          children: [
            TermulButton(
              label: l.actionSaveAndConnect,
              variant: TermulButtonVariant.primary,
              size: TermulButtonSize.lg,
              onPressed: _busy ? null : _submit,
            ),
            TermulButton(
              label: l.actionBack,
              variant: TermulButtonVariant.ghost,
              onPressed: _busy ? null : widget.onBack,
            ),
          ],
        ),
      ],
    );
  }
}
