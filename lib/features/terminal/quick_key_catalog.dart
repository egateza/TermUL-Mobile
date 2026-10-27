import '../../core/models/quick_key_settings.dart';
import '../../l10n/app_localizations.dart';

/// Kelompok katalog di sheet Tambah tombol (prototipe `QuickKeysAdd`).
enum QuickKeyGroup { action, navigation, control, symbol }

/// Satu tombol yang bisa dipasang di bilah tombol cepat. Aksinya ditentukan oleh `QuickKeyBar` menurut [id].
class QuickKeyDef {
  const QuickKeyDef(this.id, this.group, this._label, this._aria);

  final String id;
  final QuickKeyGroup group;
  final String? _label;
  final String Function(AppLocalizations l) _aria;

  /// Teks di tombol. Tempel memakai teks terjemahan; tombol lain berlabel tetap.
  String label(AppLocalizations l) => _label ?? l.keyPaste;

  String aria(AppLocalizations l) => _aria(l);

  /// Pengubah yang menyala sampai ketukan berikutnya.
  bool get isModifier => id == 'ctrl' || id == 'alt';

  /// Huruf untuk pintasan Ctrl (`ctrlc` menjadi `c`); null untuk tombol lain.
  String? get controlLetter => id.startsWith('ctrl') && id.length == 5 ? id.substring(4) : null;
}

/// Urutan katalog sama dengan prototipe; [QuickKeySettings.knownIds] harus memuat id yang sama.
final List<QuickKeyDef> quickKeyCatalog = [
  QuickKeyDef('esc', QuickKeyGroup.action, 'Esc', (l) => l.keyEsc),
  QuickKeyDef('tab', QuickKeyGroup.action, 'Tab', (l) => l.keyTab),
  QuickKeyDef('ctrl', QuickKeyGroup.action, 'Ctrl', (l) => l.keyCtrl),
  QuickKeyDef('alt', QuickKeyGroup.action, 'Alt', (l) => l.keyAlt),
  QuickKeyDef('fn', QuickKeyGroup.action, 'Fn', (l) => l.keyFunctionToggle),
  QuickKeyDef('paste', QuickKeyGroup.action, null, (l) => l.keyPasteAria),
  QuickKeyDef('bksp', QuickKeyGroup.action, '⌫', (l) => l.keyBackspace),
  QuickKeyDef('enter', QuickKeyGroup.action, '⏎', (l) => l.keyEnter),
  QuickKeyDef('up', QuickKeyGroup.navigation, '↑', (l) => l.keyArrowUp),
  QuickKeyDef('down', QuickKeyGroup.navigation, '↓', (l) => l.keyArrowDown),
  QuickKeyDef('left', QuickKeyGroup.navigation, '←', (l) => l.keyArrowLeft),
  QuickKeyDef('right', QuickKeyGroup.navigation, '→', (l) => l.keyArrowRight),
  QuickKeyDef('home', QuickKeyGroup.navigation, 'Home', (l) => l.keyHome),
  QuickKeyDef('end', QuickKeyGroup.navigation, 'End', (l) => l.keyEnd),
  QuickKeyDef('pgup', QuickKeyGroup.navigation, 'PgUp', (l) => l.keyPageUp),
  QuickKeyDef('pgdn', QuickKeyGroup.navigation, 'PgDn', (l) => l.keyPageDown),
  QuickKeyDef('ins', QuickKeyGroup.navigation, 'Ins', (l) => l.keyInsert),
  QuickKeyDef('del', QuickKeyGroup.navigation, 'Del', (l) => l.keyDelete),
  QuickKeyDef('ctrlc', QuickKeyGroup.control, '^C', (l) => l.keyCtrlC),
  QuickKeyDef('ctrld', QuickKeyGroup.control, '^D', (l) => l.keyCtrlD),
  QuickKeyDef('ctrlz', QuickKeyGroup.control, '^Z', (l) => l.keyCtrlZ),
  QuickKeyDef('ctrll', QuickKeyGroup.control, '^L', (l) => l.keyCtrlL),
  QuickKeyDef('ctrlr', QuickKeyGroup.control, '^R', (l) => l.keyCtrlR),
  QuickKeyDef('ctrla', QuickKeyGroup.control, '^A', (l) => l.keyCtrlA),
  QuickKeyDef('ctrle', QuickKeyGroup.control, '^E', (l) => l.keyCtrlE),
  QuickKeyDef('ctrlw', QuickKeyGroup.control, '^W', (l) => l.keyCtrlW),
  QuickKeyDef('ctrlu', QuickKeyGroup.control, '^U', (l) => l.keyCtrlU),
  QuickKeyDef('ctrlk', QuickKeyGroup.control, '^K', (l) => l.keyCtrlK),
  QuickKeyDef('ctrlb', QuickKeyGroup.control, '^B', (l) => l.keyCtrlB),
  QuickKeyDef('ctrlx', QuickKeyGroup.control, '^X', (l) => l.keyCtrlX),
  QuickKeyDef('pipe', QuickKeyGroup.symbol, '|', (l) => l.keyPipe),
  QuickKeyDef('tilde', QuickKeyGroup.symbol, '~', (l) => l.keyTilde),
  QuickKeyDef('slash', QuickKeyGroup.symbol, '/', (l) => l.keySlash),
  QuickKeyDef('dash', QuickKeyGroup.symbol, '-', (l) => l.keyDash),
];

final Map<String, QuickKeyDef> _byId = {for (final k in quickKeyCatalog) k.id: k};

QuickKeyDef? quickKeyById(String id) => _byId[id];
