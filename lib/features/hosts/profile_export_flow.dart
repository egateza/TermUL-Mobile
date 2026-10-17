import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/import/profile_export.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/termul_sheet.dart';

/// Alur "Ekspor profil": konfirmasi, tulis berkas sementara, buka menu bagikan bawaan Android. Galat dikembalikan sebagai
/// teks untuk banner di daftar host; `null` berarti selesai atau dibatalkan.
Future<String?> runProfileExport(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final result = const ProfileExporter().export(ref.read(hostSnapshotProvider));
  if (result.count == 0) return l.exportNothing;

  var confirmed = false;
  await showTermulSheet<void>(
    context,
    title: l.exportTitle,
    cancelLabel: l.actionCancel,
    confirmLabel: l.exportConfirm,
    onConfirm: () => confirmed = true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.exportCount(result.count), style: TermulText.body.copyWith(color: TermulPalette.ink)),
        const SizedBox(height: TermulSpacing.space3),
        Text(l.exportNote, style: TermulText.bodySm.copyWith(color: TermulPalette.inkMuted)),
        if (result.keyConverted > 0) ...[
          const SizedBox(height: TermulSpacing.space3),
          Text(
            l.exportKeyConverted(result.keyConverted),
            style: TermulText.bodySm.copyWith(color: TermulPalette.inkSoft),
          ),
        ],
      ],
    ),
  );
  if (!confirmed || !context.mounted) return null;

  try {
    final dir = await ref.read(tempDirProvider)();
    final shareDir = Directory('${dir.path}${Platform.pathSeparator}share');
    // Sisa ekspor sebelumnya dibuang: berkas ini hanya perlu hidup sampai menu bagikan selesai membacanya.
    if (shareDir.existsSync()) shareDir.deleteSync(recursive: true);
    shareDir.createSync(recursive: true);
    final file = File('${shareDir.path}${Platform.pathSeparator}${ProfileExporter.fileName}');
    await file.writeAsBytes(utf8.encode(result.text), flush: true);
    await ref
        .read(fileSharerProvider)
        .shareFile(path: file.path, name: ProfileExporter.fileName, mimeType: 'application/json', title: l.exportTitle);
    return null;
  } on Object {
    return l.exportFailed;
  }
}
