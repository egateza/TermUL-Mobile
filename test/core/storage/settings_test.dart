import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/models/app_settings.dart';
import 'package:termul_mobile/core/storage/json/json_settings_repository.dart';

void main() {
  group('AppSettings', () {
    test('bawaan: huruf 13 sp, tinggi baris 1,3', () {
      const s = AppSettings();
      expect(s.terminal.fontSize, 13);
      expect(s.terminal.lineHeight, 1.3);
    });

    test('membaca nilai bulat dan pecahan; properti tak dikenal diabaikan', () {
      final s = AppSettings.fromJson({
        'version': 1,
        'terminal': {'fontSize': 15, 'lineHeight': 1.2, 'warnaAneh': 'x'},
        'fitur_masa_depan': {'a': 1},
      });
      expect(s.terminal.fontSize, 15);
      expect(s.terminal.lineHeight, 1.2);
    });

    test('field kosong atau bagian hilang memakai bawaan', () {
      expect(AppSettings.fromJson({}).terminal, const TerminalSettings());
      expect(AppSettings.fromJson({'terminal': <String, Object?>{}}).terminal, const TerminalSettings());
      expect(
        AppSettings.fromJson({
          'terminal': {'fontSize': null},
        }).terminal.fontSize,
        13,
      );
    });

    test('nilai di luar batas dijepit, bukan dianggap rusak', () {
      final kecil = AppSettings.fromJson({
        'terminal': {'fontSize': 2, 'lineHeight': 0.1},
      });
      expect(kecil.terminal.fontSize, TerminalSettings.minFontSize);
      expect(kecil.terminal.lineHeight, TerminalSettings.minLineHeight);
      final besar = AppSettings.fromJson({
        'terminal': {'fontSize': 500, 'lineHeight': 9},
      });
      expect(besar.terminal.fontSize, TerminalSettings.maxFontSize);
      expect(besar.terminal.lineHeight, TerminalSettings.maxLineHeight);
    });

    test('tipe salah melempar FormatException (berkas dianggap rusak)', () {
      expect(() => AppSettings.fromJson({'terminal': 'besar'}), throwsFormatException);
      expect(
        () => AppSettings.fromJson({
          'terminal': {'fontSize': '14'},
        }),
        throwsFormatException,
      );
    });

    test('toJson lalu fromJson menghasilkan nilai yang sama', () {
      const s = AppSettings(terminal: TerminalSettings(fontSize: 11.5, lineHeight: 1.1));
      expect(AppSettings.fromJson(s.toJson()).terminal, s.terminal);
    });
  });

  group('JsonSettingsRepository', () {
    late Directory dir;
    late File file;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('termul_settings_');
      file = File('${dir.path}${Platform.pathSeparator}settings.json');
    });

    tearDown(() async => dir.delete(recursive: true));

    test('berkas belum ada: dibuat dengan nilai bawaan dan bisa dibaca ulang', () async {
      final repo = JsonSettingsRepository(file);
      final result = await repo.load();
      expect(result.hadCorruptFile, isFalse);
      expect(repo.settings.terminal, const TerminalSettings());
      expect(file.existsSync(), isTrue);
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      expect(json['version'], 1);
      expect((json['terminal']! as Map)['fontSize'], 13);
      expect((json['terminal']! as Map)['lineHeight'], 1.3);
    });

    test('berkas yang diubah dengan tangan dipakai', () async {
      file.writeAsStringSync('{"version":1,"terminal":{"fontSize":10,"lineHeight":1.1}}');
      final repo = JsonSettingsRepository(file);
      await repo.load();
      expect(repo.settings.terminal.fontSize, 10);
      expect(repo.settings.terminal.lineHeight, 1.1);
    });

    test('berkas yang ada tidak ditimpa', () async {
      const isi = '{"version":1,"terminal":{"fontSize":17}}';
      file.writeAsStringSync(isi);
      await JsonSettingsRepository(file).load();
      expect(file.readAsStringSync(), isi);
    });

    test('berkas rusak: disisihkan, nilai bawaan dipakai, berkas baru dibuat', () async {
      file.writeAsStringSync('{ini bukan json');
      final repo = JsonSettingsRepository(file);
      final result = await repo.load();
      expect(result.hadCorruptFile, isTrue);
      expect(File(result.quarantinedPath!).readAsStringSync(), '{ini bukan json');
      expect(repo.settings.terminal, const TerminalSettings());
      expect(file.existsSync(), isTrue);
    });

    test('tipe salah dianggap rusak', () async {
      file.writeAsStringSync('{"terminal":{"fontSize":"besar"}}');
      final result = await JsonSettingsRepository(file).load();
      expect(result.hadCorruptFile, isTrue);
    });

    test('gagal menulis berkas contoh: tetap memakai nilai bawaan tanpa galat', () async {
      final repo = JsonSettingsRepository(file, writer: (f, b) async => throw const FileSystemException('penuh'));
      final result = await repo.load();
      expect(result.hadCorruptFile, isFalse);
      expect(repo.settings.terminal, const TerminalSettings());
    });
  });
}
