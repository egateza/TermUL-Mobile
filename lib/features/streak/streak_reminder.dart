import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/platform/reminder_platform.dart';
import '../../l10n/app_localizations.dart';
import 'streak_controller.dart';

/// Pengingat streak; bawaan tanpa efek (tes), bootstrap memasang yang nyata.
final reminderPlatformProvider = Provider<ReminderPlatform>((ref) => NoopReminder());

/// Jam pengingat harian (prototipe `Settings`: "Notifikasi pukul 20.00").
const reminderHour = 20;

/// Waktu pengingat berikutnya: pukul 20.00 hari ini bila hari ini belum terhitung dan belum lewat jam itu, selain itu
/// pukul 20.00 besok. Setelah berbunyi, alarm Android memasang dirinya lagi tiap 24 jam sampai aplikasi dibuka.
DateTime nextReminder({required DateTime now, required bool todayCounted}) {
  final today = DateTime(now.year, now.month, now.day, reminderHour);
  if (!todayCounted && now.isBefore(today)) return today;
  return DateTime(now.year, now.month, now.day + 1, reminderHour);
}

/// Menyelaraskan jadwal pengingat dengan pengaturan dan keadaan streak. Hanya memanggil platform bila jadwalnya
/// berubah. Galat platform dicatat tanpa isi dan tidak mengganggu aplikasi.
class StreakReminderSync {
  StreakReminderSync(this._ref);

  final WidgetRef _ref;
  DateTime? _scheduled;
  bool _cancelled = false;

  Future<void> sync(AppLocalizations l) async {
    final platform = _ref.read(reminderPlatformProvider);
    final on = _ref.read(appSettingsProvider).streak.reminder;
    final view = _ref.read(streakControllerProvider);
    try {
      if (!on) {
        if (_cancelled) return;
        _cancelled = true;
        _scheduled = null;
        await platform.cancel();
        return;
      }
      if (!view.opened) return;
      final at = nextReminder(now: _ref.read(streakClockProvider)(), todayCounted: view.todayCounted);
      if (at == _scheduled) return;
      _scheduled = at;
      _cancelled = false;
      await platform.schedule(
        at: at,
        title: l.streakReminderTitle,
        text: l.streakReminderText,
        channelName: l.streakReminderChannel,
      );
    } on Object catch (e) {
      debugPrint('[termul] pengingat streak gagal: ${e.runtimeType}');
    }
  }
}
