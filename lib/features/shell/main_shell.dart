import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/models/host_profile.dart';
import '../../core/streak/streak.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_nav_bar.dart';
import '../connect/session_manager.dart';
import '../hosts/host_list_screen.dart';
import '../sessions/sessions_screen.dart';
import '../sftp/sftp_session_manager.dart';
import '../settings/settings_screen.dart';
import '../snippets/snippets_screen.dart';
import '../streak/streak_controller.dart';
import '../streak/streak_screen.dart';
import '../streak/streak_splash.dart';
import 'main_tab.dart';

/// Kerangka layar utama: lima tab di `NavBar` (Host, Sesi, Snippet, Streak, Pengaturan). Tab SFTP dihapus (keputusan
/// pemilik 2026-10-17): SFTP dibuka dari menu tekan lama host ("Sambung SFTP") atau tombol SFTP di terminal, dan
/// sesinya muncul di Sesi. Tab dibangun saat pertama dibuka lalu dipertahankan, jadi pencarian dan gulir di daftar host
/// tidak hilang saat berpindah tab; gerak di tab yang tidak terlihat dihentikan lewat `TickerMode`. Tab aktif disimpan
/// di [mainTabProvider] supaya bisa dipindah dari luar bar (chip streak).
///
/// Kerangka ini juga menghitung hari streak: saat pertama tampil, saat aplikasi kembali ke depan, dan tiap
/// [dayCheckInterval] selama terbuka (tanggal yang berganti dihitung seperti membuka lagi, sama dengan desktop).
/// Layar terminal dan form dibuka di atas kerangka ini sehingga bar tidak tampil di sana. Bar disembunyikan selagi
/// keyboard terbuka supaya ruang isian tidak terpotong.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.onConnect});

  final void Function(BuildContext context, HostProfile profile) onConnect;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

/// Selang memeriksa pergantian tanggal selagi aplikasi terbuka (desktop `DAY_CHECK_MS`).
const dayCheckInterval = Duration(minutes: 1);

class _MainShellState extends ConsumerState<MainShell> with WidgetsBindingObserver {
  static const _ids = ['hosts', 'sessions', 'snippets', 'streak', 'settings'];

  final _visited = <int>{0};
  Timer? _dayCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onStreakEvent(ref.read(streakControllerProvider.notifier).openToday());
      _dayCheck = Timer.periodic(dayCheckInterval, (_) => _checkDay());
    });
  }

  @override
  void dispose() {
    _dayCheck?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkDay();
  }

  void _checkDay() {
    if (!mounted) return;
    final event = ref.read(streakControllerProvider.notifier).checkDay();
    if (event != null) _onStreakEvent(event);
  }

  /// Peristiwa streak saat hari dihitung: splash bila streak ditampilkan dan tidak ada layar lain di atas kerangka
  /// (terminal, form, sheet); chip dan tab Streak tetap memperlihatkan keadaannya.
  void _onStreakEvent(StreakEvent event) {
    if (event is StreakSameDay || !mounted) return;
    if (!ref.read(appSettingsProvider).streak.show) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    showStreakSplash(context, event);
  }

  void _select(String id) => ref.read(mainTabProvider.notifier).select(id);

  Widget _page(int i, AppLocalizations l) => switch (i) {
    0 => HostListScreen(onConnect: widget.onConnect),
    1 => const SessionsScreen(showBack: false),
    2 => const SnippetsScreen(),
    3 => const StreakScreen(),
    _ => const SettingsScreen(showBack: false),
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final active = ref.watch(mainTabProvider);
    final index = _ids.indexOf(active).clamp(0, _ids.length - 1);
    _visited.add(index);
    final sessions = ref.watch(sessionManagerProvider).length + ref.watch(sftpSessionManagerProvider).length;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final items = [
      NavItem(id: 'hosts', label: l.navHosts, icon: TermulIconName.hosts),
      NavItem(
        id: 'sessions',
        label: l.navSessions,
        icon: TermulIconName.terminal,
        badge: sessions,
        semanticLabel: sessions > 0 ? l.hostsOpenSessions(sessions) : null,
      ),
      NavItem(id: 'snippets', label: l.navSnippets, icon: TermulIconName.snippets),
      // Merah api (tier 3) supaya tab Streak mencolok dibanding tab lain; permintaan pemilik 2026-10-17.
      NavItem(id: 'streak', label: l.navStreak, icon: TermulIconName.flame, highlight: TermulPalette.level3),
      NavItem(id: 'settings', label: l.navSettings, icon: TermulIconName.settings),
    ];
    final pages = IndexedStack(
      index: index,
      children: [
        for (var i = 0; i < _ids.length; i++)
          _visited.contains(i) ? TickerMode(enabled: i == index, child: _page(i, l)) : const SizedBox.shrink(),
      ],
    );
    return PopScope(
      // Tombol kembali dari tab lain menuju tab Host dulu, baru keluar.
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(_ids.first);
      },
      child: Scaffold(
        // Halaman di dalamnya (Scaffold sendiri) yang menyesuaikan tinggi dengan keyboard. Bila kerangka ini ikut
        // mengurangi, tinggi keyboard terpotong dua kali dan daftar host menyusut jadi 0 dp di landscape.
        resizeToAvoidBottomInset: false,
        // Landscape: rel di sisi kiri (tidak memakai tinggi layar). Potret: bar bawah. Selagi keyboard terbuka
        // keduanya disembunyikan supaya ruang isian tidak terpotong.
        body: landscape
            ? Row(
                children: [
                  if (!keyboardOpen)
                    TermulNavRail(label: l.navLabel, active: _ids[index], onSelect: _select, items: items),
                  // Berkunci: halaman (dan fokus kolom pencarian) tidak dibangun ulang saat rel muncul atau hilang.
                  Expanded(
                    key: const ValueKey('halaman'),
                    // Rel sudah menjaga lekukan kiri; halaman tidak perlu menjaganya lagi.
                    child: MediaQuery.removePadding(context: context, removeLeft: !keyboardOpen, child: pages),
                  ),
                ],
              )
            : pages,
        bottomNavigationBar: landscape || keyboardOpen
            ? null
            : TermulNavBar(label: l.navLabel, active: _ids[index], onSelect: _select, items: items),
      ),
    );
  }
}
