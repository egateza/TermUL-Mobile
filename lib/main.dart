import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'boot_app.dart';

/// Aplikasi hanya portrait (keputusan pemilik 2026-10-17, supaya tampilan konsisten). Kode landscape (rel navigasi,
/// terminal ringkas, banner satu baris) sengaja dibiarkan; mengaktifkannya lagi cukup dengan mengganti daftar ini dan
/// `android:screenOrientation` di manifest.
const preferredOrientations = [DeviceOrientation.portraitUp];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(preferredOrientations);
  runApp(const BootApp());
}
