import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/models/app_settings.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/switch_row.dart';
import '../../shared/widgets/termul_banner.dart';
import '../../shared/widgets/termul_button.dart';
import '../../shared/widgets/termul_card.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_icon_button.dart';
import '../../shared/widgets/termul_text_field.dart';

/// Saklar editor SFTP dan daftar pola ekstensi yang dapat ditambah atau dihapus.
class SftpEditorSettingsSection extends ConsumerStatefulWidget {
  const SftpEditorSettingsSection({super.key});

  @override
  ConsumerState<SftpEditorSettingsSection> createState() => _SftpEditorSettingsSectionState();
}

class _SftpEditorSettingsSectionState extends ConsumerState<SftpEditorSettingsSection> {
  final _extension = TextEditingController();
  String? _extensionError;
  bool _saveFailed = false;

  @override
  void dispose() {
    _extension.dispose();
    super.dispose();
  }

  Future<bool> _save(SftpEditorSettings next) async {
    try {
      final current = ref.read(appSettingsProvider);
      await ref.read(appSettingsProvider.notifier).update(current.copyWith(sftpEditor: next));
      if (mounted) setState(() => _saveFailed = false);
      return true;
    } on Object {
      if (mounted) setState(() => _saveFailed = true);
      return false;
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    final current = ref.read(appSettingsProvider).sftpEditor;
    await _save(current.copyWith(enabled: enabled));
  }

  Future<void> _add(AppLocalizations l) async {
    final current = ref.read(appSettingsProvider).sftpEditor;
    final normalized = SftpEditorSettings.normalizePattern(_extension.text);
    if (normalized == null) {
      setState(() => _extensionError = l.settingsSftpExtensionInvalid);
      return;
    }
    if (current.extensions.any((pattern) => pattern.toLowerCase() == normalized)) {
      setState(() => _extensionError = l.settingsSftpExtensionExists);
      return;
    }
    if (await _save(current.copyWith(extensions: [...current.extensions, normalized])) && mounted) {
      _extension.clear();
      setState(() => _extensionError = null);
    }
  }

  Future<void> _remove(String pattern) async {
    final current = ref.read(appSettingsProvider).sftpEditor;
    await _save(current.copyWith(extensions: current.extensions.where((e) => e != pattern).toList()));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final editor = ref.watch(appSettingsProvider).sftpEditor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_saveFailed) ...[
          TermulBanner(tone: BannerTone.warn, title: l.settingsSaveFailedTitle, child: Text(l.settingsSaveFailedBody)),
          const SizedBox(height: TermulSpacing.space3),
        ],
        SwitchRow(
          label: l.settingsSftpEditorLabel,
          description: l.settingsSftpEditorDesc,
          value: editor.enabled,
          onChanged: _setEnabled,
        ),
        const SizedBox(height: TermulSpacing.space3),
        Semantics(
          enabled: editor.enabled,
          child: AnimatedOpacity(
            opacity: editor.enabled ? 1 : 0.45,
            duration: const Duration(milliseconds: 160),
            child: IgnorePointer(
              ignoring: !editor.enabled,
              child: TermulCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l.settingsSftpExtensionsLabel, style: TermulText.body.copyWith(color: TermulPalette.ink)),
                    const SizedBox(height: TermulSpacing.space2),
                    Text(
                      l.settingsSftpExtensionsDesc,
                      style: TermulText.caption.copyWith(color: TermulPalette.inkMuted),
                    ),
                    const SizedBox(height: TermulSpacing.space4),
                    if (editor.extensions.isEmpty)
                      Text(
                        l.settingsSftpExtensionEmpty,
                        style: TermulText.caption.copyWith(color: TermulPalette.inkMuted),
                      )
                    else
                      Wrap(
                        spacing: TermulSpacing.space2,
                        runSpacing: TermulSpacing.space2,
                        children: [
                          for (final pattern in editor.extensions)
                            Container(
                              key: ValueKey('sftp-extension-$pattern'),
                              padding: const EdgeInsetsDirectional.only(start: TermulSpacing.space5, end: 2),
                              decoration: BoxDecoration(
                                color: TermulPalette.ground,
                                borderRadius: BorderRadius.circular(TermulRadius.radiusLg),
                                border: Border.all(color: TermulPalette.lineStrong),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(pattern, style: TermulText.bodySm.copyWith(fontFamily: TermulFonts.mono)),
                                  TermulIconButton(
                                    icon: TermulIconName.close,
                                    label: l.settingsSftpExtensionRemove(pattern),
                                    onPressed: () => _remove(pattern),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: TermulSpacing.space4),
                    // Seperti prototipe: kolom dan tombol Tambah sebaris dengan tinggi sama, keterangan di bawah
                    // keduanya. Label kolom hanya untuk pembaca layar supaya tepi atas kolom sejajar tombol.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: TermulSpacing.space2,
                      children: [
                        Expanded(
                          child: TermulTextField(
                            label: l.settingsSftpExtensionInput,
                            hideLabel: true,
                            placeholder: l.settingsSftpExtensionPlaceholder,
                            error: _extensionError,
                            controller: _extension,
                            mono: true,
                            enabled: editor.enabled,
                            textInputAction: TextInputAction.done,
                            onChanged: (_) {
                              if (_extensionError != null) setState(() => _extensionError = null);
                            },
                            onSubmitted: (_) => _add(l),
                          ),
                        ),
                        SizedBox(
                          key: const ValueKey('sftp-extension-add'),
                          height: TermulSize.inputH,
                          child: TermulButton(
                            label: l.settingsSftpExtensionAdd,
                            size: TermulButtonSize.sm,
                            expand: false,
                            variant: TermulButtonVariant.primary,
                            onPressed: () => _add(l),
                          ),
                        ),
                      ],
                    ),
                    if (_extensionError == null) ...[
                      const SizedBox(height: TermulSpacing.space2),
                      Text(
                        l.settingsSftpExtensionHelper,
                        style: TermulText.caption.copyWith(color: TermulPalette.inkMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
