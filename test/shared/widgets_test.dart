import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termul_mobile/core/theme/termul_theme.dart';
import 'package:termul_mobile/shared/widgets/host_row.dart';
import 'package:termul_mobile/shared/widgets/key_button.dart';
import 'package:termul_mobile/shared/widgets/status_dot.dart';
import 'package:termul_mobile/shared/widgets/switch_row.dart';
import 'package:termul_mobile/shared/widgets/termul_banner.dart';
import 'package:termul_mobile/shared/widgets/termul_button.dart';
import 'package:termul_mobile/shared/widgets/termul_card.dart';
import 'package:termul_mobile/shared/widgets/termul_chip.dart';
import 'package:termul_mobile/shared/widgets/termul_icon.dart';
import 'package:termul_mobile/shared/widgets/termul_icon_button.dart';
import 'package:termul_mobile/shared/widgets/termul_sheet.dart';
import 'package:termul_mobile/shared/widgets/termul_text_field.dart';
import 'package:termul_mobile/shared/widgets/termul_toast.dart';

import 'pump_app.dart';

void main() {
  group('target sentuh minimal 44 px', () {
    for (final size in TermulButtonSize.values) {
      testWidgets('TermulButton ${size.name} setinggi ${size.height}', (tester) async {
        await pumpApp(tester, TermulButton(label: 'Simpan', size: size, onPressed: () {}));
        expect(tester.getSize(find.byType(TermulButton)).height, size.height);
        expect(size.height, greaterThanOrEqualTo(TermulSize.tapMin));
      });
    }

    testWidgets('TermulIconButton 44x44', (tester) async {
      await pumpApp(tester, TermulIconButton(icon: TermulIconName.plus, label: 'Tambah host', onPressed: () {}));
      expect(tester.getSize(find.byType(TermulIconButton)), const Size(44, 44));
    });

    testWidgets('FilterChipButton dan KeyButton minimal 44 px tinggi', (tester) async {
      await pumpApp(
        tester,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilterChipButton(label: 'Semua', selected: true, onPressed: () {}),
            KeyButton(label: 'Esc', ariaLabel: 'Escape', onPressed: () {}),
          ],
        ),
      );
      expect(tester.getSize(find.byType(FilterChipButton)).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(find.byType(KeyButton)).height, greaterThanOrEqualTo(44));
    });

    testWidgets('HostRow dan SwitchRow minimal 64 px', (tester) async {
      await pumpApp(
        tester,
        SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HostRow(name: 'app-01', target: 'deploy@192.0.2.1', onPressed: () {}),
              SwitchRow(label: 'Biometrik', value: false, onChanged: (_) {}),
            ],
          ),
        ),
      );
      expect(tester.getSize(find.byType(HostRow)).height, greaterThanOrEqualTo(64));
      expect(tester.getSize(find.byType(SwitchRow)).height, greaterThanOrEqualTo(64));
    });
  });

  group('TermulButton', () {
    testWidgets('memanggil onPressed saat ditekan', (tester) async {
      var taps = 0;
      await pumpApp(tester, TermulButton(label: 'Simpan', onPressed: () => taps++));
      await tester.tap(find.text('Simpan'));
      expect(taps, 1);
    });

    testWidgets('nonaktif: opasitas 0,4 dan tidak merespons', (tester) async {
      await pumpApp(tester, const TermulButton(label: 'Simpan', onPressed: null));
      final opacity = tester.widget<Opacity>(
        find.descendant(of: find.byType(TermulButton), matching: find.byType(Opacity)),
      );
      expect(opacity.opacity, 0.4);
    });

    testWidgets('primary memakai accent dan on-accent', (tester) async {
      await pumpApp(tester, TermulButton(label: 'Simpan', variant: TermulButtonVariant.primary, onPressed: () {}));
      final box = tester.widget<Container>(
        find.descendant(of: find.byType(TermulButton), matching: find.byType(Container)).first,
      );
      expect((box.decoration! as BoxDecoration).color, TermulPalette.accent);
      expect(tester.widget<Text>(find.text('Simpan')).style!.color, TermulPalette.onAccent);
    });
  });

  group('status selalu dengan kata', () {
    testWidgets('StatusDot menampilkan kata untuk tiap status', (tester) async {
      for (final (status, word) in [
        (HostStatus.online, 'online'),
        (HostStatus.offline, 'offline'),
        (HostStatus.busy, 'menyambung ulang'),
        (HostStatus.idle, 'siaga'),
      ]) {
        await pumpApp(tester, StatusDot(status: status));
        expect(find.text(word), findsOneWidget);
      }
    });

    testWidgets('HostRow: online dengan latensi, tidak terjangkau, belum diperiksa', (tester) async {
      Future<void> row(HostStatus? s, int? ms) => pumpApp(
        tester,
        SizedBox(
          width: 360,
          child: HostRow(name: 'app-01', target: 'deploy@192.0.2.1', status: s, latencyMs: ms, onPressed: () {}),
        ),
      );
      await row(HostStatus.online, 18);
      expect(find.text('online · 18 ms'), findsOneWidget);
      await row(HostStatus.offline, null);
      expect(find.text('tidak terjangkau'), findsOneWidget);
      await row(null, null);
      expect(find.text('Belum diperiksa'), findsOneWidget);
    });

    testWidgets('HostRow menampilkan waktu penggunaan relatif dan tanggal 24 jam', (tester) async {
      Future<void> row(DateTime time) => pumpApp(
        tester,
        SizedBox(
          width: 360,
          child: HostRow(name: 'app-01', target: 'deploy@192.0.2.1', lastUsedAt: time, onPressed: () {}),
        ),
      );
      await row(DateTime.now().subtract(const Duration(minutes: 5)));
      expect(find.text('Terakhir digunakan 5 menit yang lalu'), findsOneWidget);
      await row(DateTime(2020, 1, 2, 9, 19, 33));
      expect(find.text('Terakhir digunakan 2020-01-02 09:19:33'), findsOneWidget);
    });

    testWidgets('HostRow punya satu nama semantik berisi nama, alamat, dan status', (tester) async {
      await pumpApp(
        tester,
        SizedBox(
          width: 360,
          child: HostRow(name: 'app-01', target: 'deploy@192.0.2.1', status: HostStatus.offline, onPressed: () {}),
        ),
      );
      expect(find.bySemanticsLabel('app-01, deploy@192.0.2.1, tidak terjangkau'), findsOneWidget);
    });
  });

  testWidgets('IconButton: label menjadi nama semantik dan tooltip', (tester) async {
    await pumpApp(tester, TermulIconButton(icon: TermulIconName.plus, label: 'Tambah host', onPressed: () {}));
    expect(find.bySemanticsLabel('Tambah host'), findsWidgets);
    expect(find.byTooltip('Tambah host'), findsOneWidget);
  });

  testWidgets('SwitchRow memanggil onChanged dengan nilai kebalikan', (tester) async {
    bool? next;
    await pumpApp(
      tester,
      SizedBox(
        width: 360,
        child: SwitchRow(label: 'Biometrik', description: 'akibatnya', value: false, onChanged: (v) => next = v),
      ),
    );
    await tester.tap(find.text('Biometrik'));
    expect(next, isTrue);
    expect(find.text('akibatnya'), findsOneWidget);
  });

  testWidgets('FilterChipButton terpilih memakai accent', (tester) async {
    await pumpApp(tester, FilterChipButton(label: 'Favorit', selected: true, onPressed: () {}));
    expect(tester.widget<Text>(find.text('Favorit')).style!.color, TermulPalette.onAccent);
  });

  group('TermulBanner', () {
    testWidgets('risk menampilkan judul, isi, dan aksi', (tester) async {
      await pumpApp(
        tester,
        SizedBox(
          width: 360,
          child: TermulBanner(
            tone: BannerTone.risk,
            title: 'Host key berubah',
            action: TermulButton(label: 'Batalkan koneksi', onPressed: () {}),
            child: const Text('Fingerprint berbeda dari yang tersimpan.'),
          ),
        ),
      );
      expect(find.text('Host key berubah'), findsOneWidget);
      expect(find.text('Fingerprint berbeda dari yang tersimpan.'), findsOneWidget);
      expect(find.text('Batalkan koneksi'), findsOneWidget);
    });

    testWidgets('risk dan warn diumumkan sebagai peringatan (live region); info tidak', (tester) async {
      Future<bool> live(BannerTone t) async {
        await pumpApp(
          tester,
          SizedBox(
            width: 360,
            child: TermulBanner(tone: t, child: const Text('x')),
          ),
        );
        final s = tester.widget<Semantics>(
          find.descendant(of: find.byType(TermulBanner), matching: find.byType(Semantics)).first,
        );
        return s.properties.liveRegion ?? false;
      }

      expect(await live(BannerTone.risk), isTrue);
      expect(await live(BannerTone.warn), isTrue);
      expect(await live(BannerTone.info), isFalse);
    });
  });

  group('TermulTextField', () {
    testWidgets('label tampil; hideLabel menyembunyikannya tetapi tetap dibaca pembaca layar', (tester) async {
      await pumpApp(tester, const SizedBox(width: 360, child: TermulTextField(label: 'Host')));
      expect(find.text('Host'), findsOneWidget);
      await pumpApp(tester, const SizedBox(width: 360, child: TermulTextField(label: 'Cari host', hideLabel: true)));
      expect(find.text('Cari host'), findsNothing);
      expect(find.bySemanticsLabel('Cari host'), findsOneWidget);
    });

    testWidgets('tinggi minimal 48 dan cincin fokus muncul saat fokus', (tester) async {
      await pumpApp(tester, const SizedBox(width: 360, child: TermulTextField(label: 'Host', autofocus: true)));
      await tester.pump();
      expect(find.byKey(const ValueKey('field-focus-ring')), findsOneWidget);
      expect(tester.getSize(find.byType(TermulTextField)).height, greaterThanOrEqualTo(TermulSize.inputH));
    });

    testWidgets('tombol hapus: muncul hanya saat ada teks, 44 px, mengosongkan, memberi tahu, fokus bertahan', (
      tester,
    ) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      final changes = <String>[];
      await pumpApp(
        tester,
        SizedBox(
          width: 360,
          child: TermulTextField(
            label: 'Cari host',
            hideLabel: true,
            controller: c,
            clearLabel: 'Hapus pencarian',
            onChanged: changes.add,
          ),
        ),
      );
      final clear = find.byKey(const ValueKey('field-clear'));
      expect(clear, findsNothing);
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      expect(clear, findsOneWidget);
      expect(find.bySemanticsLabel('Hapus pencarian'), findsOneWidget);
      expect(tester.getSize(clear).width, greaterThanOrEqualTo(TermulSize.tapMin));
      await tester.tap(clear);
      await tester.pump();
      expect(c.text, '');
      expect(changes.last, '');
      expect(clear, findsNothing);
      expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
    });

    testWidgets('tanpa clearLabel tidak ada tombol hapus', (tester) async {
      final c = TextEditingController(text: 'abc');
      addTearDown(c.dispose);
      await pumpApp(
        tester,
        SizedBox(
          width: 360,
          child: TermulTextField(label: 'Host', controller: c),
        ),
      );
      expect(find.byKey(const ValueKey('field-clear')), findsNothing);
    });

    testWidgets('galat ditampilkan dengan kata', (tester) async {
      await pumpApp(
        tester,
        const SizedBox(
          width: 360,
          child: TermulTextField(label: 'Port', error: 'Port harus 1 sampai 65535'),
        ),
      );
      expect(find.text('Port harus 1 sampai 65535'), findsOneWidget);
    });
  });

  testWidgets('cincin fokus papan ketik muncul pada tombol saat Tab ditekan', (tester) async {
    await pumpApp(tester, TermulButton(label: 'Simpan', onPressed: () {}));
    expect(find.byKey(const ValueKey('focus-ring')), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.byKey(const ValueKey('focus-ring')), findsOneWidget);
  });

  testWidgets('KeyButton tidak mengambil fokus (keyboard sistem tidak tertutup)', (tester) async {
    await pumpApp(tester, KeyButton(label: 'Esc', ariaLabel: 'Escape', onPressed: () {}));
    final ink = tester.widget<InkWell>(find.descendant(of: find.byType(KeyButton), matching: find.byType(InkWell)));
    expect(ink.canRequestFocus, isFalse);
  });

  testWidgets('KeyButton menahan (pressed) memakai accent', (tester) async {
    await pumpApp(tester, KeyButton(label: 'Ctrl', ariaLabel: 'Control', pressed: true, onPressed: () {}));
    expect(tester.widget<Text>(find.text('Ctrl')).style!.color, TermulPalette.onAccent);
  });

  testWidgets('TermulCard bertepi, tanpa bayangan', (tester) async {
    await pumpApp(tester, const TermulCard(child: Text('isi')));
    final deco =
        tester
                .widget<Container>(find.descendant(of: find.byType(TermulCard), matching: find.byType(Container)).first)
                .decoration!
            as BoxDecoration;
    expect(deco.boxShadow, isNull);
    expect(deco.border, isNotNull);
  });

  testWidgets('TermulIcon tanpa label disembunyikan dari pembaca layar; dengan label dibaca', (tester) async {
    await pumpApp(tester, const TermulIcon(TermulIconName.search));
    expect(find.bySemanticsLabel('Cari'), findsNothing);
    await pumpApp(tester, const TermulIcon(TermulIconName.search, label: 'Cari'));
    expect(find.bySemanticsLabel('Cari'), findsOneWidget);
  });

  testWidgets('semua ikon bisa digambar dan punya bentuk', (tester) async {
    await pumpApp(
      tester,
      Wrap(children: [for (final n in TermulIconName.values) TermulIcon(n, size: 24, color: TermulPalette.ink)]),
    );
    expect(tester.takeException(), isNull);
    for (final n in TermulIconName.values) {
      // Garis lurus (mis. minus) bertinggi nol, jadi "punya bentuk" = lebar atau tinggi tidak nol.
      final b = n.path.getBounds();
      expect(b.width > 0 || b.height > 0, isTrue, reason: n.name);
    }
  });

  group('showTermulSheet', () {
    Future<BuildContext> contextOf(WidgetTester tester) async {
      late BuildContext ctx;
      await pumpApp(
        tester,
        Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      );
      return ctx;
    }

    testWidgets('menampilkan judul, isi, tombol; konfirmasi memanggil callback dan menutup', (tester) async {
      var confirmed = 0;
      final ctx = await contextOf(tester);
      showTermulSheet<void>(
        ctx,
        title: 'Tempel 3 baris?',
        child: const Text('Teks masuk ke prompt tanpa menekan Enter.'),
        cancelLabel: 'Batal',
        confirmLabel: 'Tempel',
        onConfirm: () => confirmed++,
      );
      await tester.pumpAndSettle();
      expect(find.text('Tempel 3 baris?'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      await tester.tap(find.text('Tempel'));
      await tester.pumpAndSettle();
      expect(confirmed, 1);
      expect(find.text('Tempel 3 baris?'), findsNothing);
    });

    testWidgets('batal menutup tanpa memanggil konfirmasi', (tester) async {
      var confirmed = 0;
      final ctx = await contextOf(tester);
      showTermulSheet<void>(
        ctx,
        title: 'T',
        child: const Text('x'),
        cancelLabel: 'Batal',
        confirmLabel: 'Ya',
        onConfirm: () => confirmed++,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(confirmed, 0);
      expect(find.text('T'), findsNothing);
    });
  });

  testWidgets('toast satu baris muncul lalu hilang sekitar 2 detik', (tester) async {
    late BuildContext ctx;
    await pumpApp(
      tester,
      Builder(
        builder: (c) {
          ctx = c;
          return const SizedBox();
        },
      ),
    );
    showTermulToast(ctx, 'Disalin · 27 karakter');
    await tester.pump();
    expect(find.text('Disalin · 27 karakter'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1)); // animasi muncul selesai; timer 2 detik mulai
    expect(find.text('Disalin · 27 karakter'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3)); // timer habis; animasi hilang mulai
    await tester.pumpAndSettle();
    expect(find.text('Disalin · 27 karakter'), findsNothing);
  });
}
