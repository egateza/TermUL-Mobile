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

  /// Tombol x di pojok kanan kolom pencarian: mengosongkan kata kunci.
  ///
  /// In id, this message translates to:
  /// **'Hapus pencarian'**
  String get actionClearSearch;

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

  /// Judul daftar pilihan filter host (dropdown di landscape).
  ///
  /// In id, this message translates to:
  /// **'Filter host'**
  String get filterTitle;

  /// Nama tombol dropdown filter untuk pembaca layar.
  ///
  /// In id, this message translates to:
  /// **'Filter host: {current}'**
  String filterDropdownLabel(String current);

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

  /// Teks layar pemuatan saat penyimpanan dibuka.
  ///
  /// In id, this message translates to:
  /// **'Memuat…'**
  String get bootLoading;

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

  /// Tombol membatalkan sambungan yang sedang berjalan.
  ///
  /// In id, this message translates to:
  /// **'Batalkan'**
  String get actionAbort;

  /// Tombol mengulang sambungan.
  ///
  /// In id, this message translates to:
  /// **'Coba lagi'**
  String get actionRetry;

  /// Tombol kembali ke daftar host.
  ///
  /// In id, this message translates to:
  /// **'Kembali'**
  String get actionBack;

  /// Tombol memutus sambungan.
  ///
  /// In id, this message translates to:
  /// **'Putuskan'**
  String get actionDisconnect;

  /// Tombol menyimpan rahasia yang dimasukkan ulang lalu menyambung.
  ///
  /// In id, this message translates to:
  /// **'Simpan dan sambung'**
  String get actionSaveAndConnect;

  /// Status saat rahasia dibuka dari vault.
  ///
  /// In id, this message translates to:
  /// **'Membuka kredensial…'**
  String get connectPreparing;

  /// Status saat menyambung.
  ///
  /// In id, this message translates to:
  /// **'Menyambung ke {name}…'**
  String connectConnecting(String name);

  /// Judul bila autentikasi perangkat dibatalkan.
  ///
  /// In id, this message translates to:
  /// **'Autentikasi dibatalkan'**
  String get authDeniedTitle;

  /// Isi bila autentikasi perangkat dibatalkan.
  ///
  /// In id, this message translates to:
  /// **'Kredensial tidak dibuka, jadi tidak ada yang dikirim ke server.'**
  String get authDeniedBody;

  /// Judul bila autentikasi perangkat tidak tersedia.
  ///
  /// In id, this message translates to:
  /// **'Autentikasi perangkat tidak bisa dipakai'**
  String get authUnavailableTitle;

  /// Isi bila autentikasi perangkat tidak tersedia.
  ///
  /// In id, this message translates to:
  /// **'Periksa pengaturan kunci layar atau sidik jari di HP, lalu coba lagi.'**
  String get authUnavailableBody;

  /// Judul layar saat rahasia tidak ditemukan di vault.
  ///
  /// In id, this message translates to:
  /// **'Rahasia hilang'**
  String get secretMissingTitle;

  /// Isi layar rahasia hilang (password).
  ///
  /// In id, this message translates to:
  /// **'Password untuk {name} tidak ditemukan di perangkat ini. Masukkan ulang untuk melanjutkan.'**
  String secretMissingPasswordBody(String name);

  /// Isi layar rahasia hilang (kunci).
  ///
  /// In id, this message translates to:
  /// **'Kunci untuk {name} tidak ditemukan atau tidak bisa dibuka di perangkat ini. Impor ulang untuk melanjutkan.'**
  String secretMissingKeyBody(String name);

  /// Isi layar rahasia hilang bila passphrase tidak cocok.
  ///
  /// In id, this message translates to:
  /// **'Passphrase tersimpan tidak cocok dengan kunci. Impor ulang kunci beserta passphrase-nya.'**
  String get secretWrongPassphraseBody;

  /// Judul galat jaringan.
  ///
  /// In id, this message translates to:
  /// **'Tidak bisa tersambung'**
  String get failNetworkTitle;

  /// Isi galat jaringan.
  ///
  /// In id, this message translates to:
  /// **'Server tidak terjangkau atau menutup koneksi. Periksa alamat, port, dan jaringan Anda.'**
  String get failNetworkBody;

  /// Judul galat negosiasi protokol.
  ///
  /// In id, this message translates to:
  /// **'Negosiasi gagal'**
  String get failHandshakeTitle;

  /// Isi galat negosiasi protokol.
  ///
  /// In id, this message translates to:
  /// **'Server memakai algoritma yang belum didukung, atau pertukaran kunci gagal. Server yang sangat lama mungkin tidak bisa disambung.'**
  String get failHandshakeBody;

  /// Judul galat login ditolak.
  ///
  /// In id, this message translates to:
  /// **'Login ditolak'**
  String get failAuthTitle;

  /// Isi galat login ditolak.
  ///
  /// In id, this message translates to:
  /// **'Server menolak kredensial. Periksa user, password atau kunci, lalu ubah host.'**
  String get failAuthBody;

  /// Judul bila pengguna menolak host key baru.
  ///
  /// In id, this message translates to:
  /// **'Host key ditolak'**
  String get failRejectedTitle;

  /// Isi bila pengguna menolak host key baru.
  ///
  /// In id, this message translates to:
  /// **'Anda menolak host key server ini. Koneksi dibatalkan dan tidak ada yang disimpan.'**
  String get failRejectedBody;

  /// Judul bila host key berubah tidak diganti.
  ///
  /// In id, this message translates to:
  /// **'Koneksi dibatalkan'**
  String get failRejectedChangedTitle;

  /// Isi bila host key berubah tidak diganti.
  ///
  /// In id, this message translates to:
  /// **'Host key yang berubah tidak diganti, jadi koneksi tidak dibuka.'**
  String get failRejectedChangedBody;

  /// Judul bila sidik jari tidak bisa ditulis ke penyimpanan.
  ///
  /// In id, this message translates to:
  /// **'Sidik jari tidak tersimpan'**
  String get failStoreTitle;

  /// Isi bila sidik jari tidak bisa ditulis ke penyimpanan.
  ///
  /// In id, this message translates to:
  /// **'Penyimpanan perangkat bermasalah, jadi koneksi dibatalkan demi keamanan.'**
  String get failStoreBody;

  /// Judul galat tidak dikenal.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyambung'**
  String get failUnknownTitle;

  /// Isi galat tidak dikenal.
  ///
  /// In id, this message translates to:
  /// **'Terjadi kesalahan yang tidak dikenal. Coba lagi; bila berulang, ubah host atau periksa server.'**
  String get failUnknownBody;

  /// Judul layar verifikasi host key (host baru).
  ///
  /// In id, this message translates to:
  /// **'Host baru'**
  String get hostKeyNewTitle;

  /// Isi layar verifikasi host key (host baru).
  ///
  /// In id, this message translates to:
  /// **'Ini koneksi pertama ke {name}. Pastikan fingerprint di bawah cocok dengan yang Anda ketahui sebelum melanjutkan.'**
  String hostKeyNewBody(String name);

  /// Label algoritma host key.
  ///
  /// In id, this message translates to:
  /// **'Algoritma'**
  String get hostKeyAlgorithm;

  /// Label sidik jari host key.
  ///
  /// In id, this message translates to:
  /// **'Fingerprint (SHA256)'**
  String get hostKeyFingerprint;

  /// Catatan di layar host baru.
  ///
  /// In id, this message translates to:
  /// **'Fingerprint disimpan di perangkat ini. Bila nanti berubah, Anda akan diperingatkan sebelum sambungan dibuka.'**
  String get hostKeyNewNote;

  /// Tombol utama layar host baru.
  ///
  /// In id, this message translates to:
  /// **'Percayai dan sambung'**
  String get hostKeyTrustAndConnect;

  /// Tombol sambung tanpa menyimpan sidik jari.
  ///
  /// In id, this message translates to:
  /// **'Sambung sekali saja'**
  String get hostKeyConnectOnce;

  /// Judul layar host key berubah.
  ///
  /// In id, this message translates to:
  /// **'Host key berubah'**
  String get hostKeyChangedTitle;

  /// Isi layar host key berubah.
  ///
  /// In id, this message translates to:
  /// **'Fingerprint {name} berbeda dari yang tersimpan. Penyebabnya bisa server dibangun ulang, atau koneksi sedang disadap.'**
  String hostKeyChangedBody(String name);

  /// Label sidik jari yang tersimpan.
  ///
  /// In id, this message translates to:
  /// **'Tersimpan'**
  String get hostKeyStored;

  /// Label sidik jari yang baru diterima.
  ///
  /// In id, this message translates to:
  /// **'Diterima sekarang'**
  String get hostKeyReceived;

  /// Kotak persetujuan sebelum mengganti host key.
  ///
  /// In id, this message translates to:
  /// **'Saya sudah memastikan perubahan ini sah dengan pemilik server'**
  String get hostKeyAck;

  /// Tombol utama (pilihan aman) layar host key berubah.
  ///
  /// In id, this message translates to:
  /// **'Batalkan koneksi'**
  String get hostKeyCancelConnection;

  /// Tombol berisiko mengganti host key lalu menyambung.
  ///
  /// In id, this message translates to:
  /// **'Ganti key dan sambung'**
  String get hostKeyReplaceAndConnect;

  /// Alasan yang tampil di prompt sidik jari atau PIN saat kredensial dibuka.
  ///
  /// In id, this message translates to:
  /// **'Buka kredensial untuk {name}'**
  String unlockReason(String name);

  /// Status di layar terminal saat shell dibuka.
  ///
  /// In id, this message translates to:
  /// **'Membuka shell…'**
  String get terminalStatusOpening;

  /// Status di layar terminal saat shell berjalan.
  ///
  /// In id, this message translates to:
  /// **'Tersambung'**
  String get terminalStatusConnected;

  /// Status di layar terminal saat shell selesai.
  ///
  /// In id, this message translates to:
  /// **'Sesi berakhir'**
  String get terminalStatusEnded;

  /// Status di layar terminal saat shell gagal dibuka.
  ///
  /// In id, this message translates to:
  /// **'Shell tidak terbuka'**
  String get terminalStatusFailed;

  /// Judul konfirmasi keluar dari layar terminal.
  ///
  /// In id, this message translates to:
  /// **'Putuskan sambungan?'**
  String get terminalLeaveTitle;

  /// Isi konfirmasi keluar dari layar terminal.
  ///
  /// In id, this message translates to:
  /// **'Shell di server ikut berakhir dan program yang sedang berjalan berhenti. Gunakan tmux bila sesi harus tetap hidup.'**
  String get terminalLeaveBody;

  /// Nama semantik header terminal.
  ///
  /// In id, this message translates to:
  /// **'{name}, {status}'**
  String terminalHostLabel(String name, String status);

  /// Label aksesibilitas tombol Esc.
  ///
  /// In id, this message translates to:
  /// **'Tombol Escape'**
  String get keyEsc;

  /// Label aksesibilitas tombol Tab.
  ///
  /// In id, this message translates to:
  /// **'Tombol Tab'**
  String get keyTab;

  /// Label aksesibilitas tombol Ctrl.
  ///
  /// In id, this message translates to:
  /// **'Ctrl, berlaku untuk satu ketukan berikutnya'**
  String get keyCtrl;

  /// Label aksesibilitas tombol Alt.
  ///
  /// In id, this message translates to:
  /// **'Alt, berlaku untuk satu ketukan berikutnya'**
  String get keyAlt;

  /// Label aksesibilitas tombol ^C.
  ///
  /// In id, this message translates to:
  /// **'Ctrl C, hentikan program'**
  String get keyCtrlC;

  /// Label aksesibilitas tombol ^D.
  ///
  /// In id, this message translates to:
  /// **'Ctrl D, akhir masukan'**
  String get keyCtrlD;

  /// Label aksesibilitas.
  ///
  /// In id, this message translates to:
  /// **'Panah atas'**
  String get keyArrowUp;

  /// Label aksesibilitas.
  ///
  /// In id, this message translates to:
  /// **'Panah bawah'**
  String get keyArrowDown;

  /// Label aksesibilitas.
  ///
  /// In id, this message translates to:
  /// **'Panah kiri'**
  String get keyArrowLeft;

  /// Label aksesibilitas.
  ///
  /// In id, this message translates to:
  /// **'Panah kanan'**
  String get keyArrowRight;

  /// Label aksesibilitas.
  ///
  /// In id, this message translates to:
  /// **'Home'**
  String get keyHome;

  /// Label aksesibilitas.
  ///
  /// In id, this message translates to:
  /// **'End'**
  String get keyEnd;

  /// Label aksesibilitas.
  ///
  /// In id, this message translates to:
  /// **'Page Up'**
  String get keyPageUp;

  /// Label aksesibilitas.
  ///
  /// In id, this message translates to:
  /// **'Page Down'**
  String get keyPageDown;

  /// Label aksesibilitas tombol |.
  ///
  /// In id, this message translates to:
  /// **'Garis tegak'**
  String get keyPipe;

  /// Label aksesibilitas tombol ~.
  ///
  /// In id, this message translates to:
  /// **'Tilde'**
  String get keyTilde;

  /// Label aksesibilitas tombol /.
  ///
  /// In id, this message translates to:
  /// **'Garis miring'**
  String get keySlash;

  /// Label aksesibilitas tombol -.
  ///
  /// In id, this message translates to:
  /// **'Tanda hubung'**
  String get keyDash;

  /// Label aksesibilitas tombol Fn.
  ///
  /// In id, this message translates to:
  /// **'Tombol F1 sampai F12'**
  String get keyFunctionToggle;

  /// Label aksesibilitas tombol untuk menutup baris F1 sampai F12.
  ///
  /// In id, this message translates to:
  /// **'Kembali ke tombol biasa'**
  String get keyFunctionBack;

  /// Label aksesibilitas tombol F.
  ///
  /// In id, this message translates to:
  /// **'F{n}'**
  String keyFunction(int n);

  /// Nama semantik baris tombol cepat.
  ///
  /// In id, this message translates to:
  /// **'Tombol khusus terminal'**
  String get quickKeysLabel;

  /// Judul banner saat sambungan ke server putus.
  ///
  /// In id, this message translates to:
  /// **'Koneksi terputus'**
  String get reconnectLostTitle;

  /// Isi banner saat sambungan putus.
  ///
  /// In id, this message translates to:
  /// **'Riwayat layar tetap di sini. Program yang berjalan di server berhenti, kecuali yang berjalan di dalam tmux.'**
  String get reconnectLostBody;

  /// Judul banner saat menyambung ulang.
  ///
  /// In id, this message translates to:
  /// **'Menyambung ulang…'**
  String get reconnectingTitle;

  /// Isi banner saat menyambung ulang.
  ///
  /// In id, this message translates to:
  /// **'Riwayat layar tetap terlihat.'**
  String get reconnectingBody;

  /// Judul banner saat host belum terjangkau dan sambung ulang menunggu giliran berikutnya.
  ///
  /// In id, this message translates to:
  /// **'Menunggu server terjangkau…'**
  String get reconnectWaitingTitle;

  /// Isi banner saat menunggu percobaan sambung ulang berikutnya.
  ///
  /// In id, this message translates to:
  /// **'Mencoba lagi dalam {seconds} detik.'**
  String reconnectWaitingBody(int seconds);

  /// Judul banner saat sambung ulang menunggu pengguna menampilkan prompt biometrik.
  ///
  /// In id, this message translates to:
  /// **'Perlu verifikasi'**
  String get reconnectAuthTitle;

  /// Isi banner saat sambung ulang butuh autentikasi perangkat.
  ///
  /// In id, this message translates to:
  /// **'Menyambung ulang membutuhkan sidik jari, PIN, atau pola perangkat.'**
  String get reconnectAuthBody;

  /// Tombol untuk menampilkan prompt biometrik atau kunci layar.
  ///
  /// In id, this message translates to:
  /// **'Tampilkan prompt'**
  String get reconnectShowPrompt;

  /// Tombol sambung ulang manual.
  ///
  /// In id, this message translates to:
  /// **'Sambung sekarang'**
  String get reconnectNow;

  /// Judul banner saat sambung ulang gagal.
  ///
  /// In id, this message translates to:
  /// **'Gagal menyambung ulang'**
  String get reconnectFailedTitle;

  /// Pemisah yang ditulis di terminal setelah tersambung ulang.
  ///
  /// In id, this message translates to:
  /// **'— tersambung ulang —'**
  String get reconnectedMarker;

  /// Status header terminal saat sambungan putus.
  ///
  /// In id, this message translates to:
  /// **'Terputus'**
  String get terminalStatusLost;

  /// Status header terminal saat menyambung ulang.
  ///
  /// In id, this message translates to:
  /// **'Menyambung ulang…'**
  String get terminalStatusReconnecting;

  /// Nama landmark bar navigasi bawah.
  ///
  /// In id, this message translates to:
  /// **'Navigasi utama'**
  String get navLabel;

  /// Tab Host di bar navigasi.
  ///
  /// In id, this message translates to:
  /// **'Host'**
  String get navHosts;

  /// Tab Sesi di bar navigasi (satu kata).
  ///
  /// In id, this message translates to:
  /// **'Sesi'**
  String get navSessions;

  /// Tab SFTP di bar navigasi.
  ///
  /// In id, this message translates to:
  /// **'SFTP'**
  String get navSftp;

  /// Tab Snippet di bar navigasi.
  ///
  /// In id, this message translates to:
  /// **'Snippet'**
  String get navSnippets;

  /// Tab Streak di bar navigasi (satu kata).
  ///
  /// In id, this message translates to:
  /// **'Streak'**
  String get navStreak;

  /// Tab Pengaturan di bar navigasi.
  ///
  /// In id, this message translates to:
  /// **'Pengaturan'**
  String get navSettings;

  /// Judul layar tab Streak.
  ///
  /// In id, this message translates to:
  /// **'Streak'**
  String get streakTitle;

  /// Nama level api 1.
  ///
  /// In id, this message translates to:
  /// **'Bara'**
  String get streakTier1;

  /// Nama level api 2.
  ///
  /// In id, this message translates to:
  /// **'Api Jingga'**
  String get streakTier2;

  /// Nama level api 3.
  ///
  /// In id, this message translates to:
  /// **'Api Merah'**
  String get streakTier3;

  /// Nama level api 4.
  ///
  /// In id, this message translates to:
  /// **'Api Magenta'**
  String get streakTier4;

  /// Nama level api 5.
  ///
  /// In id, this message translates to:
  /// **'Api Ungu'**
  String get streakTier5;

  /// Nama level api 6.
  ///
  /// In id, this message translates to:
  /// **'Api Biru'**
  String get streakTier6;

  /// Nama level api 7.
  ///
  /// In id, this message translates to:
  /// **'Api Zamrud'**
  String get streakTier7;

  /// Nama level api 8.
  ///
  /// In id, this message translates to:
  /// **'Api Emas'**
  String get streakTier8;

  /// Nama level api 9.
  ///
  /// In id, this message translates to:
  /// **'Api Pelangi'**
  String get streakTier9;

  /// Nama api padam untuk pembaca layar.
  ///
  /// In id, this message translates to:
  /// **'Api padam'**
  String get streakFlameGray;

  /// Nama api beku untuk pembaca layar.
  ///
  /// In id, this message translates to:
  /// **'Api membeku'**
  String get streakFlameFrozen;

  /// Nama api hangus untuk pembaca layar.
  ///
  /// In id, this message translates to:
  /// **'Api hangus'**
  String get streakFlameExpired;

  /// Angka streak aktif (mono).
  ///
  /// In id, this message translates to:
  /// **'{count}x'**
  String streakCountActive(int count);

  /// Angka bara: hari ke-N dari 3.
  ///
  /// In id, this message translates to:
  /// **'{count}/3'**
  String streakCountKindling(int count);

  /// Nama aksesibilitas chip streak aktif.
  ///
  /// In id, this message translates to:
  /// **'Streak {count} hari, {tier}. Ketuk untuk membuka layar Streak.'**
  String streakChipActive(int count, String tier);

  /// Nama aksesibilitas chip bara.
  ///
  /// In id, this message translates to:
  /// **'Hari ke-{count} dari 3 menuju streak. Ketuk untuk membuka layar Streak.'**
  String streakChipKindling(int count);

  /// Nama aksesibilitas chip padam.
  ///
  /// In id, this message translates to:
  /// **'Streak {count} hari padam. Ketuk untuk membuka dan menyalakan.'**
  String streakChipGray(int count);

  /// Nama aksesibilitas chip beku.
  ///
  /// In id, this message translates to:
  /// **'Streak {count} hari beku. Ketuk untuk membuka dan memecahkan es.'**
  String streakChipFrozen(int count);

  /// Tombol bantuan di header Streak.
  ///
  /// In id, this message translates to:
  /// **'Bantuan: cara kerja streak'**
  String get streakHelpLabel;

  /// Tombol ke Pengaturan di header Streak.
  ///
  /// In id, this message translates to:
  /// **'Pengaturan streak'**
  String get streakSettingsLabel;

  /// Judul layar pengaturan khusus streak (dibuka dari tab Streak).
  ///
  /// In id, this message translates to:
  /// **'Pengaturan streak'**
  String get streakSettingsTitle;

  /// Nama tombol api padam.
  ///
  /// In id, this message translates to:
  /// **'Ketuk api untuk menyalakan'**
  String get streakStageGray;

  /// Nama tombol api beku.
  ///
  /// In id, this message translates to:
  /// **'Ketuk untuk memecahkan es'**
  String get streakStageFrozen;

  /// Nama api yang tidak menunggu ketukan.
  ///
  /// In id, this message translates to:
  /// **'Api streak'**
  String get streakStageActive;

  /// Satuan di bawah angka streak.
  ///
  /// In id, this message translates to:
  /// **'hari berturut-turut'**
  String get streakUnitDays;

  /// Status hari ini sudah dihitung.
  ///
  /// In id, this message translates to:
  /// **'Hari ini terhitung sejak aplikasi dibuka. Sampai jumpa besok.'**
  String get streakStatusActive;

  /// Status bara.
  ///
  /// In id, this message translates to:
  /// **'Buka TermUL lagi besok. Streak menyala di hari ke-3.'**
  String get streakStatusKindling;

  /// Status padam sebelum diketuk.
  ///
  /// In id, this message translates to:
  /// **'Kemarin kamu tidak membuka TermUL, jadi api padam. Ketuk api 3x cepat untuk menyalakannya lagi.'**
  String get streakStatusGray;

  /// Status padam saat diketuk.
  ///
  /// In id, this message translates to:
  /// **'Sisa {count} ketukan lagi untuk menyalakan api.'**
  String streakStatusGrayLeft(int count);

  /// Status setelah api padam dinyalakan.
  ///
  /// In id, this message translates to:
  /// **'Api menyala lagi. Hari ini terhitung.'**
  String get streakStatusGrayRelit;

  /// Status beku sebelum diketuk.
  ///
  /// In id, this message translates to:
  /// **'Kamu absen {missed} hari, api membeku. Ketuk api {need} kali untuk memecahkan es.'**
  String streakStatusFrozen(int missed, int need);

  /// Status beku saat diketuk.
  ///
  /// In id, this message translates to:
  /// **'Sisa {count} ketukan lagi untuk memecahkan es.'**
  String streakStatusFrozenLeft(int count);

  /// Status setelah es pecah.
  ///
  /// In id, this message translates to:
  /// **'Es pecah! Streak dilanjutkan. Hari ini terhitung.'**
  String get streakStatusFrozenRelit;

  /// Lencana hari ini sudah dihitung.
  ///
  /// In id, this message translates to:
  /// **'Hari ini selesai'**
  String get streakTodayDone;

  /// Tombol memutar ulang animasi layar Streak.
  ///
  /// In id, this message translates to:
  /// **'Putar ulang animasi'**
  String get streakReplay;

  /// Judul kartu pekan ini.
  ///
  /// In id, this message translates to:
  /// **'Pekan ini'**
  String get streakWeek;

  /// Nama hari singkat.
  ///
  /// In id, this message translates to:
  /// **'Sen'**
  String get streakDayMon;

  /// Nama hari singkat.
  ///
  /// In id, this message translates to:
  /// **'Sel'**
  String get streakDayTue;

  /// Nama hari singkat.
  ///
  /// In id, this message translates to:
  /// **'Rab'**
  String get streakDayWed;

  /// Nama hari singkat.
  ///
  /// In id, this message translates to:
  /// **'Kam'**
  String get streakDayThu;

  /// Nama hari singkat.
  ///
  /// In id, this message translates to:
  /// **'Jum'**
  String get streakDayFri;

  /// Nama hari singkat.
  ///
  /// In id, this message translates to:
  /// **'Sab'**
  String get streakDaySat;

  /// Nama hari singkat.
  ///
  /// In id, this message translates to:
  /// **'Min'**
  String get streakDaySun;

  /// Statistik streak terpanjang.
  ///
  /// In id, this message translates to:
  /// **'Terpanjang'**
  String get streakLongest;

  /// Statistik hari aktif bulan ini.
  ///
  /// In id, this message translates to:
  /// **'Aktif bulan ini'**
  String get streakActiveMonth;

  /// Statistik level api.
  ///
  /// In id, this message translates to:
  /// **'Level api'**
  String get streakLevel;

  /// Nilai statistik dalam hari.
  ///
  /// In id, this message translates to:
  /// **'{count} hari'**
  String streakDays(int count);

  /// Nilai level api.
  ///
  /// In id, this message translates to:
  /// **'{level} · {name}'**
  String streakLevelValue(int level, String name);

  /// Judul kartu progres level.
  ///
  /// In id, this message translates to:
  /// **'Menuju Level {level} · hari ke-{target}'**
  String streakNextLevel(int level, int target);

  /// Angka progres level (mono).
  ///
  /// In id, this message translates to:
  /// **'{count} / {target}'**
  String streakNextProgress(int count, int target);

  /// Sisa hari menuju level berikutnya.
  ///
  /// In id, this message translates to:
  /// **'Tinggal {count} hari lagi.'**
  String streakDaysLeft(int count);

  /// Judul kartu level saat level tertinggi.
  ///
  /// In id, this message translates to:
  /// **'Level 9 · {name}'**
  String streakMaxLevel(String name);

  /// Keterangan saat level tertinggi.
  ///
  /// In id, this message translates to:
  /// **'Level tertinggi sudah tercapai.'**
  String get streakMaxLevelText;

  /// Nama aksesibilitas lencana level.
  ///
  /// In id, this message translates to:
  /// **'Level {level}, {name}, {state}'**
  String streakLevelBadge(int level, String name, String state);

  /// Keadaan lencana level.
  ///
  /// In id, this message translates to:
  /// **'level sekarang'**
  String get streakBadgeCurrent;

  /// Keadaan lencana level.
  ///
  /// In id, this message translates to:
  /// **'sudah tercapai'**
  String get streakBadgeReached;

  /// Keadaan lencana level.
  ///
  /// In id, this message translates to:
  /// **'belum tercapai'**
  String get streakBadgeLocked;

  /// Nama bulan.
  ///
  /// In id, this message translates to:
  /// **'Januari'**
  String get streakMonth1;

  /// Nama bulan singkat.
  ///
  /// In id, this message translates to:
  /// **'Jan'**
  String get streakMonthShort1;

  /// Nama bulan.
  ///
  /// In id, this message translates to:
  /// **'Februari'**
  String get streakMonth2;

  /// Nama bulan singkat.
  ///
  /// In id, this message translates to:
  /// **'Feb'**
  String get streakMonthShort2;

  /// Nama bulan.
  ///
  /// In id, this message translates to:
  /// **'Maret'**
  String get streakMonth3;

  /// Nama bulan singkat.
  ///
  /// In id, this message translates to:
  /// **'Mar'**
  String get streakMonthShort3;

  /// Nama bulan.
  ///
  /// In id, this message translates to:
  /// **'April'**
  String get streakMonth4;

  /// Nama bulan singkat.
  ///
  /// In id, this message translates to:
  /// **'Apr'**
  String get streakMonthShort4;

  /// Nama bulan.
  ///
  /// In id, this message translates to:
  /// **'Mei'**
  String get streakMonth5;

  /// Nama bulan singkat.
  ///
  /// In id, this message translates to:
  /// **'Mei'**
  String get streakMonthShort5;

  /// Nama bulan.
  ///
  /// In id, this message translates to:
  /// **'Juni'**
  String get streakMonth6;

  /// Nama bulan singkat.
  ///
  /// In id, this message translates to:
  /// **'Jun'**
  String get streakMonthShort6;

  /// Nama bulan.
  ///
  /// In id, this message translates to:
  /// **'Juli'**
  String get streakMonth7;

  /// Nama bulan singkat.
  ///
  /// In id, this message translates to:
  /// **'Jul'**
  String get streakMonthShort7;

  /// Nama bulan.
  ///
  /// In id, this message translates to:
  /// **'Agustus'**
  String get streakMonth8;

  /// Nama bulan singkat.
  ///
  /// In id, this message translates to:
  /// **'Agu'**
  String get streakMonthShort8;

  /// Nama bulan.
  ///
  /// In id, this message translates to:
  /// **'September'**
  String get streakMonth9;

  /// Nama bulan singkat.
  ///
  /// In id, this message translates to:
  /// **'Sep'**
  String get streakMonthShort9;

  /// Nama bulan.
  ///
  /// In id, this message translates to:
  /// **'Oktober'**
  String get streakMonth10;

  /// Nama bulan singkat.
  ///
  /// In id, this message translates to:
  /// **'Okt'**
  String get streakMonthShort10;

  /// Nama bulan.
  ///
  /// In id, this message translates to:
  /// **'November'**
  String get streakMonth11;

  /// Nama bulan singkat.
  ///
  /// In id, this message translates to:
  /// **'Nov'**
  String get streakMonthShort11;

  /// Nama bulan.
  ///
  /// In id, this message translates to:
  /// **'Desember'**
  String get streakMonth12;

  /// Nama bulan singkat.
  ///
  /// In id, this message translates to:
  /// **'Des'**
  String get streakMonthShort12;

  /// Judul kalender.
  ///
  /// In id, this message translates to:
  /// **'{month} {year}'**
  String streakMonthTitle(String month, String year);

  /// Keterangan kalender.
  ///
  /// In id, this message translates to:
  /// **'Kotak terisi = hari aktif. Bingkai amber = hari ini. Bingkai putus-putus berwarna = hari absen.'**
  String get streakLegend;

  /// Keterangan absen beku di kalender.
  ///
  /// In id, this message translates to:
  /// **'Absen {count} hari ({range}): api membeku. Ketuk {need} kali untuk memecahkan es.'**
  String streakAbsentFrozen(int count, String range, int need);

  /// Keterangan absen padam di kalender.
  ///
  /// In id, this message translates to:
  /// **'Absen {count} hari ({range}): api padam. Ketuk 3 kali cepat untuk menyalakan.'**
  String streakAbsentGray(int count, String range);

  /// Nama aksesibilitas sel kalender.
  ///
  /// In id, this message translates to:
  /// **'{day} {month}, {state}'**
  String streakDayState(int day, String month, String state);

  /// Keadaan hari.
  ///
  /// In id, this message translates to:
  /// **'aktif'**
  String get streakDayActive;

  /// Keadaan hari.
  ///
  /// In id, this message translates to:
  /// **'hari ini, belum terhitung'**
  String get streakDayToday;

  /// Keadaan hari.
  ///
  /// In id, this message translates to:
  /// **'hari ini, aktif'**
  String get streakDayTodayActive;

  /// Keadaan hari.
  ///
  /// In id, this message translates to:
  /// **'absen'**
  String get streakDayAbsent;

  /// Keadaan hari.
  ///
  /// In id, this message translates to:
  /// **'tidak aktif'**
  String get streakDayMissed;

  /// Keadaan hari.
  ///
  /// In id, this message translates to:
  /// **'belum tiba'**
  String get streakDayFuture;

  /// Baris pembuka bantuan.
  ///
  /// In id, this message translates to:
  /// **'Cara kerja streak dan contoh jika absen'**
  String get streakHelpRow;

  /// Judul sheet bantuan.
  ///
  /// In id, this message translates to:
  /// **'Cara kerja streak'**
  String get streakHelpTitle;

  /// Bantuan paragraf 1 (teks prototipe).
  ///
  /// In id, this message translates to:
  /// **'Satu hari dihitung saat Tuan membuka aplikasi. Bila tanggal berganti selagi aplikasi terbuka, hari baru dihitung seperti membuka lagi.'**
  String get streakHelp1;

  /// Bantuan paragraf 2.
  ///
  /// In id, this message translates to:
  /// **'Hari 1-2 tampil sebagai bara dengan angka N/3 dan belum dihitung sebagai streak. Mulai hari ke-3 api menyala.'**
  String get streakHelp2;

  /// Bantuan paragraf 3.
  ///
  /// In id, this message translates to:
  /// **'Absen 1-2 hari: api padam, ketuk 3 kali cepat untuk menyalakan. Absen 3-10 hari: api membeku, ketukan = 5 + (hari absen - 3), maksimal 10. Absen lebih dari 10 hari: streak hangus dan mulai lagi dari 1/3.'**
  String get streakHelp3;

  /// Tautan bantuan ke Pengaturan.
  ///
  /// In id, this message translates to:
  /// **'Atur tampilan streak dan pengingat'**
  String get streakHelpSettings;

  /// Judul contoh absen.
  ///
  /// In id, this message translates to:
  /// **'Contoh jika tidak membuka TermUL'**
  String get streakHelpExamples;

  /// Contoh absen.
  ///
  /// In id, this message translates to:
  /// **'Absen 1-2 hari'**
  String get streakExampleGrayTitle;

  /// Contoh absen.
  ///
  /// In id, this message translates to:
  /// **'Api padam. Ketuk 3 kali cepat untuk menyalakan.'**
  String get streakExampleGrayText;

  /// Contoh absen.
  ///
  /// In id, this message translates to:
  /// **'Absen 3-10 hari'**
  String get streakExampleFrozenTitle;

  /// Contoh absen.
  ///
  /// In id, this message translates to:
  /// **'Api membeku. Ketukan = 5 + (hari absen - 3), jadi absen 5 hari = 7 ketukan.'**
  String get streakExampleFrozenText;

  /// Contoh absen.
  ///
  /// In id, this message translates to:
  /// **'Absen lebih dari 10 hari'**
  String get streakExampleExpiredTitle;

  /// Contoh absen.
  ///
  /// In id, this message translates to:
  /// **'Streak hangus dan mulai lagi dari 1/3.'**
  String get streakExampleExpiredText;

  /// Banner berkas streak rusak.
  ///
  /// In id, this message translates to:
  /// **'Data streak rusak'**
  String get streakCorruptTitle;

  /// Banner berkas streak rusak.
  ///
  /// In id, this message translates to:
  /// **'Berkas streak tidak bisa dibaca dan disimpan sebagai {name}. Streak dimulai lagi dari awal; berkas lama tidak dihapus.'**
  String streakCorruptBody(String name);

  /// Judul kecil di atas splash streak.
  ///
  /// In id, this message translates to:
  /// **'Streak harian'**
  String get streakSplashHeader;

  /// Tombol memutar ulang animasi splash.
  ///
  /// In id, this message translates to:
  /// **'Putar ulang'**
  String get streakSplashReplay;

  /// Satuan angka di splash setelah streak menyala.
  ///
  /// In id, this message translates to:
  /// **'hari streak'**
  String get streakSplashUnit;

  /// Lencana saat streak mencapai hari ke-3.
  ///
  /// In id, this message translates to:
  /// **'Streak menyala · {tier}'**
  String streakSplashLit(String tier);

  /// Lencana saat level api naik.
  ///
  /// In id, this message translates to:
  /// **'Naik level · {tier}'**
  String streakSplashLevelUp(String tier);

  /// Progres retakan es di splash (mono).
  ///
  /// In id, this message translates to:
  /// **'Retak {cracks}/{need}'**
  String streakSplashCracks(int cracks, int need);

  /// Pesan setelah api dinyalakan di splash.
  ///
  /// In id, this message translates to:
  /// **'Api menyala lagi. Streak lanjut, hari ini ikut dihitung.'**
  String get streakSplashRelit;

  /// Pesan hangus di splash.
  ///
  /// In id, this message translates to:
  /// **'Kamu absen {missed} hari. Streak {lost} hari hangus.'**
  String streakSplashExpired(int missed, int lost);

  /// Pesan setelah hangus di splash.
  ///
  /// In id, this message translates to:
  /// **'Mulai lagi hari ini. Buka TermUL 3 hari berturut-turut untuk menyalakan streak.'**
  String get streakSplashRestart;

  /// Nama tombol api padam di splash.
  ///
  /// In id, this message translates to:
  /// **'Ketuk api tiga kali cepat untuk menyalakan'**
  String get streakSplashStageGray;

  /// Nama tombol api beku di splash.
  ///
  /// In id, this message translates to:
  /// **'Ketuk api untuk memecahkan es'**
  String get streakSplashStageFrozen;

  /// Tombol menutup splash.
  ///
  /// In id, this message translates to:
  /// **'Lanjut'**
  String get streakSplashContinue;

  /// Tombol menutup splash padam atau beku tanpa menyalakan api.
  ///
  /// In id, this message translates to:
  /// **'Nanti saja'**
  String get streakSplashLater;

  /// Judul notifikasi pengingat streak harian.
  ///
  /// In id, this message translates to:
  /// **'Api streak menunggu'**
  String get streakReminderTitle;

  /// Isi notifikasi pengingat streak harian.
  ///
  /// In id, this message translates to:
  /// **'Buka TermUL hari ini supaya streak tetap menyala.'**
  String get streakReminderText;

  /// Nama saluran notifikasi pengingat streak di pengaturan Android.
  ///
  /// In id, this message translates to:
  /// **'Pengingat streak'**
  String get streakReminderChannel;

  /// Pesan saat izin notifikasi ditolak ketika menyalakan pengingat.
  ///
  /// In id, this message translates to:
  /// **'Izin notifikasi diperlukan untuk pengingat harian'**
  String get settingsStreakReminderNeedsPermission;

  /// Peringatan saat pengingat menyala tetapi notifikasi diblokir.
  ///
  /// In id, this message translates to:
  /// **'Notifikasi belum diizinkan, jadi pengingat tidak akan tampil.'**
  String get settingsStreakReminderBlocked;

  /// Saklar menampilkan chip dan splash streak.
  ///
  /// In id, this message translates to:
  /// **'Tampilkan streak api'**
  String get settingsStreakShowLabel;

  /// Keterangan saklar tampilkan streak.
  ///
  /// In id, this message translates to:
  /// **'Hari tetap dihitung walau ikonnya disembunyikan'**
  String get settingsStreakShowDesc;

  /// Saklar pengingat streak.
  ///
  /// In id, this message translates to:
  /// **'Pengingat harian'**
  String get settingsStreakReminderLabel;

  /// Keterangan saklar pengingat.
  ///
  /// In id, this message translates to:
  /// **'Notifikasi pukul 20.00 bila belum membuka aplikasi hari ini'**
  String get settingsStreakReminderDesc;

  /// Judul layar pengaturan.
  ///
  /// In id, this message translates to:
  /// **'Pengaturan'**
  String get settingsTitle;

  /// Judul bagian pengaturan terminal.
  ///
  /// In id, this message translates to:
  /// **'Terminal'**
  String get settingsTerminalSection;

  /// Label pengaturan ukuran huruf terminal.
  ///
  /// In id, this message translates to:
  /// **'Ukuran font'**
  String get settingsFontSize;

  /// Nilai ukuran huruf terminal.
  ///
  /// In id, this message translates to:
  /// **'{px} px'**
  String settingsFontSizeValue(int px);

  /// Tombol mengurangi ukuran huruf.
  ///
  /// In id, this message translates to:
  /// **'Kecilkan font'**
  String get settingsFontSmaller;

  /// Tombol menambah ukuran huruf.
  ///
  /// In id, this message translates to:
  /// **'Besarkan font'**
  String get settingsFontLarger;

  /// Label pengaturan tinggi baris terminal.
  ///
  /// In id, this message translates to:
  /// **'Tinggi baris'**
  String get settingsLineHeight;

  /// Nilai tinggi baris terminal sebagai kelipatan ukuran huruf, mis. 1,3×.
  ///
  /// In id, this message translates to:
  /// **'{value}×'**
  String settingsLineHeightValue(String value);

  /// Tombol mengurangi tinggi baris.
  ///
  /// In id, this message translates to:
  /// **'Rapatkan baris'**
  String get settingsLineTighter;

  /// Tombol menambah tinggi baris.
  ///
  /// In id, this message translates to:
  /// **'Renggangkan baris'**
  String get settingsLineLooser;

  /// Keterangan di bawah pengaturan terminal.
  ///
  /// In id, this message translates to:
  /// **'Berlaku langsung di sesi yang sedang terbuka. Makin kecil huruf dan makin rapat baris, makin banyak baris yang muat; terlalu kecil sulit dibaca.'**
  String get settingsTerminalHint;

  /// Tombol mengembalikan pengaturan terminal ke nilai bawaan.
  ///
  /// In id, this message translates to:
  /// **'Kembalikan bawaan'**
  String get settingsResetDefaults;

  /// Nama aksesibilitas pratinjau terminal.
  ///
  /// In id, this message translates to:
  /// **'Pratinjau terminal'**
  String get settingsPreviewLabel;

  /// Judul banner saat settings.json gagal ditulis.
  ///
  /// In id, this message translates to:
  /// **'Pengaturan tidak tersimpan'**
  String get settingsSaveFailedTitle;

  /// Isi banner saat settings.json gagal ditulis.
  ///
  /// In id, this message translates to:
  /// **'Perubahan tetap berlaku sampai aplikasi ditutup, tetapi akan hilang setelah itu. Periksa ruang penyimpanan HP lalu coba lagi.'**
  String get settingsSaveFailedBody;

  /// Judul notifikasi foreground service.
  ///
  /// In id, this message translates to:
  /// **'{count, plural, =1{1 sesi tersambung} other{{count} sesi tersambung}}'**
  String keepAliveNotifTitle(int count);

  /// Aksi di notifikasi: menutup semua sesi.
  ///
  /// In id, this message translates to:
  /// **'Putuskan semua'**
  String get keepAliveDisconnectAll;

  /// Nama saluran notifikasi foreground service.
  ///
  /// In id, this message translates to:
  /// **'Sesi aktif'**
  String get keepAliveChannelName;

  /// Judul bagian pengaturan koneksi.
  ///
  /// In id, this message translates to:
  /// **'Koneksi'**
  String get settingsConnectionSection;

  /// Label saklar sambung ulang otomatis.
  ///
  /// In id, this message translates to:
  /// **'Sambung ulang otomatis'**
  String get settingsAutoReconnectLabel;

  /// Keterangan saklar sambung ulang otomatis.
  ///
  /// In id, this message translates to:
  /// **'Saat jaringan berpindah atau aplikasi kembali aktif'**
  String get settingsAutoReconnectDesc;

  /// Label saklar konfirmasi tempel satu baris.
  ///
  /// In id, this message translates to:
  /// **'Konfirmasi tempel satu baris'**
  String get settingsConfirmPasteLabel;

  /// Keterangan saklar konfirmasi tempel satu baris.
  ///
  /// In id, this message translates to:
  /// **'Teks pendek tampil di popover sebelum ditempel. Teks panjang, banyak baris, atau berisiko selalu ditanya.'**
  String get settingsConfirmPasteDesc;

  /// Label saklar foreground service.
  ///
  /// In id, this message translates to:
  /// **'Pertahankan koneksi di latar belakang'**
  String get settingsKeepAliveLabel;

  /// Keterangan saklar foreground service.
  ///
  /// In id, this message translates to:
  /// **'Sesi tetap tersambung saat aplikasi ditutup ke latar belakang. Memakai baterai lebih banyak dan menampilkan notifikasi permanen.'**
  String get settingsKeepAliveDesc;

  /// Catatan saat saklar foreground service menyala.
  ///
  /// In id, this message translates to:
  /// **'Membantu sambungan bertahan, tetapi tidak menjaminnya: perpindahan jaringan atau sinyal hilang tetap memutus sesi, lalu sambung ulang otomatis berjalan.'**
  String get settingsKeepAliveNote;

  /// Pesan saat izin notifikasi ditolak dan saklar kembali mati.
  ///
  /// In id, this message translates to:
  /// **'Izin notifikasi diperlukan untuk menjaga koneksi'**
  String get settingsKeepAliveNeedsPermission;

  /// Label baris status izin notifikasi.
  ///
  /// In id, this message translates to:
  /// **'Izin notifikasi'**
  String get settingsNotifPermissionLabel;

  /// Status izin notifikasi: diizinkan.
  ///
  /// In id, this message translates to:
  /// **'Diizinkan'**
  String get settingsNotifAllowed;

  /// Status izin notifikasi: belum diizinkan.
  ///
  /// In id, this message translates to:
  /// **'Belum diizinkan'**
  String get settingsNotifDenied;

  /// Tombol meminta izin notifikasi.
  ///
  /// In id, this message translates to:
  /// **'Izinkan'**
  String get settingsNotifAllow;

  /// Label baris pembatasan baterai.
  ///
  /// In id, this message translates to:
  /// **'Pembatasan baterai HP'**
  String get settingsBatteryLabel;

  /// Keterangan baris pembatasan baterai.
  ///
  /// In id, this message translates to:
  /// **'Beberapa HP (misalnya HyperOS) perlu diatur ke \"Tanpa batasan\" agar sesi tidak dihentikan.'**
  String get settingsBatteryDesc;

  /// Tombol membuka pengaturan aplikasi Android.
  ///
  /// In id, this message translates to:
  /// **'Buka pengaturan'**
  String get settingsBatteryOpen;

  /// Tombol tempel di baris tombol cepat.
  ///
  /// In id, this message translates to:
  /// **'Tempel'**
  String get keyPaste;

  /// Nama aksesibilitas tombol tempel.
  ///
  /// In id, this message translates to:
  /// **'Tempel dari papan klip'**
  String get keyPasteAria;

  /// Keterangan di popover Tempel untuk satu baris pendek.
  ///
  /// In id, this message translates to:
  /// **'Masuk ke prompt, belum dijalankan'**
  String get pasteMenuHint;

  /// Toast bila papan klip kosong.
  ///
  /// In id, this message translates to:
  /// **'Papan klip kosong'**
  String get pasteEmpty;

  /// Toast bila isi papan klip terlalu besar.
  ///
  /// In id, this message translates to:
  /// **'Teks terlalu besar untuk ditempel (maksimal 100.000 karakter)'**
  String get pasteTooLarge;

  /// Judul dialog tempel.
  ///
  /// In id, this message translates to:
  /// **'Tempel {count} baris?'**
  String pasteTitle(int count);

  /// Tombol konfirmasi di dialog tempel.
  ///
  /// In id, this message translates to:
  /// **'Tempel'**
  String get pasteConfirm;

  /// Toast setelah tempel; teks belum dijalankan.
  ///
  /// In id, this message translates to:
  /// **'Ditempel · {count} baris · belum dijalankan'**
  String pasteDone(int count);

  /// Toast setelah tempel di server tanpa tempel aman.
  ///
  /// In id, this message translates to:
  /// **'Ditempel · {count} baris'**
  String pasteDoneRunning(int count);

  /// Peringatan di dialog tempel.
  ///
  /// In id, this message translates to:
  /// **'{count} baris berisiko (mis. rm -rf). Periksa sebelum menekan Enter.'**
  String pasteRiskNote(int count);

  /// Peringatan bila mode bracketed paste mati.
  ///
  /// In id, this message translates to:
  /// **'Server ini belum mendukung tempel aman: setiap baris langsung dijalankan begitu ditempel.'**
  String get pasteUnsafeNote;

  /// Tanda pada baris berisiko di dialog tempel.
  ///
  /// In id, this message translates to:
  /// **'berisiko'**
  String get pasteRiskTag;

  /// Catatan di dialog tempel aman.
  ///
  /// In id, this message translates to:
  /// **'Teks masuk ke prompt tanpa menekan Enter, jadi belum dijalankan.'**
  String get pasteSafeNote;

  /// Peringatan bila karakter kontrol dibuang.
  ///
  /// In id, this message translates to:
  /// **'{count} karakter kontrol dihapus dari teks yang ditempel.'**
  String pasteControlRemoved(int count);

  /// Ringkasan baris yang tidak ditampilkan di dialog tempel.
  ///
  /// In id, this message translates to:
  /// **'… dan {count} baris lagi'**
  String pasteMoreLines(int count);

  /// Jumlah karakter terpilih di bilah seleksi terminal.
  ///
  /// In id, this message translates to:
  /// **'{count} karakter dipilih'**
  String selectionCount(int count);

  /// Petunjuk di bilah seleksi terminal.
  ///
  /// In id, this message translates to:
  /// **'Seret gagang untuk mengubah pilihan'**
  String get selectionHint;

  /// Tombol salin di bilah seleksi.
  ///
  /// In id, this message translates to:
  /// **'Salin'**
  String get selectionCopy;

  /// Nama aksesibilitas tombol salin.
  ///
  /// In id, this message translates to:
  /// **'Salin teks terpilih'**
  String get selectionCopyAria;

  /// Tombol pilih semua di bilah seleksi.
  ///
  /// In id, this message translates to:
  /// **'Semua'**
  String get selectionAll;

  /// Nama aksesibilitas tombol pilih semua.
  ///
  /// In id, this message translates to:
  /// **'Pilih semua teks di terminal'**
  String get selectionAllAria;

  /// Toast setelah menyalin teks terpilih.
  ///
  /// In id, this message translates to:
  /// **'Disalin · {count} karakter'**
  String selectionCopied(int count);

  /// Nama aksesibilitas gagang awal seleksi.
  ///
  /// In id, this message translates to:
  /// **'Gagang awal pilihan'**
  String get selectionHandleStart;

  /// Nama aksesibilitas gagang akhir seleksi.
  ///
  /// In id, this message translates to:
  /// **'Gagang akhir pilihan'**
  String get selectionHandleEnd;

  /// Label pilihan bentuk gagang seleksi teks di terminal.
  ///
  /// In id, this message translates to:
  /// **'Bentuk gagang seleksi'**
  String get settingsHandleStyle;

  /// Bentuk gagang: tetesan air.
  ///
  /// In id, this message translates to:
  /// **'Tetesan'**
  String get settingsHandleDrop;

  /// Bentuk gagang: bulatan dengan segitiga di atasnya.
  ///
  /// In id, this message translates to:
  /// **'Segitiga'**
  String get settingsHandleTriangle;

  /// Bentuk gagang: bulatan polos.
  ///
  /// In id, this message translates to:
  /// **'Bulatan'**
  String get settingsHandleDot;

  /// Penjelasan di dialog keluar dari terminal dengan pilihan tetap terhubung.
  ///
  /// In id, this message translates to:
  /// **'Tetap terhubung membiarkan sesi berjalan di latar belakang; buka lagi dari tab Sesi. Putuskan menutup shell di server dan menghentikan program yang sedang berjalan.'**
  String get terminalLeaveChoiceBody;

  /// Tombol keluar dari terminal tanpa memutus sesi.
  ///
  /// In id, this message translates to:
  /// **'Tetap terhubung di latar belakang'**
  String get terminalLeaveKeep;

  /// Catatan di dialog keluar bila foreground service mati.
  ///
  /// In id, this message translates to:
  /// **'Pengaturan \"Pertahankan koneksi di latar belakang\" mati, jadi Android bisa memutus sambungan saat aplikasi tidak terlihat.'**
  String get terminalLeaveKeepAliveOff;

  /// Tombol di catatan dialog keluar untuk membuka Pengaturan.
  ///
  /// In id, this message translates to:
  /// **'Buka Pengaturan'**
  String get terminalLeaveOpenSettings;

  /// Judul layar daftar sesi yang masih hidup di latar belakang.
  ///
  /// In id, this message translates to:
  /// **'Sesi aktif'**
  String get sessionsTitle;

  /// Nama aksesibilitas tab Sesi di bar navigasi bila ada sesi di latar belakang.
  ///
  /// In id, this message translates to:
  /// **'Sesi aktif, {count}'**
  String hostsOpenSessions(int count);

  /// Judul keadaan kosong daftar sesi aktif.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada sesi di latar belakang'**
  String get sessionsEmptyTitle;

  /// Isi keadaan kosong daftar sesi aktif.
  ///
  /// In id, this message translates to:
  /// **'Tekan kembali di terminal atau SFTP lalu pilih \"Tetap terhubung di latar belakang\" untuk membiarkan sesi berjalan dan melanjutkannya dari sini.'**
  String get sessionsEmptyBody;

  /// Petunjuk di atas daftar sesi aktif.
  ///
  /// In id, this message translates to:
  /// **'Ketuk sesi untuk melanjutkannya.'**
  String get sessionsHint;

  /// Nomor sesi untuk membedakan beberapa sesi ke host yang sama.
  ///
  /// In id, this message translates to:
  /// **'sesi {n}'**
  String sessionsNumber(int n);

  /// Jam sesi dimulai.
  ///
  /// In id, this message translates to:
  /// **'mulai {time}'**
  String sessionsStarted(String time);

  /// Status sesi yang sedang menyambung pertama kali.
  ///
  /// In id, this message translates to:
  /// **'menyambung'**
  String get sessionsStatusConnecting;

  /// Status sesi yang butuh keputusan pengguna.
  ///
  /// In id, this message translates to:
  /// **'perlu tindakan'**
  String get sessionsStatusAttention;

  /// Nama aksesibilitas baris sesi.
  ///
  /// In id, this message translates to:
  /// **'{name}, {status}. Ketuk untuk melanjutkan.'**
  String sessionsOpenLabel(String name, String status);

  /// Nama aksesibilitas tombol putuskan di baris sesi.
  ///
  /// In id, this message translates to:
  /// **'Putuskan {name}'**
  String sessionsDisconnectLabel(String name);

  /// Judul konfirmasi memutus satu sesi di latar belakang.
  ///
  /// In id, this message translates to:
  /// **'Putuskan sesi?'**
  String get sessionsDisconnectTitle;

  /// Isi konfirmasi memutus satu sesi.
  ///
  /// In id, this message translates to:
  /// **'Shell di {name} ikut berakhir dan program yang sedang berjalan berhenti.'**
  String sessionsDisconnectBody(String name);

  /// Tombol memutus semua sesi di latar belakang.
  ///
  /// In id, this message translates to:
  /// **'Putuskan semua'**
  String get sessionsDisconnectAll;

  /// Judul konfirmasi memutus semua sesi.
  ///
  /// In id, this message translates to:
  /// **'Putuskan {count} sesi?'**
  String sessionsDisconnectAllTitle(int count);

  /// Isi konfirmasi memutus semua sesi.
  ///
  /// In id, this message translates to:
  /// **'Semua shell di server ikut berakhir dan program yang sedang berjalan berhenti.'**
  String get sessionsDisconnectAllBody;

  /// Judul dialog keluar dari terminal dengan pilihan tetap terhubung.
  ///
  /// In id, this message translates to:
  /// **'Keluar dari terminal?'**
  String get terminalLeaveChoiceTitle;

  /// Pengantar layar pilih host SFTP.
  ///
  /// In id, this message translates to:
  /// **'Pilih host untuk menjelajah berkasnya. Koneksi SFTP dibuka sendiri, atau pakai sesi terminal yang sedang terhubung.'**
  String get sftpIntro;

  /// Judul bagian sesi di layar pilih host SFTP.
  ///
  /// In id, this message translates to:
  /// **'Sesi terbuka'**
  String get sftpSessionsHeading;

  /// Judul bagian host di layar pilih host SFTP.
  ///
  /// In id, this message translates to:
  /// **'Koneksi sendiri'**
  String get sftpHostsHeading;

  /// Keterangan baris sesi: SFTP memakai sambungan sesi itu.
  ///
  /// In id, this message translates to:
  /// **'Pakai sesi terbuka'**
  String get sftpUseSession;

  /// Keadaan kosong layar pilih host SFTP.
  ///
  /// In id, this message translates to:
  /// **'Belum ada host. Tambahkan dulu di tab Host.'**
  String get sftpNoHosts;

  /// Subjudul layar SFTP bila tersambung.
  ///
  /// In id, this message translates to:
  /// **'{name} · terhubung'**
  String sftpConnectedTo(String name);

  /// Nama baris naik satu level.
  ///
  /// In id, this message translates to:
  /// **'..'**
  String get sftpUpTitle;

  /// Keterangan baris naik satu level.
  ///
  /// In id, this message translates to:
  /// **'Naik satu level'**
  String get sftpUpMeta;

  /// Keterangan baris folder.
  ///
  /// In id, this message translates to:
  /// **'Folder'**
  String get sftpFolderMeta;

  /// Keadaan kosong daftar berkas.
  ///
  /// In id, this message translates to:
  /// **'Folder ini kosong'**
  String get sftpEmptyFolder;

  /// Status memuat folder.
  ///
  /// In id, this message translates to:
  /// **'Memuat…'**
  String get sftpLoading;

  /// Bar aksi berkas yang dipilih.
  ///
  /// In id, this message translates to:
  /// **'{name} dipilih'**
  String sftpSelected(String name);

  /// Tombol menyalin path berkas.
  ///
  /// In id, this message translates to:
  /// **'Salin path'**
  String get sftpCopyPath;

  /// Toast setelah path disalin.
  ///
  /// In id, this message translates to:
  /// **'Path disalin'**
  String get sftpPathCopied;

  /// Nama aksi muat ulang folder.
  ///
  /// In id, this message translates to:
  /// **'Muat ulang'**
  String get sftpRefresh;

  /// Galat SFTP: tidak ada.
  ///
  /// In id, this message translates to:
  /// **'Folder atau berkas tidak ditemukan.'**
  String get sftpErrNotFound;

  /// Galat SFTP: izin ditolak.
  ///
  /// In id, this message translates to:
  /// **'Izin ditolak untuk folder ini.'**
  String get sftpErrDenied;

  /// Galat SFTP: sambungan putus.
  ///
  /// In id, this message translates to:
  /// **'Sambungan terputus.'**
  String get sftpErrLost;

  /// Galat SFTP lainnya.
  ///
  /// In id, this message translates to:
  /// **'Operasi SFTP gagal.'**
  String get sftpErrOther;

  /// Judul banner sambungan SFTP putus.
  ///
  /// In id, this message translates to:
  /// **'Sambungan SFTP terputus'**
  String get sftpLostTitle;

  /// Keterangan bila sesi yang dipinjam putus.
  ///
  /// In id, this message translates to:
  /// **'Sesi terminalnya terputus. SFTP tersambung lagi begitu sesinya tersambung ulang.'**
  String get sftpLostBorrowedBody;

  /// Keterangan bila koneksi SFTP sendiri putus.
  ///
  /// In id, this message translates to:
  /// **'Android bisa menutup sambungan di latar belakang. Sambung ulang untuk melanjutkan.'**
  String get sftpLostOwnBody;

  /// Tombol menyambung ulang SFTP.
  ///
  /// In id, this message translates to:
  /// **'Sambung ulang'**
  String get sftpReconnect;

  /// Judul bila subsistem SFTP gagal dibuka.
  ///
  /// In id, this message translates to:
  /// **'SFTP tidak tersedia di server ini'**
  String get sftpUnavailableTitle;

  /// Keterangan bila subsistem SFTP gagal dibuka.
  ///
  /// In id, this message translates to:
  /// **'Server tidak mengaktifkan subsistem SFTP, atau menolaknya untuk akun ini.'**
  String get sftpUnavailableBody;

  /// Waktu ubah berkas dalam menit.
  ///
  /// In id, this message translates to:
  /// **'{count} menit lalu'**
  String sftpAgoMinutes(int count);

  /// Waktu ubah berkas dalam jam.
  ///
  /// In id, this message translates to:
  /// **'{count} jam lalu'**
  String sftpAgoHours(int count);

  /// Waktu ubah berkas: kemarin.
  ///
  /// In id, this message translates to:
  /// **'kemarin'**
  String get sftpYesterday;

  /// Waktu ubah berkas: kurang dari semenit.
  ///
  /// In id, this message translates to:
  /// **'baru saja'**
  String get sftpJustNow;

  /// Judul konfirmasi keluar dari layar SFTP.
  ///
  /// In id, this message translates to:
  /// **'Keluar dari SFTP?'**
  String get sftpLeaveTitle;

  /// Isi konfirmasi keluar (koneksi sendiri).
  ///
  /// In id, this message translates to:
  /// **'Koneksi SFTP ke {name} akan ditutup. Sesi terminal tidak terpengaruh.'**
  String sftpLeaveBodyOwn(String name);

  /// Isi konfirmasi keluar (sesi dipinjam).
  ///
  /// In id, this message translates to:
  /// **'Hanya layar SFTP yang ditutup. Sesi terminal {name} tetap berjalan.'**
  String sftpLeaveBodyBorrowed(String name);

  /// Tombol konfirmasi keluar dari SFTP.
  ///
  /// In id, this message translates to:
  /// **'Keluar'**
  String get sftpLeaveConfirm;

  /// Judul konfirmasi keluar bila ada transfer.
  ///
  /// In id, this message translates to:
  /// **'Transfer masih berjalan'**
  String get sftpLeaveBusyTitle;

  /// Isi konfirmasi keluar bila ada transfer.
  ///
  /// In id, this message translates to:
  /// **'{count} transfer belum selesai. Bila keluar, semuanya dibatalkan.'**
  String sftpLeaveBusyBody(int count);

  /// Catatan akibat membatalkan unggahan.
  ///
  /// In id, this message translates to:
  /// **'Berkas unggahan yang belum lengkap dihapus dari server.'**
  String get sftpLeaveBusyUploadNote;

  /// Catatan akibat membatalkan unduhan.
  ///
  /// In id, this message translates to:
  /// **'Berkas unduhan yang belum lengkap dihapus dari perangkat.'**
  String get sftpLeaveBusyDownloadNote;

  /// Tombol konfirmasi keluar bila ada transfer.
  ///
  /// In id, this message translates to:
  /// **'Batalkan transfer dan keluar'**
  String get sftpLeaveBusyConfirm;

  /// Baris transfer unggahan di konfirmasi keluar.
  ///
  /// In id, this message translates to:
  /// **'Unggah {name}'**
  String sftpTransferUpload(String name);

  /// Baris transfer unduhan di konfirmasi keluar.
  ///
  /// In id, this message translates to:
  /// **'Unduh {name}'**
  String sftpTransferDownload(String name);

  /// Persen kemajuan transfer.
  ///
  /// In id, this message translates to:
  /// **'{percent}%'**
  String sftpTransferPercent(int percent);

  /// Subjudul layar SFTP bila sambungan putus.
  ///
  /// In id, this message translates to:
  /// **'{name} · terputus'**
  String sftpDisconnectedFrom(String name);

  /// Isi banner saat SFTP menyambung ulang.
  ///
  /// In id, this message translates to:
  /// **'Folder yang dibuka tetap terlihat.'**
  String get sftpReconnectingBody;

  /// Nama tombol unggah di header SFTP.
  ///
  /// In id, this message translates to:
  /// **'Unggah berkas'**
  String get sftpUploadAction;

  /// Tombol unduh di bar berkas terpilih.
  ///
  /// In id, this message translates to:
  /// **'Unduh'**
  String get sftpDownloadAction;

  /// Toast setelah berkas diunduh.
  ///
  /// In id, this message translates to:
  /// **'Diunduh ke {location} · {name}'**
  String sftpDownloaded(String location, String name);

  /// Toast setelah berkas diunggah.
  ///
  /// In id, this message translates to:
  /// **'Diunggah · {name}'**
  String sftpUploaded(String name);

  /// Toast bila transfer dibatalkan.
  ///
  /// In id, this message translates to:
  /// **'Dibatalkan · {name}'**
  String sftpTransferCancelledToast(String name);

  /// Toast bila unduhan gagal.
  ///
  /// In id, this message translates to:
  /// **'Unduhan gagal · {reason}'**
  String sftpDownloadFailed(String reason);

  /// Toast bila unggahan gagal.
  ///
  /// In id, this message translates to:
  /// **'Unggahan gagal · {reason}'**
  String sftpUploadFailed(String reason);

  /// Toast bila penyimpanan ke Unduhan gagal.
  ///
  /// In id, this message translates to:
  /// **'Berkas diterima, tetapi tidak bisa disimpan ke Unduhan'**
  String get sftpSaveFailed;

  /// Nama tombol membatalkan satu transfer.
  ///
  /// In id, this message translates to:
  /// **'Batalkan transfer'**
  String get sftpTransferCancel;

  /// Judul pilihan saat nama berkas sudah dipakai.
  ///
  /// In id, this message translates to:
  /// **'{name} sudah ada'**
  String sftpConflictTitle(String name);

  /// Isi pilihan konflik nama (unggah).
  ///
  /// In id, this message translates to:
  /// **'Di {dir} di server. Pilih cara menyimpannya.'**
  String sftpConflictBodyUpload(String dir);

  /// Isi pilihan konflik nama (unduh).
  ///
  /// In id, this message translates to:
  /// **'Di Unduhan/TermUL. Pilih cara menyimpannya.'**
  String get sftpConflictBodyDownload;

  /// Tombol utama: simpan dengan nama bernomor.
  ///
  /// In id, this message translates to:
  /// **'Simpan sebagai {name}'**
  String sftpConflictRename(String name);

  /// Tombol berisiko: ganti isi berkas lama.
  ///
  /// In id, this message translates to:
  /// **'Timpa berkas lama'**
  String get sftpConflictOverwrite;

  /// Catatan akibat menimpa.
  ///
  /// In id, this message translates to:
  /// **'Menimpa mengganti isi berkas lama dan tidak bisa dibatalkan.'**
  String get sftpConflictOverwriteNote;

  /// Toast setelah unduhan menimpa berkas lama.
  ///
  /// In id, this message translates to:
  /// **'Ditimpa di {location} · {name}'**
  String sftpDownloadedOverwritten(String location, String name);

  /// Tombol memilih semua entri di folder.
  ///
  /// In id, this message translates to:
  /// **'Pilih semua'**
  String get sftpSelectAll;

  /// Tombol melepas semua pilihan dan keluar dari mode seleksi.
  ///
  /// In id, this message translates to:
  /// **'Batal pilih'**
  String get sftpSelectionCancel;

  /// Jumlah entri dipilih (berkas dan folder).
  ///
  /// In id, this message translates to:
  /// **'{count} dipilih'**
  String sftpSelectedCount(int count);

  /// Toast setelah beberapa path disalin.
  ///
  /// In id, this message translates to:
  /// **'{count} path disalin'**
  String sftpPathsCopied(int count);

  /// Judul pilihan saat beberapa nama berkas atau folder sudah dipakai di Unduhan/TermUL.
  ///
  /// In id, this message translates to:
  /// **'{count} item sudah ada'**
  String sftpConflictManyTitle(int count);

  /// Tombol utama: semua yang bentrok disimpan dengan nama bernomor.
  ///
  /// In id, this message translates to:
  /// **'Simpan dengan nama bernomor'**
  String get sftpConflictRenameAll;

  /// Tombol berisiko: semua berkas lama yang bentrok diganti isinya.
  ///
  /// In id, this message translates to:
  /// **'Timpa semuanya'**
  String get sftpConflictOverwriteAll;

  /// Toast setelah beberapa berkas diunduh.
  ///
  /// In id, this message translates to:
  /// **'{count} berkas diunduh ke {location}'**
  String sftpDownloadedMany(int count, String location);

  /// Toast bila sebagian unduhan gagal.
  ///
  /// In id, this message translates to:
  /// **'{done} berkas diunduh, {failed} gagal'**
  String sftpDownloadedManyPartial(int done, int failed);

  /// Toast unduhan folder bila ada tautan rusak atau tidak terbaca yang dilewati.
  ///
  /// In id, this message translates to:
  /// **'{count} berkas diunduh ke {location} · {skipped} dilewati'**
  String sftpDownloadedManySkipped(int count, String location, int skipped);

  /// Toast bila folder yang diunduh tidak punya berkas.
  ///
  /// In id, this message translates to:
  /// **'{name} tidak berisi berkas'**
  String sftpFolderNoFiles(String name);

  /// Toast setelah daftar folder berhasil dimuat ulang (tombol atau tarik ke bawah).
  ///
  /// In id, this message translates to:
  /// **'Daftar file diperbarui'**
  String get sftpRefreshed;

  /// Penanda di baris berkas atau folder yang berupa tautan simbolik (symlink).
  ///
  /// In id, this message translates to:
  /// **'Tautan'**
  String get sftpLinkTag;

  /// Tombol folder di header terminal: membuka SFTP lewat sambungan sesi yang sama.
  ///
  /// In id, this message translates to:
  /// **'Buka panel SFTP'**
  String get terminalOpenSftp;

  /// Isi sheet keluar SFTP mandiri.
  ///
  /// In id, this message translates to:
  /// **'Tetap terhubung membiarkan koneksi SFTP ke {name} di latar belakang; buka lagi dari tab Sesi. Putuskan menutup koneksinya.'**
  String sftpLeaveChoiceBody(String name);

  /// Tombol utama sheet keluar SFTP mandiri.
  ///
  /// In id, this message translates to:
  /// **'Tetap terhubung di latar belakang'**
  String get sftpLeaveKeep;

  /// Tombol menutup koneksi SFTP mandiri saat keluar.
  ///
  /// In id, this message translates to:
  /// **'Putuskan'**
  String get sftpLeaveDisconnect;

  /// Catatan sheet keluar SFTP mandiri saat ada transfer.
  ///
  /// In id, this message translates to:
  /// **'Transfer tetap berjalan bila Anda memilih Tetap terhubung. Memutuskan membatalkan semuanya.'**
  String get sftpLeaveBusyKeepNote;

  /// Tanda jenis sesi SFTP di daftar Sesi.
  ///
  /// In id, this message translates to:
  /// **'SFTP'**
  String get sessionsSftpTag;

  /// Aksi di menu tekan lama host: membuka sesi SFTP mandiri.
  ///
  /// In id, this message translates to:
  /// **'Sambung SFTP'**
  String get actionConnectSftp;

  /// Chip di header daftar host saat vault terkunci.
  ///
  /// In id, this message translates to:
  /// **'Vault terkunci'**
  String get vaultChipLocked;

  /// Chip di header daftar host saat vault terbuka.
  ///
  /// In id, this message translates to:
  /// **'Vault terbuka'**
  String get vaultChipOpen;

  /// Label pembaca layar chip saat terkunci.
  ///
  /// In id, this message translates to:
  /// **'Vault terkunci. Ketuk untuk membuka dengan biometrik.'**
  String get vaultChipLockedHint;

  /// Label pembaca layar chip saat terbuka sementara.
  ///
  /// In id, this message translates to:
  /// **'Vault terbuka. Ketuk untuk mengunci.'**
  String get vaultChipOpenHint;

  /// Label pembaca layar chip saat selalu terbuka.
  ///
  /// In id, this message translates to:
  /// **'Vault terbuka permanen. Ketuk untuk keterangan.'**
  String get vaultChipAlwaysOpenHint;

  /// Alasan yang tampil di prompt autentikasi saat membuka vault.
  ///
  /// In id, this message translates to:
  /// **'Buka vault supaya host tersambung tanpa prompt'**
  String get vaultUnlockReason;

  /// Toast setelah vault dibuka sementara.
  ///
  /// In id, this message translates to:
  /// **'Vault terbuka sampai layar mati'**
  String get vaultUnlockedToast;

  /// Toast setelah vault dikunci.
  ///
  /// In id, this message translates to:
  /// **'Vault terkunci'**
  String get vaultLockedToast;

  /// Toast bila autentikasi dibatalkan atau gagal.
  ///
  /// In id, this message translates to:
  /// **'Vault tetap terkunci'**
  String get vaultUnlockFailedToast;

  /// Toast bila chip diketuk saat vault selalu terbuka.
  ///
  /// In id, this message translates to:
  /// **'Vault terbuka permanen. Matikan di Pengaturan, bagian Keamanan.'**
  String get vaultAlwaysOpenToast;

  /// Judul bagian pengaturan keamanan.
  ///
  /// In id, this message translates to:
  /// **'Keamanan'**
  String get settingsSecuritySection;

  /// Label saklar vault selalu terbuka.
  ///
  /// In id, this message translates to:
  /// **'Jangan kunci vault'**
  String get settingsVaultAlwaysOpenLabel;

  /// Keterangan saklar vault selalu terbuka.
  ///
  /// In id, this message translates to:
  /// **'Host tersambung tanpa biometrik atau PIN. Siapa pun yang memegang HP yang sedang terbuka bisa menyambung ke semua server Anda.'**
  String get settingsVaultAlwaysOpenDesc;

  /// Judul dialog konfirmasi vault selalu terbuka.
  ///
  /// In id, this message translates to:
  /// **'Jangan kunci vault?'**
  String get vaultAlwaysOpenConfirmTitle;

  /// Isi dialog konfirmasi vault selalu terbuka.
  ///
  /// In id, this message translates to:
  /// **'Password dan kunci privat tetap terenkripsi, tetapi aplikasi akan memakainya tanpa meminta biometrik atau PIN. Bila HP hilang saat terbuka, server Anda ikut terbuka. Anda bisa mematikannya kapan saja.'**
  String get vaultAlwaysOpenConfirmBody;

  /// Tombol konfirmasi vault selalu terbuka.
  ///
  /// In id, this message translates to:
  /// **'Jangan kunci'**
  String get vaultAlwaysOpenConfirmAction;

  /// Alasan di prompt autentikasi saat menyalakan saklar.
  ///
  /// In id, this message translates to:
  /// **'Konfirmasi untuk tidak mengunci vault'**
  String get vaultAlwaysOpenReason;

  /// Pesan bila autentikasi saat menyalakan saklar gagal.
  ///
  /// In id, this message translates to:
  /// **'Dibatalkan. Vault tetap terkunci.'**
  String get vaultAlwaysOpenAuthFailed;

  /// Tag kata di baris pengaturan berisiko (zona bahaya).
  ///
  /// In id, this message translates to:
  /// **'Berisiko'**
  String get settingsDangerTag;

  /// Label tombol impor di daftar host.
  ///
  /// In id, this message translates to:
  /// **'Impor profil'**
  String get importAction;

  /// Judul panel pratinjau impor.
  ///
  /// In id, this message translates to:
  /// **'Impor profil'**
  String get importTitle;

  /// Tombol konfirmasi impor.
  ///
  /// In id, this message translates to:
  /// **'Impor'**
  String get importConfirm;

  /// Galat saat berkas impor gagal dibaca.
  ///
  /// In id, this message translates to:
  /// **'Berkas tidak bisa dibaca.'**
  String get importReadFailed;

  /// Galat bila berkas tidak berisi profil valid.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada profil yang bisa diimpor dari berkas ini.'**
  String get importNothing;

  /// Catatan di pratinjau impor.
  ///
  /// In id, this message translates to:
  /// **'Profil yang sudah ada di HP tidak dihapus. Password dan kunci tidak ikut terimpor.'**
  String get importKeepNote;

  /// Ringkasan impor: jumlah profil baru.
  ///
  /// In id, this message translates to:
  /// **'{n} profil baru ditambahkan'**
  String importAdded(int n);

  /// Ringkasan impor: jumlah profil diganti.
  ///
  /// In id, this message translates to:
  /// **'{n} profil diperbarui'**
  String importUpdated(int n);

  /// Ringkasan impor: jumlah salinan.
  ///
  /// In id, this message translates to:
  /// **'{n} profil disimpan sebagai salinan'**
  String importCopied(int n);

  /// Ringkasan impor: jumlah profil dilewati.
  ///
  /// In id, this message translates to:
  /// **'{n} profil dilewati karena sudah ada'**
  String importSkipped(int n);

  /// Ringkasan impor: jumlah entri ditolak.
  ///
  /// In id, this message translates to:
  /// **'{n} entri tidak valid dan dilewati'**
  String importRejected(int n);

  /// Satu entri berkas yang ditolak.
  ///
  /// In id, this message translates to:
  /// **'#{index} {name}: {reason}'**
  String importRejectedItem(int index, String name, String reason);

  /// Catatan profil agen di pratinjau impor.
  ///
  /// In id, this message translates to:
  /// **'{n} profil memakai agen SSH dan perlu dilengkapi di HP sebelum bisa tersambung.'**
  String importAgentNote(int n);

  /// Label pilihan penanganan id bentrok.
  ///
  /// In id, this message translates to:
  /// **'Bila profil sudah ada di HP'**
  String get importConflictLabel;

  /// Pilihan: profil di HP dibiarkan.
  ///
  /// In id, this message translates to:
  /// **'Lewati'**
  String get importConflictSkip;

  /// Pilihan: profil di HP diganti isi berkas.
  ///
  /// In id, this message translates to:
  /// **'Perbarui'**
  String get importConflictUpdate;

  /// Pilihan: profil berkas disimpan sebagai profil baru.
  ///
  /// In id, this message translates to:
  /// **'Salinan'**
  String get importConflictCopy;

  /// Peringatan jump host hilang.
  ///
  /// In id, this message translates to:
  /// **'{name}: jump host tidak ditemukan, dikosongkan.'**
  String importWarnJump(String name);

  /// Peringatan path kunci dibuang.
  ///
  /// In id, this message translates to:
  /// **'{name}: path kunci dari perangkat asal dibuang, impor kunci lagi di HP.'**
  String importWarnKeyPath(String name);

  /// Toast setelah impor berhasil.
  ///
  /// In id, this message translates to:
  /// **'Diimpor · {n} profil'**
  String importDone(int n);

  /// Toast bila impor tidak mengubah apa pun.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada perubahan'**
  String get importNoChange;

  /// Galat bila penulisan hasil impor gagal.
  ///
  /// In id, this message translates to:
  /// **'Impor gagal. Daftar host tidak berubah.'**
  String get importFailed;

  /// Nama bintang penanda host favorit di baris daftar (untuk pembaca layar).
  ///
  /// In id, this message translates to:
  /// **'Favorit'**
  String get hostFavoriteLabel;

  /// Label tombol ekspor di daftar host.
  ///
  /// In id, this message translates to:
  /// **'Ekspor profil'**
  String get exportAction;

  /// Judul panel konfirmasi ekspor.
  ///
  /// In id, this message translates to:
  /// **'Ekspor profil'**
  String get exportTitle;

  /// Tombol konfirmasi ekspor.
  ///
  /// In id, this message translates to:
  /// **'Bagikan'**
  String get exportConfirm;

  /// Ringkasan ekspor: jumlah profil.
  ///
  /// In id, this message translates to:
  /// **'{n} profil akan diekspor'**
  String exportCount(int n);

  /// Catatan di panel ekspor.
  ///
  /// In id, this message translates to:
  /// **'Berkas JSON ini bisa diimpor lagi di HP atau dimuat TermUL desktop. Menu bagikan Android akan terbuka: kirim ke aplikasi lain atau simpan ke penyimpanan. Password, passphrase, dan kunci tidak ikut.'**
  String get exportNote;

  /// Catatan profil KEY yang diubah di ekspor.
  ///
  /// In id, this message translates to:
  /// **'{n} profil memakai kunci yang tersimpan di HP. Di berkas ekspor metodenya menjadi agen SSH supaya desktop tetap bisa memuat berkas ini; lengkapi kuncinya di desktop.'**
  String exportKeyConverted(int n);

  /// Galat bila daftar host kosong.
  ///
  /// In id, this message translates to:
  /// **'Belum ada profil untuk diekspor.'**
  String get exportNothing;

  /// Galat bila berkas ekspor tidak bisa disimpan.
  ///
  /// In id, this message translates to:
  /// **'Ekspor gagal. Menu bagikan tidak bisa dibuka; coba lagi.'**
  String get exportFailed;

  /// Tombol tambah di layar Snippet.
  ///
  /// In id, this message translates to:
  /// **'Snippet baru'**
  String get snippetsAdd;

  /// Label kolom pencarian snippet (disembunyikan, dibaca pembaca layar).
  ///
  /// In id, this message translates to:
  /// **'Cari snippet'**
  String get snippetsSearchLabel;

  /// Placeholder kolom pencarian snippet.
  ///
  /// In id, this message translates to:
  /// **'Cari judul atau perintah'**
  String get snippetsSearchPlaceholder;

  /// Daftar snippet kosong karena pencarian atau filter.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada snippet yang cocok. Ubah kata kunci atau filter.'**
  String get snippetsNoMatch;

  /// Judul keadaan kosong layar Snippet.
  ///
  /// In id, this message translates to:
  /// **'Belum ada snippet'**
  String get snippetsEmptyTitle;

  /// Keterangan keadaan kosong layar Snippet.
  ///
  /// In id, this message translates to:
  /// **'Simpan perintah yang sering dipakai di sini, lengkap dengan variabel yang diisi saat dipakai.'**
  String get snippetsEmptyBody;

  /// Judul banner berkas snippet rusak.
  ///
  /// In id, this message translates to:
  /// **'Daftar snippet rusak'**
  String get snippetsCorruptTitle;

  /// Isi banner berkas snippet rusak.
  ///
  /// In id, this message translates to:
  /// **'Berkas snippet tidak bisa dibaca dan disimpan sebagai {name}. Aplikasi mulai dari daftar kosong; berkas lama tidak dihapus.'**
  String snippetsCorruptBody(String name);

  /// Cakupan snippet: berlaku untuk semua host.
  ///
  /// In id, this message translates to:
  /// **'Semua host'**
  String get snippetScopeAll;

  /// Tag jumlah variabel di kartu snippet.
  ///
  /// In id, this message translates to:
  /// **'{count} variabel'**
  String snippetVarCount(int count);

  /// Label semantik bintang favorit di kartu snippet.
  ///
  /// In id, this message translates to:
  /// **'Favorit'**
  String get snippetFavoriteLabel;

  /// Placeholder isian nilai variabel snippet.
  ///
  /// In id, this message translates to:
  /// **'Isi nilai'**
  String get snippetDetailVariable;

  /// Peringatan di detail snippet berisiko.
  ///
  /// In id, this message translates to:
  /// **'Perintah berbahaya. Periksa dulu sebelum dipakai: tempel, periksa, lalu tekan Enter sendiri.'**
  String get snippetDetailRisky;

  /// Keterangan saat variabel belum lengkap.
  ///
  /// In id, this message translates to:
  /// **'Isi semua variabel untuk menempel atau menyalin.'**
  String get snippetDetailNotReady;

  /// Tombol salin perintah snippet ke papan klip.
  ///
  /// In id, this message translates to:
  /// **'Salin'**
  String get snippetDetailCopy;

  /// Tombol buka editor di detail snippet.
  ///
  /// In id, this message translates to:
  /// **'Edit'**
  String get snippetDetailEdit;

  /// Konfirmasi salin snippet.
  ///
  /// In id, this message translates to:
  /// **'Disalin · {count} karakter'**
  String snippetCopied(int count);

  /// Judul editor snippet baru.
  ///
  /// In id, this message translates to:
  /// **'Snippet baru'**
  String get snippetEditorNewTitle;

  /// Judul editor snippet yang sudah ada.
  ///
  /// In id, this message translates to:
  /// **'Edit snippet'**
  String get snippetEditorEditTitle;

  /// Label isian judul snippet.
  ///
  /// In id, this message translates to:
  /// **'Judul'**
  String get snippetFieldTitle;

  /// Placeholder judul snippet.
  ///
  /// In id, this message translates to:
  /// **'Mis. Cek config lalu reload Nginx'**
  String get snippetFieldTitlePlaceholder;

  /// Label isian perintah snippet.
  ///
  /// In id, this message translates to:
  /// **'Perintah (boleh beberapa baris; variabel ditulis {example})'**
  String snippetFieldCommand(String example);

  /// Label pilihan kategori snippet.
  ///
  /// In id, this message translates to:
  /// **'Kategori'**
  String get snippetFieldCategory;

  /// Label pilihan cakupan snippet.
  ///
  /// In id, this message translates to:
  /// **'Berlaku untuk'**
  String get snippetFieldScope;

  /// Pil cakupan: pilih satu host.
  ///
  /// In id, this message translates to:
  /// **'Satu host'**
  String get snippetScopeOneHost;

  /// Judul daftar pilihan host untuk cakupan snippet.
  ///
  /// In id, this message translates to:
  /// **'Pilih host'**
  String get snippetScopePickTitle;

  /// Label saklar favorit di editor snippet.
  ///
  /// In id, this message translates to:
  /// **'Tandai favorit'**
  String get snippetFavoriteToggle;

  /// Konfirmasi simpan snippet.
  ///
  /// In id, this message translates to:
  /// **'Snippet disimpan'**
  String get snippetSaved;

  /// Galat saat menyimpan snippet.
  ///
  /// In id, this message translates to:
  /// **'Snippet tidak bisa disimpan. Coba lagi.'**
  String get snippetSaveFailed;

  /// Judul konfirmasi hapus snippet.
  ///
  /// In id, this message translates to:
  /// **'Hapus {title}?'**
  String snippetDeleteTitle(String title);

  /// Isi konfirmasi hapus snippet.
  ///
  /// In id, this message translates to:
  /// **'Snippet ini dihapus permanen dari perangkat.'**
  String get snippetDeleteBody;

  /// Konfirmasi hapus snippet.
  ///
  /// In id, this message translates to:
  /// **'Snippet dihapus'**
  String get snippetDeleted;

  /// Galat saat menghapus snippet.
  ///
  /// In id, this message translates to:
  /// **'Snippet tidak bisa dihapus. Coba lagi.'**
  String get snippetDeleteFailed;

  /// Pilihan kategori snippet: tidak ada kategori.
  ///
  /// In id, this message translates to:
  /// **'Tanpa kategori'**
  String get snippetCategoryNone;

  /// Tombol di header layar Snippet untuk membuka pengelola kategori.
  ///
  /// In id, this message translates to:
  /// **'Kelola kategori'**
  String get snippetsManageCategories;

  /// Judul sheet pengelola kategori snippet.
  ///
  /// In id, this message translates to:
  /// **'Kelola kategori'**
  String get categoryManagerTitle;

  /// Keadaan kosong pengelola kategori.
  ///
  /// In id, this message translates to:
  /// **'Belum ada kategori. Tambahkan satu untuk mengelompokkan snippet.'**
  String get categoryManagerEmpty;

  /// Jumlah snippet di bawah nama kategori.
  ///
  /// In id, this message translates to:
  /// **'{count} snippet'**
  String categoryCount(int count);

  /// Tombol tambah kategori.
  ///
  /// In id, this message translates to:
  /// **'Kategori baru'**
  String get categoryAdd;

  /// Nama aksesibilitas tombol ubah nama kategori.
  ///
  /// In id, this message translates to:
  /// **'Ubah {name}'**
  String categoryEditLabel(String name);

  /// Nama aksesibilitas tombol hapus kategori.
  ///
  /// In id, this message translates to:
  /// **'Hapus {name}'**
  String categoryDeleteLabel(String name);

  /// Label isian nama kategori.
  ///
  /// In id, this message translates to:
  /// **'Nama kategori'**
  String get categoryNameLabel;

  /// Judul sheet tambah kategori.
  ///
  /// In id, this message translates to:
  /// **'Kategori baru'**
  String get categoryNewTitle;

  /// Judul sheet ubah nama kategori.
  ///
  /// In id, this message translates to:
  /// **'Ubah kategori'**
  String get categoryRenameTitle;

  /// Galat isian nama kategori yang kembar.
  ///
  /// In id, this message translates to:
  /// **'Nama kategori sudah dipakai.'**
  String get categoryNameTaken;

  /// Galat isian nama kategori terlalu panjang.
  ///
  /// In id, this message translates to:
  /// **'Nama kategori maksimal {max} karakter.'**
  String categoryNameTooLong(int max);

  /// Judul konfirmasi hapus kategori.
  ///
  /// In id, this message translates to:
  /// **'Hapus kategori {name}?'**
  String categoryDeleteTitle(String name);

  /// Isi konfirmasi hapus kategori yang berisi snippet.
  ///
  /// In id, this message translates to:
  /// **'{count} snippet di dalamnya dipindah ke Tanpa kategori; snippet tidak ikut terhapus.'**
  String categoryDeleteBodyUsed(int count);

  /// Isi konfirmasi hapus kategori kosong.
  ///
  /// In id, this message translates to:
  /// **'Kategori ini dihapus dari perangkat.'**
  String get categoryDeleteBodyEmpty;

  /// Konfirmasi simpan kategori.
  ///
  /// In id, this message translates to:
  /// **'Kategori disimpan'**
  String get categorySaved;

  /// Konfirmasi hapus kategori.
  ///
  /// In id, this message translates to:
  /// **'Kategori dihapus'**
  String get categoryDeleted;

  /// Galat saat menyimpan kategori.
  ///
  /// In id, this message translates to:
  /// **'Kategori tidak bisa disimpan. Coba lagi.'**
  String get categorySaveFailed;

  /// Galat saat menghapus kategori.
  ///
  /// In id, this message translates to:
  /// **'Kategori tidak bisa dihapus. Coba lagi.'**
  String get categoryDeleteFailed;

  /// Petunjuk di pengelola kategori bila ada lebih dari satu kategori.
  ///
  /// In id, this message translates to:
  /// **'Tahan dan geser ikon titik di kiri untuk mengubah urutan. Urutan ini dipakai di filter dan di editor.'**
  String get categoryManagerHint;

  /// Nama aksesibilitas pegangan geser kategori.
  ///
  /// In id, this message translates to:
  /// **'Geser untuk mengurutkan {name}'**
  String categoryDragLabel(String name);

  /// Galat saat menyimpan urutan kategori.
  ///
  /// In id, this message translates to:
  /// **'Urutan kategori tidak bisa disimpan. Coba lagi.'**
  String get categoryMoveFailed;

  /// Tag kartu snippet dan penanda baris saklar untuk perintah berbahaya.
  ///
  /// In id, this message translates to:
  /// **'berbahaya'**
  String get snippetDangerousTag;

  /// Label saklar penanda berbahaya di editor snippet.
  ///
  /// In id, this message translates to:
  /// **'Tandai sebagai perintah berbahaya'**
  String get snippetDangerousToggle;

  /// Keterangan saklar penanda berbahaya.
  ///
  /// In id, this message translates to:
  /// **'Setiap kali dipakai, aplikasi memperingatkan dulu dan meminta Anda memastikan.'**
  String get snippetDangerousDesc;

  /// Keterangan saklar bila perintah terdeteksi berbahaya otomatis.
  ///
  /// In id, this message translates to:
  /// **'Perintah ini juga terdeteksi berbahaya (mis. rm -rf, dd, mkfs), jadi peringatan tetap muncul walau penanda ini mati.'**
  String get snippetDangerousDescAuto;

  /// Judul peringatan sebelum memakai snippet berbahaya.
  ///
  /// In id, this message translates to:
  /// **'Perintah berbahaya'**
  String get snippetDangerWarnTitle;

  /// Isi peringatan sebelum memakai snippet berbahaya.
  ///
  /// In id, this message translates to:
  /// **'Perintah ini bisa merusak data atau layanan di server bila salah dipakai. Periksa isinya sebelum menyalin dan menjalankannya.'**
  String get snippetDangerWarnBody;

  /// Tombol konfirmasi di peringatan snippet berbahaya.
  ///
  /// In id, this message translates to:
  /// **'Tetap salin'**
  String get snippetDangerWarnConfirm;

  /// Tombol di header Snippet untuk masuk ke mode mengurutkan.
  ///
  /// In id, this message translates to:
  /// **'Urutkan snippet'**
  String get snippetsSort;

  /// Tombol di header Snippet untuk keluar dari mode mengurutkan.
  ///
  /// In id, this message translates to:
  /// **'Selesai mengurutkan'**
  String get snippetsSortDone;

  /// Petunjuk di mode mengurutkan snippet.
  ///
  /// In id, this message translates to:
  /// **'Tahan dan geser ikon titik di kiri untuk mengubah urutan snippet. Semua snippet tampil selama mengurutkan.'**
  String get snippetsSortHint;

  /// Nama aksesibilitas pegangan geser snippet.
  ///
  /// In id, this message translates to:
  /// **'Geser untuk mengurutkan {title}'**
  String snippetsSortDragLabel(String title);

  /// Galat saat menyimpan urutan snippet.
  ///
  /// In id, this message translates to:
  /// **'Urutan snippet tidak bisa disimpan. Coba lagi.'**
  String get snippetMoveFailed;

  /// Nama aksesibilitas tombol hapus snippet di baris mode mengurutkan.
  ///
  /// In id, this message translates to:
  /// **'Hapus {title}'**
  String snippetDeleteLabel(String title);

  /// Tombol utama detail snippet: tempel ke sesi tujuan tanpa menjalankan.
  ///
  /// In id, this message translates to:
  /// **'Tempel ke {target}'**
  String snippetPasteTo(String target);

  /// Tombol detail snippet: tempel lalu tekan Enter.
  ///
  /// In id, this message translates to:
  /// **'Tempel & jalankan'**
  String get snippetPasteRun;

  /// Konfirmasi snippet ditempel ke sesi.
  ///
  /// In id, this message translates to:
  /// **'Ditempel ke {target} · belum dijalankan'**
  String snippetPasted(String target);

  /// Konfirmasi snippet dijalankan di sesi.
  ///
  /// In id, this message translates to:
  /// **'Dijalankan di {target}'**
  String snippetRan(String target);

  /// Tombol konfirmasi menempel perintah berbahaya.
  ///
  /// In id, this message translates to:
  /// **'Tetap tempel'**
  String get snippetDangerWarnPaste;

  /// Nama aksesibilitas tombol ikon Snippet di bilah tombol cepat terminal (membuka dan menutup panel snippet).
  ///
  /// In id, this message translates to:
  /// **'Snippet'**
  String get keySnippetsAria;

  /// Keadaan kosong pemilih snippet di terminal.
  ///
  /// In id, this message translates to:
  /// **'Belum ada snippet untuk host ini. Buat di tab Snippet.'**
  String get snippetPickerEmpty;

  /// Tautan di panel snippet terminal yang membuka tab Snippet.
  ///
  /// In id, this message translates to:
  /// **'Kelola semua'**
  String get snippetPanelManage;

  /// Nama aksesibilitas tab Pengaturan bila ada versi baru (lencana titik).
  ///
  /// In id, this message translates to:
  /// **'Pengaturan, pembaruan tersedia'**
  String get navSettingsUpdate;

  /// Judul bagian pembaruan aplikasi di Pengaturan.
  ///
  /// In id, this message translates to:
  /// **'Pembaruan'**
  String get settingsUpdateSection;

  /// Label baris pembaruan di Pengaturan.
  ///
  /// In id, this message translates to:
  /// **'Pembaruan aplikasi'**
  String get updateRowLabel;

  /// Status pembaruan sebelum pemeriksaan pertama.
  ///
  /// In id, this message translates to:
  /// **'Belum diperiksa'**
  String get updateStatusIdle;

  /// Status selagi memeriksa rilis di GitHub.
  ///
  /// In id, this message translates to:
  /// **'Memeriksa…'**
  String get updateStatusChecking;

  /// Status bila versi terpasang adalah yang terbaru.
  ///
  /// In id, this message translates to:
  /// **'Sudah versi terbaru'**
  String get updateStatusUpToDate;

  /// Status bila repo belum punya rilis.
  ///
  /// In id, this message translates to:
  /// **'Belum ada rilis di GitHub'**
  String get updateStatusNoRelease;

  /// Status bila ada versi baru.
  ///
  /// In id, this message translates to:
  /// **'Versi {version} tersedia'**
  String updateStatusAvailable(String version);

  /// Status selagi mengunduh APK.
  ///
  /// In id, this message translates to:
  /// **'Mengunduh versi {version}'**
  String updateStatusDownloading(String version);

  /// Status setelah APK diunduh dan cocok dengan checksum.
  ///
  /// In id, this message translates to:
  /// **'Versi {version} siap dipasang'**
  String updateStatusReady(String version);

  /// Status bila pemeriksaan rilis gagal.
  ///
  /// In id, this message translates to:
  /// **'Gagal memeriksa'**
  String get updateStatusCheckFailed;

  /// Status bila unduhan APK gagal.
  ///
  /// In id, this message translates to:
  /// **'Gagal mengunduh versi {version}'**
  String updateStatusDownloadFailed(String version);

  /// Status bila penginstal Android tidak bisa dibuka.
  ///
  /// In id, this message translates to:
  /// **'Gagal membuka penginstal'**
  String get updateStatusInstallFailed;

  /// Alasan gagal: jaringan.
  ///
  /// In id, this message translates to:
  /// **'Tidak bisa menghubungi GitHub. Periksa koneksi lalu coba lagi.'**
  String get updateFailureNetwork;

  /// Alasan gagal: jawaban server (mis. batas permintaan).
  ///
  /// In id, this message translates to:
  /// **'GitHub menolak permintaan saat ini. Coba lagi nanti.'**
  String get updateFailureServer;

  /// Alasan gagal: isi rilis tidak sesuai.
  ///
  /// In id, this message translates to:
  /// **'Rilis terbaru tidak berisi APK dan checksum yang dibutuhkan.'**
  String get updateFailureBadRelease;

  /// Alasan gagal: checksum tidak cocok.
  ///
  /// In id, this message translates to:
  /// **'Berkas yang diunduh tidak sama dengan checksum rilis, jadi tidak dipasang.'**
  String get updateFailureChecksum;

  /// Alasan gagal: penyimpanan.
  ///
  /// In id, this message translates to:
  /// **'Berkas tidak bisa disimpan. Kosongkan ruang penyimpanan lalu coba lagi.'**
  String get updateFailureStorage;

  /// Alasan gagal: penginstal.
  ///
  /// In id, this message translates to:
  /// **'Penginstal Android tidak bisa dibuka. Coba lagi.'**
  String get updateFailureInstall;

  /// Tombol memeriksa pembaruan.
  ///
  /// In id, this message translates to:
  /// **'Periksa'**
  String get updateCheck;

  /// Tombol mengulang pemeriksaan, unduhan, atau pemasangan yang gagal.
  ///
  /// In id, this message translates to:
  /// **'Coba lagi'**
  String get updateRetry;

  /// Tombol mengunduh versi baru.
  ///
  /// In id, this message translates to:
  /// **'Unduh dan pasang'**
  String get updateDownload;

  /// Tombol membatalkan unduhan APK.
  ///
  /// In id, this message translates to:
  /// **'Batalkan unduhan'**
  String get updateCancel;

  /// Tombol membuka penginstal Android untuk APK yang sudah diunduh.
  ///
  /// In id, this message translates to:
  /// **'Pasang'**
  String get updateInstall;

  /// Ukuran APK rilis.
  ///
  /// In id, this message translates to:
  /// **'Ukuran {size}'**
  String updateSize(String size);

  /// Kemajuan unduhan APK.
  ///
  /// In id, this message translates to:
  /// **'{received} dari {total}'**
  String updateProgress(String received, String total);

  /// Nama aksesibilitas kotak catatan rilis.
  ///
  /// In id, this message translates to:
  /// **'Catatan rilis'**
  String get updateNotesLabel;

  /// Catatan di bawah tombol Pasang.
  ///
  /// In id, this message translates to:
  /// **'Android akan meminta konfirmasi. Host, snippet, dan vault tetap ada karena aplikasi diperbarui, bukan dipasang ulang.'**
  String get updateInstallNote;

  /// Judul banner bila izin pasang aplikasi belum diberikan.
  ///
  /// In id, this message translates to:
  /// **'Izinkan pemasangan dari TermUL'**
  String get updatePermissionTitle;

  /// Isi banner izin pasang aplikasi.
  ///
  /// In id, this message translates to:
  /// **'Aktifkan \"Izinkan dari sumber ini\" untuk TermUL, lalu kembali dan ketuk Pasang lagi.'**
  String get updatePermissionBody;

  /// Tombol membuka halaman izin pasang aplikasi.
  ///
  /// In id, this message translates to:
  /// **'Buka pengaturan'**
  String get updatePermissionOpen;

  /// Keterangan versi di paling bawah Pengaturan.
  ///
  /// In id, this message translates to:
  /// **'TermUL Mobile {name} · build {build}'**
  String updateVersionFooter(String name, int build);
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
