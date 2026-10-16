import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../../core/models/app_settings.dart' show SelectionHandleStyle;
import '../../core/models/host_profile.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/status_dot.dart';
import '../../shared/widgets/termul_banner.dart';
import '../../shared/widgets/termul_button.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_icon_button.dart';
import '../../shared/widgets/termul_action_sheet.dart';
import '../../shared/widgets/termul_sheet.dart';
import '../../shared/widgets/termul_toast.dart';
import 'paste_analysis.dart';
import 'paste_popover.dart';
import 'quick_key_bar.dart';
import 'selection_bar.dart';
import 'selection_overlay.dart';
import 'terminal_palette.dart';
import 'terminal_session.dart';

/// Keadaan sambungan di bawah layar terminal.
enum TerminalLink {
  /// Tersambung (atau shell sedang dibuka di sambungan yang hidup).
  up,

  /// Sambungan putus dan sedang disambung ulang; riwayat layar tetap terlihat.
  reconnecting,

  /// Sambungan putus (atau sambung ulang gagal); menunggu pengguna menekan "Sambung sekarang".
  lost,
}

/// Layar terminal satu host. [session] dimiliki pemanggil (supaya riwayat layar bertahan saat sambungan diganti)
/// dan ditutup olehnya. Layar yang tingginya (di luar keyboard) kurang dari 480 dp memakai mode ringkas: tanpa
/// header, satu baris status, dan tombol cepat 36 dp (landscape).
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({
    super.key,
    required this.profile,
    required this.session,
    this.link = TerminalLink.up,
    this.failureText,
    this.onReconnect,
    this.retryInSeconds,
    this.needsAuth = false,
    this.textStyle,
    this.handleStyle = SelectionHandleStyle.drop,
    this.onKeepInBackground,
    this.keepAliveEnabled = true,
    this.onOpenSettings,
  });

  final HostProfile profile;
  final TerminalSession session;
  final TerminalLink link;

  /// Alasan sambung ulang terakhir gagal (judul galat yang sudah dilokalkan), bila ada.
  final String? failureText;

  /// Dipanggil oleh tombol "Sambung sekarang".
  final VoidCallback? onReconnect;

  /// Detik sampai sambung ulang otomatis berikutnya; null bila tidak sedang menunggu.
  final int? retryInSeconds;

  /// Sambung ulang menunggu pengguna menampilkan prompt biometrik; [onReconnect] menampilkannya.
  final bool needsAuth;

  /// Gaya huruf terminal; bawaan [termulTerminalStyle].
  final TerminalStyle? textStyle;

  /// Bentuk gagang seleksi teks (pengaturan Terminal).
  final SelectionHandleStyle handleStyle;

  /// Dipanggil bila pengguna memilih "Tetap terhubung" saat keluar: layar ditutup tanpa menutup sesi. Kosong =
  /// pilihan itu tidak ditawarkan (hanya Putuskan atau Batal).
  final VoidCallback? onKeepInBackground;

  /// Pengaturan "Pertahankan koneksi di latar belakang" menyala. Bila mati, dialog keluar memberi catatan bahwa
  /// Android bisa memutus sambungan di latar belakang.
  final bool keepAliveEnabled;

  /// Membuka Pengaturan (dari catatan di dialog keluar).
  final VoidCallback? onOpenSettings;

  static const compactBelowDp = 480.0;

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  TerminalSession get _session => widget.session;
  final _controller = TerminalController();
  final _scrollController = ScrollController();
  final _viewKey = GlobalKey<TerminalViewState>();
  final _areaKey = GlobalKey();

  /// Popover Tempel di kursor prompt; null bila tertutup.
  _PasteMenu? _pasteMenu;

  @override
  void initState() {
    super.initState();
    _session.onInput = _clearSelectionOnInput;
    _session.terminal.addListener(_closeMenuIfCursorMoved);
    _scrollController.addListener(_closePasteMenu);
    // Buka shell setelah layout pertama supaya PTY langsung berukuran layar sebenarnya, bukan 80x24.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _session.start();
    });
  }

  @override
  void dispose() {
    _session.terminal.removeListener(_closeMenuIfCursorMoved);
    _scrollController.removeListener(_closePasteMenu);
    if (_session.onInput == _clearSelectionOnInput) _session.onInput = null;
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Mengetik (atau menekan Enter, tombol cepat, tempel) mengakhiri seleksi.
  void _clearSelectionOnInput() {
    _closePasteMenu();
    if (_controller.selection != null) _controller.clearSelection();
  }

  void _closePasteMenu() {
    if (_pasteMenu == null) return;
    if (mounted) setState(() => _pasteMenu = null);
  }

  void _closeMenuIfCursorMoved() {
    final menu = _pasteMenu;
    if (menu == null) return;
    final b = _session.terminal.buffer;
    if (b.cursorX != menu.cursorX || b.absoluteCursorY != menu.cursorY) _closePasteMenu();
  }

  Offset? _downAt;
  Duration? _downTime;

  void _onPointerDown(PointerDownEvent e) {
    _downAt = e.position;
    _downTime = e.timeStamp;
  }

  /// Ketukan singkat tanpa geser (bukan gulir, tekan lama, atau seret gagang) dibaca sebagai ketuk.
  void _onPointerUp(PointerUpEvent e) {
    final at = _downAt;
    final time = _downTime;
    _downAt = null;
    _downTime = null;
    final view = _viewKey.currentState;
    if (at == null || time == null || view == null || !view.renderTerminal.attached) return;
    if ((e.position - at).distance > kTouchSlop || e.timeStamp - time > const Duration(milliseconds: 350)) return;
    _onTerminalTap(view.renderTerminal.getCellOffset(view.renderTerminal.globalToLocal(e.position)));
  }

  /// Ketukan di kursor prompt membuka popover Tempel; ketukan lain (atau di kursor lagi) menutupnya.
  Future<void> _onTerminalTap(CellOffset cell) async {
    if (_pasteMenu != null) {
      _closePasteMenu();
      return;
    }
    final terminal = _session.terminal;
    final b = terminal.buffer;
    final atCursor = cell.y == b.absoluteCursorY && (cell.x - b.cursorX).abs() <= 2;
    if (!atCursor || !_alive || terminal.isUsingAltBuffer || _session.state != TerminalSessionState.running) return;
    var lines = 0;
    try {
      final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
      if (text.isNotEmpty) lines = text.replaceFirst(RegExp(r'\n+$'), '').split('\n').length;
    } on Object {
      lines = 0;
    }
    if (!mounted || _pasteMenu != null) return;
    final area = _areaKey.currentContext?.findRenderObject();
    final view = _viewKey.currentState;
    if (area is! RenderBox || !area.attached || view == null) return;
    final global = view.globalCursorRect;
    final topLeft = area.globalToLocal(global.topLeft);
    setState(
      () => _pasteMenu = _PasteMenu(
        cursorX: b.cursorX,
        cursorY: b.absoluteCursorY,
        anchor: topLeft & global.size,
        areaSize: area.size,
        lines: lines,
      ),
    );
  }

  void _pasteFromMenu() {
    _closePasteMenu();
    _paste();
  }

  Widget _pasteMenuOverlay(BuildContext context) {
    final menu = _pasteMenu!;
    if (MediaQuery.sizeOf(context) != menu.screenSize) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _closePasteMenu());
      return const SizedBox.shrink();
    }
    final right = (menu.areaSize.width - menu.anchor.right - 6).clamp(4.0, menu.areaSize.width);
    final popover = PastePopover(clipLines: menu.lines, onPaste: _pasteFromMenu);
    // Di atas kursor; di baris paling atas layar (tidak muat) di bawahnya.
    return menu.anchor.top > 100
        ? Positioned(right: right, bottom: menu.areaSize.height - menu.anchor.top + 6, child: popover)
        : Positioned(right: right, top: menu.anchor.bottom + 6, child: popover);
  }

  bool get _alive =>
      widget.link == TerminalLink.up &&
      (_session.state == TerminalSessionState.opening || _session.state == TerminalSessionState.running);

  /// Tempel dari papan klip. Satu baris tanpa tanda bahaya langsung masuk ke prompt; selain itu isi dan akibatnya
  /// ditampilkan dulu (layar 2b dan 2c di desain).
  Future<void> _paste() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final offset = TermulSize.tapMin + TermulSpacing.space3 * 2 + TermulSpacing.space3;
    ClipboardData? clip;
    try {
      clip = await Clipboard.getData(Clipboard.kTextPlain);
    } on Object {
      clip = null;
    }
    if (!mounted) return;
    final raw = clip?.text ?? '';
    if (raw.isEmpty) {
      showTermulToastOn(messenger, l.pasteEmpty, icon: TermulIconName.warning, bottomOffset: offset);
      return;
    }
    if (raw.length > PasteAnalysis.maxChars) {
      showTermulToastOn(messenger, l.pasteTooLarge, icon: TermulIconName.warning, bottomOffset: offset);
      return;
    }
    final analysis = PasteAnalysis.of(raw, bracketed: _session.terminal.bracketedPasteMode);
    if (analysis.isEmpty) {
      showTermulToastOn(messenger, l.pasteEmpty, icon: TermulIconName.warning, bottomOffset: offset);
      return;
    }
    void send() {
      _session.paste(analysis.outgoing);
      showTermulToastOn(
        messenger,
        analysis.runsImmediately ? l.pasteDoneRunning(analysis.lineCount) : l.pasteDone(analysis.lineCount),
        bottomOffset: offset,
      );
    }

    if (!analysis.needsConfirm) {
      send();
      return;
    }
    await showTermulSheet<void>(
      context,
      title: l.pasteTitle(analysis.lineCount),
      child: _PasteDetails(analysis: analysis),
      cancelLabel: l.actionCancel,
      confirmLabel: l.pasteConfirm,
      cancelIsPrimary: analysis.cancelIsPrimary,
      onConfirm: send,
    );
  }

  /// Salin teks terpilih ke papan klip, lalu hapus seleksi.
  Future<void> _copySelection() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final range = _controller.selection?.normalized;
    if (range == null) return;
    final text = _session.terminal.buffer.getText(range);
    _controller.clearSelection();
    if (text.isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } on Object {
      return;
    }
    if (!mounted) return;
    showTermulToastOn(
      messenger,
      l.selectionCopied(text.length),
      bottomOffset: TermulSize.tapMin + TermulSpacing.space3 * 3,
    );
  }

  /// Memilih seluruh isi terminal sampai baris terakhir yang berisi teks.
  void _selectAll() {
    final buffer = _session.terminal.buffer;
    var last = buffer.lines.length - 1;
    while (last > 0 && buffer.lines[last].getText().trim().isEmpty) {
      last--;
    }
    _controller.setSelection(
      buffer.createAnchorFromOffset(CellOffset(0, 0)),
      buffer.createAnchorFromOffset(CellOffset(_session.terminal.viewWidth, last)),
    );
  }

  Future<void> _confirmLeave() async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final keep = widget.onKeepInBackground;
    if (keep == null) {
      await showTermulSheet<void>(
        context,
        title: l.terminalLeaveTitle,
        child: Text(l.terminalLeaveBody, style: TermulText.body.copyWith(color: TermulPalette.inkSoft)),
        cancelLabel: l.actionCancel,
        confirmLabel: l.actionDisconnect,
        confirmIsDanger: true,
        onConfirm: navigator.pop,
      );
      return;
    }
    await showTermulActions(
      context,
      title: l.terminalLeaveChoiceTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TermulSpacing.space4,
        children: [
          Text(l.terminalLeaveChoiceBody, style: TermulText.body.copyWith(color: TermulPalette.inkSoft)),
          if (!widget.keepAliveEnabled)
            TermulBanner(
              tone: BannerTone.warn,
              action: widget.onOpenSettings == null
                  ? null
                  : TermulButton(
                      label: l.terminalLeaveOpenSettings,
                      size: TermulButtonSize.sm,
                      expand: false,
                      onPressed: () {
                        // Tutup sheet lalu buka Pengaturan; sheet ada di atas layar ini.
                        navigator.pop();
                        widget.onOpenSettings!();
                      },
                    ),
              child: Text(l.terminalLeaveKeepAliveOff),
            ),
        ],
      ),
      actions: [
        SheetAction(label: l.terminalLeaveKeep, primary: true, onSelected: keep),
        SheetAction(label: l.actionDisconnect, danger: true, onSelected: navigator.pop),
        SheetAction(label: l.actionCancel, onSelected: () {}),
      ],
    );
  }

  Widget _linkBanner(AppLocalizations l) {
    if (widget.link == TerminalLink.reconnecting) {
      return TermulBanner(
        tone: BannerTone.warn,
        title: l.reconnectingTitle,
        icon: TermulIconName.refresh,
        child: Text(l.reconnectingBody),
      );
    }
    if (widget.needsAuth) {
      return TermulBanner(
        tone: BannerTone.warn,
        title: l.reconnectAuthTitle,
        action: widget.onReconnect == null
            ? null
            : TermulButton(
                label: l.reconnectShowPrompt,
                variant: TermulButtonVariant.primary,
                size: TermulButtonSize.sm,
                expand: false,
                onPressed: widget.onReconnect,
              ),
        child: Text(l.reconnectAuthBody),
      );
    }
    final failure = widget.failureText;
    final retry = widget.retryInSeconds;
    return TermulBanner(
      tone: failure == null || retry != null ? BannerTone.warn : BannerTone.risk,
      title: retry != null
          ? l.reconnectWaitingTitle
          : (failure == null ? l.reconnectLostTitle : l.reconnectFailedTitle),
      action: widget.onReconnect == null
          ? null
          : TermulButton(
              label: l.reconnectNow,
              variant: TermulButtonVariant.primary,
              size: TermulButtonSize.sm,
              expand: false,
              onPressed: widget.onReconnect,
            ),
      child: Text(retry != null ? l.reconnectWaitingBody(retry) : (failure ?? l.reconnectLostBody)),
    );
  }

  (HostStatus, String) _status(AppLocalizations l) => switch (widget.link) {
    TerminalLink.reconnecting => (HostStatus.busy, l.terminalStatusReconnecting),
    TerminalLink.lost => (HostStatus.offline, l.terminalStatusLost),
    TerminalLink.up => _sessionStatus(l),
  };

  (HostStatus, String) _sessionStatus(AppLocalizations l) => switch (_session.state) {
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
                if (widget.link != TerminalLink.up)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TermulSpacing.space5,
                      0,
                      TermulSpacing.space5,
                      TermulSpacing.space3,
                    ),
                    child: _linkBanner(l),
                  ),
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
                      child: Stack(
                        key: _areaKey,
                        fit: StackFit.expand,
                        children: [
                          // `onTapUp` milik TerminalView tidak pernah dipanggil di xterm 4.0.0, jadi ketukan dibaca dari
                          // pointer mentah (tidak ikut arena gestur: ketuk, gulir, dan seleksi xterm tidak terganggu).
                          Listener(
                            behavior: HitTestBehavior.translucent,
                            onPointerDown: _onPointerDown,
                            onPointerUp: _onPointerUp,
                            child: TerminalView(
                              _session.terminal,
                              key: _viewKey,
                              controller: _controller,
                              scrollController: _scrollController,
                              theme: termulTerminalTheme,
                              textStyle: widget.textStyle ?? termulTerminalStyle,
                              padding: const EdgeInsets.symmetric(horizontal: TermulSpacing.space2),
                              autofocus: true,
                              backgroundOpacity: 1,
                            ),
                          ),
                          SelectionHandles(
                            terminal: _session.terminal,
                            controller: _controller,
                            scrollController: _scrollController,
                            viewKey: _viewKey,
                            style: widget.handleStyle,
                          ),
                          if (_pasteMenu != null) _pasteMenuOverlay(context),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) {
                      final range = _controller.selection?.normalized;
                      if (range == null || range.isCollapsed) {
                        return QuickKeyBar(
                          session: _session,
                          compact: compact,
                          onPaste: widget.link == TerminalLink.up ? _paste : null,
                        );
                      }
                      return SelectionBar(
                        count: _session.terminal.buffer.getText(range).length,
                        compact: compact,
                        onCopy: _copySelection,
                        onSelectAll: _selectAll,
                        onCancel: _controller.clearSelection,
                      );
                    },
                  ),
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

/// Isi dialog tempel: peringatan akibat, daftar baris (yang berisiko diberi kata "berisiko"), dan catatan.
class _PasteDetails extends StatelessWidget {
  const _PasteDetails({required this.analysis});

  final PasteAnalysis analysis;

  /// Baris yang ditampilkan paling banyak; sisanya diringkas supaya dialog tetap ringan.
  static const _maxShown = 50;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final shown = analysis.lines.take(_maxShown).toList();
    final hidden = analysis.lineCount - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TermulSpacing.space5,
      children: [
        if (analysis.hasRisk)
          TermulBanner(tone: BannerTone.risk, child: Text(l.pasteRiskNote(analysis.riskCount)))
        else if (analysis.runsImmediately)
          TermulBanner(tone: BannerTone.risk, child: Text(l.pasteUnsafeNote)),
        if (analysis.hasRisk && analysis.runsImmediately)
          TermulBanner(tone: BannerTone.risk, child: Text(l.pasteUnsafeNote)),
        if (analysis.removedControls > 0)
          TermulBanner(tone: BannerTone.warn, child: Text(l.pasteControlRemoved(analysis.removedControls))),
        Container(
          key: const ValueKey('paste-lines'),
          padding: const EdgeInsets.all(TermulSpacing.space4),
          decoration: BoxDecoration(
            color: TermulPalette.groundDeep,
            borderRadius: BorderRadius.circular(TermulRadius.radiusMd),
            border: Border.all(color: TermulPalette.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final line in shown)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${line.number}',
                          style: TermulText.terminalSm.copyWith(color: TermulPalette.inkFaint),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          line.text.isEmpty ? ' ' : line.text,
                          style: TermulText.terminalSm.copyWith(
                            color: line.risky ? TermulPalette.bad : TermulPalette.terminalInk,
                          ),
                        ),
                      ),
                      if (line.risky)
                        Padding(
                          padding: const EdgeInsets.only(left: TermulSpacing.space3),
                          child: Text(l.pasteRiskTag, style: TermulText.caption.copyWith(color: TermulPalette.bad)),
                        ),
                    ],
                  ),
                ),
              if (hidden > 0)
                Padding(
                  padding: const EdgeInsets.only(top: TermulSpacing.space3),
                  child: Text(
                    l.pasteMoreLines(hidden),
                    style: TermulText.caption.copyWith(color: TermulPalette.inkMuted),
                  ),
                ),
            ],
          ),
        ),
        if (!analysis.runsImmediately)
          Text(l.pasteSafeNote, style: TermulText.caption.copyWith(color: TermulPalette.inkMuted)),
      ],
    );
  }
}

/// Keadaan popover Tempel: posisi kursor saat dibuka (untuk menutupnya bila kursor pindah), kotak kursor di
/// koordinat area terminal, dan isi papan klip.
class _PasteMenu {
  _PasteMenu({
    required this.cursorX,
    required this.cursorY,
    required this.anchor,
    required this.areaSize,
    required this.lines,
  }) : screenSize =
           WidgetsBinding.instance.platformDispatcher.views.first.physicalSize /
           WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

  final int cursorX;
  final int cursorY;
  final Rect anchor;
  final Size areaSize;
  final int lines;

  /// Ukuran layar saat dibuka; berubah (putar layar, keyboard) menutup popover karena posisinya usang.
  final Size screenSize;
}
