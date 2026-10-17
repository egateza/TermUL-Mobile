import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_toast.dart';

/// Chip status vault di header daftar host (prototipe `Main`). Terkunci: ketuk untuk membuka dengan satu kali
/// autentikasi perangkat; terbuka sementara: ketuk untuk mengunci; selalu terbuka (Pengaturan): ketuk memberi
/// keterangan. Status selalu dengan kata, tidak hanya ikon.
class VaultChip extends ConsumerStatefulWidget {
  const VaultChip({super.key});

  @override
  ConsumerState<VaultChip> createState() => _VaultChipState();
}

class _VaultChipState extends ConsumerState<VaultChip> with WidgetsBindingObserver {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Layar mungkin mati saat Dart dibekukan; periksa ulang supaya chip tidak menampilkan "terbuka" yang basi.
    if (state == AppLifecycleState.resumed) ref.read(vaultLockProvider).refresh();
  }

  Future<void> _tap() async {
    final lock = ref.read(vaultLockProvider);
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (lock.alwaysOpen) {
      showTermulToastOn(messenger, l.vaultAlwaysOpenToast, icon: TermulIconName.lockOpen);
      return;
    }
    if (lock.tempOpen) {
      lock.lock();
      showTermulToastOn(messenger, l.vaultLockedToast, icon: TermulIconName.lock);
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    final reason = l.vaultUnlockReason;
    // Satu prompt pada satu waktu bersama sesi yang sedang menyambung.
    final ok = await ref.read(authGateProvider).run(() => lock.unlock(reason));
    if (mounted) setState(() => _busy = false);
    showTermulToastOn(
      messenger,
      ok ? l.vaultUnlockedToast : l.vaultUnlockFailedToast,
      icon: ok ? TermulIconName.lockOpen : TermulIconName.lock,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lock = ref.watch(vaultLockProvider);
    return ListenableBuilder(
      listenable: lock,
      builder: (context, _) {
        final open = lock.openNow;
        final color = open ? TermulPalette.accent : TermulPalette.inkMuted;
        return Pressable(
          onPressed: _tap,
          radius: TermulRadius.radiusPill,
          semanticLabel: lock.alwaysOpen
              ? l.vaultChipAlwaysOpenHint
              : open
              ? l.vaultChipOpenHint
              : l.vaultChipLockedHint,
          builder: (context, pressed) => Container(
            constraints: const BoxConstraints(minHeight: TermulSize.tapMin),
            padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space6),
            decoration: BoxDecoration(
              color: pressed ? TermulPalette.surfaceRaised : TermulPalette.surface,
              borderRadius: BorderRadius.circular(TermulRadius.radiusPill),
              border: Border.all(color: open ? TermulPalette.accent : TermulPalette.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: TermulSpacing.space3,
              children: [
                TermulIcon(open ? TermulIconName.lockOpen : TermulIconName.lock, size: 16, color: color),
                Text(open ? l.vaultChipOpen : l.vaultChipLocked, style: TermulText.caption.copyWith(color: color)),
              ],
            ),
          ),
        );
      },
    );
  }
}
