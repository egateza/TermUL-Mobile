import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:xterm/xterm.dart';
// RenderTerminal tidak diekspor xterm 4.0.0; dibutuhkan untuk mengubah sel menjadi posisi layar (lampiran A8).
// ignore: implementation_imports
import 'package:xterm/src/ui/render.dart' show RenderTerminal;

import '../../core/models/app_settings.dart' show SelectionHandleStyle;
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';

/// Dua gagang (tetesan `accent` bertepi `ground`, pilihan pemilik) yang bisa diseret di awal dan akhir seleksi, plus kaca pembesar di atas jari saat menyeret (xterm
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
    this.style = SelectionHandleStyle.drop,
  });

  final Terminal terminal;
  final TerminalController controller;
  final ScrollController scrollController;
  final GlobalKey<TerminalViewState> viewKey;

  /// Bentuk gagang (pengaturan Terminal).
  final SelectionHandleStyle style;

  /// Jarak pusat bulatan dari bawah sel, supaya jari tidak menutupi huruf yang dipilih.
  static const _gap = 14.0;
  static const _touch = 44.0;

  /// Ukuran tetesan: jari-jari bulatan, jarak ujung ke pusat bulatan, dan jarak ujung dari tepi atas area sentuh.
  static const _dropRadius = 8.0;
  static const _dropReach = 12.0;
  static const _dropTop = 5.0;

  /// Jarak minimum pusat gagang dari tepi kiri dan kanan (zona gestur kembali Android sekitar 24 dp).
  static const _edgeMargin = 36.0;

  /// Gulir otomatis: jari dalam jarak [_autoScrollZone] dari tepi atas atau bawah area terminal menggulir isi, makin
  /// dekat makin cepat sampai [_autoScrollMaxSpeed] (px/detik).
  static const _autoScrollZone = 56.0;
  static const _autoScrollMaxSpeed = 900.0;

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

class _SelectionHandlesState extends State<SelectionHandles> with SingleTickerProviderStateMixin {
  _Drag? _drag;

  /// Posisi jari terakhir (global) selama seretan; dipakai gulir otomatis untuk memperbarui seleksi tanpa gerakan jari.
  Offset? _lastGlobal;
  Ticker? _scroller;
  Duration _lastTick = Duration.zero;

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
    _scroller?.dispose();
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
    _lastGlobal = global;
    _applyDrag(global);
    _syncAutoScroll();
  }

  /// Kecepatan gulir (px/detik, negatif ke atas) bagi jari di [localY]: nol di luar zona tepi, makin cepat makin
  /// dekat ke tepi (dan di luar tepi).
  static double scrollVelocity(double localY, double height) {
    const zone = SelectionHandles._autoScrollZone;
    const maxSpeed = SelectionHandles._autoScrollMaxSpeed;
    if (height <= zone * 2) return 0;
    if (localY < zone) return -maxSpeed * ((zone - localY) / zone).clamp(0.0, 1.0);
    if (localY > height - zone) return maxSpeed * ((localY - (height - zone)) / zone).clamp(0.0, 1.0);
    return 0;
  }

  double _velocity() {
    final global = _lastGlobal;
    final box = _box;
    if (global == null || box == null) return 0;
    return scrollVelocity(box.globalToLocal(global).dy, box.size.height);
  }

  /// Menyalakan atau mematikan gulir otomatis sesuai posisi jari.
  void _syncAutoScroll() {
    final moving = _drag != null && _velocity() != 0 && widget.scrollController.hasClients;
    final ticker = _scroller ??= createTicker(_onScrollTick);
    if (moving && !ticker.isActive) {
      _lastTick = Duration.zero;
      ticker.start();
    } else if (!moving && ticker.isActive) {
      ticker.stop();
    }
  }

  void _onScrollTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    final v = _velocity();
    final scroll = widget.scrollController;
    final global = _lastGlobal;
    if (_drag == null || global == null || v == 0 || !scroll.hasClients) {
      _scroller?.stop();
      return;
    }
    final position = scroll.position;
    final target = (position.pixels + v * dt).clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target != position.pixels) {
      scroll.jumpTo(target);
      // Isi bergeser di bawah jari: hitung ulang sel yang ditunjuk.
      _applyDrag(global);
    }
  }

  void _applyDrag(Offset global) {
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
    _scroller?.stop();
    _lastGlobal = null;
    if (_drag == null) return;
    setState(() => _drag = null);
  }

  Widget _handle(Offset anchor, {required bool isStart, required Size cell, required Size area}) {
    final l = AppLocalizations.of(context);
    const half = SelectionHandles._touch / 2;
    const margin = SelectionHandles._edgeMargin;
    final cx = area.width > margin * 2 ? anchor.dx.clamp(margin, area.width - margin) : anchor.dx;
    // Badan gagang dijauhkan dari tepi kiri dan kanan, tetapi ujungnya tetap menunjuk titik seleksi yang sebenarnya:
    // gagang miring ke arahnya.
    final tilt = anchor.dx - cx;
    // Ujung menyentuh dasar sel. Bila tidak ada ruang di bawah (baris paling bawah), gagang dibalik: ujungnya
    // menyentuh sisi atas sel dan badannya berada di atas.
    final below = anchor.dy + cell.height + 1 - SelectionHandles._dropTop;
    final flip = below + SelectionHandles._touch > area.height && anchor.dy - 1 - SelectionHandles._touch > 0;
    final top = flip ? anchor.dy - 1 - SelectionHandles._touch + SelectionHandles._dropTop : below;
    return Positioned(
      left: cx - half,
      top: top,
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
          // Bentuk gagang pilihan pemilik (bawaan tetesan `accent` bertepi `ground`, bisa diganti di Pengaturan),
          // bukan bulatan `info` bertangkai seperti prototipe.
          child: SelectionHandleShape(
            style: widget.style,
            tilt: tilt,
            flip: flip,
            size: const Size.square(SelectionHandles._touch),
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

/// Gambar satu gagang seleksi dalam salah satu bentuk [SelectionHandleStyle]; dipakai oleh gagang di terminal dan
/// pratinjau di Pengaturan. Ujung (titik yang menunjuk batas seleksi) ada [SelectionHandles._dropTop] dari tepi atas
/// gambar dan sejajar dengan pusat bulatan; [tilt] menggesernya ke samping (gagang miring) dan [flip] membalik gambar
/// secara vertikal (ujung di bawah).
class SelectionHandleShape extends StatelessWidget {
  const SelectionHandleShape({
    super.key,
    required this.style,
    this.tilt = 0,
    this.flip = false,
    this.size = const Size(44, 36),
  });

  final SelectionHandleStyle style;

  /// Selisih mendatar ujung dari pusat bulatan (dp); positif ke kanan.
  final double tilt;
  final bool flip;
  final Size size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: size, painter: _HandlePainter(style, tilt, flip)),
  );
}

/// Bentuk:
/// - tetesan: bulatan dengan ujung runcing yang sisinya sedikit melengkung ke dalam, bersambung halus ke bulatan;
/// - segitiga: bulatan dengan segitiga terpisah di dekat ujung, sisi bawah segitiga melengkung mengikuti bulatan;
/// - bulatan: bulatan polos (tanpa ujung, jadi tidak miring).
class _HandlePainter extends CustomPainter {
  const _HandlePainter(this.style, this.tilt, this.flip);

  final SelectionHandleStyle style;
  final double tilt;
  final bool flip;

  static const _ring = 3.0;
  static const _radius = 7.0;

  void _paint(Canvas canvas, Path path) {
    canvas.drawPath(
      path,
      Paint()
        ..color = TermulPalette.ground
        ..style = PaintingStyle.stroke
        ..strokeWidth = _ring
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(path, Paint()..color = TermulPalette.accent);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (flip) {
      canvas.translate(0, size.height);
      canvas.scale(1, -1);
    }
    final x = size.width / 2;
    switch (style) {
      case SelectionHandleStyle.drop:
        final center = Offset(x, SelectionHandles._dropTop + SelectionHandles._dropReach);
        _drop(canvas, _tipFor(center, SelectionHandles._dropReach), center);
      case SelectionHandleStyle.triangle:
        final center = Offset(x, SelectionHandles._dropTop + 15);
        _triangle(canvas, _tipFor(center, 15), center);
      case SelectionHandleStyle.dot:
        _paint(
          canvas,
          Path()..addOval(Rect.fromCircle(center: Offset(x, SelectionHandles._dropTop + 13), radius: _radius)),
        );
    }
  }

  /// Letak ujung: dari pusat bulatan ke arah titik seleksi yang sebenarnya ([tilt] ke samping, [reach] ke atas),
  /// dengan jarak tetap [reach] dan sudut dari tegak lurus paling 45 derajat. Jarak tetap membuat bentuk hanya
  /// berputar, tidak memanjang atau menggepeng saat miring.
  Offset _tipFor(Offset center, double reach) {
    const maxAngle = 45 * math.pi / 180;
    final angle = math.atan2(tilt, reach).clamp(-maxAngle, maxAngle);
    return center + Offset(math.sin(angle), -math.cos(angle)) * reach;
  }

  /// Tetesan: garis singgung dari [tip] ke bulatan di [center]; titik kendali ditarik sedikit ke sumbu supaya sisi
  /// runcing melengkung ke dalam.
  void _drop(Canvas canvas, Offset tip, Offset center) {
    const r = SelectionHandles._dropRadius;
    final toTip = tip - center;
    final d = toTip.distance;
    final base = math.atan2(toTip.dy, toTip.dx);
    final alpha = math.acos(r / d);
    final start = base - alpha;
    final end = base + alpha;
    final left = center + Offset(math.cos(start), math.sin(start)) * r;
    final right = center + Offset(math.cos(end), math.sin(end)) * r;
    final axis = toTip / d;
    final normal = Offset(-axis.dy, axis.dx);
    Offset control(Offset p) {
      final mid = Offset.lerp(tip, p, 0.5)!;
      final side = ((p - tip).dx * normal.dx + (p - tip).dy * normal.dy).sign;
      return mid - normal * (1.2 * side);
    }

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(control(left).dx, control(left).dy, left.dx, left.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: r), start, -(2 * math.pi - 2 * alpha), false)
      ..quadraticBezierTo(control(right).dx, control(right).dy, tip.dx, tip.dy)
      ..close();
    _paint(canvas, path);
  }

  /// Segitiga: ujung di [tip], alas berupa busur sepusat dengan bulatan di [center] sehingga melengkung mengikuti
  /// bulatan; arah segitiga mengikuti arah [tip] dari pusat.
  void _triangle(Canvas canvas, Offset tip, Offset center) {
    const gap = 3.0;
    const halfAngle = 28 * math.pi / 180;
    _paint(canvas, Path()..addOval(Rect.fromCircle(center: center, radius: _radius)));
    const outer = _radius + gap;
    final toTip = tip - center;
    final base = math.atan2(toTip.dy, toTip.dx);
    final corner = center + Offset(math.cos(base + halfAngle), math.sin(base + halfAngle)) * outer;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(corner.dx, corner.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: outer), base + halfAngle, -2 * halfAngle, false)
      ..close();
    _paint(canvas, path);
  }

  @override
  bool shouldRepaint(_HandlePainter old) => old.style != style || old.tilt != tilt || old.flip != flip;
}
