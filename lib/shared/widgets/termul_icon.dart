import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../core/theme/termul_theme.dart';

String _rect(double x, double y, double w, double h, double r) =>
    'M${x + r} $y H${x + w - r} A$r $r 0 0 1 ${x + w} ${y + r} V${y + h - r} A$r $r 0 0 1 ${x + w - r} ${y + h} '
    'H${x + r} A$r $r 0 0 1 $x ${y + h - r} V${y + r} A$r $r 0 0 1 ${x + r} $y Z';

String _circle(double cx, double cy, double r) => 'M${cx - r} $cy a$r $r 0 1 0 ${2 * r} 0 a$r $r 0 1 0 ${-2 * r} 0 Z';

/// Ikon garis inline (viewBox 24, tebal 1,75, ujung dan sambungan bulat, warna dari [color] atau `IconTheme`).
/// Bentuk dari prototipe desain; ikon yang tidak ada di prototipe (hapus, ubah, kunci, bintang, muat ulang,
/// lainnya) dibuat dengan gaya yang sama dan belum ditinjau desainer.
enum TermulIconName {
  search('M20 20l-3.5-3.5'),
  plus('M12 5v14M5 12h14'),
  minus('M5 12h14'),
  close('M6 6l12 12M18 6L6 18'),
  check('M5 12l5 5 9-10'),
  chevronDown('M6 9l6 6 6-6'),
  chevronLeft('M15 6l-6 6 6 6'),
  chevronRight('M9 6l6 6-6 6'),
  warning('M12 4l10 17H2zM12 10v5M12 18h.01'),
  shield('M12 3l8 3v6c0 4.5-3.2 8-8 9-4.8-1-8-4.5-8-9V6zM9 12l2 2 4-4'),
  lock('M8 11V8a4 4 0 0 1 8 0v3'),
  // Gembok terbuka: pengait terangkat di sisi kanan (vault terbuka).
  lockOpen('M8 11V8a4 4 0 0 1 7.5-2'),
  hosts('M7 7.5h.01M7 16.5h.01'),
  terminal('M7 9l3 3-3 3M13 15h4'),
  folder('M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z'),
  snippets(
    'M8 4c-2 0-3 1-3 3v2c0 1-1 3-2 3 1 0 2 2 2 3v2c0 2 1 3 3 3M16 4c2 0 3 1 3 3v2c0 1 1 3 2 3-1 0-2 2-2 3v2c0 2-1 3-3 3',
  ),
  settings('M4 7h10M18 7h2M4 17h2M10 17h10'),
  trash('M4 7h16M10 11v6M14 11v6M6 7l1 12a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-12M9 7V4h6v3'),
  edit('M4 20h4L19 9a2.8 2.8 0 0 0-4-4L4 16zM14 6l4 4'),
  key('M11 12l9-9M16 7l3 3M14 9l2 2'),
  // Api satu lidah bergaya garis untuk tab Streak; bukan `Flame` desain (api berwarna tier).
  flame('M12 3c.5 3.2 5.5 5.3 5.5 10.2a5.5 5.5 0 0 1-11 0c0-2.2 1-3.6 2.3-4.7.1 1.8.9 2.8 2 3.2C10 8.8 10.5 5.7 12 3z'),
  star('M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z'),
  refresh('M20 12a8 8 0 1 1-2.3-5.7M20 4v4h-4'),
  more('M12 6h.01M12 12h.01M12 18h.01'),
  // Dua kolom titik: pegangan untuk menggeser baris (urutan kategori).
  // Dua panah berlawanan: mengurutkan.
  sort('M7 4v16M4 17l3 3 3-3M17 20V4M14 7l3-3 3 3'),
  grip('M9 6h.01M9 12h.01M9 18h.01M15 6h.01M15 12h.01M15 18h.01'),
  copy('M5 15V6a2 2 0 0 1 2-2h8'),
  selectAll('M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2M8 12h8'),
  file('M6 3h8l5 5v13H6zM14 3v5h5'),
  upload('M12 16V5M7 10l5-5 5 5M5 19h14'),
  download('M12 5v11M7 11l5 5 5-5M5 19h14'),
  link('M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1'),
  // Folder berpanah naik-turun: folder di server jauh (SFTP), berbeda dari `folder` polos.
  sftp(
    'M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2zM9.5 16v-5.5M7.5 12.5l2-2 2 2M14.5 10.5V16M12.5 14l2 2 2-2',
  );

  const TermulIconName(this._extra);

  final String _extra;

  static final _cache = <TermulIconName, Path>{};

  Path get path => _cache[this] ??= parseSvgPathData(pathData);

  /// Bentuk dasar yang dihasilkan dari persegi dan lingkaran, digabung dengan [_extra].
  String get pathData => switch (this) {
    search => '${_circle(11, 11, 7)} $_extra',
    lock || lockOpen => '${_rect(5, 11, 14, 9, 2)} $_extra',
    hosts => '${_rect(3, 4, 18, 7, 2)} ${_rect(3, 13, 18, 7, 2)} $_extra',
    terminal => '${_rect(3, 4, 18, 16, 2)} $_extra',
    key => '${_circle(8, 15, 4)} $_extra',
    copy => '${_rect(9, 9, 11, 11, 2)} $_extra',
    _ => _extra,
  };
}

class TermulIcon extends StatelessWidget {
  const TermulIcon(this.name, {super.key, this.size = 20, this.color, this.label, this.filled = false});

  final TermulIconName name;
  final double size;
  final Color? color;

  /// Nama untuk pembaca layar. Tanpa label, ikon disembunyikan dari pembaca layar.
  final String? label;

  /// Mengisi bentuk (bintang, api) dengan warna ikon.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? TermulPalette.ink;
    final icon = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _IconPainter(name.path, c, filled)),
    );
    return label == null ? ExcludeSemantics(child: icon) : Semantics(label: label, image: true, child: icon);
  }
}

class _IconPainter extends CustomPainter {
  const _IconPainter(this.path, this.color, this.filled);

  final Path path;
  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.75
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
    if (filled) {
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) => old.path != path || old.color != color || old.filled != filled;
}
