import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('id')];

  /// Nama aplikasi di daftar aplikasi terbaru Android.
  ///
  /// In id, this message translates to:
  /// **'TermUL'**
  String get appTitle;

  /// Kata status titik: server terjangkau.
  ///
  /// In id, this message translates to:
  /// **'online'**
  String get statusOnline;

  /// Kata status titik: server tidak terjangkau.
  ///
  /// In id, this message translates to:
  /// **'offline'**
  String get statusOffline;

  /// Kata status titik: sedang menyambung ulang.
  ///
  /// In id, this message translates to:
  /// **'menyambung ulang'**
  String get statusBusy;

  /// Kata status titik: siaga.
  ///
  /// In id, this message translates to:
  /// **'siaga'**
  String get statusIdle;

  /// Status baris host saat online beserta latensi.
  ///
  /// In id, this message translates to:
  /// **'online · {ms} ms'**
  String hostStatusOnlineMs(int ms);

  /// Status baris host saat server tidak terjangkau.
  ///
  /// In id, this message translates to:
  /// **'tidak terjangkau'**
  String get hostStatusUnreachable;

  /// Status baris host sebelum pengecekan pertama (cache, bukan fakta).
  ///
  /// In id, this message translates to:
  /// **'belum diperiksa'**
  String get hostStatusNotChecked;

  /// Tombol batal di sheet dan form.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get actionCancel;

  /// Tombol tutup banner atau sheet.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get actionClose;

  /// Tombol simpan form.
  ///
  /// In id, this message translates to:
  /// **'Simpan'**
  String get actionSave;

  /// Judul layar daftar host.
  ///
  /// In id, this message translates to:
  /// **'Host'**
  String get hostsTitle;

  /// Nama aksesibilitas tombol tambah host.
  ///
  /// In id, this message translates to:
  /// **'Tambah host'**
  String get hostsAddHost;

  /// Label kolom pencarian (disembunyikan secara visual).
  ///
  /// In id, this message translates to:
  /// **'Cari host'**
  String get hostsSearchLabel;

  /// Placeholder kolom pencarian host.
  ///
  /// In id, this message translates to:
  /// **'Cari nama, user, atau IP'**
  String get hostsSearchPlaceholder;

  /// Chip filter: semua host.
  ///
  /// In id, this message translates to:
  /// **'Semua'**
  String get filterAll;

  /// Chip filter: host favorit.
  ///
  /// In id, this message translates to:
  /// **'Favorit'**
  String get filterFavorites;

  /// Nama grup untuk host yang tidak punya grup.
  ///
  /// In id, this message translates to:
  /// **'Tanpa grup'**
  String get hostsRootGroup;

  /// Nama aksesibilitas tombol buka-tutup grup.
  ///
  /// In id, this message translates to:
  /// **'Grup {name}, {count} host'**
  String hostsGroupToggle(String name, int count);

  /// Judul keadaan kosong daftar host.
  ///
  /// In id, this message translates to:
  /// **'Belum ada host'**
  String get hostsEmptyTitle;

  /// Isi keadaan kosong daftar host.
  ///
  /// In id, this message translates to:
  /// **'Tambahkan server pertama Anda untuk menyambung lewat SSH.'**
  String get hostsEmptyBody;

  /// Pesan saat pencarian atau filter tidak menemukan host.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada host yang cocok. Ubah kata kunci atau filter.'**
  String get hostsNoMatch;

  /// Judul banner bila profiles.json rusak.
  ///
  /// In id, this message translates to:
  /// **'Daftar host rusak'**
  String get corruptHostsTitle;

  /// Isi banner bila profiles.json rusak.
  ///
  /// In id, this message translates to:
  /// **'Berkas daftar host tidak bisa dibaca dan disimpan sebagai {name}. Aplikasi mulai dari daftar kosong; berkas lama tidak dihapus.'**
  String corruptHostsBody(String name);

  /// Judul banner bila known_hosts.json rusak.
  ///
  /// In id, this message translates to:
  /// **'Sidik jari server hilang'**
  String get corruptKnownTitle;

  /// Isi banner bila known_hosts.json rusak.
  ///
  /// In id, this message translates to:
  /// **'Berkas sidik jari rusak dan disimpan sebagai {name}. Setiap server dianggap host baru sampai Anda memercayainya lagi.'**
  String corruptKnownBody(String name);

  /// Judul sheet aksi host.
  ///
  /// In id, this message translates to:
  /// **'Aksi untuk {name}'**
  String hostActionsTitle(String name);

  /// Aksi menyambung ke host.
  ///
  /// In id, this message translates to:
  /// **'Sambung'**
  String get actionConnect;

  /// Aksi mengubah host.
  ///
  /// In id, this message translates to:
  /// **'Ubah'**
  String get actionEdit;

  /// Aksi menambah host ke favorit.
  ///
  /// In id, this message translates to:
  /// **'Jadikan favorit'**
  String get actionFavorite;

  /// Aksi menghapus host dari favorit.
  ///
  /// In id, this message translates to:
  /// **'Hapus dari favorit'**
  String get actionUnfavorite;

  /// Aksi menghapus host.
  ///
  /// In id, this message translates to:
  /// **'Hapus'**
  String get actionDelete;

  /// Judul peringatan profil bermetode agen SSH.
  ///
  /// In id, this message translates to:
  /// **'Perlu dilengkapi'**
  String get agentNeedsCompletionTitle;

  /// Isi peringatan profil bermetode agen SSH.
  ///
  /// In id, this message translates to:
  /// **'Profil ini memakai agen SSH di desktop. HP tidak punya agen, jadi pilih password atau kunci di HP lalu simpan.'**
  String get agentNeedsCompletionBody;

  /// Aksi melengkapi profil agen di form.
  ///
  /// In id, this message translates to:
  /// **'Lengkapi'**
  String get actionComplete;

  /// Judul konfirmasi hapus host.
  ///
  /// In id, this message translates to:
  /// **'Hapus {name}?'**
  String deleteHostTitle(String name);

  /// Isi konfirmasi hapus host.
  ///
  /// In id, this message translates to:
  /// **'Password atau kunci yang tersimpan untuk host ini ikut terhapus, begitu juga sidik jari servernya. Server sendiri tidak berubah.'**
  String get deleteHostBody;

  /// Pesan bila hapus host gagal.
  ///
  /// In id, this message translates to:
  /// **'Host belum terhapus. Penyimpanan perangkat bermasalah; coba lagi.'**
  String get deleteHostFailed;

  /// Toast setelah host dihapus.
  ///
  /// In id, this message translates to:
  /// **'Dihapus · {name}'**
  String hostDeleted(String name);

  /// Judul form tambah host.
  ///
  /// In id, this message translates to:
  /// **'Host baru'**
  String get formAddTitle;

  /// Judul form ubah host.
  ///
  /// In id, this message translates to:
  /// **'Ubah host'**
  String get formEditTitle;

  /// Label kolom nama host.
  ///
  /// In id, this message translates to:
  /// **'Nama'**
  String get fieldName;

  /// Label kolom host.
  ///
  /// In id, this message translates to:
  /// **'Host'**
  String get fieldHost;

  /// Teks bantu kolom host.
  ///
  /// In id, this message translates to:
  /// **'Nama host atau alamat IP'**
  String get fieldHostHelper;

  /// Label kolom port.
  ///
  /// In id, this message translates to:
  /// **'Port'**
  String get fieldPort;

  /// Label kolom user.
  ///
  /// In id, this message translates to:
  /// **'User'**
  String get fieldUsername;

  /// Label kolom grup.
  ///
  /// In id, this message translates to:
  /// **'Grup (opsional)'**
  String get fieldGroup;

  /// Teks bantu kolom grup.
  ///
  /// In id, this message translates to:
  /// **'Pisahkan tingkat dengan /, mis. Produksi/Backend'**
  String get fieldGroupHelper;

  /// Label pilihan metode login.
  ///
  /// In id, this message translates to:
  /// **'Cara login'**
  String get authMethodLabel;

  /// Opsi metode login: password.
  ///
  /// In id, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// Opsi metode login: kunci privat.
  ///
  /// In id, this message translates to:
  /// **'Kunci'**
  String get authKey;

  /// Label kolom password.
  ///
  /// In id, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// Teks bantu kolom password saat mengubah host.
  ///
  /// In id, this message translates to:
  /// **'Kosongkan untuk tetap memakai password yang tersimpan'**
  String get passwordStoredHint;

  /// Tombol impor kunci privat.
  ///
  /// In id, this message translates to:
  /// **'Impor kunci dari berkas'**
  String get keyImport;

  /// Tombol mengganti kunci privat.
  ///
  /// In id, this message translates to:
  /// **'Ganti kunci'**
  String get keyReplace;

  /// Status kunci yang baru diimpor.
  ///
  /// In id, this message translates to:
  /// **'Kunci {type} siap disimpan'**
  String keyReady(String type);

  /// Status kunci yang sudah tersimpan.
  ///
  /// In id, this message translates to:
  /// **'Kunci tersimpan di perangkat'**
  String get keyStored;

  /// Keterangan kunci yang dienkripsi.
  ///
  /// In id, this message translates to:
  /// **'Kunci ini dilindungi passphrase.'**
  String get keyPassphraseEncrypted;

  /// Label kolom passphrase.
  ///
  /// In id, this message translates to:
  /// **'Passphrase kunci'**
  String get fieldPassphrase;

  /// Galat form: nama kosong.
  ///
  /// In id, this message translates to:
  /// **'Nama wajib diisi'**
  String get errNameRequired;

  /// Galat form: host kosong.
  ///
  /// In id, this message translates to:
  /// **'Host wajib diisi'**
  String get errHostRequired;

  /// Galat form: port tidak valid.
  ///
  /// In id, this message translates to:
  /// **'Port harus 1 sampai 65535'**
  String get errPortInvalid;

  /// Galat form: user kosong.
  ///
  /// In id, this message translates to:
  /// **'User wajib diisi'**
  String get errUserRequired;

  /// Galat form: password kosong.
  ///
  /// In id, this message translates to:
  /// **'Password wajib diisi'**
  String get errPasswordRequired;

  /// Galat form: kunci belum dipilih.
  ///
  /// In id, this message translates to:
  /// **'Pilih berkas kunci privat'**
  String get errKeyRequired;

  /// Galat form: passphrase tidak cocok.
  ///
  /// In id, this message translates to:
  /// **'Passphrase salah atau kosong'**
  String get errPassphraseWrong;

  /// Galat impor kunci: bukan kunci.
  ///
  /// In id, this message translates to:
  /// **'Berkas ini bukan kunci privat (terlalu besar atau bukan teks).'**
  String get keyErrNotAKey;

  /// Galat impor kunci: bukan PEM.
  ///
  /// In id, this message translates to:
  /// **'Berkas ini bukan kunci dalam format PEM.'**
  String get keyErrNotPem;

  /// Galat impor kunci: PKCS#8.
  ///
  /// In id, this message translates to:
  /// **'Format kunci ini belum didukung (PKCS#8). Ubah dengan ssh-keygen -p -m PEM, atau pakai kunci OpenSSH.'**
  String get keyErrPkcs8;

  /// Galat impor kunci: jenis lain.
  ///
  /// In id, this message translates to:
  /// **'Jenis kunci {type} belum didukung.'**
  String keyErrType(String type);

  /// Galat impor kunci: rusak.
  ///
  /// In id, this message translates to:
  /// **'Kunci rusak atau tidak terbaca.'**
  String get keyErrMalformed;

  /// Judul peringatan HP tanpa penguncian layar.
  ///
  /// In id, this message translates to:
  /// **'HP ini tidak punya kunci layar'**
  String get lockWarningTitle;

  /// Isi peringatan HP tanpa penguncian layar.
  ///
  /// In id, this message translates to:
  /// **'Siapa pun yang memegang HP bisa membuka server ini tanpa kata sandi. Menyimpan kredensial di sini berbahaya, tetapi tetap bisa dilakukan.'**
  String get lockWarningBody;

  /// Toast setelah host disimpan.
  ///
  /// In id, this message translates to:
  /// **'Disimpan · {name}'**
  String hostSaved(String name);

  /// Pesan bila simpan host gagal.
  ///
  /// In id, this message translates to:
  /// **'Belum tersimpan. Penyimpanan perangkat bermasalah; coba lagi.'**
  String get saveFailed;

  /// Judul layar galat saat aplikasi mulai.
  ///
  /// In id, this message translates to:
  /// **'Penyimpanan tidak bisa dibuka'**
  String get bootErrorTitle;

  /// Isi layar galat saat aplikasi mulai.
  ///
  /// In id, this message translates to:
  /// **'Data Anda tidak diubah. Mulai ulang aplikasi; bila berulang, periksa ruang penyimpanan HP.'**
  String get bootErrorBody;

  /// Toast sementara saat host ditekan sebelum alur sambung dibuat.
  ///
  /// In id, this message translates to:
  /// **'Sambungan belum tersedia di versi ini'**
  String get connectNotAvailable;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
