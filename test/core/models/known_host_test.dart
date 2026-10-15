import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/models/known_host.dart';

const fpA = 'SHA256:c2FtcGxlLWZpbmdlcnByaW50LW5vdC1yZWFs';
const fpB = 'SHA256:bmV3LXNhbXBsZS1maW5nZXJwcmludC1ub3QtcmVhbA';

KnownHost k(
  String type,
  String fp, {
  String host = 'Host.Contoh',
  int port = 22,
}) => KnownHost(host: host, port: port, type: type, fingerprint: fp);

void main() {
  test('host menjadi huruf kecil dan id = host:port', () {
    expect(k('ssh-ed25519', fpA).host, 'host.contoh');
    expect(k('ssh-ed25519', fpA, port: 2211).id, 'host.contoh:2211');
    expect(KnownHost.idFor(' HOST.contoh ', 22), 'host.contoh:22');
  });

  test(
    'validasi: sidik jari harus SHA256:..., port 1..65535, tipe dan host wajib',
    () {
      expect(() => k('ssh-ed25519', 'MD5:aa:bb'), throwsArgumentError);
      expect(() => k('ssh-ed25519', '53:48:41:32'), throwsArgumentError);
      expect(() => k('', fpA), throwsArgumentError);
      expect(() => k('t', fpA, host: ' '), throwsArgumentError);
      expect(() => k('t', fpA, port: 0), throwsArgumentError);
    },
  );

  test('JSON bolak-balik (waktu disimpan UTC)', () {
    final e = KnownHost(
      host: 'h',
      port: 22,
      type: 'ssh-ed25519',
      fingerprint: fpA,
      addedAt: DateTime.utc(2026, 10, 15, 9, 30),
    );
    expect(KnownHost.fromJson(e.toJson()), e);
    expect(
      () => KnownHost.fromJson({...e.toJson(), 'addedAt': 'kemarin'}),
      throwsFormatException,
    );
  });

  group('evaluateHostKey', () {
    test('tidak ada entri: host baru', () {
      expect(
        evaluateHostKey([], type: 'ssh-ed25519', fingerprint: fpA),
        HostKeyVerdict.newHost,
      );
    });
    test('tipe dan sidik jari sama: dipercaya', () {
      expect(
        evaluateHostKey(
          [k('ssh-ed25519', fpA)],
          type: 'ssh-ed25519',
          fingerprint: fpA,
        ),
        HostKeyVerdict.trusted,
      );
    });
    test('tipe sama, sidik jari beda: berubah (blokir)', () {
      expect(
        evaluateHostKey(
          [k('ssh-ed25519', fpA)],
          type: 'ssh-ed25519',
          fingerprint: fpB,
        ),
        HostKeyVerdict.changed,
      );
    });
    test('tipe asing pada host yang sudah dikenal: berubah (konservatif)', () {
      expect(
        evaluateHostKey(
          [k('ssh-ed25519', fpA)],
          type: 'ssh-rsa',
          fingerprint: fpB,
        ),
        HostKeyVerdict.changed,
      );
    });
    test('beberapa tipe tersimpan: cocok dengan salah satunya sudah cukup', () {
      final stored = [k('ssh-rsa', fpB), k('ssh-ed25519', fpA)];
      expect(
        evaluateHostKey(stored, type: 'ssh-ed25519', fingerprint: fpA),
        HostKeyVerdict.trusted,
      );
    });
  });
}
