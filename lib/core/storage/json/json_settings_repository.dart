import 'dart:convert';
import 'dart:io';

import '../../io/atomic_file.dart';
import '../../io/json_file.dart';
import '../../models/app_settings.dart';
import '../load_result.dart';

/// Memuat `settings.json`. Berkas yang belum ada dibuat dengan nilai bawaan supaya mudah ditemukan dan diubah
/// dengan tangan; berkas rusak disisihkan ke `settings.json.corrupt-<waktu>` dan nilai bawaan dipakai (pengaturan
/// hilang tidak berbahaya, jadi tanpa banner). Layar pengaturan menyimpannya lewat [save].
class JsonSettingsRepository {
  JsonSettingsRepository(this._file, {this._writer = writeAtomic});

  final File _file;
  final AtomicWriter _writer;

  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;

  Future<LoadResult> load() async {
    final loaded = await loadJsonOrQuarantine<AppSettings>(
      _file,
      parse: AppSettings.fromJson,
      empty: const AppSettings(),
    );
    _settings = loaded.value;
    if (!await _file.exists()) {
      try {
        await _writer(_file, utf8.encode('${const JsonEncoder.withIndent('  ').convert(_settings.toJson())}\n'));
      } on Object {
        // Tidak bisa menulis berkas contoh: aplikasi tetap jalan dengan nilai bawaan.
      }
    }
    return LoadResult(quarantinedPath: loaded.quarantinedPath);
  }

  /// Menyimpan [settings] (tulis atomik) lalu menjadikannya nilai terkini. Melempar bila gagal menulis; berkas lama
  /// tetap utuh dan nilai terkini tidak berubah.
  Future<void> save(AppSettings settings) async {
    await _writer(_file, _encode(settings));
    _settings = settings;
  }

  static List<int> _encode(AppSettings settings) =>
      utf8.encode('${const JsonEncoder.withIndent('  ').convert(settings.toJson())}\n');
}
