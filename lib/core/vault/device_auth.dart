import 'package:local_auth/local_auth.dart';

/// Tingkat penguncian HP saat ini, menentukan gerbang saat rahasia dibaca.
enum AuthLevel {
  /// Ada sidik jari atau wajah terdaftar: prompt sistem (boleh juga dengan PIN/pola/sandi perangkat).
  biometric,

  /// Tanpa biometrik, tetapi ada PIN, pola, atau sandi layar kunci: prompt sistem dengan itu.
  deviceCredential,

  /// Tidak ada penguncian layar: tanpa prompt. Rahasia tetap terenkripsi; UI wajib memberi peringatan.
  none,
}

/// Pembungkus autentikasi perangkat supaya vault bisa diuji tanpa platform.
abstract interface class DeviceAuth {
  Future<AuthLevel> level();

  /// true bila lolos, false bila pengguna membatalkan atau gagal. Melempar bila perangkat tidak bisa.
  Future<bool> authenticate(String reason);
}

/// Implementasi dengan `local_auth`. `biometricOnly: false` membuat Android menambahkan `DEVICE_CREDENTIAL`
/// ke `BiometricPrompt`. Jalur PIN/pola/sandi dan deteksi `none` belum diuji di HP fisik.
class LocalAuthDeviceAuth implements DeviceAuth {
  LocalAuthDeviceAuth([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<AuthLevel> level() async {
    try {
      if ((await _auth.getAvailableBiometrics()).isNotEmpty) {
        return AuthLevel.biometric;
      }
      if (await _auth.isDeviceSupported()) return AuthLevel.deviceCredential;
      return AuthLevel.none;
    } on Object {
      // Gagal mendeteksi: anggap ada penguncian (gagal tertutup), supaya rahasia tidak terbuka tanpa gerbang.
      return AuthLevel.deviceCredential;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.systemCanceled:
        case LocalAuthExceptionCode.timeout:
        case LocalAuthExceptionCode.authInProgress:
        case LocalAuthExceptionCode.uiUnavailable:
          return false;
        default:
          rethrow;
      }
    }
  }
}
