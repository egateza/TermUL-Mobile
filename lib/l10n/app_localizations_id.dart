// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'TermUL';

  @override
  String get statusOnline => 'online';

  @override
  String get statusOffline => 'offline';

  @override
  String get statusBusy => 'menyambung ulang';

  @override
  String get statusIdle => 'siaga';

  @override
  String hostStatusOnlineMs(int ms) {
    return 'online · $ms ms';
  }

  @override
  String get hostStatusUnreachable => 'tidak terjangkau';

  @override
  String get hostStatusNotChecked => 'belum diperiksa';
}
