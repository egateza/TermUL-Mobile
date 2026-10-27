import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/models/app_settings.dart';
import 'package:termul_mobile/core/storage/json/json_settings_repository.dart';

void main() {
  group('AppSettings', () {
    test('pengaturan editor SFTP: bawaan, pencocokan ekstensi, validasi, dan serialisasi', () {
      const defaults = SftpEditorSettings();
      expect(defaults.enabled, isTrue);
      expect(defaults.extensions, ['*.conf', '*.txt', '*.log', '*.json', '*.yml']);
      expect(defaults.allows('DEFAULT.CONF'), isTrue);
      expect(defaults.allows('data.yml'), isTrue);
      expect(defaults.allows('data.yaml'), isFalse);
      expect(defaults.allows('conf'), isFalse);
      expect(SftpEditorSettings.normalizePattern('.yaml'), '*.yaml');
      expect(SftpEditorSettings.normalizePattern('*.ini'), '*.ini');
      expect(SftpEditorSettings.normalizePattern('a/*.ini'), isNull);

      const configured = SftpEditorSettings(enabled: false, extensions: ['*.yaml']);
      expect(AppSettings.fromJson(AppSettings(sftpEditor: configured).toJson()).sftpEditor, configured);
      expect(
        AppSettings.fromJson({
          'sftpEditor': {'extensions': <String>[]},
        }).sftpEditor.extensions,
        isEmpty,
      );
      expect(
        () => AppSettings.fromJson({
          'sftpEditor': {'enabled': 'ya'},
        }),
        throwsFormatException,
      );
      expect(
        () => AppSettings.fromJson({
          'sftpEditor': {
            'extensions': ['*.bad/pattern'],
          },
        }),
        throwsFormatException,
      );
    });

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

    test('bentuk gagang seleksi: bawaan tetesan; nama dikenal dibaca; nama asing kembali ke bawaan', () {
      expect(const AppSettings().terminal.handleStyle, SelectionHandleStyle.drop);
      expect(
        AppSettings.fromJson({
          'terminal': {'handleStyle': 'triangle'},
        }).terminal.handleStyle,
        SelectionHandleStyle.triangle,
      );
      expect(
        AppSettings.fromJson({
          'terminal': {'handleStyle': 'dot'},
        }).terminal.handleStyle,
        SelectionHandleStyle.dot,
      );
      expect(
        AppSettings.fromJson({
          'terminal': {'handleStyle': 'bintang'},
        }).terminal.handleStyle,
        SelectionHandleStyle.drop,
      );
      expect(
        () => AppSettings.fromJson({
          'terminal': {'handleStyle': 5},
        }),
        throwsFormatException,
        reason: 'tipe salah dianggap rusak, seperti field lain',
      );
      const s = AppSettings(terminal: TerminalSettings(handleStyle: SelectionHandleStyle.triangle));
      expect((s.toJson()['terminal']! as Map)['handleStyle'], 'triangle');
      expect(AppSettings.fromJson(s.toJson()).terminal, s.terminal);
    });

    test('konfirmasi tempel satu baris: bawaan nyala; nilai dibaca dan ditulis; tipe salah dianggap rusak', () {
      expect(const AppSettings().terminal.confirmSingleLinePaste, isTrue);
      expect(AppSettings.fromJson({'terminal': <String, Object?>{}}).terminal.confirmSingleLinePaste, isTrue);
      expect(
        AppSettings.fromJson({
          'terminal': {'confirmSingleLinePaste': false},
        }).terminal.confirmSingleLinePaste,
        isFalse,
      );
      expect(
        () => AppSettings.fromJson({
          'terminal': {'confirmSingleLinePaste': 'ya'},
        }),
        throwsFormatException,
      );
      const s = AppSettings(terminal: TerminalSettings(confirmSingleLinePaste: false));
      expect((s.toJson()['terminal']! as Map)['confirmSingleLinePaste'], false);
      expect(AppSettings.fromJson(s.toJson()).terminal, s.terminal);
    });

    test('periksa update otomatis: bawaan nyala; nilai dibaca dan ditulis; bagian hilang memakai bawaan', () {
      expect(const AppSettings().update.autoCheck, isTrue);
      expect(AppSettings.fromJson({}).update.autoCheck, isTrue);
      final off = AppSettings.fromJson({
        'update': {'autoCheck': false},
      });
      expect(off.update.autoCheck, isFalse);
      expect(AppSettings.fromJson(off.toJson()).update, const UpdateSettings(autoCheck: false));
      expect(
        () => AppSettings.fromJson({
          'update': {'autoCheck': 'ya'},
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
    test('save menulis berkas yang bisa dibaca ulang dan menjadi nilai terkini', () async {
      final repo = JsonSettingsRepository(file);
      await repo.load();
      const baru = AppSettings(terminal: TerminalSettings(fontSize: 10, lineHeight: 1.1));
      await repo.save(baru);
      expect(repo.settings.terminal, baru.terminal);
      final lain = JsonSettingsRepository(file);
      await lain.load();
      expect(lain.settings.terminal, baru.terminal);
    });

    test('save gagal: berkas lama utuh, nilai terkini tidak berubah, galat dilempar', () async {
      file.writeAsStringSync('{"version":1,"terminal":{"fontSize":17}}');
      final repo = JsonSettingsRepository(file, writer: (f, b) async => throw const FileSystemException('penuh'));
      await repo.load();
      await expectLater(
        repo.save(const AppSettings(terminal: TerminalSettings(fontSize: 9))),
        throwsA(isA<FileSystemException>()),
      );
      expect(repo.settings.terminal.fontSize, 17);
      expect(file.readAsStringSync(), '{"version":1,"terminal":{"fontSize":17}}');
    });
  });
}
