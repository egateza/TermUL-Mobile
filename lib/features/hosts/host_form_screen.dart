import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app_providers.dart';
import '../../core/keys/private_key_inspector.dart';
import '../../core/models/auth_method.dart';
import '../../core/models/host_profile.dart';
import '../../core/theme/termul_theme.dart';
import '../../core/vault/credential_vault.dart';
import '../../core/vault/secret_type.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/key_import_text.dart';
import '../../shared/widgets/termul_banner.dart';
import '../../shared/widgets/termul_button.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_icon_button.dart';
import '../../shared/widgets/termul_segmented.dart';
import '../../shared/widgets/termul_text_field.dart';
import '../../shared/widgets/termul_toast.dart';
import 'host_service.dart';

/// Form tambah atau ubah host. Metode login hanya Password atau Kunci (profil agen dari desktop dilengkapi di sini).
/// Rahasia yang diketik atau diimpor langsung ke vault lewat [HostService]; tidak disimpan di profil.
class HostFormScreen extends ConsumerStatefulWidget {
  const HostFormScreen({super.key, this.existing});

  final HostProfile? existing;

  @override
  ConsumerState<HostFormScreen> createState() => _HostFormScreenState();
}

class _HostFormScreenState extends ConsumerState<HostFormScreen> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _host = TextEditingController(text: widget.existing?.host);
  late final _port = TextEditingController(text: '${widget.existing?.port ?? HostProfile.defaultPort}');
  late final _user = TextEditingController(text: widget.existing?.username);
  late final _group = TextEditingController(text: widget.existing?.group);
  final _password = TextEditingController();
  final _passphrase = TextEditingController();

  late AuthMethod _method = widget.existing?.authMethod == AuthMethod.key ? AuthMethod.key : AuthMethod.password;
  InspectedKey? _picked;
  String? _keyError;
  bool _hasStoredPassword = false;
  bool _hasStoredKey = false;
  bool _saving = false;
  bool _saveFailed = false;
  final _errors = <String, String>{};

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) _loadStoredFlags(existing.id);
  }

  Future<void> _loadStoredFlags(String id) async {
    final vault = ref.read(credentialVaultProvider);
    try {
      final pw = await vault.has(id, SecretType.loginPassword);
      final key = await vault.has(id, SecretType.privateKeyPem);
      if (mounted) {
        setState(() {
          _hasStoredPassword = pw;
          _hasStoredKey = key;
        });
      }
    } on Object {
      // Keystore tidak terbaca: anggap belum ada rahasia, pengguna diminta mengisinya.
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _host, _port, _user, _group, _password, _passphrase]) {
      c.dispose();
    }
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
        _errors.remove('key');
        _passphrase.clear();
      });
    } on KeyImportException catch (e) {
      setState(() {
        _picked = null;
        _keyError = keyErrorText(AppLocalizations.of(context), e);
      });
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final errors = <String, String>{};
    final name = _name.text.trim();
    final host = _host.text.trim();
    final user = _user.text.trim();
    final port = int.tryParse(_port.text.trim());
    if (name.isEmpty) errors['name'] = l.errNameRequired;
    if (host.isEmpty) errors['host'] = l.errHostRequired;
    if (user.isEmpty) errors['user'] = l.errUserRequired;
    if (port == null || port < 1 || port > 65535) errors['port'] = l.errPortInvalid;
    if (_method == AuthMethod.password) {
      if (_password.text.isEmpty && !_hasStoredPassword) errors['password'] = l.errPasswordRequired;
    } else {
      if (_picked == null && !_hasStoredKey) errors['key'] = l.errKeyRequired;
      if (_picked != null && _picked!.encrypted) {
        // Memeriksa passphrase memakai KDF yang berat; beri kesempatan layar menampilkan keadaan menyimpan dulu.
        setState(() => _saving = true);
        await Future<void>.delayed(const Duration(milliseconds: 16));
        try {
          PrivateKeyInspector.verifyPassphrase(_picked!.pem, _passphrase.text);
        } on KeyImportException {
          errors['passphrase'] = l.errPassphraseWrong;
        }
      }
    }
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
        _saving = false;
      });
      return;
    }

    setState(() {
      _errors.clear();
      _saving = true;
      _saveFailed = false;
    });
    final old = widget.existing;
    final profile = HostProfile(
      id: old?.id ?? const Uuid().v4(),
      name: name,
      group: _group.text,
      host: host,
      port: port!,
      username: user,
      authMethod: _method,
      privateKeyPath: old?.privateKeyPath,
      jumpHostId: old?.jumpHostId,
      environment: old?.environment,
      initialDirectory: old?.initialDirectory,
      notes: old?.notes,
      autoSudo: old?.autoSudo ?? false,
      os: old?.os,
      terminalTheme: old?.terminalTheme,
      wslDistro: old?.wslDistro,
    );
    final secrets = _method == AuthMethod.password
        ? HostSecretsInput(password: _password.text.isEmpty ? null : _password.text)
        : HostSecretsInput(
            privateKeyPem: _picked?.pem,
            passphrase: _picked != null && _picked!.encrypted ? _passphrase.text : null,
          );
    try {
      await ref.read(hostServiceProvider).saveHost(profile, secrets: secrets);
      if (!mounted) return;
      showTermulToastOn(messenger, l.hostSaved(profile.name));
      navigator.pop(true);
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final level = ref.watch(authLevelProvider).value;
    final editing = widget.existing != null;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TermulSpacing.space3,
                TermulSpacing.space5,
                TermulSpacing.space8,
                TermulSpacing.space3,
              ),
              child: Row(
                children: [
                  TermulIconButton(
                    icon: TermulIconName.chevronLeft,
                    label: l.actionCancel,
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: TermulSpacing.space3),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        editing ? l.formEditTitle : l.formAddTitle,
                        style: TermulText.h2.copyWith(color: TermulPalette.ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  TermulSpacing.space8,
                  TermulSpacing.space3,
                  TermulSpacing.space8,
                  TermulSpacing.space9,
                ),
                children: [
                  if (widget.existing?.authMethod == AuthMethod.agent)
                    Padding(
                      padding: const EdgeInsets.only(bottom: TermulSpacing.space7),
                      child: TermulBanner(
                        tone: BannerTone.warn,
                        title: l.agentNeedsCompletionTitle,
                        child: Text(l.agentNeedsCompletionBody),
                      ),
                    ),
                  _field(
                    TermulTextField(label: l.fieldName, controller: _name, error: _errors['name'], enabled: !_saving),
                  ),
                  _field(
                    TermulTextField(
                      label: l.fieldHost,
                      controller: _host,
                      mono: true,
                      helper: l.fieldHostHelper,
                      error: _errors['host'],
                      keyboardType: TextInputType.url,
                      enabled: !_saving,
                    ),
                  ),
                  _field(
                    TermulTextField(
                      label: l.fieldPort,
                      controller: _port,
                      mono: true,
                      error: _errors['port'],
                      keyboardType: TextInputType.number,
                      enabled: !_saving,
                    ),
                  ),
                  _field(
                    TermulTextField(
                      label: l.fieldUsername,
                      controller: _user,
                      mono: true,
                      error: _errors['user'],
                      enabled: !_saving,
                    ),
                  ),
                  _field(
                    TermulTextField(
                      label: l.fieldGroup,
                      controller: _group,
                      helper: l.fieldGroupHelper,
                      enabled: !_saving,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: TermulSpacing.space3, bottom: TermulSpacing.space7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.authMethodLabel, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
                        const SizedBox(height: TermulSpacing.space1),
                        TermulSegmented<AuthMethod>(
                          label: l.authMethodLabel,
                          value: _method,
                          options: [
                            SegmentOption(value: AuthMethod.password, label: l.authPassword),
                            SegmentOption(value: AuthMethod.key, label: l.authKey),
                          ],
                          onChanged: (m) => setState(() {
                            if (!_saving) _method = m;
                          }),
                        ),
                      ],
                    ),
                  ),
                  if (level == AuthLevel.none)
                    Padding(
                      padding: const EdgeInsets.only(bottom: TermulSpacing.space7),
                      child: TermulBanner(
                        tone: BannerTone.risk,
                        title: l.lockWarningTitle,
                        child: Text(l.lockWarningBody),
                      ),
                    ),
                  if (_method == AuthMethod.password) _passwordSection(l) else _keySection(l),
                  if (_saveFailed)
                    Padding(
                      padding: const EdgeInsets.only(top: TermulSpacing.space7),
                      child: TermulBanner(tone: BannerTone.risk, child: Text(l.saveFailed)),
                    ),
                ],
              ),
            ),
            Container(
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
              child: TermulButton(
                label: l.actionSave,
                variant: TermulButtonVariant.primary,
                size: TermulButtonSize.lg,
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: TermulSpacing.space6),
    child: child,
  );

  Widget _passwordSection(AppLocalizations l) => TermulTextField(
    label: l.fieldPassword,
    controller: _password,
    obscure: true,
    mono: true,
    helper: _hasStoredPassword ? l.passwordStoredHint : null,
    error: _errors['password'],
    enabled: !_saving,
  );

  Widget _keySection(AppLocalizations l) {
    final picked = _picked;
    final hasKey = picked != null || _hasStoredKey;
    final status = picked != null ? l.keyReady(keyTypeLabel(picked.type)) : (_hasStoredKey ? l.keyStored : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TermulButton(
          label: hasKey ? l.keyReplace : l.keyImport,
          icon: TermulIconName.key,
          onPressed: _saving ? null : _pickKey,
        ),
        if (status != null)
          Padding(
            padding: const EdgeInsets.only(top: TermulSpacing.space3),
            child: Text(status, style: TermulText.caption.copyWith(color: TermulPalette.ok)),
          ),
        if (_errors['key'] != null)
          Padding(
            padding: const EdgeInsets.only(top: TermulSpacing.space3),
            child: Text(_errors['key']!, style: TermulText.caption.copyWith(color: TermulPalette.bad)),
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
            error: _errors['passphrase'],
            enabled: !_saving,
          ),
        ],
      ],
    );
  }
}
