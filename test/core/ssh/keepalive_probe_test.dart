import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/ssh/keepalive_watchdog.dart';

class _FakeSocket implements SSHSocket {
  final incoming = StreamController<Uint8List>();
  final outgoing = StreamController<List<int>>();

  @override
  Stream<Uint8List> get stream => incoming.stream;

  @override
  StreamSink<List<int>> get sink => outgoing.sink;

  @override
  Future<void> get done => Completer<void>().future;

  @override
  Future<void> close() async {}

  @override
  void destroy() {}

  @override
  Future<void> flush() async {}
}

void main() {
  const timeout = Duration(milliseconds: 50);

  group('KeepAliveProbe', () {
    test('ping dibalas: hidup', () async {
      final probe = KeepAliveProbe(ping: () async {}, isClosed: () => false, nextInbound: () => Completer<void>().future);
      expect(await probe.check(timeout), isTrue);
      expect(probe.pingUnanswered, isFalse);
    });

    test('ping tidak dibalas tetapi ada data masuk (mis. MikroTik membalas UNIMPLEMENTED): tetap hidup', () async {
      final probe = KeepAliveProbe(
        ping: () => Completer<void>().future,
        isClosed: () => false,
        nextInbound: () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      expect(await probe.check(timeout), isTrue);
      expect(probe.pingUnanswered, isTrue);
    });

    test('ping tidak dibalas dan tidak ada data masuk: mati', () async {
      final probe = KeepAliveProbe(
        ping: () => Completer<void>().future,
        isClosed: () => false,
        nextInbound: () => Completer<void>().future,
      );
      expect(await probe.check(timeout), isFalse);
    });

    test('tanpa pemantau data masuk: hanya balasan ping yang dihitung', () async {
      final probe = KeepAliveProbe(ping: () => Completer<void>().future, isClosed: () => false);
      expect(await probe.check(timeout), isFalse);
    });

    test('klien sudah tertutup: mati tanpa mengirim ping', () async {
      var pinged = false;
      final probe = KeepAliveProbe(ping: () async => pinged = true, isClosed: () => true);
      expect(await probe.check(timeout), isFalse);
      expect(pinged, isFalse);
    });

    test('galat ping diteruskan', () async {
      final probe = KeepAliveProbe(ping: () => Future<void>.error(StateError('tertutup')), isClosed: () => false);
      await expectLater(probe.check(timeout), throwsStateError);
    });

    test('ping yang galat setelah data masuk menang tidak menjadi galat tak tertangani', () async {
      final ping = Completer<void>();
      final probe = KeepAliveProbe(ping: () => ping.future, isClosed: () => false, nextInbound: () async {});
      expect(await probe.check(timeout), isTrue);
      ping.completeError(StateError('klien ditutup'));
      await Future<void>.delayed(Duration.zero);
    });
  });

  group('InboundActivitySocket', () {
    test('nextInbound selesai saat data datang dan data diteruskan utuh', () async {
      final inner = _FakeSocket();
      final socket = InboundActivitySocket(inner);
      final received = <Uint8List>[];
      socket.stream.listen(received.add);

      var signalled = false;
      unawaited(socket.nextInbound().then((_) => signalled = true));
      await Future<void>.delayed(Duration.zero);
      expect(signalled, isFalse);

      inner.incoming.add(Uint8List.fromList([1, 2, 3]));
      await Future<void>.delayed(Duration.zero);
      expect(signalled, isTrue);
      expect(received.single, [1, 2, 3]);

      // Penantian baru menunggu data berikutnya, bukan data yang sudah lewat.
      var again = false;
      unawaited(socket.nextInbound().then((_) => again = true));
      await Future<void>.delayed(Duration.zero);
      expect(again, isFalse);
      inner.incoming.add(Uint8List.fromList([4]));
      await Future<void>.delayed(Duration.zero);
      expect(again, isTrue);
    });
  });

  group('startKeepAliveWatchdog', () {
    test('tanpa tanda hidup: onDead lalu onClose', () async {
      final probe = KeepAliveProbe(ping: () => Completer<void>().future, isClosed: () => false);
      final dead = Completer<void>();
      var closed = false;
      final timer = startKeepAliveWatchdog(
        probe,
        onClose: () => closed = true,
        interval: const Duration(milliseconds: 10),
        timeout: timeout,
        onDead: dead.complete,
      );
      await dead.future.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(Duration.zero);
      expect(closed, isTrue);
      expect(timer.isActive, isFalse);
    });

    test('data masuk menjaga sambungan walau ping tidak pernah dibalas', () async {
      var checks = 0;
      final probe = KeepAliveProbe(
        ping: () {
          checks++;
          return Completer<void>().future;
        },
        isClosed: () => false,
        nextInbound: () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      var dead = false;
      final timer = startKeepAliveWatchdog(
        probe,
        onClose: () {},
        interval: const Duration(milliseconds: 10),
        timeout: timeout,
        onDead: () => dead = true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
      timer.cancel();
      expect(dead, isFalse);
      expect(checks, greaterThan(3));
    });

    test('klien tertutup: berhenti tanpa onDead', () async {
      var dead = false;
      final probe = KeepAliveProbe(ping: () async {}, isClosed: () => true);
      final timer = startKeepAliveWatchdog(
        probe,
        onClose: () {},
        interval: const Duration(milliseconds: 10),
        onDead: () => dead = true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(dead, isFalse);
      expect(timer.isActive, isFalse);
    });
  });
}
