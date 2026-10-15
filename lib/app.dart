import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/models/host_profile.dart';
import 'core/theme/termul_theme.dart';
import 'debug/widget_gallery.dart';
import 'features/connect/connect_screen.dart';
import 'features/hosts/host_list_screen.dart';
import 'l10n/app_localizations.dart';

/// Konfigurasi MaterialApp bersama (tema, bahasa), dipakai aplikasi utama dan layar galat saat mulai.
MaterialApp termulMaterialApp({Widget? home, GlobalKey<NavigatorState>? navigatorKey}) => MaterialApp(
  navigatorKey: navigatorKey,
  onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('id')],
  locale: const Locale('id'),
  theme: termulTheme(),
  home: home,
);

/// Akar aplikasi. Provider penyimpanan harus sudah disuntikkan lewat `ProviderScope` (lihat `bootstrap()`).
class TermulApp extends StatelessWidget {
  const TermulApp({super.key, this.onConnect});

  /// Dipanggil saat host ditekan. Bawaan: membuka alur sambung ([ConnectScreen]).
  final void Function(BuildContext context, HostProfile profile)? onConnect;

  @override
  Widget build(BuildContext context) {
    return termulMaterialApp(
      home: WidgetGallery.enabled
          ? const WidgetGallery()
          : HostListScreen(
              onConnect:
                  onConnect ??
                  (context, profile) =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => ConnectScreen(profile: profile))),
            ),
    );
  }
}
