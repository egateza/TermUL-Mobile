import 'package:flutter/foundation.dart';

/// Log siklus sambungan untuk diagnosis di perangkat (`adb logcat -s flutter`). Hanya di build debug dan hanya
/// berisi kejadian dan alasan: tidak pernah nama host, user, sidik jari, atau rahasia.
void connLog(String message) {
  if (kDebugMode) debugPrint('[termul] $message');
}
