import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/host_profile.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_nav_bar.dart';
import '../connect/session_manager.dart';
import '../hosts/host_list_screen.dart';
import '../sessions/sessions_screen.dart';
import '../sftp/sftp_session_manager.dart';
import '../settings/settings_screen.dart';
import 'coming_soon_screen.dart';

/// Kerangka layar utama: empat tab di `NavBar` (Host, Sesi, Snippet, Pengaturan). Tab SFTP dihapus (keputusan pemilik
/// 2026-10-17): SFTP dibuka dari menu tekan lama host ("Sambung SFTP") atau tombol SFTP di terminal, dan sesinya muncul
/// di Sesi. Tab dibangun
/// saat pertama dibuka lalu dipertahankan, jadi pencarian dan gulir di daftar host tidak hilang saat berpindah tab.
/// Layar terminal dan form dibuka di atas kerangka ini sehingga bar tidak tampil di sana. Bar disembunyikan selagi
/// keyboard terbuka supaya ruang isian tidak terpotong.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.onConnect});

  final void Function(BuildContext context, HostProfile profile) onConnect;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  static const _ids = ['hosts', 'sessions', 'snippets', 'settings'];

  int _index = 0;
  final _visited = <int>{0};

  void _select(String id) {
    final i = _ids.indexOf(id);
    if (i < 0 || i == _index) return;
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  Widget _page(int i, AppLocalizations l) => switch (i) {
    0 => HostListScreen(onConnect: widget.onConnect),
    1 => const SessionsScreen(showBack: false),
    2 => ComingSoonScreen(title: l.navSnippets, heading: l.comingSoonHeading, body: l.comingSoonSnippets),
    _ => const SettingsScreen(showBack: false),
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
      NavItem(id: 'settings', label: l.navSettings, icon: TermulIconName.settings),
    ];
    final pages = IndexedStack(
      index: _index,
      children: [for (var i = 0; i < _ids.length; i++) _visited.contains(i) ? _page(i, l) : const SizedBox.shrink()],
    );
    return PopScope(
      // Tombol kembali dari tab lain menuju tab Host dulu, baru keluar.
      canPop: _index == 0,
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
                    TermulNavRail(label: l.navLabel, active: _ids[_index], onSelect: _select, items: items),
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
            : TermulNavBar(label: l.navLabel, active: _ids[_index], onSelect: _select, items: items),
      ),
    );
  }
}
