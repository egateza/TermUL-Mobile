import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' show ListView;
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/app_providers.dart';
import 'package:termul_mobile/core/models/auth_method.dart';
import 'package:termul_mobile/core/models/host_profile.dart';
import 'package:termul_mobile/core/models/known_host.dart';
import 'package:termul_mobile/core/ssh/ssh_connector.dart';
import 'package:termul_mobile/core/ssh/ssh_failure.dart';
import 'package:termul_mobile/core/vault/secret_type.dart';
import 'package:termul_mobile/features/connect/connect_flow.dart';
import 'package:termul_mobile/features/terminal/terminal_screen.dart';
import 'package:termul_mobile/shared/widgets/host_row.dart';

import 'hosts_ui_harness.dart';
import 'silent_socket.dart';

/// Fungsi sambung palsu: tiap panggilan dicatat dan dijalankan oleh [script].
class _Net {
  final calls = <SshCredentials>[];
  final connections = <SshConnection>[];
  Future<SshConnection> Function(HostKeyDecider decide)? script;

  ConnectFunction get fn =>
      ({required HostProfile profile, required SshCredentials credentials, required HostKeyDecider decideHostKey}) {
        calls.add(credentials);
        return script!(decideHostKey);
      };

  SshConnection open(HostProfile profile) {
    final c = fakeConnection(profile);
    connections.add(c);
    return c;
  }
}

HostKeyChallenge _challenge(HostKeyVerdict v, {List<String> stored = const []}) => HostKeyChallenge(
  host: '192.0.2.11',
  port: 22,
  type: 'ssh-ed25519',
  fingerprint: 'SHA256:baruBaruBaru',
  verdict: v,
  storedFingerprints: stored,
);

late Uint8List plainKey;
bool keygen = false;

Future<void> _openConnect(WidgetTester tester, Harness h, _Net net) async {
  await h.pump(tester, overrides: [connectFunctionProvider.overrideWithValue(net.fn)], realConnect: true);
  await tester.tap(find.widgetWithText(HostRow, 'app-01'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> leaveTerminal(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Kembali'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Putuskan'));
  await tester.pumpAndSettle();
}

Future<void> reopen(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(HostRow, 'app-01'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(() async {
    try {
      final r = await Process.run('ssh-keygen', ['-?']);
      keygen = r.exitCode != 127;
    } on ProcessException {
      keygen = false;
    }
    if (!keygen) return;
    final dir = await Directory.systemTemp.createTemp('termul_connkeys_');
    final path = '${dir.path}${Platform.pathSeparator}k';
    await Process.run('ssh-keygen', ['-t', 'ed25519', '-N', '', '-q', '-C', 'uji', '-f', path]);
    plainKey = await File(path).readAsBytes();
    await dir.delete(recursive: true);
  });

  testWidgets('ketuk host membuka alur sambung; password tersimpan dipakai; Putuskan menutup sambungan', (
    tester,
  ) async {
    final h = Harness();
    await h.seed([host(id1)]);
    await h.vault.put(id1, SecretType.loginPassword, 'rahasia');
    final net = _Net();
    net.script = (_) async => net.open(h.hosts.snapshot.profiles.single);
    await _openConnect(tester, h, net);
    await tester.pumpAndSettle();
    expect(find.byType(TerminalScreen), findsOneWidget);
    expect((net.calls.single as PasswordCredentials).password, 'rahasia');
    await leaveTerminal(tester);
    expect(find.byType(TerminalScreen), findsNothing);
    expect(net.connections.single.isClosed, isTrue);
  });

  testWidgets('host baru: layar host key menampilkan sidik jari; "Percayai dan sambung" mengirim trustAndSave', (
    tester,
  ) async {
    final h = Harness();
    await h.seed([host(id1)]);
    await h.vault.put(id1, SecretType.loginPassword, 'rahasia');
    HostKeyChoice? got;
    final net = _Net();
    net.script = (decide) async {
      got = await decide(_challenge(HostKeyVerdict.newHost));
      return net.open(h.hosts.snapshot.profiles.single);
    };
    await _openConnect(tester, h, net);
    expect(find.text('Host baru'), findsOneWidget);
    expect(find.text('SHA256:baruBaruBaru'), findsOneWidget);
    expect(find.text('ssh-ed25519'), findsOneWidget);
    expect(find.text('Sambung sekali saja'), findsOneWidget);
    await tester.tap(find.text('Percayai dan sambung'));
    await tester.pumpAndSettle();
    expect(got, HostKeyChoice.trustAndSave);
    expect(find.byType(TerminalScreen), findsOneWidget);
  });

  testWidgets('host baru: "Sambung sekali saja" dan "Batalkan" memberi pilihan yang sesuai', (tester) async {
    final h = Harness();
    await h.seed([host(id1)]);
    await h.vault.put(id1, SecretType.loginPassword, 'rahasia');
    HostKeyChoice? got;
    final net = _Net();
    net.script = (decide) async {
      got = await decide(_challenge(HostKeyVerdict.newHost));
      if (got == HostKeyChoice.reject) throw const SshHostKeyRejected(changed: false);
      return net.open(h.hosts.snapshot.profiles.single);
    };
    await _openConnect(tester, h, net);
    await tester.tap(find.text('Sambung sekali saja'));
    await tester.pumpAndSettle();
    expect(got, HostKeyChoice.connectOnce);
    await leaveTerminal(tester);

    await reopen(tester);
    await tester.tap(find.text('Batalkan'));
    await tester.pumpAndSettle();
    expect(got, HostKeyChoice.reject);
    expect(find.text('Host key ditolak'), findsOneWidget);
  });

  testWidgets('host key berubah: pilihan aman jadi tombol utama; ganti key aktif setelah persetujuan', (tester) async {
    final h = Harness();
    await h.seed([host(id1)]);
    await h.vault.put(id1, SecretType.loginPassword, 'rahasia');
    HostKeyChoice? got;
    final net = _Net();
    net.script = (decide) async {
      got = await decide(_challenge(HostKeyVerdict.changed, stored: const ['SHA256:lamaLamaLama']));
      return net.open(h.hosts.snapshot.profiles.single);
    };
    await _openConnect(tester, h, net);
    expect(find.text('Host key berubah'), findsOneWidget);
    expect(find.text('SHA256:lamaLamaLama'), findsOneWidget);
    expect(find.text('SHA256:baruBaruBaru'), findsOneWidget);
    expect(find.text('Tersimpan'), findsOneWidget);
    expect(find.text('Diterima sekarang'), findsOneWidget);
    expect(find.text('Percayai dan sambung'), findsNothing);

    // Tanpa persetujuan, "Ganti key dan sambung" tidak berbuat apa-apa.
    await tester.ensureVisible(find.text('Ganti key dan sambung'));
    await tester.tap(find.text('Ganti key dan sambung'), warnIfMissed: false);
    await tester.pump();
    expect(got, isNull);
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saya sudah memastikan perubahan ini sah dengan pemilik server'));
    await tester.pump();
    await tester.tap(find.text('Ganti key dan sambung'));
    await tester.pumpAndSettle();
    expect(got, HostKeyChoice.replaceAndTrust);
  });

  testWidgets('host key berubah: "Batalkan koneksi" menolak dan menampilkan galat yang sesuai', (tester) async {
    final h = Harness();
    await h.seed([host(id1)]);
    await h.vault.put(id1, SecretType.loginPassword, 'rahasia');
    final net = _Net();
    net.script = (decide) async {
      final c = await decide(_challenge(HostKeyVerdict.changed, stored: const ['SHA256:lamaLamaLama']));
      expect(c, HostKeyChoice.reject);
      throw const SshHostKeyRejected(changed: true);
    };
    await _openConnect(tester, h, net);
    await tester.tap(find.text('Batalkan koneksi'));
    await tester.pumpAndSettle();
    expect(find.text('Koneksi dibatalkan'), findsOneWidget);
  });

  testWidgets('tombol kembali saat menunggu keputusan host key sama dengan menolak', (tester) async {
    final h = Harness();
    await h.seed([host(id1)]);
    await h.vault.put(id1, SecretType.loginPassword, 'rahasia');
    HostKeyChoice? got;
    final net = _Net();
    net.script = (decide) async {
      got = await decide(_challenge(HostKeyVerdict.newHost));
      throw const SshHostKeyRejected(changed: false);
    };
    await _openConnect(tester, h, net);
    await tester.tap(find.bySemanticsLabel('Kembali'));
    await tester.pumpAndSettle();
    expect(got, HostKeyChoice.reject);
    expect(find.text('Host key ditolak'), findsOneWidget);
  });

  testWidgets('password hilang: layar Rahasia hilang, simpan dan sambung memakai password baru', (tester) async {
    final h = Harness();
    await h.seed([host(id1)]);
    final net = _Net();
    net.script = (_) async => net.open(h.hosts.snapshot.profiles.single);
    await _openConnect(tester, h, net);
    await tester.pumpAndSettle();
    expect(find.text('Rahasia hilang'), findsOneWidget);
    expect(net.calls, isEmpty);

    await tester.tap(find.text('Simpan dan sambung'));
    await tester.pump();
    expect(find.text('Password wajib diisi'), findsOneWidget);

    await tester.enterText(inputByLabel('Password'), 'baru123');
    await tester.tap(find.text('Simpan dan sambung'));
    await tester.pumpAndSettle();
    expect((net.calls.single as PasswordCredentials).password, 'baru123');
    expect(find.byType(TerminalScreen), findsOneWidget);
    expect(await h.vault.has(id1, SecretType.loginPassword), isTrue);
  });

  testWidgets('kunci hilang: impor ulang kunci lewat pemilih berkas lalu sambung', (tester) async {
    if (!keygen) {
      markTestSkipped('ssh-keygen tidak tersedia');
      return;
    }
    final h = Harness();
    await h.seed([host(id1, auth: AuthMethod.key)]);
    final net = _Net();
    net.script = (_) async => net.open(h.hosts.snapshot.profiles.single);
    await _openConnect(tester, h, net);
    await tester.pumpAndSettle();
    expect(find.text('Rahasia hilang'), findsOneWidget);

    await tester.tap(find.text('Simpan dan sambung'));
    await tester.pump();
    expect(find.text('Pilih berkas kunci privat'), findsOneWidget);

    h.picker.next = plainKey;
    await tester.tap(find.text('Impor kunci dari berkas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan dan sambung'));
    await tester.pumpAndSettle();
    expect(net.calls.single, isA<KeyCredentials>());
    expect(find.byType(TerminalScreen), findsOneWidget);
  });

  testWidgets('galat jaringan: judul sesuai; Coba lagi mengulang', (tester) async {
    final h = Harness();
    await h.seed([host(id1)]);
    await h.vault.put(id1, SecretType.loginPassword, 'rahasia');
    var n = 0;
    final net = _Net();
    net.script = (_) async {
      if (n++ == 0) throw const SshNetworkFailure('putus');
      return net.open(h.hosts.snapshot.profiles.single);
    };
    await _openConnect(tester, h, net);
    await tester.pumpAndSettle();
    expect(find.text('Tidak bisa tersambung'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.byType(TerminalScreen), findsOneWidget);
  });

  testWidgets('tiap jenis kegagalan punya judul sendiri', (tester) async {
    final h = Harness();
    await h.seed([host(id1)]);
    await h.vault.put(id1, SecretType.loginPassword, 'rahasia');
    final cases = <SshFailure, String>{
      const SshHandshakeFailure('h'): 'Negosiasi gagal',
      const SshAuthFailure(): 'Login ditolak',
      const SshHostKeyStoreFailure(): 'Sidik jari tidak tersimpan',
      const SshUnknownFailure('x'): 'Gagal menyambung',
    };
    final net = _Net();
    await h.pump(tester, overrides: [connectFunctionProvider.overrideWithValue(net.fn)], realConnect: true);
    for (final e in cases.entries) {
      net.script = (_) async => throw e.key;
      await reopen(tester);
      await tester.pumpAndSettle();
      expect(find.text(e.value), findsOneWidget, reason: '${e.key}');
      await tester.tap(find.text('Kembali'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('autentikasi dibatalkan: pesan tersendiri dan Coba lagi meminta ulang', (tester) async {
    final h = Harness();
    await h.seed([host(id1)]);
    await h.vault.put(id1, SecretType.loginPassword, 'rahasia');
    h.auth.result = false;
    final net = _Net();
    net.script = (_) async => net.open(h.hosts.snapshot.profiles.single);
    await _openConnect(tester, h, net);
    await tester.pumpAndSettle();
    expect(find.text('Autentikasi dibatalkan'), findsOneWidget);
    expect(net.calls, isEmpty);
    h.auth.result = true;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.byType(TerminalScreen), findsOneWidget);
  });

  testWidgets('menyambung: status dengan kata; Batalkan menutup layar dan sambungan yang terlambat ditutup', (
    tester,
  ) async {
    final h = Harness();
    await h.seed([host(id1)]);
    await h.vault.put(id1, SecretType.loginPassword, 'rahasia');
    final gate = Completer<SshConnection>();
    final net = _Net();
    net.script = (_) => gate.future;
    await _openConnect(tester, h, net);
    expect(find.text('Menyambung ke app-01…'), findsOneWidget);
    await tester.tap(find.text('Batalkan'));
    await tester.pumpAndSettle();
    expect(find.byType(HostRow), findsOneWidget);
    final terlambat = net.open(h.hosts.snapshot.profiles.single);
    gate.complete(terlambat);
    await tester.pumpAndSettle();
    expect(terlambat.isClosed, isTrue);
  });
}
