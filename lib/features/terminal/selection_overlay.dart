import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:xterm/xterm.dart';
// RenderTerminal tidak diekspor xterm 4.0.0; dibutuhkan untuk mengubah sel menjadi posisi layar (lampiran A8).
// ignore: implementation_imports
import 'package:xterm/src/ui/render.dart' show RenderTerminal;

import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';

/// Dua gagang yang bisa diseret di awal dan akhir seleksi (xterm 4.0.0 hanya memilih satu kata tanpa gagang;
/// perhitungannya dari lampiran A8 di `docs/design/spike-temuan.md`). Dipasang di atas [TerminalView] dalam
/// `Stack`; tanpa seleksi, widget ini kosong dan tidak menangkap sentuhan.
class SelectionHandles extends StatefulWidget {
  const SelectionHandles({
    super.key,
    required this.terminal,
    required this.controller,
    required this.scrollController,
    required this.viewKey,
  });

  final Terminal terminal;
  final TerminalController controller;
  final ScrollController scrollController;
  final GlobalKey<TerminalViewState> viewKey;

  /// Jarak pusat bulatan dari bawah sel, supaya jari tidak menutupi huruf yang dipilih.
  static const _gap = 14.0;
  static const _touch = 44.0;
  static const _dot = 14.0;

  @override
  State<SelectionHandles> createState() => _SelectionHandlesState();
}

class _SelectionHandlesState extends State<SelectionHandles> {
  /// Sisi seleksi yang tidak sedang digeser (anchor akan dibuat ulang dari offset ini).
  CellOffset? _fixed;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(SelectionHandles old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller ||
        old.scrollController != widget.scrollController ||
        old.terminal != widget.terminal) {
      _unlisten(old);
      _listen();
    }
  }

  @override
  void dispose() {
    _unlisten(widget);
    super.dispose();
  }

  void _listen() {
    widget.controller.addListener(_changed);
    widget.scrollController.addListener(_changed);
    widget.terminal.addListener(_changed);
  }

  void _unlisten(SelectionHandles w) {
    w.controller.removeListener(_changed);
    w.scrollController.removeListener(_changed);
    w.terminal.removeListener(_changed);
  }

  /// Pendengar bisa terpanggil saat layout (gulir); tunda ke akhir frame bila begitu.
  void _changed() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  RenderTerminal? get _render => widget.viewKey.currentState?.renderTerminal;

  /// Pojok kiri atas sel di koordinat widget ini; null bila belum bisa dihitung.
  Offset? _cellTopLeft(CellOffset cell) {
    final render = _render;
    final box = context.findRenderObject();
    if (render == null || !render.attached || box is! RenderBox || !box.hasSize) return null;
    return box.globalToLocal(render.localToGlobal(render.getOffset(cell)));
  }

  void _drag(Offset global, {required bool movingStart}) {
    final render = _render;
    final fixed = _fixed;
    final box = context.findRenderObject();
    if (render == null || fixed == null || box is! RenderBox) return;
    final cell = render.cellSize;
    final local = box.globalToLocal(global);
    // Jari ada di bulatan; sel yang dimaksud ada di atasnya. Geser setengah lebar sel agar yang dipilih adalah
    // batas antar-sel terdekat (ujung seleksi bersifat eksklusif).
    final p = local - Offset(0, SelectionHandles._gap + cell.height / 2);
    final hit = render.getCellOffset(render.globalToLocal(box.localToGlobal(Offset(p.dx + cell.width / 2, p.dy))));
    final terminal = widget.terminal;
    final target = CellOffset(hit.x.clamp(0, terminal.viewWidth), hit.y.clamp(0, terminal.buffer.lines.length - 1));
    widget.controller.setSelection(
      terminal.buffer.createAnchorFromOffset(movingStart ? target : fixed),
      terminal.buffer.createAnchorFromOffset(movingStart ? fixed : target),
    );
  }

  Widget _handle(Offset anchor, {required bool isStart, required Size cell}) {
    final l = AppLocalizations.of(context);
    final center = Offset(anchor.dx, anchor.dy + cell.height + SelectionHandles._gap);
    const half = SelectionHandles._touch / 2;
    return Positioned(
      left: center.dx - half,
      top: center.dy - half,
      width: SelectionHandles._touch,
      height: SelectionHandles._touch,
      child: Semantics(
        label: isStart ? l.selectionHandleStart : l.selectionHandleEnd,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) {
            final range = widget.controller.selection?.normalized;
            _fixed = range == null ? null : (isStart ? range.end : range.begin);
          },
          onPanUpdate: (d) => _drag(d.globalPosition, movingStart: isStart),
          onPanEnd: (_) => _fixed = null,
          onPanCancel: () => _fixed = null,
          child: Center(
            child: Container(
              width: SelectionHandles._dot,
              height: SelectionHandles._dot,
              decoration: BoxDecoration(
                color: TermulPalette.accent,
                shape: BoxShape.circle,
                border: Border.all(color: TermulPalette.ground, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = widget.controller.selection?.normalized;
    final render = _render;
    if (range == null || range.isCollapsed || render == null || !render.attached) {
      return const SizedBox.shrink();
    }
    final start = _cellTopLeft(range.begin);
    final end = _cellTopLeft(range.end);
    if (start == null || end == null) return const SizedBox.shrink();
    final cell = render.cellSize;
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _handle(start, isStart: true, cell: cell),
          _handle(end, isStart: false, cell: cell),
        ],
      ),
    );
  }
}
