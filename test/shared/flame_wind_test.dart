import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/shared/widgets/flame_weather.dart';
import 'package:termul_mobile/shared/widgets/flame_wind.dart';

/// Acak tetap: selalu mengembalikan [value].
class _Fixed implements math.Random {
  _Fixed(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  bool nextBool() => value < 0.5;

  @override
  int nextInt(int max) => (value * max).floor();
}

void main() {
  late double now;
  WindField wind({int level = 1, bool auto = false, double random = 0}) =>
      WindField(auto: auto, level: level, random: _Fixed(random), clock: () => now);

  /// Memajukan waktu bertahap 0,05 detik (langkah bingkai), membaca angin tiap langkah.
  void run(WindField w, double seconds, [void Function()? each]) {
    final end = now + seconds;
    while (now < end - 1e-9) {
      now = math.min(end, now + 0.05);
      w.update();
      each?.call();
    }
  }

  setUp(() => now = 0);

  test('tenang sebelum hembusan pertama (1,5 detik)', () {
    final w = wind();
    expect(w.at(), 0);
    now = 1.4;
    expect(w.at(), 0);
  });

  test('hembusan sepoi-sepoi: naik cepat, meluruh, lalu tenang lagi', () {
    final w = wind(); // acak 0: arah kanan, durasi 1,3 detik, kekuatan 0,32 x 0,75
    w.at(); // menjadwalkan hembusan pertama pada 1,5 detik
    now = 1.5;
    w.at(); // hembusan dimulai
    now = 1.5 + 1.3 * 0.22; // puncak selubung
    final peak = w.at();
    expect(peak, greaterThan(0.15));
    now = 1.5 + 1.3 * 0.8;
    final late = w.at();
    expect(late, inExclusiveRange(0, peak));
    now = 1.5 + 1.31;
    expect(w.at(), 0, reason: 'sepoi-sepoi tanpa angin dasar');
  });

  test('hembusan berikutnya sepoi-sepoi 4,5-8 detik kemudian', () {
    final w = wind(random: 0.99);
    w.at();
    now = 1.5;
    w.at(); // hembusan pertama, jadwal berikutnya 1,5 + 4,5 + 0,99 x 3,5
    now = 1.5 + 4.5 + 3.4;
    expect(w.at(), 0, reason: 'belum waktunya');
    now = 1.5 + 4.5 + 3.47;
    w.at();
    now += 0.3;
    expect(w.at(), isNot(0));
  });

  test('arah kiri memberi nilai negatif; nilai dibatasi -1,5..1,5', () {
    final w = wind(level: 0);
    for (var i = 0; i < 5; i++) {
      w.gust(strength: 1, dir: -1);
    }
    now = 0.3;
    final v = w.at();
    expect(v, lessThan(0));
    expect(v, greaterThanOrEqualTo(-1.5));
  });

  test('tenang: tanpa hembusan otomatis', () {
    final w = wind(level: 0);
    run(w, 30, () => expect(w.at(), 0));
  });

  test('jeda (lapisan dalam) membaca angin yang lebih lama', () {
    final w = wind(level: 0)..gust(strength: 1, dir: 1);
    now = 0.05;
    expect(w.at(delay: 0.1), 0, reason: 'sebelum hembusan dimulai');
    expect(w.at(), greaterThan(0));
  });

  test('kencang: angin dasar bertiup walau belum ada hembusan', () {
    final w = wind(level: 3);
    run(w, 1.4);
    expect(w.at(), greaterThan(0.05));
    expect(wind(level: 1).at(), 0);
  });

  test('naik bertahap: sepoi-sepoi, agak kencang, kencang, hujan badai, tenang, lalu ulang', () {
    final w = wind(auto: true);
    final seen = <int>[w.level];
    run(w, 42, () {
      if (w.level != seen.last) seen.add(w.level);
    });
    expect(seen, [1, 2, 3, 4, 0, 1]);
  });

  test('hujan badai: hujan naik perlahan, kilat berkedip, lalu reda di jenjang lain', () {
    final w = wind(level: 4);
    run(w, 1);
    expect(w.rain, inExclusiveRange(0.3, 0.6));
    var flashes = 0;
    var lit = false;
    run(w, 8, () {
      final on = w.flash > 0.5;
      if (on && !lit) flashes++;
      lit = on;
    });
    expect(w.rain, greaterThan(0.95));
    expect(flashes, greaterThanOrEqualTo(2), reason: 'acak 0: kilat selalu berkedip dua kali');
    w.setLevel(1);
    run(w, 10);
    expect(w.rain, lessThan(0.01));
    expect(w.flash, 0);
  });

  testWidgets('FlameWeather: hujan tergambar saat badai, tidak saat reduce motion', (tester) async {
    final w = wind(level: 4);
    run(w, 6); // hujan sudah deras
    final flameKey = GlobalKey();
    Widget host({required bool reduce}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: FlameWeather(key: ValueKey(reduce), flameKey: flameKey, wind: w, child: const SizedBox.expand()),
          ),
        ),
      ),
    );
    RenderObject paint() =>
        tester.renderObject(find.descendant(of: find.byType(FlameWeather), matching: find.byType(CustomPaint)));

    await tester.pumpWidget(host(reduce: false));
    for (var i = 0; i < 10; i++) {
      now += 0.05;
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(paint(), paints..path());

    await tester.pumpWidget(host(reduce: true));
    await tester.pump(const Duration(milliseconds: 50));
    expect(paint(), isNot(paints..path()));
  });
}
