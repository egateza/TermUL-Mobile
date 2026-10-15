import 'package:flutter/material.dart';

import '../core/theme/termul_theme.dart';
import '../shared/widgets/host_row.dart';
import '../shared/widgets/key_button.dart';
import '../shared/widgets/status_dot.dart';
import '../shared/widgets/switch_row.dart';
import '../shared/widgets/termul_banner.dart';
import '../shared/widgets/termul_button.dart';
import '../shared/widgets/termul_card.dart';
import '../shared/widgets/termul_chip.dart';
import '../shared/widgets/termul_icon.dart';
import '../shared/widgets/termul_icon_button.dart';
import '../shared/widgets/termul_sheet.dart';
import '../shared/widgets/termul_text_field.dart';
import '../shared/widgets/termul_toast.dart';

/// Galeri widget untuk pemeriksaan visual di perangkat. Hanya aktif dengan
/// `--dart-define=TERMUL_GALLERY=true`; tidak dipakai di rilis.
class WidgetGallery extends StatefulWidget {
  const WidgetGallery({super.key});

  static const enabled = bool.fromEnvironment('TERMUL_GALLERY');

  @override
  State<WidgetGallery> createState() => _WidgetGalleryState();
}

class _WidgetGalleryState extends State<WidgetGallery> {
  bool _switch = true;
  int _chip = 0;

  Widget _section(String title, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: TermulSpacing.space9),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TermulText.overline.copyWith(color: TermulPalette.inkMuted),
        ),
        const SizedBox(height: TermulSpacing.space4),
        child,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(TermulSpacing.space8),
          children: [
            Text(
              'Galeri widget',
              style: TermulText.h1.copyWith(color: TermulPalette.ink),
            ),
            const SizedBox(height: TermulSpacing.space9),
            _section(
              'Tombol',
              Column(
                spacing: TermulSpacing.space3,
                children: [
                  TermulButton(
                    label: 'Percayai dan sambung',
                    variant: TermulButtonVariant.primary,
                    size: TermulButtonSize.lg,
                    onPressed: () {},
                  ),
                  TermulButton(label: 'Sambung sekali saja', onPressed: () {}),
                  TermulButton(
                    label: 'Ganti key dan sambung',
                    variant: TermulButtonVariant.danger,
                    onPressed: () {},
                  ),
                  TermulButton(
                    label: 'Batalkan',
                    variant: TermulButtonVariant.ghost,
                    size: TermulButtonSize.sm,
                    onPressed: () {},
                  ),
                  const TermulButton(label: 'Nonaktif', onPressed: null),
                  Row(
                    spacing: TermulSpacing.space3,
                    children: [
                      TermulIconButton(
                        icon: TermulIconName.plus,
                        label: 'Tambah host',
                        tone: IconButtonTone.accent,
                        onPressed: () {},
                      ),
                      TermulIconButton(
                        icon: TermulIconName.search,
                        label: 'Cari',
                        tone: IconButtonTone.filled,
                        onPressed: () {},
                      ),
                      TermulIconButton(
                        icon: TermulIconName.trash,
                        label: 'Hapus',
                        onPressed: () {},
                      ),
                      TermulIconButton(
                        icon: TermulIconName.star,
                        label: 'Favorit',
                        pressed: true,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _section(
              'Ikon',
              Wrap(
                spacing: TermulSpacing.space6,
                runSpacing: TermulSpacing.space6,
                children: [
                  for (final n in TermulIconName.values)
                    TermulIcon(n, size: 24, color: TermulPalette.ink),
                ],
              ),
            ),
            _section(
              'Chip dan tag',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: TermulSpacing.space4,
                children: [
                  Row(
                    spacing: TermulSpacing.space3,
                    children: [
                      for (final (i, l) in [
                        'Semua',
                        'Favorit',
                        'Online',
                      ].indexed)
                        FilterChipButton(
                          label: l,
                          selected: _chip == i,
                          onPressed: () => setState(() => _chip = i),
                        ),
                    ],
                  ),
                  const Wrap(
                    spacing: TermulSpacing.space3,
                    children: [
                      TermulTag('netral'),
                      TermulTag('berisiko', tone: TagTone.bad),
                      TermulTag('online', tone: TagTone.ok),
                      TermulTag('beku', tone: TagTone.ice),
                      TermulTag('prod', tone: TagTone.accent),
                    ],
                  ),
                ],
              ),
            ),
            _section(
              'Daftar host',
              Column(
                spacing: TermulSpacing.space2,
                children: [
                  HostRow(
                    name: 'app-01',
                    target: 'deploy@192.0.2.11',
                    status: HostStatus.online,
                    latencyMs: 18,
                    onPressed: () {},
                  ),
                  HostRow(
                    name: 'stg-db-01',
                    target: 'postgres@192.0.2.21',
                    status: HostStatus.offline,
                    onPressed: () {},
                  ),
                  HostRow(
                    name: 'nas-01 dengan nama yang panjang sekali',
                    target: 'admin@198.51.100.8:2222',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            _section(
              'Status',
              const Wrap(
                spacing: TermulSpacing.space7,
                children: [
                  StatusDot(status: HostStatus.online),
                  StatusDot(status: HostStatus.offline),
                  StatusDot(status: HostStatus.busy),
                  StatusDot(status: HostStatus.idle),
                ],
              ),
            ),
            _section(
              'Input',
              Column(
                spacing: TermulSpacing.space5,
                children: [
                  const TermulTextField(
                    label: 'Cari host',
                    hideLabel: true,
                    icon: TermulIconName.search,
                    placeholder: 'Cari nama, user, atau IP',
                  ),
                  const TermulTextField(
                    label: 'Host',
                    mono: true,
                    placeholder: '192.0.2.11',
                    helper: 'Nama host atau alamat IP',
                  ),
                  const TermulTextField(
                    label: 'Port',
                    mono: true,
                    error: 'Port harus 1 sampai 65535',
                  ),
                  SwitchRow(
                    label: 'Biometrik untuk membuka vault',
                    description:
                        'Hanya setelah konfirmasi pertama di tiap sesi.',
                    value: _switch,
                    onChanged: (v) => setState(() => _switch = v),
                  ),
                ],
              ),
            ),
            _section(
              'Banner',
              Column(
                spacing: TermulSpacing.space3,
                children: [
                  TermulBanner(
                    tone: BannerTone.risk,
                    title: 'Host key berubah',
                    action: TermulButton(
                      label: 'Batalkan koneksi',
                      variant: TermulButtonVariant.primary,
                      onPressed: () {},
                    ),
                    child: const Text(
                      'Fingerprint berbeda dari yang tersimpan. Penyebabnya bisa server dibangun ulang, atau koneksi sedang disadap.',
                    ),
                  ),
                  const TermulBanner(
                    tone: BannerTone.warn,
                    title: 'Koneksi terputus',
                    child: Text('Menyambung ulang…'),
                  ),
                  const TermulBanner(
                    tone: BannerTone.info,
                    child: Text('Fingerprint disimpan di perangkat ini.'),
                  ),
                  const TermulBanner(
                    tone: BannerTone.ok,
                    child: Text('Tersambung ke app-01.'),
                  ),
                ],
              ),
            ),
            _section(
              'Kartu dan tombol khusus',
              Column(
                spacing: TermulSpacing.space3,
                children: [
                  const SizedBox(
                    width: double.infinity,
                    child: TermulCard(child: Text('Kartu biasa')),
                  ),
                  const SizedBox(
                    width: double.infinity,
                    child: TermulCard(
                      tone: CardTone.inset,
                      child: Text(
                        'sudo systemctl restart nginx',
                        style: TermulText.terminalSm,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: double.infinity,
                    child: TermulCard(
                      tone: CardTone.selected,
                      child: Text('Kartu terpilih'),
                    ),
                  ),
                  Row(
                    spacing: TermulSpacing.space2,
                    children: [
                      KeyButton(
                        label: 'Esc',
                        ariaLabel: 'Escape',
                        onPressed: () {},
                      ),
                      KeyButton(
                        label: 'Tab',
                        ariaLabel: 'Tab',
                        onPressed: () {},
                      ),
                      KeyButton(
                        label: 'Ctrl',
                        ariaLabel: 'Control',
                        pressed: true,
                        onPressed: () {},
                      ),
                      KeyButton(
                        label: '^C',
                        ariaLabel: 'Control C',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _section(
              'Sheet dan toast',
              Row(
                spacing: TermulSpacing.space3,
                children: [
                  Expanded(
                    child: TermulButton(
                      label: 'Buka sheet',
                      onPressed: () => showTermulSheet<void>(
                        context,
                        title: 'Tempel 3 baris?',
                        child: const TermulBanner(
                          tone: BannerTone.risk,
                          child: Text(
                            'Baris kedua mengandung rm -rf. Bila dikirim, perintah langsung dijalankan.',
                          ),
                        ),
                        cancelLabel: 'Batal',
                        confirmLabel: 'Tempel',
                        onConfirm: () {},
                      ),
                    ),
                  ),
                  Expanded(
                    child: TermulButton(
                      label: 'Toast',
                      onPressed: () =>
                          showTermulToast(context, 'Disalin · 27 karakter'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
