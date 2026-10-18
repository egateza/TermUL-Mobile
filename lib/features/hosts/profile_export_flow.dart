import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/import/profile_export.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/termul_action_sheet.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_toast.dart';

/// Alur "Ekspor profil": tampilkan ringkasan lalu pilih Bagikan atau Simpan ke perangkat.
/// Galat dikembalikan sebagai teks untuk banner di daftar host; `null` berarti selesai atau dibatalkan.
Future<String?> runProfileExport(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final result = const ProfileExporter().export(ref.read(hostSnapshotProvider));
  if (result.count == 0) return l.exportNothing;

  String? destination;
  await showTermulActions(
    context,
    title: l.exportTitle,
    actions: [
      SheetAction(
        label: l.exportConfirm,
        icon: TermulIconName.upload,
        primary: true,
        onSelected: () => destination = 'share',
      ),
      SheetAction(label: l.exportSaveToDevice, icon: TermulIconName.download, onSelected: () => destination = 'device'),
      SheetAction(label: l.actionCancel, onSelected: () {}),
    ],
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
  if (destination == null || !context.mounted) return null;

  try {
    if (destination == 'device') {
      final saved = await ref
          .read(deviceDocumentSaverProvider)
          .save(
            name: ProfileExporter.fileName,
            mimeType: 'application/json',
            bytes: Uint8List.fromList(utf8.encode(result.text)),
          );
      if (saved && context.mounted) showTermulToast(context, l.exportSaved);
      return null;
    }

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
