import json, re, sys
src, out = sys.argv[1], sys.argv[2]
d = json.load(open(src, encoding='utf-8'))
def camel(n):
    p = n.split('-'); return p[0] + ''.join(x.capitalize() for x in p[1:])
colors = {t['name']: t['value'] for t in d['color']['tokens']}
def resolve(v, seen=()):
    m = re.fullmatch(r'\{(.+)\}', v)
    return resolve(colors[m.group(1)], seen + (v,)) if m else v
def argb(h):
    h = h.lstrip('#')
    if len(h) == 6: return '0xFF' + h.upper()
    if len(h) == 8: return '0x' + (h[6:8] + h[0:6]).upper()   # CSS RGBA -> ARGB
    raise ValueError(h)
L = []
L.append('// GENERATED dari docs/design/tokens.json oleh skrip di luar repo. Jangan diubah tangan;')
L.append('// test/core/theme/tokens_test.dart membandingkan berkas ini dengan tokens.json.')
L.append("import 'package:flutter/painting.dart';\n")
L.append('/// Semua token warna (tema Gelap).')
L.append('abstract final class TermulPalette {')
for n, v in colors.items():
    L.append(f'  static const Color {camel(n)} = Color({argb(resolve(v))});')
L.append('')
L.append('  /// Nama token (kebab-case, seperti di tokens.json) ke warna, untuk test dan alat bantu.')
L.append('  static const Map<String, Color> byName = {')
for n in colors: L.append(f"    '{n}': {camel(n)},")
L.append('  };')
L.append('\n  /// level-1 sampai level-9, hanya untuk api streak.')
L.append('  static const List<Color> levels = [' + ', '.join(f'level{i}' for i in range(1, 10)) + '];')
L.append('}\n')
def px(v): return float(v.replace('px',''))
for grp, cls, key in (('spacing','TermulSpacing','tokens'),('size','TermulSize','tokens'),('radius','TermulRadius','tokens')):
    L.append(f'abstract final class {cls} {{')
    names = {}
    for t in d[grp][key]:
        v = t['value']
        val = 999.0 if v == '50%' else px(v)
        nm = camel(t['name']); names[t['name']] = nm
        L.append(f'  static const double {nm} = {val};' + ('  // 50% di token; dipakai sebagai bulat penuh' if v=='50%' else ''))
    L.append('\n  static const Map<String, double> byName = {')
    for k, nm in names.items(): L.append(f"    '{k}': {nm},")
    L.append('  };\n}\n')
fam = d['type']['families']
L.append("/// Keluarga font (aset di assets/fonts, lisensi OFL).")
L.append("abstract final class TermulFonts {\n  static const String sans = 'IBMPlexSans';\n  static const String mono = 'JetBrainsMono';\n}\n")
L.append("/// Gaya teks tanpa warna; warna ditentukan pemakai (token ink-*).")
L.append('abstract final class TermulText {')
styles = {}
for g in d['type']['groups']:
    f = 'sans' if g['family'] == 'sans' else 'mono'
    for s in g['styles']:
        size = px(s['fontSize']); lh = float(s['lineHeight']); w = s['fontWeight']
        ls = s.get('letterSpacing'); lsv = round(float(ls.replace('em','')) * size, 4) if ls else None
        nm = camel(s['name']); styles[s['name']] = nm
        extra = f', letterSpacing: {lsv}' if lsv is not None else ''
        L.append(f'  static const TextStyle {nm} = TextStyle(fontFamily: TermulFonts.{f}, fontSize: {size}, height: {lh}, '
                 f'fontWeight: FontWeight.w{w}, fontVariations: [FontVariation(\'wght\', {float(w)})]{extra});')
L.append('\n  /// Nama token ke (ukuran, tinggi baris, bobot), untuk test.')
L.append('  static const Map<String, (double, double, int)> specByName = {')
for g in d['type']['groups']:
    for s in g['styles']:
        L.append(f"    '{s['name']}': ({px(s['fontSize'])}, {float(s['lineHeight'])}, {s['fontWeight']}),")
L.append('  };\n}')
open(out, 'w', encoding='utf-8', newline='\n').write('\n'.join(L) + '\n')
print(len(colors), 'warna;', sum(len(d[g]['tokens']) for g in ('spacing','size','radius')), 'ukuran;', len(styles), 'gaya teks')
