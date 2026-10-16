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

  /// Tab Pengaturan di bar navigasi.
  ///
  /// In id, this message translates to:
  /// **'Pengaturan'**
  String get navSettings;

  /// Judul banner di tab yang fiturnya belum dibuat.
  ///
  /// In id, this message translates to:
  /// **'Belum tersedia'**
  String get comingSoonHeading;

  /// Keterangan tab SFTP yang belum dibuat.
  ///
  /// In id, this message translates to:
  /// **'Menjelajah dan memindahkan berkas lewat SFTP belum ada di versi ini.'**
  String get comingSoonSftp;

  /// Keterangan tab Snippet yang belum dibuat.
  ///
  /// In id, this message translates to:
  /// **'Menyimpan perintah yang sering dipakai belum ada di versi ini.'**
  String get comingSoonSnippets;

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
  /// **'Tekan kembali di terminal lalu pilih \"Tetap terhubung di latar belakang\" untuk membiarkan sesi berjalan dan melanjutkannya dari sini.'**
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
