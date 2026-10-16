import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'app_providers.dart';
import 'boot_error_app.dart';
import 'bootstrap.dart';
import 'core/theme/termul_theme.dart';
import 'l10n/app_localizations.dart';

/// Akar aplikasi: menggambar layar pemuatan segera, lalu membuka penyimpanan ([bootstrap]) di belakangnya. Tanpa
/// ini, `runApp` baru dipanggil setelah penyimpanan terbuka dan jendela tampak kosong selama itu. Gagal membuka
/// penyimpanan menampilkan [BootErrorApp].
class BootApp extends StatefulWidget {
  const BootApp({super.key, this.boot = bootstrap});

  /// Pembuka penyimpanan; diganti di tes.
  final Future<AppDependencies> Function() boot;

  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> {
  late final Future<AppDependencies> _deps = widget.boot();

  @override
  Widget build(BuildContext context) => FutureBuilder<AppDependencies>(
    future: _deps,
    builder: (context, snapshot) {
      if (snapshot.hasError) return const BootErrorApp();
      final deps = snapshot.data;
      if (deps == null) return termulMaterialApp(home: const _BootLoadingScreen());
      return ProviderScope(overrides: deps.overrides, child: const TermulApp());
    },
  );
}

/// Layar pemuatan: warna dasar yang sama dengan jendela peluncuran Android, satu baris teks, tanpa animasi.
class _BootLoadingScreen extends StatelessWidget {
  const _BootLoadingScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Text(
        AppLocalizations.of(context).bootLoading,
        style: TermulText.caption.copyWith(color: TermulPalette.inkMuted),
      ),
    ),
  );
}
