import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../../core/ssh/ssh_connector.dart';

/// Saluran shell interaktif. Antarmuka tipis di atas `SSHSession` supaya sesi terminal bisa dites tanpa jaringan.
abstract interface class ShellChannel {
  Stream<Uint8List> get stdout;

  Stream<Uint8List> get stderr;

  /// Selesai saat saluran tertutup (shell keluar, atau sambungan putus).
  Future<void> get done;

  void write(Uint8List data);

  void resize(int columns, int rows);

  void close();
}

/// Membuka shell dengan ukuran PTY [columns] x [rows] (ukuran layar sebenarnya, bukan 80x24).
typedef ShellOpener = Future<ShellChannel> Function({required int columns, required int rows});

class SshShellChannel implements ShellChannel {
  SshShellChannel(this._session);

  final SSHSession _session;

  /// Membuka shell pada [connection]. `xterm-256color` adalah bawaan `dartssh2`.
  static Future<ShellChannel> open(SshConnection connection, {required int columns, required int rows}) async {
    final session = await connection.client.shell(
      pty: SSHPtyConfig(width: columns, height: rows),
    );
    return SshShellChannel(session);
  }

  @override
  Stream<Uint8List> get stdout => _session.stdout;

  @override
  Stream<Uint8List> get stderr => _session.stderr;

  @override
  Future<void> get done => _session.done;

  @override
  void write(Uint8List data) => _session.write(data);

  @override
  void resize(int columns, int rows) {
    // `resizeTerminal` mengirim permintaan tanpa menunggu balasan; bila sambungan tertutup sebelum dibalas,
    // `dartssh2` melempar `SSHStateError` ke zona (tanpa penampung). Itu wajar saat memutus, jadi ditelan di sini.
    runZonedGuarded(() => _session.resizeTerminal(columns, rows), (_, _) {});
  }

  @override
  void close() => _session.close();
}
