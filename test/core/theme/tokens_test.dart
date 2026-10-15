import 'dart:convert';
import 'dart:math';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/theme/termul_theme.dart';

/// Menjaga agar konstanta Dart tidak melenceng dari docs/design/tokens.json.
void main() {
  final json = jsonDecode(File('docs/design/tokens.json').readAsStringSync()) as Map<String, Object?>;
  Map<String, Object?> section(String k) => json[k]! as Map<String, Object?>;
  List<Map<String, Object?>> list(Object? v) => (v! as List<Object?>).cast<Map<String, Object?>>();

  Color parse(String hex) {
    final h = hex.substring(1);
    return h.length == 6
        ? Color(int.parse('FF$h', radix: 16))
        : Color(int.parse('${h.substring(6)}${h.substring(0, 6)}', radix: 16));
  }

  final colorTokens = {for (final t in list(section('color')['tokens'])) t['name']! as String: t['value']! as String};
  String resolve(String v) {
    final m = RegExp(r'^\{(.+)\}$').firstMatch(v);
    return m == null ? v : resolve(colorTokens[m.group(1)]!);
  }

  test('setiap token warna di tokens.json ada di TermulPalette dengan nilai sama', () {
    expect(TermulPalette.byName.length, colorTokens.length);
    for (final e in colorTokens.entries) {
      expect(TermulPalette.byName[e.key], parse(resolve(e.value)), reason: 'token ${e.key}');
    }
  });

  test('level-1 sampai level-9 lengkap dan berurutan', () {
    expect(TermulPalette.levels, hasLength(9));
    for (var i = 1; i <= 9; i++) {
      expect(TermulPalette.levels[i - 1], TermulPalette.byName['level-$i']);
    }
  });

  for (final (name, map) in [
    ('spacing', TermulSpacing.byName),
    ('size', TermulSize.byName),
    ('radius', TermulRadius.byName),
  ]) {
    test('token $name sama dengan tokens.json', () {
      final tokens = list(section(name)['tokens']);
      expect(map.length, tokens.length);
      for (final t in tokens) {
        final v = t['value']! as String;
        final expected = v == '50%' ? 999.0 : double.parse(v.replaceAll('px', ''));
        expect(map[t['name']], expected, reason: 'token ${t['name']}');
      }
    });
  }

  test('gaya teks: ukuran, tinggi baris, dan bobot sama dengan tokens.json', () {
    var count = 0;
    for (final g in list(section('type')['groups'])) {
      for (final s in list(g['styles'])) {
        final spec = TermulText.specByName[s['name']]!;
        expect(spec.$1, double.parse((s['fontSize']! as String).replaceAll('px', '')), reason: s['name']! as String);
        expect(spec.$2, double.parse(s['lineHeight']! as String), reason: s['name']! as String);
        expect(spec.$3, s['fontWeight'], reason: s['name']! as String);
        count++;
      }
    }
    expect(TermulText.specByName.length, count);
  });

  test('keluarga font sesuai tokens.json', () {
    final fam = section('type')['families']! as Map<String, Object?>;
    expect(fam['sans'], contains('IBM Plex Sans'));
    expect(fam['mono'], contains('JetBrains Mono'));
    expect(TermulFonts.sans, 'IBMPlexSans');
    expect(TermulFonts.mono, 'JetBrainsMono');
  });

  test('kontras teks utama: ink di ground dan on-accent di accent minimal 4,5:1 (token mengklaim 15,9 dan 9,8)', () {
    double lum(Color c) {
      double f(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }

    double ratio(Color a, Color b) {
      final la = lum(a), lb = lum(b);
      return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
    }

    expect(ratio(TermulPalette.ink, TermulPalette.ground), greaterThan(15));
    expect(ratio(TermulPalette.onAccent, TermulPalette.accent), greaterThan(9));
    expect(ratio(TermulPalette.inkMuted, TermulPalette.surface), greaterThan(4.5));
  });
}
