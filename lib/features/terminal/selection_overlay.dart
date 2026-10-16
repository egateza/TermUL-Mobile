import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:xterm/xterm.dart';
// RenderTerminal tidak diekspor xterm 4.0.0; dibutuhkan untuk mengubah sel menjadi posisi layar (lampiran A8).
// ignore: implementation_imports
import 'package:xterm/src/ui/render.dart' show RenderTerminal;

import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';

/// Dua gagang (bulatan `accent` bertepi `ground`, pilihan pemilik) yang bisa diseret di awal dan akhir seleksi, plus kaca pembesar di atas jari saat menyeret (xterm
/// 4.0.0 hanya memilih satu kata tanpa gagang; perhitungannya dari lampiran A8 di `docs/design/spike-temuan.md`).
/// Dipasang di atas [TerminalView] dalam `Stack`; tanpa seleksi, widget ini kosong dan tidak menangkap sentuhan.
///
/// - Gagang tetap berada di dalam layar: di tepi bawah ia naik, di tepi kiri dan kanan ia menjauh dari tepi
///   ([_edgeMargin]) supaya sentuhan tidak jatuh di zona gestur kembali Android. Yang dihitung adalah selisih jari
///   dari titik seleksi saat gagang diraih, bukan posisi gagang, jadi seleksi tetap bisa mencapai kolom pertama,
///   kolom terakhir, dan baris terakhir.
/// - Kaca pembesar menampilkan sel yang sedang ditunjuk dengan perbesaran [_zoom].
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

  /// Jarak minimum pusat gagang dari tepi kiri dan kanan (zona gestur kembali Android sekitar 24 dp).
  static const _edgeMargin = 36.0;

  static const _lensSize = Size(120, 56);
  static const _zoom = 1.6;

  @override
  State<SelectionHandles> createState() => _SelectionHandlesState();
}

/// Keadaan satu seretan gagang.
class _Drag {
  _Drag({required this.fixed, required this.movingStart, required this.grab});

  /// Sisi seleksi yang tidak digeser.
  final CellOffset fixed;
  final bool movingStart;

  /// Selisih jari dari titik seleksi (tepi kiri sel, tengah baris) saat gagang diraih.
  final Offset grab;

  /// Titik yang sedang ditunjuk (tepi kiri sel, tengah baris) di koordinat widget; dasar posisi kaca pembesar.
  Offset? focal;
}

class _SelectionHandlesState extends State<SelectionHandles> {
  _Drag? _drag;

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

  RenderBox? get _box {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize ? box : null;
  }

  /// Pojok kiri atas sel di koordinat widget ini; null bila belum bisa dihitung. Widget ini menutupi persis
  /// [TerminalView] (sama-sama memenuhi `Stack`), jadi koordinat render terminal sama dengan koordinat di sini; ini
  /// juga berlaku saat dipanggil dari tahap layout (LayoutBuilder), ketika transformasi global belum siap.
  Offset? _cellTopLeft(CellOffset cell) {
    final render = _render;
    if (render == null || !render.attached) return null;
    return render.getOffset(cell);
  }

  void _startDrag(Offset global, {required bool isStart}) {
    final range = widget.controller.selection?.normalized;
    final render = _render;
    final box = _box;
    if (range == null || render == null || box == null) return;
    final boundary = isStart ? range.begin : range.end;
    final topLeft = _cellTopLeft(boundary);
    if (topLeft == null) return;
    final point = Offset(topLeft.dx, topLeft.dy + render.cellSize.height / 2);
    _drag = _Drag(
      fixed: isStart ? range.end : range.begin,
      movingStart: isStart,
      grab: box.globalToLocal(global) - point,
    );
  }

  void _updateDrag(Offset global) {
    final drag = _drag;
    final render = _render;
    final box = _box;
    if (drag == null || render == null || box == null) return;
    final cell = render.cellSize;
    final p = box.globalToLocal(global) - drag.grab;
    // Geser setengah lebar sel supaya yang dipilih adalah batas antar-sel terdekat (ujung seleksi eksklusif).
    final hit = render.getCellOffset(render.globalToLocal(box.localToGlobal(Offset(p.dx + cell.width / 2, p.dy))));
    final terminal = widget.terminal;
    final target = CellOffset(hit.x.clamp(0, terminal.viewWidth), hit.y.clamp(0, terminal.buffer.lines.length - 1));
    widget.controller.setSelection(
      terminal.buffer.createAnchorFromOffset(drag.movingStart ? target : drag.fixed),
      terminal.buffer.createAnchorFromOffset(drag.movingStart ? drag.fixed : target),
    );
    final tl = _cellTopLeft(target);
    setState(() => drag.focal = tl == null ? null : Offset(tl.dx, tl.dy + cell.height / 2));
  }

  void _endDrag() {
    if (_drag == null) return;
    setState(() => _drag = null);
  }

  Widget _handle(Offset anchor, {required bool isStart, required Size cell, required Size area}) {
    final l = AppLocalizations.of(context);
    const half = SelectionHandles._touch / 2;
    const margin = SelectionHandles._edgeMargin;
    final cx = area.width > margin * 2 ? anchor.dx.clamp(margin, area.width - margin) : anchor.dx;
    final cy = (anchor.dy + cell.height + SelectionHandles._gap).clamp(half, area.height - half);
    return Positioned(
      left: cx - half,
      top: cy - half,
      width: SelectionHandles._touch,
      height: SelectionHandles._touch,
      child: Semantics(
        label: isStart ? l.selectionHandleStart : l.selectionHandleEnd,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _startDrag(d.globalPosition, isStart: isStart),
          onPanUpdate: (d) => _updateDrag(d.globalPosition),
          onPanEnd: (_) => _endDrag(),
          onPanCancel: _endDrag,
          // Pilihan pemilik (2026-10-16): bulatan `accent` bertepi `ground`, bukan `info` bertangkai seperti prototipe.
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

  /// Kaca pembesar di atas titik yang ditunjuk; bila tidak muat di atas, di bawah gagang.
  Widget? _lens(Size cell, Size area) {
    final focal = _drag?.focal;
    if (focal == null) return null;
    const size = SelectionHandles._lensSize;
    final dx = focal.dx.clamp(size.width / 2, area.width - size.width / 2);
    var dy = focal.dy - cell.height / 2 - 12 - size.height / 2 - SelectionHandles._touch / 2;
    if (dy - size.height / 2 < 0) {
      dy = focal.dy + cell.height / 2 + SelectionHandles._gap + SelectionHandles._touch + size.height / 2;
    }
    final center = Offset(dx, dy);
    // Kaca pembesar hanya bisa mengambil isi yang ada di layar: di tepi, wilayah yang diambil (lebar lensa dibagi
    // perbesaran) digeser ke dalam. Titik yang sebenarnya ditunjuk lalu tidak lagi di tengah lensa, jadi ditandai
    // dengan garis.
    const zoom = SelectionHandles._zoom;
    final halfW = size.width / zoom / 2;
    final halfH = size.height / zoom / 2;
    final sample = Offset(
      area.width > halfW * 2 ? focal.dx.clamp(halfW, area.width - halfW) : focal.dx,
      area.height > halfH * 2 ? focal.dy.clamp(halfH, area.height - halfH) : focal.dy,
    );
    final mark = Offset(size.width / 2, size.height / 2) + (focal - sample) * zoom;
    return Positioned(
      left: center.dx - size.width / 2,
      top: center.dy - size.height / 2,
      width: size.width,
      height: size.height,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: RawMagnifier(
            key: const ValueKey('selection-lens'),
            size: size,
            magnificationScale: zoom,
            focalPointOffset: sample - center,
            clipBehavior: Clip.hardEdge,
            decoration: MagnifierDecoration(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TermulRadius.radiusLg),
                side: const BorderSide(color: TermulPalette.accent, width: 1.5),
              ),
            ),
            child: CustomPaint(painter: _LensMarkerPainter(mark, cell.height * zoom)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = widget.controller.selection?.normalized;
    if (range == null || range.isCollapsed) return const SizedBox.shrink();
    // LayoutBuilder: ukuran area harus yang terbaru (bilah di bawah bisa berganti tinggi dalam frame yang sama).
    return LayoutBuilder(
      builder: (context, constraints) {
        final render = _render;
        if (render == null || !render.attached) return const SizedBox.shrink();
        final start = _cellTopLeft(range.begin);
        final end = _cellTopLeft(range.end);
        if (start == null || end == null) return const SizedBox.shrink();
        final area = constraints.biggest;
        final cell = render.cellSize;
        final lens = _lens(cell, area);
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _handle(start, isStart: true, cell: cell, area: area),
              _handle(end, isStart: false, cell: cell, area: area),
              ?lens,
            ],
          ),
        );
      },
    );
  }
}

/// Garis tegak di titik yang sedang ditunjuk di dalam kaca pembesar.
class _LensMarkerPainter extends CustomPainter {
  const _LensMarkerPainter(this.at, this.height);

  final Offset at;
  final double height;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(at.dx, at.dy - height / 2),
      Offset(at.dx, at.dy + height / 2),
      Paint()
        ..color = TermulPalette.accent
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_LensMarkerPainter old) => old.at != at || old.height != height;
}
