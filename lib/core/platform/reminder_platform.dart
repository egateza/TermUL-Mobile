import 'package:flutter/services.dart';

/// Jembatan ke pengingat streak harian Android (`android/.../StreakReminder.kt`): satu alarm inexact yang memasang
/// dirinya lagi tiap 24 jam sampai dijadwalkan ulang atau dibatalkan. Android saja.
abstract interface class ReminderPlatform {
  /// Menjadwalkan pengingat pertama pada [at] (menggantikan jadwal sebelumnya) dan menutup pengingat yang masih tampil.
  Future<void> schedule({
    required DateTime at,
    required String title,
    required String text,
    required String channelName,
  });

  Future<void> cancel();
}

class MethodChannelReminder implements ReminderPlatform {
  MethodChannelReminder([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('io.github.egateza.termul/reminder');

  final MethodChannel _channel;

  @override
  Future<void> schedule({
    required DateTime at,
    required String title,
    required String text,
    required String channelName,
  }) => _channel.invokeMethod<void>('schedule', {
    'at': at.millisecondsSinceEpoch,
    'title': title,
    'text': text,
    'channelName': channelName,
  });

  @override
  Future<void> cancel() => _channel.invokeMethod<void>('cancel');
}

/// Tanpa efek (tes); mencatat permintaan terakhir.
class NoopReminder implements ReminderPlatform {
  NoopReminder();

  /// Waktu terjadwal terakhir; null bila dibatalkan atau belum pernah.
  DateTime? scheduledAt;
  String? title;
  String? text;
  int calls = 0;

  @override
  Future<void> schedule({
    required DateTime at,
    required String title,
    required String text,
    required String channelName,
  }) async {
    scheduledAt = at;
    this.title = title;
    this.text = text;
    calls++;
  }

  @override
  Future<void> cancel() async {
    scheduledAt = null;
    calls++;
  }
}
