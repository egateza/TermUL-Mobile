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
import '../../shared/widgets/termul_segmented.dart';
import '../../shared/widgets/termul_sheet.dart';
import '../../shared/widgets/termul_stepper.dart';
import '../../shared/widgets/termul_toast.dart';
import '../terminal/selection_overlay.dart' show SelectionHandleShape;
import '../terminal/terminal_palette.dart';

/// Layar Pengaturan. Sekarang hanya bagian Terminal (ukuran huruf dan tinggi baris, dengan pratinjau); perubahan
/// langsung berlaku di sesi terminal yang sedang terbuka dan disimpan ke `settings.json`.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.showBack = true});

  /// Tombol kembali: true bila dibuka sebagai layar tersendiri (dari terminal), false sebagai tab di `NavBar`.
  final bool showBack;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with WidgetsBindingObserver {
  bool _saveFailed = false;

  /// Izin notifikasi (untuk foreground service); null selagi belum diketahui.
  bool? _notifAllowed;

  /// Pengingat streak dinyalakan tetapi izin notifikasi ditolak.
  bool _reminderNeedsPermission = false;

  /// Saklar "Pertahankan koneksi" baru saja ditolak karena izin notifikasi tidak diberikan.
  bool _needsPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshNotif();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pengguna mungkin baru mengubah izin di pengaturan Android.
    if (state == AppLifecycleState.resumed) _refreshNotif();
  }

  Future<void> _refreshNotif() async {
    try {
      final allowed = await ref.read(keepAlivePlatformProvider).notificationsEnabled();
      if (mounted) setState(() => _notifAllowed = allowed);
    } on Object {
      // Platform tak tersedia: biarkan status tidak diketahui.
    }
  }

  /// Menyalakan meminta izin notifikasi lebih dulu; bila ditolak, saklar tetap mati dan pesan tampil.
  Future<void> _setKeepAlive(bool on) async {
    final platform = ref.read(keepAlivePlatformProvider);
    if (on) {
      bool allowed;
      try {
        allowed = await platform.requestNotifications();
      } on Object {
        allowed = false;
      }
      if (!mounted) return;
      setState(() {
        _notifAllowed = allowed;
        _needsPermission = !allowed;
      });
      if (!allowed) return;
    } else if (_needsPermission) {
      setState(() => _needsPermission = false);
    }
    try {
      final current = ref.read(appSettingsProvider);
      await ref
          .read(appSettingsProvider.notifier)
          .update(current.copyWith(connection: current.connection.copyWith(keepAlive: on)));
      if (mounted && _saveFailed) setState(() => _saveFailed = false);
    } on Object {
      if (mounted) setState(() => _saveFailed = true);
    }
  }

  Future<void> _setAutoReconnect(bool on) async {
    try {
      final current = ref.read(appSettingsProvider);
      await ref
          .read(appSettingsProvider.notifier)
          .update(current.copyWith(connection: current.connection.copyWith(autoReconnect: on)));
      if (mounted && _saveFailed) setState(() => _saveFailed = false);
    } on Object {
      if (mounted) setState(() => _saveFailed = true);
    }
  }

  Future<void> _setStreakShow(bool on) async {
    try {
      final current = ref.read(appSettingsProvider);
      await ref.read(appSettingsProvider.notifier).update(current.copyWith(streak: current.streak.copyWith(show: on)));
      if (mounted && _saveFailed) setState(() => _saveFailed = false);
    } on Object {
      if (mounted) setState(() => _saveFailed = true);
    }
  }

  /// Menyalakan meminta izin notifikasi lebih dulu; bila ditolak, saklar tetap mati dan pesan tampil.
  Future<void> _setStreakReminder(bool on) async {
    if (on) {
      final allowed = await _requestNotifications();
      if (!mounted) return;
      setState(() => _reminderNeedsPermission = !allowed);
      if (!allowed) return;
    } else if (_reminderNeedsPermission) {
      setState(() => _reminderNeedsPermission = false);
    }
    try {
      final current = ref.read(appSettingsProvider);
      await ref
          .read(appSettingsProvider.notifier)
          .update(current.copyWith(streak: current.streak.copyWith(reminder: on)));
      if (mounted && _saveFailed) setState(() => _saveFailed = false);
    } on Object {
      if (mounted) setState(() => _saveFailed = true);
    }
  }

  Future<bool> _requestNotifications() async {
    bool allowed;
    try {
      allowed = await ref.read(keepAlivePlatformProvider).requestNotifications();
    } on Object {
      allowed = false;
    }
    if (mounted) setState(() => _notifAllowed = allowed);
    return allowed;
  }

  /// Menyalakan meminta konfirmasi (peringatan) lalu satu kali autentikasi perangkat; mematikan langsung berlaku.
  Future<void> _setVaultAlwaysOpen(bool on) async {
    if (!on) {
      await _saveVaultAlwaysOpen(false);
      return;
    }
    final l = AppLocalizations.of(context);
    showTermulSheet<void>(
      context,
      title: l.vaultAlwaysOpenConfirmTitle,
      child: Text(l.vaultAlwaysOpenConfirmBody, style: TermulText.body.copyWith(color: TermulPalette.inkSoft)),
      cancelLabel: l.actionCancel,
      confirmLabel: l.vaultAlwaysOpenConfirmAction,
      confirmIsDanger: true,
      cancelIsPrimary: true,
      onConfirm: _confirmVaultAlwaysOpen,
    );
  }

  Future<void> _confirmVaultAlwaysOpen() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final lock = ref.read(vaultLockProvider);
    final reason = l.vaultAlwaysOpenReason;
    final ok = await ref.read(authGateProvider).run(() => lock.authenticate(reason));
    if (!ok) {
      showTermulToastOn(messenger, l.vaultAlwaysOpenAuthFailed, icon: TermulIconName.lock);
      return;
    }
    await _saveVaultAlwaysOpen(true);
  }

  Future<void> _saveVaultAlwaysOpen(bool on) async {
    // Status vault berubah lebih dulu; bila berkas gagal disimpan, nilai tetap berlaku sampai aplikasi ditutup.
    ref.read(vaultLockProvider).alwaysOpen = on;
    try {
      final current = ref.read(appSettingsProvider);
      await ref
          .read(appSettingsProvider.notifier)
          .update(current.copyWith(security: current.security.copyWith(vaultAlwaysOpen: on)));
      if (mounted && _saveFailed) setState(() => _saveFailed = false);
    } on Object {
      if (mounted) setState(() => _saveFailed = true);
    }
  }

  /// Langkah ukuran huruf (px) dan tinggi baris (kelipatan).
  static const _fontStep = 1.0;
  static const _lineStep = 0.1;

  /// Menerapkan [change] pada nilai terkini (dibaca saat diketuk, bukan saat layar digambar, supaya ketukan
  /// beruntun tidak memakai nilai usang).
  Future<void> _apply(TerminalSettings Function(TerminalSettings current) change) async {
    try {
      final next = change(ref.read(appSettingsProvider).terminal);
      await ref.read(appSettingsProvider.notifier).update(ref.read(appSettingsProvider).copyWith(terminal: next));
      if (mounted && _saveFailed) setState(() => _saveFailed = false);
    } on Object {
      if (mounted) setState(() => _saveFailed = true);
    }
  }

  /// Membulatkan ke satu desimal supaya penjumlahan 0,1 tidak menyisakan 1,3000000000000003.
  static double _round1(double v) => (v * 10).round() / 10;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = ref.watch(appSettingsProvider).terminal;
    final isDefault = t == const TerminalSettings();
    final keepAlive = ref.watch(appSettingsProvider).connection.keepAlive;
    final autoReconnect = ref.watch(appSettingsProvider).connection.autoReconnect;
    final vaultAlwaysOpen = ref.watch(appSettingsProvider).security.vaultAlwaysOpen;
    final streak = ref.watch(appSettingsProvider).streak;

    TerminalSettings Function(TerminalSettings) fontBy(double d) =>
        (c) => c.copyWith(fontSize: (c.fontSize + d).clamp(TerminalSettings.minFontSize, TerminalSettings.maxFontSize));
    TerminalSettings Function(TerminalSettings) lineBy(double d) =>
        (c) => c.copyWith(
          lineHeight: _round1(c.lineHeight + d).clamp(TerminalSettings.minLineHeight, TerminalSettings.maxLineHeight),
        );

    final showBack = widget.showBack;
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                showBack ? TermulSpacing.space3 : TermulSpacing.space8,
                // Landscape: header lebih rendah supaya isi mendapat tinggi layar.
                landscape ? TermulSpacing.space1 : TermulSpacing.space5,
                TermulSpacing.space8,
                TermulSpacing.space3,
              ),
              child: Row(
                children: [
                  if (showBack) ...[
                    TermulIconButton(
                      icon: TermulIconName.chevronLeft,
                      label: l.actionBack,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: TermulSpacing.space3),
                  ],
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l.settingsTitle,
                        style: (landscape ? TermulText.h2 : TermulText.h1).copyWith(color: TermulPalette.ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  TermulSpacing.space5,
                  TermulSpacing.space3,
                  TermulSpacing.space5,
                  TermulSpacing.space8,
                ),
                children: [
                  if (_saveFailed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: TermulSpacing.space5),
                      child: TermulBanner(
                        tone: BannerTone.warn,
                        title: l.settingsSaveFailedTitle,
                        child: Text(l.settingsSaveFailedBody),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TermulSpacing.space3,
                      0,
                      TermulSpacing.space3,
                      TermulSpacing.space3,
                    ),
                    child: Semantics(
                      header: true,
                      child: Text(
                        l.settingsTerminalSection.toUpperCase(),
                        style: TermulText.overline.copyWith(color: TermulPalette.inkMuted),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: TermulPalette.surface,
                      borderRadius: BorderRadius.circular(TermulRadius.radiusXl),
                      border: Border.all(color: TermulPalette.line),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(TermulRadius.radiusXl - 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(TermulSpacing.space6),
                            child: _Preview(settings: t),
                          ),
                          TermulStepper(
                            label: l.settingsFontSize,
                            valueText: l.settingsFontSizeValue(t.fontSize.round()),
                            decrementLabel: l.settingsFontSmaller,
                            incrementLabel: l.settingsFontLarger,
                            onDecrement: t.fontSize <= TerminalSettings.minFontSize
                                ? null
                                : () => _apply(fontBy(-_fontStep)),
                            onIncrement: t.fontSize >= TerminalSettings.maxFontSize
                                ? null
                                : () => _apply(fontBy(_fontStep)),
                          ),
                          TermulStepper(
                            label: l.settingsLineHeight,
                            valueText: l.settingsLineHeightValue(t.lineHeight.toStringAsFixed(1).replaceAll('.', ',')),
                            decrementLabel: l.settingsLineTighter,
                            incrementLabel: l.settingsLineLooser,
                            onDecrement: t.lineHeight <= TerminalSettings.minLineHeight
                                ? null
                                : () => _apply(lineBy(-_lineStep)),
                            onIncrement: t.lineHeight >= TerminalSettings.maxLineHeight
                                ? null
                                : () => _apply(lineBy(_lineStep)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(TermulSpacing.space6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: TermulSpacing.space4,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l.settingsHandleStyle,
                                        style: TermulText.body.copyWith(color: TermulPalette.ink),
                                      ),
                                    ),
                                    SelectionHandleShape(style: t.handleStyle),
                                  ],
                                ),
                                TermulSegmented<SelectionHandleStyle>(
                                  label: l.settingsHandleStyle,
                                  value: t.handleStyle,
                                  onChanged: (v) => _apply((c) => c.copyWith(handleStyle: v)),
                                  options: [
                                    SegmentOption(value: SelectionHandleStyle.drop, label: l.settingsHandleDrop),
                                    SegmentOption(
                                      value: SelectionHandleStyle.triangle,
                                      label: l.settingsHandleTriangle,
                                    ),
                                    SegmentOption(value: SelectionHandleStyle.dot, label: l.settingsHandleDot),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: TermulSpacing.space3),
                  SwitchRow(
                    label: l.settingsConfirmPasteLabel,
                    description: l.settingsConfirmPasteDesc,
                    value: t.confirmSingleLinePaste,
                    onChanged: (on) => _apply((c) => c.copyWith(confirmSingleLinePaste: on)),
                  ),
                  const SizedBox(height: TermulSpacing.space5),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space3),
                    child: Text(
                      l.settingsTerminalHint,
                      style: TermulText.caption.copyWith(color: TermulPalette.inkMuted),
                    ),
                  ),
                  const SizedBox(height: TermulSpacing.space5),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space3),
                    child: TermulButton(
                      label: l.settingsResetDefaults,
                      onPressed: isDefault ? null : () => _apply((_) => const TerminalSettings()),
                    ),
                  ),
                  const SizedBox(height: TermulSpacing.space8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TermulSpacing.space3,
                      0,
                      TermulSpacing.space3,
                      TermulSpacing.space3,
                    ),
                    child: Semantics(
                      header: true,
                      child: Text(
                        l.settingsConnectionSection.toUpperCase(),
                        style: TermulText.overline.copyWith(color: TermulPalette.inkMuted),
                      ),
                    ),
                  ),
                  if (_needsPermission)
                    Padding(
                      padding: const EdgeInsets.only(bottom: TermulSpacing.space3),
                      child: TermulBanner(tone: BannerTone.warn, child: Text(l.settingsKeepAliveNeedsPermission)),
                    ),
                  SwitchRow(
                    label: l.settingsAutoReconnectLabel,
                    description: l.settingsAutoReconnectDesc,
                    value: autoReconnect,
                    onChanged: _setAutoReconnect,
                  ),
                  const SizedBox(height: TermulSpacing.space3),
                  SwitchRow(
                    label: l.settingsKeepAliveLabel,
                    description: l.settingsKeepAliveDesc,
                    value: keepAlive,
                    onChanged: _setKeepAlive,
                  ),
                  if (keepAlive) ...[
                    const SizedBox(height: TermulSpacing.space3),
                    TermulCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: TermulSpacing.space5,
                        children: [
                          Text(
                            l.settingsKeepAliveNote,
                            style: TermulText.caption.copyWith(color: TermulPalette.inkMuted),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.settingsNotifPermissionLabel,
                                      style: TermulText.body.copyWith(color: TermulPalette.ink),
                                    ),
                                    Text(
                                      _notifAllowed == false ? l.settingsNotifDenied : l.settingsNotifAllowed,
                                      style: TermulText.caption.copyWith(
                                        color: _notifAllowed == false ? TermulPalette.accent : TermulPalette.ok,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_notifAllowed == false)
                                TermulButton(
                                  label: l.settingsNotifAllow,
                                  size: TermulButtonSize.sm,
                                  expand: false,
                                  onPressed: () async {
                                    try {
                                      await ref.read(keepAlivePlatformProvider).requestNotifications();
                                    } on Object {
                                      // Tetap tampilkan status terbaru di bawah.
                                    }
                                    await _refreshNotif();
                                  },
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.settingsBatteryLabel,
                                      style: TermulText.body.copyWith(color: TermulPalette.ink),
                                    ),
                                    Text(
                                      l.settingsBatteryDesc,
                                      style: TermulText.caption.copyWith(color: TermulPalette.inkMuted),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: TermulSpacing.space5),
                              TermulButton(
                                label: l.settingsBatteryOpen,
                                size: TermulButtonSize.sm,
                                expand: false,
                                onPressed: () => ref.read(keepAlivePlatformProvider).openAppSettings(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: TermulSpacing.space8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TermulSpacing.space3,
                      0,
                      TermulSpacing.space3,
                      TermulSpacing.space3,
                    ),
                    child: Semantics(
                      header: true,
                      child: Text(
                        l.settingsSecuritySection.toUpperCase(),
                        style: TermulText.overline.copyWith(color: TermulPalette.inkMuted),
                      ),
                    ),
                  ),
                  SwitchRow(
                    label: l.settingsVaultAlwaysOpenLabel,
                    description: l.settingsVaultAlwaysOpenDesc,
                    value: vaultAlwaysOpen,
                    dangerTag: l.settingsDangerTag,
                    onChanged: _setVaultAlwaysOpen,
                  ),
                  const SizedBox(height: TermulSpacing.space8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TermulSpacing.space3,
                      0,
                      TermulSpacing.space3,
                      TermulSpacing.space3,
                    ),
                    child: Semantics(
                      header: true,
                      child: Text(
                        l.settingsStreakSection.toUpperCase(),
                        style: TermulText.overline.copyWith(color: TermulPalette.inkMuted),
                      ),
                    ),
                  ),
                  SwitchRow(
                    key: const ValueKey('settings-streak-show'),
                    label: l.settingsStreakShowLabel,
                    description: l.settingsStreakShowDesc,
                    value: streak.show,
                    onChanged: _setStreakShow,
                  ),
                  const SizedBox(height: TermulSpacing.space3),
                  SwitchRow(
                    key: const ValueKey('settings-streak-reminder'),
                    label: l.settingsStreakReminderLabel,
                    description: l.settingsStreakReminderDesc,
                    value: streak.reminder,
                    onChanged: _setStreakReminder,
                  ),
                  if (_reminderNeedsPermission) ...[
                    const SizedBox(height: TermulSpacing.space3),
                    TermulBanner(tone: BannerTone.warn, child: Text(l.settingsStreakReminderNeedsPermission)),
                  ] else if (streak.reminder && _notifAllowed == false) ...[
                    const SizedBox(height: TermulSpacing.space3),
                    TermulBanner(
                      tone: BannerTone.warn,
                      action: TermulButton(
                        label: l.settingsNotifAllow,
                        size: TermulButtonSize.sm,
                        variant: TermulButtonVariant.secondary,
                        onPressed: _requestNotifications,
                      ),
                      child: Text(l.settingsStreakReminderBlocked),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pratinjau dua baris dengan gaya terminal yang sama dengan sesi sungguhan.
class _Preview extends StatelessWidget {
  const _Preview({required this.settings});

  final TerminalSettings settings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final base = terminalStyleFor(settings).toTextStyle(color: TermulPalette.terminalInk);
    return Semantics(
      label: l.settingsPreviewLabel,
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('settings-preview'),
        width: double.infinity,
        padding: const EdgeInsets.all(TermulSpacing.space5),
        decoration: BoxDecoration(
          color: TermulPalette.groundDeep,
          borderRadius: BorderRadius.circular(TermulRadius.radiusMd),
        ),
        child: Text.rich(
          TextSpan(
            style: base,
            children: const [
              TextSpan(
                text: 'deploy@app-01',
                style: TextStyle(color: TermulPalette.terminalPrompt),
              ),
              TextSpan(text: ':~\$ ls -la\ndrwxr-xr-x 4 deploy deploy'),
            ],
          ),
          maxLines: 2,
          softWrap: false,
          overflow: TextOverflow.clip,
        ),
      ),
    );
  }
}
