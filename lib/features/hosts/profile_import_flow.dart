import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/import/profile_import.dart';
import '../../core/models/profile_snapshot.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/termul_segmented.dart';
import '../../shared/widgets/termul_sheet.dart';
import '../../shared/widgets/termul_toast.dart';

/// Alur "Impor profil": pilih berkas, pratinjau penggabungan, konfirmasi, tulis. Galat dikembalikan sebagai
/// teks untuk ditampilkan pemanggil (banner); `null` berarti selesai atau dibatalkan.
Future<String?> runProfileImport(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final String? text;
  try {
    text = await ref.read(profileFilePickerProvider).pick();
  } on ImportFormatException catch (e) {
    return e.message;
  } on Object {
    return l.importReadFailed;
  }
  if (text == null) return null;

  final ProfileImportSource source;
  try {
    source = ProfileImportSource.parse(text);
  } on ImportFormatException catch (e) {
    return e.message;
  }
  if (source.profiles.isEmpty) return l.importNothing;
  if (!context.mounted) return null;

  final policy = ValueNotifier(ImportConflictPolicy.skip);
  final service = ref.read(hostServiceProvider);
  final snapshot = ref.read(hostSnapshotProvider);
  var confirmed = false;
  await showTermulSheet<void>(
    context,
    title: l.importTitle,
    cancelLabel: l.actionCancel,
    confirmLabel: l.importConfirm,
    onConfirm: () => confirmed = true,
    child: _ImportPreview(source: source, existing: snapshot, policy: policy),
  );
  if (!confirmed || !context.mounted) return null;

  try {
    final plan = await service.importProfiles(source, policy.value);
    if (!context.mounted) return null;
    showTermulToast(context, plan.isEmpty ? l.importNoChange : l.importDone(plan.importedCount));
    return null;
  } on Object {
    return l.importFailed;
  }
}

class _ImportPreview extends StatelessWidget {
  const _ImportPreview({required this.source, required this.existing, required this.policy});

  final ProfileImportSource source;
  final ProfileSnapshot existing;
  final ValueNotifier<ImportConflictPolicy> policy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder<ImportConflictPolicy>(
      valueListenable: policy,
      builder: (context, current, _) {
        final plan = source.plan(existing, current);
        final lines = <String>[
          if (plan.added > 0) l.importAdded(plan.added),
          if (plan.updated > 0) l.importUpdated(plan.updated),
          if (plan.copied > 0) l.importCopied(plan.copied),
          if (plan.skipped > 0) l.importSkipped(plan.skipped),
          if (plan.rejections.isNotEmpty) l.importRejected(plan.rejections.length),
        ];
        final warnings = <String>[
          for (final w in plan.warnings)
            switch (w.kind) {
              ImportWarningKind.jumpHostMissing => l.importWarnJump(w.profileName),
              ImportWarningKind.keyPathDropped => l.importWarnKeyPath(w.profileName),
            },
          if (plan.agentCount > 0) l.importAgentNote(plan.agentCount),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: TermulSpacing.space2),
                child: Text(line, style: TermulText.body.copyWith(color: TermulPalette.ink)),
              ),
            Padding(
              padding: const EdgeInsets.only(top: TermulSpacing.space3, bottom: TermulSpacing.space3),
              child: Text(l.importKeepNote, style: TermulText.bodySm.copyWith(color: TermulPalette.inkMuted)),
            ),
            Text(l.importConflictLabel, style: TermulText.label.copyWith(color: TermulPalette.inkSoft)),
            const SizedBox(height: TermulSpacing.space3),
            TermulSegmented<ImportConflictPolicy>(
              label: l.importConflictLabel,
              value: current,
              onChanged: (v) => policy.value = v,
              options: [
                SegmentOption(value: ImportConflictPolicy.skip, label: l.importConflictSkip),
                SegmentOption(value: ImportConflictPolicy.update, label: l.importConflictUpdate),
                SegmentOption(value: ImportConflictPolicy.copy, label: l.importConflictCopy),
              ],
            ),
            for (final w in warnings)
              Padding(
                padding: const EdgeInsets.only(top: TermulSpacing.space3),
                child: Text(w, style: TermulText.bodySm.copyWith(color: TermulPalette.inkSoft)),
              ),
            for (final r in plan.rejections.take(5))
              Padding(
                padding: const EdgeInsets.only(top: TermulSpacing.space3),
                child: Text(
                  l.importRejectedItem(r.index, r.name ?? '-', r.reason),
                  style: TermulText.bodySm.copyWith(color: TermulPalette.badInk),
                ),
              ),
          ],
        );
      },
    );
  }
}
