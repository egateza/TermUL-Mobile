import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/vault/auth_gate.dart';

void main() {
  test('run memberi giliran satu per satu, sesuai urutan masuk', () async {
    final gate = AuthGate();
    final log = <String>[];
    final first = Completer<void>();
    final a = gate.run(() async {
      log.add('a mulai');
      await first.future;
      log.add('a selesai');
      return 1;
    });
    final b = gate.run(() async {
      log.add('b mulai');
      return 2;
    });
    await Future<void>.delayed(Duration.zero);
    expect(log, ['a mulai'], reason: 'b menunggu a');
    first.complete();
    expect(await a, 1);
    expect(await b, 2);
    expect(log, ['a mulai', 'a selesai', 'b mulai']);
  });

  test('galat satu giliran tidak menahan giliran berikutnya', () async {
    final gate = AuthGate();
    final a = gate.run<void>(() async => throw StateError('gagal'));
    await expectLater(a, throwsStateError);
    expect(await gate.run(() async => 'lanjut'), 'lanjut');
  });

  test('recentlyDenied: berlaku selama jendela, bisa dihapus', () {
    var now = DateTime(2026, 10, 16, 12);
    final gate = AuthGate(window: const Duration(seconds: 30), now: () => now);
    expect(gate.recentlyDenied, isFalse);
    gate.recordDenied();
    expect(gate.recentlyDenied, isTrue);
    now = now.add(const Duration(seconds: 29));
    expect(gate.recentlyDenied, isTrue);
    now = now.add(const Duration(seconds: 2));
    expect(gate.recentlyDenied, isFalse);
    gate.recordDenied();
    gate.clearDenied();
    expect(gate.recentlyDenied, isFalse);
  });
}
