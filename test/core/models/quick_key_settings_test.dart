import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/models/app_settings.dart';

void main() {
  test('bawaan dua baris, sembilan tombol per baris, tiap id dikenal dan tidak berulang', () {
    const k = QuickKeySettings();
    expect(k.isDefault, isTrue);
    expect(k.row1.length, 9);
    expect(k.row2.length, 9);
    final all = [...k.row1, ...k.row2];
    expect(all.toSet().length, all.length);
    expect(all.every(QuickKeySettings.knownIds.contains), isTrue);
    // Home, panah atas, End tepat di atas panah kiri, bawah, kanan.
    expect(k.row1.indexOf('up'), k.row2.indexOf('down'));
    expect(k.row1.indexOf('home'), k.row2.indexOf('left'));
  });

  test('membaca longgar: id asing dan id berulang dibuang, baris dipotong ke 10', () {
    final k = QuickKeySettings.fromJson({
      'row1': ['esc', 'bukan-tombol', 'esc', 42, 'tab'],
      'row2': ['tab', 'ctrlc', 'up', 'down', 'left', 'right', 'home', 'end', 'pgup', 'pgdn', 'ins', 'del'],
    });
    expect(k.row1, ['esc', 'tab']);
    expect(k.row2, ['ctrlc', 'up', 'down', 'left', 'right', 'home', 'end', 'pgup', 'pgdn', 'ins']);
  });

  test('baris yang hilang atau bukan daftar memakai bawaan tanpa mengulang id baris lain', () {
    final k = QuickKeySettings.fromJson({'row1': ['tab', 'esc'], 'row2': 'rusak'});
    expect(k.row1, ['tab', 'esc']);
    expect(k.row2, QuickKeySettings.defaultRow2.where((id) => id != 'tab').toList());
  });

  test('baris boleh kosong', () {
    final k = QuickKeySettings.fromJson({'row1': <Object?>[], 'row2': ['esc']});
    expect(k.row1, isEmpty);
    expect(k.row2, ['esc']);
  });

  test('tersimpan dan terbaca ulang lewat AppSettings', () {
    final s = const AppSettings().copyWith(
      quickKeys: const QuickKeySettings().withRow(1, ['ctrlz', 'ctrll']),
    );
    final back = AppSettings.fromJson(s.toJson());
    expect(back.quickKeys, s.quickKeys);
    expect(back.quickKeys.isDefault, isFalse);
    expect(AppSettings.fromJson(const {}).quickKeys.isDefault, isTrue);
  });
}
