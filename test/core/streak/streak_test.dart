import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/streak/streak.dart';
import 'package:termul_mobile/core/streak/streak_tier.dart';

// Port dari StreakTest, TapCounterTest, dan StreakTierTest desktop (commit b3d7854150).
final d = DateTime.utc(2026, 10, 13);

Streak streak(int count, int daysAgo) => Streak(count, d.subtract(Duration(days: daysAgo)));

void main() {
  group('Streak', () {
    test('pertama kali dibuka jadi hari ke-1', () {
      final opening = Streak.none.open(d);
      expect(opening.streak, Streak(1, d));
      expect(opening.event, const StreakCounted(0, 1));
      expect(opening.streak.status(d), const StreakKindling(1));
    });

    test('hari yang sama tidak dihitung dua', () {
      final s = streak(5, 0);
      final opening = s.open(d);
      expect(identical(opening.streak, s), isTrue);
      expect(opening.event, const StreakSameDay());
    });

    test('jam mundur ke hari sebelumnya tidak mengubah apa pun', () {
      final s = streak(5, 0);
      final opening = s.open(d.subtract(const Duration(days: 3)));
      expect(opening.event, const StreakSameDay());
      expect(identical(opening.streak, s), isTrue);
    });

    test('aktif di hari ketiga', () {
      final day2 = streak(2, 1);
      expect(day2.active, isFalse);
      final opening = day2.open(d);
      expect(opening.event, const StreakCounted(2, 3));
      expect(opening.streak.active, isTrue);
      expect(opening.streak.status(d), const StreakBurning(3));
    });

    test('bara yang bolong mulai lagi dari hari ke-1', () {
      final opening = streak(2, 2).open(d);
      expect(opening.streak, Streak(1, d));
      expect(opening.event, const StreakCounted(0, 1));
    });

    test('absen satu dan dua hari padam', () {
      for (var missed = 1; missed <= 2; missed++) {
        final s = streak(47, missed + 1);
        final opening = s.open(d);
        expect(identical(opening.streak, s), isTrue);
        expect(opening.event, StreakNeedsRevival(StreakGray(47, missed)));
      }
    });

    test('absen 3 sampai 10 hari beku dengan 5 sampai 10 ketukan', () {
      const expected = [5, 6, 7, 8, 9, 10, 10, 10];
      for (var missed = 3; missed <= 10; missed++) {
        expect(streak(47, missed + 1).status(d), StreakFrozen(47, missed, expected[missed - 3]));
      }
    });

    test('absen lebih dari 10 hari hangus', () {
      final opening = streak(47, 12).open(d);
      expect(opening.event, const StreakExpiredEvent(47, 11));
      expect(opening.streak, Streak(1, d));
    });

    test('memulihkan melanjutkan angka dan menghitung hari ini', () {
      expect(streak(47, 2).revive(d), Streak(48, d));
      final frozen = streak(47, 6);
      expect(frozen.revive(d), Streak(48, d));
      expect(frozen.revive(d).status(d), const StreakBurning(48));
    });

    test('ditunda tetap menunggu dan bisa membeku', () {
      final gray = streak(47, 3); // absen 2 hari
      expect(gray.status(d), isA<StreakGray>());
      // "Nanti saja" lalu besok dibuka lagi: absen 3 hari, jadi beku.
      expect(gray.open(d.add(const Duration(days: 1))).event, const StreakNeedsRevival(StreakFrozen(47, 3, 5)));
    });

    test('tidak bisa memulihkan streak yang menyala atau hangus', () {
      expect(() => streak(47, 0).revive(d), throwsStateError);
      expect(() => streak(47, 12).revive(d), throwsStateError);
    });

    test('tanpa tanggal berarti kosong; angka negatif ditolak', () {
      expect(Streak(5, null), Streak.none);
      expect(() => Streak(-1, d), throwsArgumentError);
    });

    test('tanggal lokal dengan jam disamakan ke harinya', () {
      final opening = Streak(3, DateTime(2026, 10, 12, 23, 59)).open(DateTime(2026, 10, 13, 0, 1));
      expect(opening.event, const StreakCounted(3, 4));
    });
  });

  group('tanggal ISO', () {
    test('bolak-balik dan menolak tanggal yang tidak ada', () {
      expect(isoDay(d), '2026-10-13');
      expect(parseIsoDay('2026-10-13'), d);
      expect(() => parseIsoDay('kemarin'), throwsFormatException);
      expect(() => parseIsoDay('2026-02-30'), throwsFormatException);
    });
  });

  group('TapCounter', () {
    test('tiga ketukan cepat menggenapi', () {
      final taps = TapCounter(3);
      expect(taps.tap(1000), isFalse);
      expect(taps.tap(1300), isFalse);
      expect(taps.tap(1700), isTrue);
    });

    test('jeda terlalu lama mulai dari awal', () {
      final taps = TapCounter(3)
        ..tap(1000)
        ..tap(1400);
      expect(taps.tap(1400 + TapCounter.windowMs), isFalse, reason: 'jeda tepat 500 ms terlalu lama');
      expect(taps.tap(2100), isFalse);
      expect(taps.tap(2200), isTrue);
    });

    test('setelah genap hitungan mulai lagi', () {
      final taps = TapCounter(3)
        ..tap(0)
        ..tap(100);
      expect(taps.tap(200), isTrue);
      expect(taps.tap(300), isFalse);
    });
  });

  group('StreakTier', () {
    test('batas level berjenjang', () {
      expect(StreakTier.of(0), StreakTier.bara);
      expect(StreakTier.of(2), StreakTier.bara);
      expect(StreakTier.of(3), StreakTier.jingga);
      expect(StreakTier.of(9), StreakTier.jingga);
      expect(StreakTier.of(10), StreakTier.merah);
      expect(StreakTier.of(29), StreakTier.merah);
      expect(StreakTier.of(30), StreakTier.magenta);
      expect(StreakTier.of(60), StreakTier.ungu);
      expect(StreakTier.of(100), StreakTier.biru);
      expect(StreakTier.of(180), StreakTier.zamrud);
      expect(StreakTier.of(364), StreakTier.zamrud);
      expect(StreakTier.of(365), StreakTier.emas);
      expect(StreakTier.of(730), StreakTier.pelangi);
      expect(StreakTier.of(100000), StreakTier.pelangi);
    });

    test('level atas makin ramai', () {
      StreakTier? previous;
      for (final tier in StreakTier.values) {
        if (previous != null) {
          expect(tier.min, greaterThan(previous.min));
          expect(tier.tongues, greaterThanOrEqualTo(previous.tongues));
          expect(tier.sparks, greaterThanOrEqualTo(previous.sparks));
        }
        previous = tier;
      }
      expect(StreakTier.values.where((t) => t.stars), [StreakTier.emas, StreakTier.pelangi]);
      expect(StreakTier.values.where((t) => t.rainbow), [StreakTier.pelangi]);
    });
  });
}
