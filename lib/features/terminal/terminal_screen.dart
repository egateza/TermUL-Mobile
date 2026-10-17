import 'dart:async';

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
    this.confirmSingleLinePaste = true,
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

  /// Satu baris pendek yang aman tampil di popover dulu (true) atau langsung masuk ke prompt (false). Teks panjang,
  /// banyak baris, atau berisiko selalu lewat dialog konfirmasi.
  final bool confirmSingleLinePaste;

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
  final _bodyKey = GlobalKey();

  /// Popover Tempel di kursor prompt; null bila tertutup.
  _PasteMenu? _pasteMenu;

  @override
  void initState() {
    super.initState();
    _session.onInput = _clearSelectionOnInput;
    _session.terminal.addListener(_closeMenuIfCursorMoved);
    _scrollController.addListener(_closePasteMenu);
    _controller.addListener(_dropSelectionWhileMenuOpen);
    // Buka shell setelah layout pertama supaya PTY langsung berukuran layar sebenarnya, bukan 80x24.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _session.start();
    });
  }

  @override
  void dispose() {
    _session.terminal.removeListener(_closeMenuIfCursorMoved);
    _scrollController.removeListener(_closePasteMenu);
    _controller.removeListener(_dropSelectionWhileMenuOpen);
    _longPressTimer?.cancel();
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
  Timer? _longPressTimer;

  /// Tekan-tahan di area kosong membuka popover Tempel; ditunggu sedikit lebih singkat dari tekan lama xterm
  /// (500 ms) supaya seleksi bawaannya bisa dibatalkan.
  static const _emptyHold = Duration(milliseconds: 450);

  void _onPointerDown(PointerDownEvent e) {
    _downAt = e.position;
    _longPressTimer?.cancel();
    final at = e.position;
    _longPressTimer = Timer(_emptyHold, () => _onHoldAt(at));
  }

  void _onPointerMove(PointerMoveEvent e) {
    final at = _downAt;
    if (at != null && (e.position - at).distance > kTouchSlop) _longPressTimer?.cancel();
  }

  void _onPointerEnd(PointerEvent e) {
    _longPressTimer?.cancel();
    _downAt = null;
  }

  /// Pemicu popover lewat sentuhan: hanya saat sesi berjalan. Tetap aktif di layar alternatif (`tmux`, `vim`,
  /// `htop`) dan di mouse mode, karena yang dicari adalah sel kosong (tekan-tahan di atas teks tidak memicunya).
  bool get _canHoldToPaste => _alive && _session.state == TerminalSessionState.running;

  final _menuKey = GlobalKey();

  /// Ketukan di mana saja di luar popover menutupnya. Dibaca di tingkat layar (pointer mentah) supaya juga
  /// berlaku untuk bar atas, tombol cepat, dan terminal.
  void _onAnyPointerDown(PointerDownEvent e) {
    if (_pasteMenu == null) return;
    final box = _menuKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.attached && box.paintBounds.contains(box.globalToLocal(e.position))) return;
    _closePasteMenu();
  }

  /// Tekan-tahan di area kosong (sisa baris di kanan teks, baris kosong, atau ruang di bawah prompt) menjalankan
  /// alur tempel dengan popover di dekat jari. Di atas teks, tekan lama tetap memilih kata (xterm).
  Future<void> _onHoldAt(Offset global) async {
    if (!mounted || _downAt == null || _pasteMenu != null || !_canHoldToPaste) return;
    final view = _viewKey.currentState;
    if (view == null || !view.renderTerminal.attached) return;
    final render = view.renderTerminal;
    final cell = render.getCellOffset(render.globalToLocal(global));
    final buffer = _session.terminal.buffer;
    final empty = cell.y >= buffer.lines.length || cell.x >= buffer.lines[cell.y].getTrimmedLength();
    if (!empty) return;
    _downAt = null;
    HapticFeedback.selectionClick();
    // Tekan lama xterm bisa sempat memilih kata kosong: buang supaya bilah seleksi tidak menggantikan tombol cepat.
    if (_controller.selection != null) _controller.clearSelection();
    // Area jari: popover muncul di atasnya, tidak tertutup jari.
    await _paste(anchor: Rect.fromCenter(center: global, width: 1, height: 40));
  }

  /// Titik tempat popover muncul bila dipicu tombol Tempel di panel: di atas baris prompt (kursor), supaya baris
  /// itu tetap terlihat dan teks yang akan masuk bisa dibandingkan dengan konteksnya.
  Rect? _defaultPasteAnchor() {
    final view = _viewKey.currentState;
    if (view == null || !view.renderTerminal.attached) return null;
    return view.globalCursorRect;
  }

  /// Menampilkan popover berisi [text] di atas [anchorGlobal] (koordinat layar); [onPaste] menempel.
  void _showPasteMenu(Rect anchorGlobal, String text, VoidCallback onPaste) {
    final area = _bodyKey.currentContext?.findRenderObject();
    if (area is! RenderBox || !area.attached) return;
    final b = _session.terminal.buffer;
    setState(
      () => _pasteMenu = _PasteMenu(
        cursorX: b.cursorX,
        cursorY: b.absoluteCursorY,
        anchor: area.globalToLocal(anchorGlobal.topLeft) & anchorGlobal.size,
        text: text,
        onPaste: () {
          _closePasteMenu();
          onPaste();
        },
      ),
    );
  }

  /// Seleksi kosong dari tekan lama xterm yang terlambat datang saat popover terbuka dibuang.
  void _dropSelectionWhileMenuOpen() {
    if (_pasteMenu != null && _controller.selection != null) _controller.clearSelection();
  }

  Widget _pasteMenuOverlay(BuildContext context) {
    final menu = _pasteMenu!;
    if (MediaQuery.sizeOf(context) != menu.screenSize) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _closePasteMenu());
      return const SizedBox.shrink();
    }
    return CustomSingleChildLayout(
      delegate: _PopoverLayout(menu.anchor, MediaQuery.paddingOf(context)),
      child: PastePopover(key: _menuKey, text: menu.text, onPaste: menu.onPaste),
    );
  }

  bool get _alive =>
      widget.link == TerminalLink.up &&
      (_session.state == TerminalSessionState.opening || _session.state == TerminalSessionState.running);

  /// Tempel dari papan klip. Satu baris tanpa tanda bahaya langsung masuk ke prompt; selain itu isi dan akibatnya
  /// ditampilkan dulu (layar 2b dan 2c di desain).
  Future<void> _paste({Rect? anchor}) async {
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
      final at = anchor ?? _defaultPasteAnchor();
      if (!widget.confirmSingleLinePaste || at == null) {
        send();
      } else {
        _showPasteMenu(at, analysis.text, send);
      }
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

  Widget _linkBanner(AppLocalizations l, {required bool compact, required bool showBody}) {
    if (widget.link == TerminalLink.reconnecting) {
      return TermulBanner(
        compact: compact,
        showBody: showBody,
        tone: BannerTone.warn,
        title: l.reconnectingTitle,
        icon: TermulIconName.refresh,
        child: Text(l.reconnectingBody),
      );
    }
    if (widget.needsAuth) {
      return TermulBanner(
        compact: compact,
        showBody: showBody,
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
      compact: compact,
      showBody: showBody,
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
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _onAnyPointerDown,
            child: Scaffold(
              backgroundColor: TermulPalette.ground,
              // Popover digambar di atas seluruh isi layar (bukan hanya area terminal): di landscape dengan keyboard
              // terbuka area terminal hanya sekitar 65 dp, lebih rendah daripada popover.
              body: Stack(
                key: _bodyKey,
                fit: StackFit.expand,
                children: [
                  Column(
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
                        _Header(
                          profile: widget.profile,
                          status: status,
                          word: word,
                          onBack: Navigator.of(context).maybePop,
                        ),
                      if (widget.link != TerminalLink.up)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            TermulSpacing.space5,
                            0,
                            TermulSpacing.space5,
                            compact && keyboardOpen ? TermulSpacing.space1 : TermulSpacing.space3,
                          ),
                          child: _linkBanner(l, compact: compact, showBody: !(compact && keyboardOpen)),
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
                              fit: StackFit.expand,
                              children: [
                                // Tekan-tahan dibaca dari pointer mentah: tidak ikut arena gestur, jadi ketuk, gulir, dan seleksi
                                // xterm tidak terganggu (`TerminalView.onTapUp` juga tidak pernah dipanggil di xterm 4.0.0).
                                // ClipRect: saat area menyusut (keyboard di landscape) xterm menggambar barisnya sampai melewati
                                // batas atas, menimpa label profil di bar atas.
                                ClipRect(
                                  child: Listener(
                                    behavior: HitTestBehavior.translucent,
                                    onPointerDown: _onPointerDown,
                                    onPointerMove: _onPointerMove,
                                    onPointerCancel: _onPointerEnd,
                                    onPointerUp: _onPointerEnd,
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
                                ),
                                SelectionHandles(
                                  terminal: _session.terminal,
                                  controller: _controller,
                                  scrollController: _scrollController,
                                  viewKey: _viewKey,
                                  style: widget.handleStyle,
                                ),
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
                  if (_pasteMenu != null) _pasteMenuOverlay(context),
                ],
              ),
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

/// Keadaan popover Tempel: posisi kursor saat dibuka (untuk menutupnya bila kursor pindah), area jangkar di
/// koordinat area terminal (jari atau tombol Tempel), teks yang akan ditempel, dan aksi menempel.
class _PasteMenu {
  _PasteMenu({
    required this.cursorX,
    required this.cursorY,
    required this.anchor,
    required this.text,
    required this.onPaste,
  }) : screenSize =
           WidgetsBinding.instance.platformDispatcher.views.first.physicalSize /
           WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

  final int cursorX;
  final int cursorY;
  final Rect anchor;
  final String text;
  final VoidCallback onPaste;

  /// Ukuran layar saat dibuka; berubah (putar layar, keyboard) menutup popover karena posisinya usang.
  final Size screenSize;
}

/// Menaruh popover di atas [anchor], dipusatkan pada jangkar dan dibatasi 8 dp dari tepi area serta dari area aman
/// [safe] (bilah status, lekukan layar, bilah gestur); bila tidak muat di atas, di bawahnya.
class _PopoverLayout extends SingleChildLayoutDelegate {
  const _PopoverLayout(this.anchor, this.safe);

  final Rect anchor;
  final EdgeInsets safe;

  static const _margin = 8.0;
  static const _gap = 6.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => BoxConstraints(
    maxWidth: constraints.maxWidth - safe.horizontal - _margin * 2,
    maxHeight: constraints.maxHeight - safe.vertical - _margin * 2,
  );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final minX = safe.left + _margin;
    final maxX = size.width - safe.right - _margin - childSize.width;
    final x = (anchor.center.dx - childSize.width / 2).clamp(minX, maxX < minX ? minX : maxX);
    final minY = safe.top + _margin;
    final maxY = size.height - safe.bottom - _margin - childSize.height;
    final above = anchor.top - childSize.height - _gap;
    final below = anchor.bottom + _gap;
    final y = above >= minY ? above : below;
    return Offset(x, y.clamp(minY, maxY < minY ? minY : maxY));
  }

  @override
  bool shouldRelayout(_PopoverLayout old) => old.anchor != anchor || old.safe != safe;
}
