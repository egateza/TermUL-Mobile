import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/models/app_settings.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/switch_row.dart';
import '../../shared/widgets/termul_banner.dart';
import '../../shared/widgets/termul_button.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_icon_button.dart';

/// Membuka "Pengaturan streak" di atas layar sekarang.
Future<void> openStreakSettings(BuildContext context) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    settings: const RouteSettings(name: 'streak-settings'),
    builder: (_) => const StreakSettingsScreen(),
  ),
);

/// Pengaturan khusus streak, dibuka dari tab Streak (ikon pengaturan di header dan tautan di bantuan), terpisah dari
/// tab Pengaturan (keputusan pemilik 2026-10-18; prototipe 8d `StreakSettings`): "Tampilkan streak api" dan
/// "Pengingat harian". Menyalakan pengingat meminta izin notifikasi lebih dulu; bila ditolak saklar tetap mati dan
/// pesan tampil. Bila pengingat menyala tetapi notifikasi diblokir, peringatan dengan tombol "Izinkan" tampil.
class StreakSettingsScreen extends ConsumerStatefulWidget {
  const StreakSettingsScreen({super.key});

  @override
  ConsumerState<StreakSettingsScreen> createState() => _StreakSettingsScreenState();
}

class _StreakSettingsScreenState extends ConsumerState<StreakSettingsScreen> with WidgetsBindingObserver {
  bool _saveFailed = false;

  /// Izin notifikasi; null selagi belum diketahui.
  bool? _notifAllowed;

  /// Pengingat baru saja ditolak karena izin notifikasi tidak diberikan.
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

  Future<void> _update(StreakSettings Function(StreakSettings) change) async {
    try {
      final current = ref.read(appSettingsProvider);
      await ref.read(appSettingsProvider.notifier).update(current.copyWith(streak: change(current.streak)));
      if (mounted && _saveFailed) setState(() => _saveFailed = false);
    } on Object {
      if (mounted) setState(() => _saveFailed = true);
    }
  }

  Future<void> _setReminder(bool on) async {
    if (on) {
      final allowed = await _requestNotifications();
      if (!mounted) return;
      setState(() => _needsPermission = !allowed);
      if (!allowed) return;
    } else if (_needsPermission) {
      setState(() => _needsPermission = false);
    }
    await _update((s) => s.copyWith(reminder: on));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final streak = ref.watch(appSettingsProvider).streak;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TermulSpacing.space3,
                TermulSpacing.space5,
                TermulSpacing.space8,
                TermulSpacing.space3,
              ),
              child: Row(
                spacing: TermulSpacing.space3,
                children: [
                  TermulIconButton(
                    icon: TermulIconName.chevronLeft,
                    label: l.actionBack,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(l.streakSettingsTitle, style: TermulText.h2.copyWith(color: TermulPalette.ink)),
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
                  SwitchRow(
                    key: const ValueKey('settings-streak-show'),
                    label: l.settingsStreakShowLabel,
                    description: l.settingsStreakShowDesc,
                    value: streak.show,
                    onChanged: (on) => _update((s) => s.copyWith(show: on)),
                  ),
                  const SizedBox(height: TermulSpacing.space3),
                  SwitchRow(
                    key: const ValueKey('settings-streak-reminder'),
                    label: l.settingsStreakReminderLabel,
                    description: l.settingsStreakReminderDesc,
                    value: streak.reminder,
                    onChanged: _setReminder,
                  ),
                  if (_needsPermission) ...[
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
