import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
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
  WindField wind({double amount = WindField.sepoi, double random = 0}) =>
      WindField(amount: amount, random: _Fixed(random), clock: () => now);

  setUp(() => now = 0);

  test('tenang sebelum hembusan pertama (2,2 detik)', () {
    final w = wind();
    expect(w.at(), 0);
    now = 2.1;
    expect(w.at(), 0);
  });

  test('hembusan otomatis sepoi: naik cepat, meluruh, lalu tenang lagi', () {
    final w = wind(); // acak 0: arah kanan, durasi 1,3 detik, kekuatan 0,6 x 0,75
    w.at(); // menjadwalkan hembusan pertama pada 2,2 detik
    now = 2.2;
    w.at(); // hembusan dimulai
    now = 2.2 + 1.3 * 0.22; // puncak selubung
    final peak = w.at();
    expect(peak, greaterThan(0.3));
    now = 2.2 + 1.3 * 0.8;
    final late = w.at();
    expect(late, inExclusiveRange(0, peak));
    now = 2.2 + 1.31;
    expect(w.at(), 0);
  });

  test('hembusan berikutnya sepoi 4,5-8,5 detik kemudian', () {
    final w = wind(random: 0.99);
    w.at();
    now = 2.2;
    w.at(); // hembusan pertama, jadwal berikutnya 2,2 + 4,5 + 0,99 x 4
    now = 2.2 + 4.5 + 3.9;
    expect(w.at(), 0, reason: 'belum waktunya');
    now = 2.2 + 4.5 + 3.97;
    w.at();
    now += 0.3;
    expect(w.at(), isNot(0));
  });

  test('arah kiri memberi nilai negatif; nilai dibatasi -1,2..1,2', () {
    final w = wind(amount: 0);
    for (var i = 0; i < 5; i++) {
      w.gust(strength: 1, dir: -1);
    }
    now = 0.3;
    final v = w.at();
    expect(v, lessThan(0));
    expect(v, greaterThanOrEqualTo(-1.2));
  });

  test('kekuatan 0: tanpa hembusan otomatis', () {
    final w = wind(amount: 0);
    for (now = 0; now < 30; now += 0.5) {
      expect(w.at(), 0);
    }
  });

  test('jeda (lapisan dalam) membaca angin yang lebih lama', () {
    final w = wind(amount: 0)..gust(strength: 1, dir: 1);
    now = 0.05;
    expect(w.at(delay: 0.1), 0, reason: 'sebelum hembusan dimulai');
    expect(w.at(), greaterThan(0));
  });
}
