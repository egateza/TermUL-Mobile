# Pemetaan ke Flutter

Token di sistem ini dipetakan ke `ThemeData` dan satu `ThemeExtension` untuk token yang tidak punya padanan di Material. Nama field mengikuti nama token (kebab menjadi camelCase). Jangan menulis warna atau ukuran langsung di widget.

| Token | Flutter |
|---|---|
| `ground` | `ThemeData.scaffoldBackgroundColor` dan `ColorScheme.surface` |
| `surface`, `surface-raised` | `TermulColors.surface`, `TermulColors.surfaceRaised` |
| `ink` | `ColorScheme.onSurface` |
| `accent`, `on-accent` | `ColorScheme.primary`, `ColorScheme.onPrimary` |
| `bad` | `ColorScheme.error` |
| `ok`, `ice`, `info`, `terminal-*`, `level-*` | field di `TermulColors` |
| `space-*`, `size`, `radius-*` | konstanta di kelas `TermulSpacing`, `TermulSize`, `TermulRadius` |
| gaya teks `h1`..`nav-label`, `count-*`, `terminal`, `key` | `TextTheme` dan `TermulText` (gaya mono) |

```dart
// theme.dart (acuan; sesuaikan dengan versi Flutter yang dipakai)
@immutable
class TermulColors extends ThemeExtension<TermulColors> {
  const TermulColors({
    required this.groundDeep,
    required this.surface,
    required this.surfaceRaised,
    required this.line,
    required this.lineStrong,
    required this.ok,
    required this.ice,
    required this.levels,
  });

  final Color groundDeep, surface, surfaceRaised, line, lineStrong, ok, ice;
  final List<Color> levels; // level-1..level-9

  static const dark = TermulColors(
    groundDeep: Color(0xFF0A0E10),
    surface: Color(0xFF161C20),
    surfaceRaised: Color(0xFF1E262B),
    line: Color(0xFF2A343A),
    lineStrong: Color(0xFF5C6A71),
    ok: Color(0xFF5ED3A6),
    ice: Color(0xFF9BD4F5),
    levels: [Color(0xFFC96A2B), Color(0xFFF0B34A), Color(0xFFFF8A3D)],
  );

  @override
  TermulColors copyWith() => this;

  @override
  TermulColors lerp(ThemeExtension<TermulColors>? other, double t) => this;
}

ThemeData termulTheme() => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0F1316),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFF0B34A),
        onPrimary: Color(0xFF1B1406),
        surface: Color(0xFF0F1316),
        onSurface: Color(0xFFE8EEF0),
        error: Color(0xFFFF7F70),
      ),
      fontFamily: 'IBMPlexSans',
      extensions: const [TermulColors.dark],
    );
```

- Daftar `levels` di contoh hanya tiga warna pertama; isi sembilan sesuai token `level-1` sampai `level-9`, dan simpan warna lapis luar, inti dan cahaya (`tier-n-outer`, `tier-n-core`, `tier-n-glow`) untuk menggambar api.
- Api digambar ulang di Flutter dengan `CustomPainter` memakai path yang sama dengan komponen `Flame` (tiga lapis bentuk, lidah api, percikan), atau memakai Rive bila ingin state machine; jalankan goyangan hanya saat layar terlihat.
- Sertakan berkas font IBM Plex Sans dan JetBrains Mono sebagai aset aplikasi agar tidak bergantung pada jaringan. Keduanya setahu kami berlisensi OFL; periksa berkas lisensi saat membundelnya.
- Fokus: bungkus kontrol interaktif dengan `FocusableActionDetector` atau `Focus` dan gambar cincin 2px `accent`, offset 2px.
- Reduce motion: baca `MediaQuery.disableAnimationsOf(context)` dan lewati animasi bila benar.
