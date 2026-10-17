import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/storage/json/json_streak_repository.dart';
import 'package:termul_mobile/core/streak/streak.dart';
import 'package:termul_mobile/core/streak/streak_record.dart';

final d = DateTime.utc(2026, 10, 13);
DateTime ago(int days) => d.subtract(Duration(days: days));

void main() {
  group('StreakRecord', () {
    test('membuka mencatat hari yang dihitung dan streak terpanjang', () {
      var r = StreakRecord();
      for (var i = 4; i >= 0; i--) {
        r = r.open(ago(i)).record;
      }
      expect(r.streak, Streak(5, d));
      expect(r.days, [for (var i = 4; i >= 0; i--) ago(i)]);
      expect(r.longest, 5);
    });

    test('hari yang sama tidak mengubah rekaman', () {
      final r = StreakRecord().open(d).record;
      final again = r.open(d);
      expect(identical(again.record, r), isTrue);
      expect(again.event, const StreakSameDay());
    });

    test('padam: hari bolong tidak dicatat, menyalakan mencatat hari ini', () {
      final r = StreakRecord(streak: Streak(23, ago(2)), days: [ago(3), ago(2)], longest: 23);
      final opening = r.open(d);
      expect(opening.event, const StreakNeedsRevival(StreakGray(23, 1)));
      expect(opening.record.isActiveDay(d), isFalse);
      final revived = opening.record.revive(d);
      expect(revived.streak, Streak(24, d));
      expect(revived.days, [ago(3), ago(2), d]);
      expect(revived.longest, 24);
    });

    test('hangus memulai lagi dari 1 tanpa menurunkan streak terpanjang', () {
      final r = StreakRecord(streak: Streak(47, ago(12)), longest: 47);
      final opening = r.open(d);
      expect(opening.event, const StreakExpiredEvent(47, 11));
      expect(opening.record.streak, Streak(1, d));
      expect(opening.record.longest, 47);
    });

    test('riwayat dibatasi dan lastDay selalu tercatat', () {
      final many = [for (var i = 0; i < StreakRecord.maxDays + 20; i++) ago(i)];
      final r = StreakRecord(streak: Streak(3, d), days: many);
      expect(r.days, hasLength(StreakRecord.maxDays));
      expect(r.days.last, d);
      expect(StreakRecord(streak: Streak(3, d)).days, [d]);
    });

    test('JSON: format desktop terbaca, field tambahan ditulis', () {
      final desktop = StreakRecord.fromJson({'format': 1, 'count': 23, 'lastDay': '2026-10-13', 'lain': true});
      expect(desktop.streak, Streak(23, d));
      expect(desktop.days, [d]);
      expect(desktop.longest, 23);
      final json = desktop.toJson();
      expect(json, {
        'format': 1,
        'count': 23,
        'lastDay': '2026-10-13',
        'days': ['2026-10-13'],
        'longest': 23,
      });
      expect(StreakRecord.fromJson(json), desktop);
    });

    test('JSON: angka negatif menjadi kosong seperti desktop; tanggal rusak ditolak', () {
      expect(StreakRecord.fromJson({'count': -4, 'lastDay': '2026-10-13'}).streak, Streak.none);
      expect(() => StreakRecord.fromJson({'count': 5, 'lastDay': 'kemarin'}), throwsFormatException);
      expect(
        () => StreakRecord.fromJson({
          'count': 5,
          'lastDay': '2026-10-13',
          'days': [1],
        }),
        throwsFormatException,
      );
      expect(() => StreakRecord.fromJson({'count': '5'}), throwsFormatException);
    });
  });

  group('JsonStreakRepository', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('streak'));
    tearDown(() async => dir.delete(recursive: true));

    File file() => File('${dir.path}${Platform.pathSeparator}streak.json');

    test('berkas belum ada berarti kosong', () async {
      final repo = JsonStreakRepository(file());
      final res = await repo.load();
      expect(res.hadCorruptFile, isFalse);
      expect(repo.record.streak, Streak.none);
    });

    test('tersimpan dan terbaca lagi', () async {
      final record = StreakRecord(streak: Streak(23, d), days: [ago(1), d], longest: 30);
      await JsonStreakRepository(file()).save(record);
      final repo = JsonStreakRepository(file());
      await repo.load();
      expect(repo.record, record);
      final text = await file().readAsString();
      expect(jsonDecode(text), containsPair('lastDay', '2026-10-13'));
    });

    test('berkas rusak disisihkan', () async {
      await file().writeAsString('{"count": 5, "lastDay": "kemarin"}');
      final repo = JsonStreakRepository(file());
      final res = await repo.load();
      expect(res.hadCorruptFile, isTrue);
      expect(repo.record.streak, Streak.none);
      expect(await file().exists(), isFalse);
      expect(dir.listSync().any((e) => e.path.contains('streak.json.corrupt-')), isTrue);
    });
  });
}
