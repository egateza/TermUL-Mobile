import '../../l10n/app_localizations.dart';

/// Ukuran berkas dengan koma desimal (format Indonesia): `512 B`, `1,2 KB`, `3,4 MB`.
String formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  final text = (value < 10 ? value.toStringAsFixed(1) : value.round().toString()).replaceAll('.', ',');
  return '$text ${units[i]}';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

/// Waktu ubah singkat: `baru saja`, `5 menit lalu`, `2 jam lalu`, `kemarin`, `12 Sep`, atau `12 Sep 2024` bila
/// bukan tahun ini.
String formatModified(AppLocalizations l, DateTime when, DateTime now) {
  final diff = now.difference(when);
  if (!diff.isNegative) {
    if (diff.inMinutes < 1) return l.sftpJustNow;
    if (diff.inHours < 1) return l.sftpAgoMinutes(diff.inMinutes);
    if (diff.inHours < 24 && now.day == when.day) return l.sftpAgoHours(diff.inHours);
  }
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(when.year, when.month, when.day);
  if (today.difference(day).inDays == 1) return l.sftpYesterday;
  final base = '${when.day} ${_months[when.month - 1]}';
  return when.year == now.year ? base : '$base ${when.year}';
}
