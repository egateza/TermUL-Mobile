import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/streak_repository.dart';
import '../../core/streak/streak.dart';
import '../../core/streak/streak_record.dart';

/// Penyimpanan streak; bawaan di memori (tes), bootstrap menyuntikkan `JsonStreakRepository`.
final streakRepositoryProvider = Provider<StreakRepository>((ref) => MemoryStreakRepository());

/// Jam untuk menentukan hari ini dan jeda ketukan; diganti di tes.
final streakClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Keadaan streak yang ditampilkan: rekaman tersimpan, hari yang sedang berlaku, dan progres ketukan.
class StreakView {
  const StreakView({required this.record, required this.today, this.cracks = 0, this.taps = 0, this.opened = false});

  final StreakRecord record;

  /// Hari yang berlaku (hasil `dayOf`).
  final DateTime today;

  /// Retakan es sejak beku ditampilkan.
  final int cracks;

  /// Ketukan beruntun pada api padam (titik progres).
  final int taps;

  /// Hari ini sudah dihitung ([StreakController.openToday] sudah berjalan).
  final bool opened;

  int get count => record.streak.count;

  StreakStatus get status => record.streak.status(today);

  /// Api padam atau beku dan menunggu diketuk.
  bool get waiting => status is StreakGray || status is StreakFrozen;

  /// Ketukan yang dibutuhkan untuk menyalakan; 0 bila tidak menunggu.
  int get need => switch (status) {
    StreakGray() => 3,
    StreakFrozen(:final clicks) => clicks,
    _ => 0,
  };

  /// Ketukan yang sudah terkumpul menuju [need].
  int get progress => status is StreakFrozen ? cracks : taps;

  /// Hari ini sudah terhitung (bukan padam atau beku yang menunggu).
  bool get todayCounted => record.isActiveDay(today);

  StreakView copyWith({StreakRecord? record, DateTime? today, int? cracks, int? taps, bool? opened}) => StreakView(
    record: record ?? this.record,
    today: today ?? this.today,
    cracks: cracks ?? this.cracks,
    taps: taps ?? this.taps,
    opened: opened ?? this.opened,
  );
}

/// Akibat satu ketukan pada api, untuk animasi.
enum StreakTapEffect {
  /// Api tidak menunggu: hanya bergoyang.
  poke,

  /// Ketukan pada api padam yang belum genap tiga.
  tap,

  /// Api padam menyala lagi.
  revive,

  /// Es retak.
  crack,

  /// Es pecah dan api menyala lagi.
  shatter,
}

/// Menghitung hari saat aplikasi dibuka atau tanggal berganti, dan menangani ketukan pada api (port
/// `StreakController` desktop). Penyimpanan ke disk berjalan di belakang; bila gagal, keadaan di memori tetap
/// berlaku sampai aplikasi ditutup (sama dengan desktop yang hanya mencatat peringatan).
class StreakController extends Notifier<StreakView> {
  final _taps = TapCounter(3);

  @override
  StreakView build() {
    final record = ref.watch(streakRepositoryProvider).record;
    return StreakView(record: record, today: dayOf(ref.read(streakClockProvider)()));
  }

  /// Aplikasi dibuka (atau tanggal berganti selagi terbuka): hitung hari ini. Mengembalikan peristiwanya untuk splash.
  StreakEvent openToday() {
    final day = dayOf(ref.read(streakClockProvider)());
    final result = state.record.open(day);
    _taps.reset();
    final changed = !identical(result.record, state.record);
    state = StreakView(record: result.record, today: day, opened: true);
    if (changed) _save(result.record);
    return result.event;
  }

  /// Dipanggil berkala dan saat aplikasi kembali ke depan. Bila tanggal sudah berganti sejak [openToday], hari
  /// baru dihitung dan peristiwanya dikembalikan; selain itu null.
  StreakEvent? checkDay() {
    if (!state.opened) return null;
    final day = dayOf(ref.read(streakClockProvider)());
    if (day == state.today) return null;
    return openToday();
  }

  /// Ketukan pada api: tiga ketukan cepat menyalakan api padam, [StreakView.need] ketukan memecahkan es.
  StreakTapEffect tap() {
    checkDay();
    final now = ref.read(streakClockProvider)();
    final view = state;
    switch (view.status) {
      case StreakGray():
        if (_taps.tap(now.millisecondsSinceEpoch)) {
          _revive(view.today);
          return StreakTapEffect.revive;
        }
        state = view.copyWith(taps: _taps.taps);
        return StreakTapEffect.tap;
      case StreakFrozen(:final clicks):
        final cracks = view.cracks + 1;
        if (cracks >= clicks) {
          _revive(view.today);
          return StreakTapEffect.shatter;
        }
        state = view.copyWith(cracks: cracks);
        return StreakTapEffect.crack;
      default:
        return StreakTapEffect.poke;
    }
  }

  void _revive(DateTime day) {
    final next = state.record.revive(day);
    _taps.reset();
    state = StreakView(record: next, today: day, opened: state.opened);
    _save(next);
  }

  void _save(StreakRecord record) {
    unawaited(
      ref.read(streakRepositoryProvider).save(record).catchError((Object e) {
        // Tanpa rahasia; cukup jenis galat.
        debugPrint('[termul] streak tidak tersimpan: ${e.runtimeType}');
      }),
    );
  }
}

final streakControllerProvider = NotifierProvider<StreakController, StreakView>(StreakController.new);
