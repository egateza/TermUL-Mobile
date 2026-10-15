import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:termul_mobile/core/models/host_profile.dart';
import 'package:termul_mobile/core/ssh/ssh_connector.dart';

/// Soket yang tidak pernah menjawab: cukup untuk membangun `SSHClient` tanpa jaringan.
class SilentSocket extends SSHSocket {
  SilentSocket() {
    _out.stream.listen((_) {}, onDone: () => _done.isCompleted ? null : _done.complete());
  }

  final _in = StreamController<Uint8List>();
  final _out = StreamController<List<int>>();
  final _done = Completer<void>();

  @override
  Stream<Uint8List> get stream => _in.stream;
  @override
  StreamSink<List<int>> get sink => _out.sink;
  @override
  Future<void> get done => _done.future;
  @override
  Future<void> close() async {
    await _out.close();
    await _in.close();
  }

  @override
  void destroy() {
    unawaited(close());
  }
}

/// Sambungan SSH palsu (belum terautentikasi) untuk tes layar.
SshConnection fakeConnection(HostProfile profile) =>
    SshConnection.forTest(SSHClient(SilentSocket(), username: 'x'), profile);
