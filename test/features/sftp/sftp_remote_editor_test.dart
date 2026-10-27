import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/models/host_profile.dart';
import 'package:termul_mobile/core/theme/termul_theme.dart';
import 'package:termul_mobile/features/sftp/sftp_link.dart';
import 'package:termul_mobile/features/sftp/sftp_remote_editor_screen.dart';
import 'package:termul_mobile/l10n/app_localizations.dart';

import 'sftp_browser_test.dart' show FakeFiles, file;

void main() {
  testWidgets('unduhan selesai: isi UTF-8 tampil dan status Membaca file hilang', (tester) async {
    final fake = FakeFiles({
      '/': [file('/', 'config.conf')],
    })..downloadBytes = Uint8List.fromList('server config\n'.codeUnits);
    final link = SftpLink.ready(
      profile: HostProfile(
        id: '11111111-1111-4111-8111-111111111111',
        name: 'uji',
        host: 'host',
        port: 22,
        username: 'u',
      ),
      service: fake,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: termulTheme(),
        locale: const Locale('id'),
        supportedLocales: const [Locale('id')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: SftpRemoteEditorScreen(link: link, entry: file('/', 'config.conf')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Membaca file'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'server config\n');
    link.dispose();
  });
}
