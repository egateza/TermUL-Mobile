// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'TermUL';

  @override
  String get statusOnline => 'online';

  @override
  String get statusOffline => 'offline';

  @override
  String get statusBusy => 'menyambung ulang';

  @override
  String get statusIdle => 'siaga';

  @override
  String hostStatusOnlineMs(int ms) {
    return 'online · $ms ms';
  }

  @override
  String get hostStatusUnreachable => 'tidak terjangkau';

  @override
  String get hostStatusNotChecked => 'belum diperiksa';

  @override
  String get actionCancel => 'Batal';

  @override
  String get actionClearSearch => 'Hapus pencarian';

  @override
  String get actionClose => 'Tutup';

  @override
  String get actionSave => 'Simpan';

  @override
  String get hostsTitle => 'Host';

  @override
  String get hostsAddHost => 'Tambah host';

  @override
  String get hostsSearchLabel => 'Cari host';

  @override
  String get hostsSearchPlaceholder => 'Cari nama, user, atau IP';

  @override
  String get filterTitle => 'Filter host';

  @override
  String filterDropdownLabel(String current) {
    return 'Filter host: $current';
  }

  @override
  String get filterAll => 'Semua';

  @override
  String get filterFavorites => 'Favorit';

  @override
  String get hostsRootGroup => 'Tanpa grup';

  @override
  String hostsGroupToggle(String name, int count) {
    return 'Grup $name, $count host';
  }

  @override
  String get hostsEmptyTitle => 'Belum ada host';

  @override
  String get hostsEmptyBody => 'Tambahkan server pertama Anda untuk menyambung lewat SSH.';

  @override
  String get hostsNoMatch => 'Tidak ada host yang cocok. Ubah kata kunci atau filter.';

  @override
  String get corruptHostsTitle => 'Daftar host rusak';

  @override
  String corruptHostsBody(String name) {
    return 'Berkas daftar host tidak bisa dibaca dan disimpan sebagai $name. Aplikasi mulai dari daftar kosong; berkas lama tidak dihapus.';
  }

  @override
  String get corruptKnownTitle => 'Sidik jari server hilang';

  @override
  String corruptKnownBody(String name) {
    return 'Berkas sidik jari rusak dan disimpan sebagai $name. Setiap server dianggap host baru sampai Anda memercayainya lagi.';
  }

  @override
  String hostActionsTitle(String name) {
    return 'Aksi untuk $name';
  }

  @override
  String get actionConnect => 'Sambung';

  @override
  String get actionEdit => 'Ubah';

  @override
  String get actionFavorite => 'Jadikan favorit';

  @override
  String get actionUnfavorite => 'Hapus dari favorit';

  @override
  String get actionDelete => 'Hapus';

  @override
  String get agentNeedsCompletionTitle => 'Perlu dilengkapi';

  @override
  String get agentNeedsCompletionBody =>
      'Profil ini memakai agen SSH di desktop. HP tidak punya agen, jadi pilih password atau kunci di HP lalu simpan.';

  @override
  String get actionComplete => 'Lengkapi';

  @override
  String deleteHostTitle(String name) {
    return 'Hapus $name?';
  }

  @override
  String get deleteHostBody =>
      'Password atau kunci yang tersimpan untuk host ini ikut terhapus, begitu juga sidik jari servernya. Server sendiri tidak berubah.';

  @override
  String get deleteHostFailed => 'Host belum terhapus. Penyimpanan perangkat bermasalah; coba lagi.';

  @override
  String hostDeleted(String name) {
    return 'Dihapus · $name';
  }

  @override
  String get formAddTitle => 'Host baru';

  @override
  String get formEditTitle => 'Ubah host';

  @override
  String get fieldName => 'Nama';

  @override
  String get fieldHost => 'Host';

  @override
  String get fieldHostHelper => 'Nama host atau alamat IP';

  @override
  String get fieldPort => 'Port';

  @override
  String get fieldUsername => 'User';

  @override
  String get fieldGroup => 'Grup (opsional)';

  @override
  String get fieldGroupHelper => 'Pisahkan tingkat dengan /, mis. Produksi/Backend';

  @override
  String get authMethodLabel => 'Cara login';

  @override
  String get authPassword => 'Password';

  @override
  String get authKey => 'Kunci';

  @override
  String get fieldPassword => 'Password';

  @override
  String get passwordStoredHint => 'Kosongkan untuk tetap memakai password yang tersimpan';

  @override
  String get keyImport => 'Impor kunci dari berkas';

  @override
  String get keyReplace => 'Ganti kunci';

  @override
  String keyReady(String type) {
    return 'Kunci $type siap disimpan';
  }

  @override
  String get keyStored => 'Kunci tersimpan di perangkat';

  @override
  String get keyPassphraseEncrypted => 'Kunci ini dilindungi passphrase.';

  @override
  String get fieldPassphrase => 'Passphrase kunci';

  @override
  String get errNameRequired => 'Nama wajib diisi';

  @override
  String get errHostRequired => 'Host wajib diisi';

  @override
  String get errPortInvalid => 'Port harus 1 sampai 65535';

  @override
  String get errUserRequired => 'User wajib diisi';

  @override
  String get errPasswordRequired => 'Password wajib diisi';

  @override
  String get errKeyRequired => 'Pilih berkas kunci privat';

  @override
  String get errPassphraseWrong => 'Passphrase salah atau kosong';

  @override
  String get keyErrNotAKey => 'Berkas ini bukan kunci privat (terlalu besar atau bukan teks).';

  @override
  String get keyErrNotPem => 'Berkas ini bukan kunci dalam format PEM.';

  @override
  String get keyErrPkcs8 =>
      'Format kunci ini belum didukung (PKCS#8). Ubah dengan ssh-keygen -p -m PEM, atau pakai kunci OpenSSH.';

  @override
  String keyErrType(String type) {
    return 'Jenis kunci $type belum didukung.';
  }

  @override
  String get keyErrMalformed => 'Kunci rusak atau tidak terbaca.';

  @override
  String get lockWarningTitle => 'HP ini tidak punya kunci layar';

  @override
  String get lockWarningBody =>
      'Siapa pun yang memegang HP bisa membuka server ini tanpa kata sandi. Menyimpan kredensial di sini berbahaya, tetapi tetap bisa dilakukan.';

  @override
  String hostSaved(String name) {
    return 'Disimpan · $name';
  }

  @override
  String get saveFailed => 'Belum tersimpan. Penyimpanan perangkat bermasalah; coba lagi.';

  @override
  String get bootLoading => 'Memuat…';

  @override
  String get bootErrorTitle => 'Penyimpanan tidak bisa dibuka';

  @override
  String get bootErrorBody =>
      'Data Anda tidak diubah. Mulai ulang aplikasi; bila berulang, periksa ruang penyimpanan HP.';

  @override
  String get actionAbort => 'Batalkan';

  @override
  String get actionRetry => 'Coba lagi';

  @override
  String get actionBack => 'Kembali';

  @override
  String get actionDisconnect => 'Putuskan';

  @override
  String get actionSaveAndConnect => 'Simpan dan sambung';

  @override
  String get connectPreparing => 'Membuka kredensial…';

  @override
  String connectConnecting(String name) {
    return 'Menyambung ke $name…';
  }

  @override
  String get authDeniedTitle => 'Autentikasi dibatalkan';

  @override
  String get authDeniedBody => 'Kredensial tidak dibuka, jadi tidak ada yang dikirim ke server.';

  @override
  String get authUnavailableTitle => 'Autentikasi perangkat tidak bisa dipakai';

  @override
  String get authUnavailableBody => 'Periksa pengaturan kunci layar atau sidik jari di HP, lalu coba lagi.';

  @override
  String get secretMissingTitle => 'Rahasia hilang';

  @override
  String secretMissingPasswordBody(String name) {
    return 'Password untuk $name tidak ditemukan di perangkat ini. Masukkan ulang untuk melanjutkan.';
  }

  @override
  String secretMissingKeyBody(String name) {
    return 'Kunci untuk $name tidak ditemukan atau tidak bisa dibuka di perangkat ini. Impor ulang untuk melanjutkan.';
  }

  @override
  String get secretWrongPassphraseBody =>
      'Passphrase tersimpan tidak cocok dengan kunci. Impor ulang kunci beserta passphrase-nya.';

  @override
  String get failNetworkTitle => 'Tidak bisa tersambung';

  @override
  String get failNetworkBody =>
      'Server tidak terjangkau atau menutup koneksi. Periksa alamat, port, dan jaringan Anda.';

  @override
  String get failHandshakeTitle => 'Negosiasi gagal';

  @override
  String get failHandshakeBody =>
      'Server memakai algoritma yang belum didukung, atau pertukaran kunci gagal. Server yang sangat lama mungkin tidak bisa disambung.';

  @override
  String get failAuthTitle => 'Login ditolak';

  @override
  String get failAuthBody => 'Server menolak kredensial. Periksa user, password atau kunci, lalu ubah host.';

  @override
  String get failRejectedTitle => 'Host key ditolak';

  @override
  String get failRejectedBody => 'Anda menolak host key server ini. Koneksi dibatalkan dan tidak ada yang disimpan.';

  @override
  String get failRejectedChangedTitle => 'Koneksi dibatalkan';

  @override
  String get failRejectedChangedBody => 'Host key yang berubah tidak diganti, jadi koneksi tidak dibuka.';

  @override
  String get failStoreTitle => 'Sidik jari tidak tersimpan';

  @override
  String get failStoreBody => 'Penyimpanan perangkat bermasalah, jadi koneksi dibatalkan demi keamanan.';

  @override
  String get failUnknownTitle => 'Gagal menyambung';

  @override
  String get failUnknownBody =>
      'Terjadi kesalahan yang tidak dikenal. Coba lagi; bila berulang, ubah host atau periksa server.';

  @override
  String get hostKeyNewTitle => 'Host baru';

  @override
  String hostKeyNewBody(String name) {
    return 'Ini koneksi pertama ke $name. Pastikan fingerprint di bawah cocok dengan yang Anda ketahui sebelum melanjutkan.';
  }

  @override
  String get hostKeyAlgorithm => 'Algoritma';

  @override
  String get hostKeyFingerprint => 'Fingerprint (SHA256)';

  @override
  String get hostKeyNewNote =>
      'Fingerprint disimpan di perangkat ini. Bila nanti berubah, Anda akan diperingatkan sebelum sambungan dibuka.';

  @override
  String get hostKeyTrustAndConnect => 'Percayai dan sambung';

  @override
  String get hostKeyConnectOnce => 'Sambung sekali saja';

  @override
  String get hostKeyChangedTitle => 'Host key berubah';

  @override
  String hostKeyChangedBody(String name) {
    return 'Fingerprint $name berbeda dari yang tersimpan. Penyebabnya bisa server dibangun ulang, atau koneksi sedang disadap.';
  }

  @override
  String get hostKeyStored => 'Tersimpan';

  @override
  String get hostKeyReceived => 'Diterima sekarang';

  @override
  String get hostKeyAck => 'Saya sudah memastikan perubahan ini sah dengan pemilik server';

  @override
  String get hostKeyCancelConnection => 'Batalkan koneksi';

  @override
  String get hostKeyReplaceAndConnect => 'Ganti key dan sambung';

  @override
  String unlockReason(String name) {
    return 'Buka kredensial untuk $name';
  }

  @override
  String get terminalStatusOpening => 'Membuka shell…';

  @override
  String get terminalStatusConnected => 'Tersambung';

  @override
  String get terminalStatusEnded => 'Sesi berakhir';

  @override
  String get terminalStatusFailed => 'Shell tidak terbuka';

  @override
  String get terminalLeaveTitle => 'Putuskan sambungan?';

  @override
  String get terminalLeaveBody =>
      'Shell di server ikut berakhir dan program yang sedang berjalan berhenti. Gunakan tmux bila sesi harus tetap hidup.';

  @override
  String terminalHostLabel(String name, String status) {
    return '$name, $status';
  }

  @override
  String get keyEsc => 'Tombol Escape';

  @override
  String get keyTab => 'Tombol Tab';

  @override
  String get keyCtrl => 'Ctrl, berlaku untuk satu ketukan berikutnya';

  @override
  String get keyAlt => 'Alt, berlaku untuk satu ketukan berikutnya';

  @override
  String get keyCtrlC => 'Ctrl C, hentikan program';

  @override
  String get keyCtrlD => 'Ctrl D, akhir masukan';

  @override
  String get keyArrowUp => 'Panah atas';

  @override
  String get keyArrowDown => 'Panah bawah';

  @override
  String get keyArrowLeft => 'Panah kiri';

  @override
  String get keyArrowRight => 'Panah kanan';

  @override
  String get keyHome => 'Home';

  @override
  String get keyEnd => 'End';

  @override
  String get keyPageUp => 'Page Up';

  @override
  String get keyPageDown => 'Page Down';

  @override
  String get keyPipe => 'Garis tegak';

  @override
  String get keyTilde => 'Tilde';

  @override
  String get keySlash => 'Garis miring';

  @override
  String get keyDash => 'Tanda hubung';

  @override
  String get keyFunctionToggle => 'Tombol F1 sampai F12';

  @override
  String get keyFunctionBack => 'Kembali ke tombol biasa';

  @override
  String keyFunction(int n) {
    return 'F$n';
  }

  @override
  String get quickKeysLabel => 'Tombol khusus terminal';

  @override
  String get reconnectLostTitle => 'Koneksi terputus';

  @override
  String get reconnectLostBody =>
      'Riwayat layar tetap di sini. Program yang berjalan di server berhenti, kecuali yang berjalan di dalam tmux.';

  @override
  String get reconnectingTitle => 'Menyambung ulang…';

  @override
  String get reconnectingBody => 'Riwayat layar tetap terlihat.';

  @override
  String get reconnectWaitingTitle => 'Menunggu server terjangkau…';

  @override
  String reconnectWaitingBody(int seconds) {
    return 'Mencoba lagi dalam $seconds detik.';
  }

  @override
  String get reconnectAuthTitle => 'Perlu verifikasi';

  @override
  String get reconnectAuthBody => 'Menyambung ulang membutuhkan sidik jari, PIN, atau pola perangkat.';

  @override
  String get reconnectShowPrompt => 'Tampilkan prompt';

  @override
  String get reconnectNow => 'Sambung sekarang';

  @override
  String get reconnectFailedTitle => 'Gagal menyambung ulang';

  @override
  String get reconnectedMarker => '— tersambung ulang —';

  @override
  String get terminalStatusLost => 'Terputus';

  @override
  String get terminalStatusReconnecting => 'Menyambung ulang…';

  @override
  String get navLabel => 'Navigasi utama';

  @override
  String get navHosts => 'Host';

  @override
  String get navSessions => 'Sesi';

  @override
  String get navSftp => 'SFTP';

  @override
  String get navSnippets => 'Snippet';

  @override
  String get navStreak => 'Streak';

  @override
  String get navSettings => 'Pengaturan';

  @override
  String get streakTitle => 'Streak';

  @override
  String get streakTier1 => 'Bara';

  @override
  String get streakTier2 => 'Api Jingga';

  @override
  String get streakTier3 => 'Api Merah';

  @override
  String get streakTier4 => 'Api Magenta';

  @override
  String get streakTier5 => 'Api Ungu';

  @override
  String get streakTier6 => 'Api Biru';

  @override
  String get streakTier7 => 'Api Zamrud';

  @override
  String get streakTier8 => 'Api Emas';

  @override
  String get streakTier9 => 'Api Pelangi';

  @override
  String get streakFlameGray => 'Api padam';

  @override
  String get streakFlameFrozen => 'Api membeku';

  @override
  String get streakFlameExpired => 'Api hangus';

  @override
  String streakCountActive(int count) {
    return '${count}x';
  }

  @override
  String streakCountKindling(int count) {
    return '$count/3';
  }

  @override
  String streakChipActive(int count, String tier) {
    return 'Streak $count hari, $tier. Ketuk untuk membuka layar Streak.';
  }

  @override
  String streakChipKindling(int count) {
    return 'Hari ke-$count dari 3 menuju streak. Ketuk untuk membuka layar Streak.';
  }

  @override
  String streakChipGray(int count) {
    return 'Streak $count hari padam. Ketuk untuk membuka dan menyalakan.';
  }

  @override
  String streakChipFrozen(int count) {
    return 'Streak $count hari beku. Ketuk untuk membuka dan memecahkan es.';
  }

  @override
  String get streakHelpLabel => 'Bantuan: cara kerja streak';

  @override
  String get streakSettingsLabel => 'Pengaturan streak';

  @override
  String get streakStageGray => 'Ketuk api untuk menyalakan';

  @override
  String get streakStageFrozen => 'Ketuk untuk memecahkan es';

  @override
  String get streakStageActive => 'Api streak';

  @override
  String get streakUnitDays => 'hari berturut-turut';

  @override
  String get streakStatusActive => 'Hari ini terhitung sejak aplikasi dibuka. Sampai jumpa besok.';

  @override
  String get streakStatusKindling => 'Buka TermUL lagi besok. Streak menyala di hari ke-3.';

  @override
  String get streakStatusGray =>
      'Kemarin kamu tidak membuka TermUL, jadi api padam. Ketuk api 3x cepat untuk menyalakannya lagi.';

  @override
  String streakStatusGrayLeft(int count) {
    return 'Sisa $count ketukan lagi untuk menyalakan api.';
  }

  @override
  String get streakStatusGrayRelit => 'Api menyala lagi. Hari ini terhitung.';

  @override
  String streakStatusFrozen(int missed, int need) {
    return 'Kamu absen $missed hari, api membeku. Ketuk api $need kali untuk memecahkan es.';
  }

  @override
  String streakStatusFrozenLeft(int count) {
    return 'Sisa $count ketukan lagi untuk memecahkan es.';
  }

  @override
  String get streakStatusFrozenRelit => 'Es pecah! Streak dilanjutkan. Hari ini terhitung.';

  @override
  String get streakTodayDone => 'Hari ini selesai';

  @override
  String get streakReplay => 'Putar ulang animasi';

  @override
  String get streakWeek => 'Pekan ini';

  @override
  String get streakDayMon => 'Sen';

  @override
  String get streakDayTue => 'Sel';

  @override
  String get streakDayWed => 'Rab';

  @override
  String get streakDayThu => 'Kam';

  @override
  String get streakDayFri => 'Jum';

  @override
  String get streakDaySat => 'Sab';

  @override
  String get streakDaySun => 'Min';

  @override
  String get streakLongest => 'Terpanjang';

  @override
  String get streakActiveMonth => 'Aktif bulan ini';

  @override
  String get streakLevel => 'Level api';

  @override
  String streakDays(int count) {
    return '$count hari';
  }

  @override
  String streakLevelValue(int level, String name) {
    return '$level · $name';
  }

  @override
  String streakNextLevel(int level, int target) {
    return 'Menuju Level $level · hari ke-$target';
  }

  @override
  String streakNextProgress(int count, int target) {
    return '$count / $target';
  }

  @override
  String streakDaysLeft(int count) {
    return 'Tinggal $count hari lagi.';
  }

  @override
  String streakMaxLevel(String name) {
    return 'Level 9 · $name';
  }

  @override
  String get streakMaxLevelText => 'Level tertinggi sudah tercapai.';

  @override
  String streakLevelBadge(int level, String name, String state) {
    return 'Level $level, $name, $state';
  }

  @override
  String get streakBadgeCurrent => 'level sekarang';

  @override
  String get streakBadgeReached => 'sudah tercapai';

  @override
  String get streakBadgeLocked => 'belum tercapai';

  @override
  String get streakMonth1 => 'Januari';

  @override
  String get streakMonthShort1 => 'Jan';

  @override
  String get streakMonth2 => 'Februari';

  @override
  String get streakMonthShort2 => 'Feb';

  @override
  String get streakMonth3 => 'Maret';

  @override
  String get streakMonthShort3 => 'Mar';

  @override
  String get streakMonth4 => 'April';

  @override
  String get streakMonthShort4 => 'Apr';

  @override
  String get streakMonth5 => 'Mei';

  @override
  String get streakMonthShort5 => 'Mei';

  @override
  String get streakMonth6 => 'Juni';

  @override
  String get streakMonthShort6 => 'Jun';

  @override
  String get streakMonth7 => 'Juli';

  @override
  String get streakMonthShort7 => 'Jul';

  @override
  String get streakMonth8 => 'Agustus';

  @override
  String get streakMonthShort8 => 'Agu';

  @override
  String get streakMonth9 => 'September';

  @override
  String get streakMonthShort9 => 'Sep';

  @override
  String get streakMonth10 => 'Oktober';

  @override
  String get streakMonthShort10 => 'Okt';

  @override
  String get streakMonth11 => 'November';

  @override
  String get streakMonthShort11 => 'Nov';

  @override
  String get streakMonth12 => 'Desember';

  @override
  String get streakMonthShort12 => 'Des';

  @override
  String streakMonthTitle(String month, String year) {
    return '$month $year';
  }

  @override
  String get streakLegend =>
      'Kotak terisi = hari aktif. Bingkai amber = hari ini. Bingkai putus-putus berwarna = hari absen.';

  @override
  String streakAbsentFrozen(int count, String range, int need) {
    return 'Absen $count hari ($range): api membeku. Ketuk $need kali untuk memecahkan es.';
  }

  @override
  String streakAbsentGray(int count, String range) {
    return 'Absen $count hari ($range): api padam. Ketuk 3 kali cepat untuk menyalakan.';
  }

  @override
  String streakDayState(int day, String month, String state) {
    return '$day $month, $state';
  }

  @override
  String get streakDayActive => 'aktif';

  @override
  String get streakDayToday => 'hari ini, belum terhitung';

  @override
  String get streakDayTodayActive => 'hari ini, aktif';

  @override
  String get streakDayAbsent => 'absen';

  @override
  String get streakDayMissed => 'tidak aktif';

  @override
  String get streakDayFuture => 'belum tiba';

  @override
  String get streakHelpRow => 'Cara kerja streak dan contoh jika absen';

  @override
  String get streakHelpTitle => 'Cara kerja streak';

  @override
  String get streakHelp1 =>
      'Satu hari dihitung saat Tuan membuka aplikasi. Bila tanggal berganti selagi aplikasi terbuka, hari baru dihitung seperti membuka lagi.';

  @override
  String get streakHelp2 =>
      'Hari 1-2 tampil sebagai bara dengan angka N/3 dan belum dihitung sebagai streak. Mulai hari ke-3 api menyala.';

  @override
  String get streakHelp3 =>
      'Absen 1-2 hari: api padam, ketuk 3 kali cepat untuk menyalakan. Absen 3-10 hari: api membeku, ketukan = 5 + (hari absen - 3), maksimal 10. Absen lebih dari 10 hari: streak hangus dan mulai lagi dari 1/3.';

  @override
  String get streakHelpSettings => 'Atur tampilan streak dan pengingat';

  @override
  String get streakHelpExamples => 'Contoh jika tidak membuka TermUL';

  @override
  String get streakExampleGrayTitle => 'Absen 1-2 hari';

  @override
  String get streakExampleGrayText => 'Api padam. Ketuk 3 kali cepat untuk menyalakan.';

  @override
  String get streakExampleFrozenTitle => 'Absen 3-10 hari';

  @override
  String get streakExampleFrozenText => 'Api membeku. Ketukan = 5 + (hari absen - 3), jadi absen 5 hari = 7 ketukan.';

  @override
  String get streakExampleExpiredTitle => 'Absen lebih dari 10 hari';

  @override
  String get streakExampleExpiredText => 'Streak hangus dan mulai lagi dari 1/3.';

  @override
  String get streakCorruptTitle => 'Data streak rusak';

  @override
  String streakCorruptBody(String name) {
    return 'Berkas streak tidak bisa dibaca dan disimpan sebagai $name. Streak dimulai lagi dari awal; berkas lama tidak dihapus.';
  }

  @override
  String get streakSplashHeader => 'Streak harian';

  @override
  String get streakSplashReplay => 'Putar ulang';

  @override
  String get streakSplashUnit => 'hari streak';

  @override
  String streakSplashLit(String tier) {
    return 'Streak menyala · $tier';
  }

  @override
  String streakSplashLevelUp(String tier) {
    return 'Naik level · $tier';
  }

  @override
  String streakSplashCracks(int cracks, int need) {
    return 'Retak $cracks/$need';
  }

  @override
  String get streakSplashRelit => 'Api menyala lagi. Streak lanjut, hari ini ikut dihitung.';

  @override
  String streakSplashExpired(int missed, int lost) {
    return 'Kamu absen $missed hari. Streak $lost hari hangus.';
  }

  @override
  String get streakSplashRestart => 'Mulai lagi hari ini. Buka TermUL 3 hari berturut-turut untuk menyalakan streak.';

  @override
  String get streakSplashStageGray => 'Ketuk api tiga kali cepat untuk menyalakan';

  @override
  String get streakSplashStageFrozen => 'Ketuk api untuk memecahkan es';

  @override
  String get streakSplashContinue => 'Lanjut';

  @override
  String get streakSplashLater => 'Nanti saja';

  @override
  String get streakReminderTitle => 'Api streak menunggu';

  @override
  String get streakReminderText => 'Buka TermUL hari ini supaya streak tetap menyala.';

  @override
  String get streakReminderChannel => 'Pengingat streak';

  @override
  String get settingsStreakReminderNeedsPermission => 'Izin notifikasi diperlukan untuk pengingat harian';

  @override
  String get settingsStreakReminderBlocked => 'Notifikasi belum diizinkan, jadi pengingat tidak akan tampil.';

  @override
  String get settingsStreakSection => 'Streak';

  @override
  String get settingsStreakShowLabel => 'Tampilkan streak api';

  @override
  String get settingsStreakShowDesc => 'Hari tetap dihitung walau ikonnya disembunyikan';

  @override
  String get settingsStreakReminderLabel => 'Pengingat harian';

  @override
  String get settingsStreakReminderDesc => 'Notifikasi pukul 20.00 bila belum membuka aplikasi hari ini';

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get settingsTerminalSection => 'Terminal';

  @override
  String get settingsFontSize => 'Ukuran font';

  @override
  String settingsFontSizeValue(int px) {
    return '$px px';
  }

  @override
  String get settingsFontSmaller => 'Kecilkan font';

  @override
  String get settingsFontLarger => 'Besarkan font';

  @override
  String get settingsLineHeight => 'Tinggi baris';

  @override
  String settingsLineHeightValue(String value) {
    return '$value×';
  }

  @override
  String get settingsLineTighter => 'Rapatkan baris';

  @override
  String get settingsLineLooser => 'Renggangkan baris';

  @override
  String get settingsTerminalHint =>
      'Berlaku langsung di sesi yang sedang terbuka. Makin kecil huruf dan makin rapat baris, makin banyak baris yang muat; terlalu kecil sulit dibaca.';

  @override
  String get settingsResetDefaults => 'Kembalikan bawaan';

  @override
  String get settingsPreviewLabel => 'Pratinjau terminal';

  @override
  String get settingsSaveFailedTitle => 'Pengaturan tidak tersimpan';

  @override
  String get settingsSaveFailedBody =>
      'Perubahan tetap berlaku sampai aplikasi ditutup, tetapi akan hilang setelah itu. Periksa ruang penyimpanan HP lalu coba lagi.';

  @override
  String keepAliveNotifTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sesi tersambung',
      one: '1 sesi tersambung',
    );
    return '$_temp0';
  }

  @override
  String get keepAliveDisconnectAll => 'Putuskan semua';

  @override
  String get keepAliveChannelName => 'Sesi aktif';

  @override
  String get settingsConnectionSection => 'Koneksi';

  @override
  String get settingsAutoReconnectLabel => 'Sambung ulang otomatis';

  @override
  String get settingsAutoReconnectDesc => 'Saat jaringan berpindah atau aplikasi kembali aktif';

  @override
  String get settingsConfirmPasteLabel => 'Konfirmasi tempel satu baris';

  @override
  String get settingsConfirmPasteDesc =>
      'Teks pendek tampil di popover sebelum ditempel. Teks panjang, banyak baris, atau berisiko selalu ditanya.';

  @override
  String get settingsKeepAliveLabel => 'Pertahankan koneksi di latar belakang';

  @override
  String get settingsKeepAliveDesc =>
      'Sesi tetap tersambung saat aplikasi ditutup ke latar belakang. Memakai baterai lebih banyak dan menampilkan notifikasi permanen.';

  @override
  String get settingsKeepAliveNote =>
      'Membantu sambungan bertahan, tetapi tidak menjaminnya: perpindahan jaringan atau sinyal hilang tetap memutus sesi, lalu sambung ulang otomatis berjalan.';

  @override
  String get settingsKeepAliveNeedsPermission => 'Izin notifikasi diperlukan untuk menjaga koneksi';

  @override
  String get settingsNotifPermissionLabel => 'Izin notifikasi';

  @override
  String get settingsNotifAllowed => 'Diizinkan';

  @override
  String get settingsNotifDenied => 'Belum diizinkan';

  @override
  String get settingsNotifAllow => 'Izinkan';

  @override
  String get settingsBatteryLabel => 'Pembatasan baterai HP';

  @override
  String get settingsBatteryDesc =>
      'Beberapa HP (misalnya HyperOS) perlu diatur ke \"Tanpa batasan\" agar sesi tidak dihentikan.';

  @override
  String get settingsBatteryOpen => 'Buka pengaturan';

  @override
  String get keyPaste => 'Tempel';

  @override
  String get keyPasteAria => 'Tempel dari papan klip';

  @override
  String get pasteMenuHint => 'Masuk ke prompt, belum dijalankan';

  @override
  String get pasteEmpty => 'Papan klip kosong';

  @override
  String get pasteTooLarge => 'Teks terlalu besar untuk ditempel (maksimal 100.000 karakter)';

  @override
  String pasteTitle(int count) {
    return 'Tempel $count baris?';
  }

  @override
  String get pasteConfirm => 'Tempel';

  @override
  String pasteDone(int count) {
    return 'Ditempel · $count baris · belum dijalankan';
  }

  @override
  String pasteDoneRunning(int count) {
    return 'Ditempel · $count baris';
  }

  @override
  String pasteRiskNote(int count) {
    return '$count baris berisiko (mis. rm -rf). Periksa sebelum menekan Enter.';
  }

  @override
  String get pasteUnsafeNote =>
      'Server ini belum mendukung tempel aman: setiap baris langsung dijalankan begitu ditempel.';

  @override
  String get pasteRiskTag => 'berisiko';

  @override
  String get pasteSafeNote => 'Teks masuk ke prompt tanpa menekan Enter, jadi belum dijalankan.';

  @override
  String pasteControlRemoved(int count) {
    return '$count karakter kontrol dihapus dari teks yang ditempel.';
  }

  @override
  String pasteMoreLines(int count) {
    return '… dan $count baris lagi';
  }

  @override
  String selectionCount(int count) {
    return '$count karakter dipilih';
  }

  @override
  String get selectionHint => 'Seret gagang untuk mengubah pilihan';

  @override
  String get selectionCopy => 'Salin';

  @override
  String get selectionCopyAria => 'Salin teks terpilih';

  @override
  String get selectionAll => 'Semua';

  @override
  String get selectionAllAria => 'Pilih semua teks di terminal';

  @override
  String selectionCopied(int count) {
    return 'Disalin · $count karakter';
  }

  @override
  String get selectionHandleStart => 'Gagang awal pilihan';

  @override
  String get selectionHandleEnd => 'Gagang akhir pilihan';

  @override
  String get settingsHandleStyle => 'Bentuk gagang seleksi';

  @override
  String get settingsHandleDrop => 'Tetesan';

  @override
  String get settingsHandleTriangle => 'Segitiga';

  @override
  String get settingsHandleDot => 'Bulatan';

  @override
  String get terminalLeaveChoiceBody =>
      'Tetap terhubung membiarkan sesi berjalan di latar belakang; buka lagi dari tab Sesi. Putuskan menutup shell di server dan menghentikan program yang sedang berjalan.';

  @override
  String get terminalLeaveKeep => 'Tetap terhubung di latar belakang';

  @override
  String get terminalLeaveKeepAliveOff =>
      'Pengaturan \"Pertahankan koneksi di latar belakang\" mati, jadi Android bisa memutus sambungan saat aplikasi tidak terlihat.';

  @override
  String get terminalLeaveOpenSettings => 'Buka Pengaturan';

  @override
  String get sessionsTitle => 'Sesi aktif';

  @override
  String hostsOpenSessions(int count) {
    return 'Sesi aktif, $count';
  }

  @override
  String get sessionsEmptyTitle => 'Tidak ada sesi di latar belakang';

  @override
  String get sessionsEmptyBody =>
      'Tekan kembali di terminal atau SFTP lalu pilih \"Tetap terhubung di latar belakang\" untuk membiarkan sesi berjalan dan melanjutkannya dari sini.';

  @override
  String get sessionsHint => 'Ketuk sesi untuk melanjutkannya.';

  @override
  String sessionsNumber(int n) {
    return 'sesi $n';
  }

  @override
  String sessionsStarted(String time) {
    return 'mulai $time';
  }

  @override
  String get sessionsStatusConnecting => 'menyambung';

  @override
  String get sessionsStatusAttention => 'perlu tindakan';

  @override
  String sessionsOpenLabel(String name, String status) {
    return '$name, $status. Ketuk untuk melanjutkan.';
  }

  @override
  String sessionsDisconnectLabel(String name) {
    return 'Putuskan $name';
  }

  @override
  String get sessionsDisconnectTitle => 'Putuskan sesi?';

  @override
  String sessionsDisconnectBody(String name) {
    return 'Shell di $name ikut berakhir dan program yang sedang berjalan berhenti.';
  }

  @override
  String get sessionsDisconnectAll => 'Putuskan semua';

  @override
  String sessionsDisconnectAllTitle(int count) {
    return 'Putuskan $count sesi?';
  }

  @override
  String get sessionsDisconnectAllBody =>
      'Semua shell di server ikut berakhir dan program yang sedang berjalan berhenti.';

  @override
  String get terminalLeaveChoiceTitle => 'Keluar dari terminal?';

  @override
  String get sftpIntro =>
      'Pilih host untuk menjelajah berkasnya. Koneksi SFTP dibuka sendiri, atau pakai sesi terminal yang sedang terhubung.';

  @override
  String get sftpSessionsHeading => 'Sesi terbuka';

  @override
  String get sftpHostsHeading => 'Koneksi sendiri';

  @override
  String get sftpUseSession => 'Pakai sesi terbuka';

  @override
  String get sftpNoHosts => 'Belum ada host. Tambahkan dulu di tab Host.';

  @override
  String sftpConnectedTo(String name) {
    return '$name · terhubung';
  }

  @override
  String get sftpUpTitle => '..';

  @override
  String get sftpUpMeta => 'Naik satu level';

  @override
  String get sftpFolderMeta => 'Folder';

  @override
  String get sftpEmptyFolder => 'Folder ini kosong';

  @override
  String get sftpLoading => 'Memuat…';

  @override
  String sftpSelected(String name) {
    return '$name dipilih';
  }

  @override
  String get sftpCopyPath => 'Salin path';

  @override
  String get sftpPathCopied => 'Path disalin';

  @override
  String get sftpRefresh => 'Muat ulang';

  @override
  String get sftpErrNotFound => 'Folder atau berkas tidak ditemukan.';

  @override
  String get sftpErrDenied => 'Izin ditolak untuk folder ini.';

  @override
  String get sftpErrLost => 'Sambungan terputus.';

  @override
  String get sftpErrOther => 'Operasi SFTP gagal.';

  @override
  String get sftpLostTitle => 'Sambungan SFTP terputus';

  @override
  String get sftpLostBorrowedBody => 'Sesi terminalnya terputus. SFTP tersambung lagi begitu sesinya tersambung ulang.';

  @override
  String get sftpLostOwnBody => 'Android bisa menutup sambungan di latar belakang. Sambung ulang untuk melanjutkan.';

  @override
  String get sftpReconnect => 'Sambung ulang';

  @override
  String get sftpUnavailableTitle => 'SFTP tidak tersedia di server ini';

  @override
  String get sftpUnavailableBody => 'Server tidak mengaktifkan subsistem SFTP, atau menolaknya untuk akun ini.';

  @override
  String sftpAgoMinutes(int count) {
    return '$count menit lalu';
  }

  @override
  String sftpAgoHours(int count) {
    return '$count jam lalu';
  }

  @override
  String get sftpYesterday => 'kemarin';

  @override
  String get sftpJustNow => 'baru saja';

  @override
  String get sftpLeaveTitle => 'Keluar dari SFTP?';

  @override
  String sftpLeaveBodyOwn(String name) {
    return 'Koneksi SFTP ke $name akan ditutup. Sesi terminal tidak terpengaruh.';
  }

  @override
  String sftpLeaveBodyBorrowed(String name) {
    return 'Hanya layar SFTP yang ditutup. Sesi terminal $name tetap berjalan.';
  }

  @override
  String get sftpLeaveConfirm => 'Keluar';

  @override
  String get sftpLeaveBusyTitle => 'Transfer masih berjalan';

  @override
  String sftpLeaveBusyBody(int count) {
    return '$count transfer belum selesai. Bila keluar, semuanya dibatalkan.';
  }

  @override
  String get sftpLeaveBusyUploadNote => 'Berkas unggahan yang belum lengkap dihapus dari server.';

  @override
  String get sftpLeaveBusyDownloadNote => 'Berkas unduhan yang belum lengkap dihapus dari perangkat.';

  @override
  String get sftpLeaveBusyConfirm => 'Batalkan transfer dan keluar';

  @override
  String sftpTransferUpload(String name) {
    return 'Unggah $name';
  }

  @override
  String sftpTransferDownload(String name) {
    return 'Unduh $name';
  }

  @override
  String sftpTransferPercent(int percent) {
    return '$percent%';
  }

  @override
  String sftpDisconnectedFrom(String name) {
    return '$name · terputus';
  }

  @override
  String get sftpReconnectingBody => 'Folder yang dibuka tetap terlihat.';

  @override
  String get sftpUploadAction => 'Unggah berkas';

  @override
  String get sftpDownloadAction => 'Unduh';

  @override
  String sftpDownloaded(String location, String name) {
    return 'Diunduh ke $location · $name';
  }

  @override
  String sftpUploaded(String name) {
    return 'Diunggah · $name';
  }

  @override
  String sftpTransferCancelledToast(String name) {
    return 'Dibatalkan · $name';
  }

  @override
  String sftpDownloadFailed(String reason) {
    return 'Unduhan gagal · $reason';
  }

  @override
  String sftpUploadFailed(String reason) {
    return 'Unggahan gagal · $reason';
  }

  @override
  String get sftpSaveFailed => 'Berkas diterima, tetapi tidak bisa disimpan ke Unduhan';

  @override
  String get sftpTransferCancel => 'Batalkan transfer';

  @override
  String sftpConflictTitle(String name) {
    return '$name sudah ada';
  }

  @override
  String sftpConflictBodyUpload(String dir) {
    return 'Di $dir di server. Pilih cara menyimpannya.';
  }

  @override
  String get sftpConflictBodyDownload => 'Di Unduhan/TermUL. Pilih cara menyimpannya.';

  @override
  String sftpConflictRename(String name) {
    return 'Simpan sebagai $name';
  }

  @override
  String get sftpConflictOverwrite => 'Timpa berkas lama';

  @override
  String get sftpConflictOverwriteNote => 'Menimpa mengganti isi berkas lama dan tidak bisa dibatalkan.';

  @override
  String sftpDownloadedOverwritten(String location, String name) {
    return 'Ditimpa di $location · $name';
  }

  @override
  String get sftpSelectAll => 'Pilih semua';

  @override
  String get sftpSelectionCancel => 'Batal pilih';

  @override
  String sftpSelectedCount(int count) {
    return '$count dipilih';
  }

  @override
  String sftpPathsCopied(int count) {
    return '$count path disalin';
  }

  @override
  String sftpConflictManyTitle(int count) {
    return '$count item sudah ada';
  }

  @override
  String get sftpConflictRenameAll => 'Simpan dengan nama bernomor';

  @override
  String get sftpConflictOverwriteAll => 'Timpa semuanya';

  @override
  String sftpDownloadedMany(int count, String location) {
    return '$count berkas diunduh ke $location';
  }

  @override
  String sftpDownloadedManyPartial(int done, int failed) {
    return '$done berkas diunduh, $failed gagal';
  }

  @override
  String sftpDownloadedManySkipped(int count, String location, int skipped) {
    return '$count berkas diunduh ke $location · $skipped dilewati';
  }

  @override
  String sftpFolderNoFiles(String name) {
    return '$name tidak berisi berkas';
  }

  @override
  String get sftpRefreshed => 'Daftar file diperbarui';

  @override
  String get sftpLinkTag => 'Tautan';

  @override
  String get terminalOpenSftp => 'Buka panel SFTP';

  @override
  String sftpLeaveChoiceBody(String name) {
    return 'Tetap terhubung membiarkan koneksi SFTP ke $name di latar belakang; buka lagi dari tab Sesi. Putuskan menutup koneksinya.';
  }

  @override
  String get sftpLeaveKeep => 'Tetap terhubung di latar belakang';

  @override
  String get sftpLeaveDisconnect => 'Putuskan';

  @override
  String get sftpLeaveBusyKeepNote =>
      'Transfer tetap berjalan bila Anda memilih Tetap terhubung. Memutuskan membatalkan semuanya.';

  @override
  String get sessionsSftpTag => 'SFTP';

  @override
  String get actionConnectSftp => 'Sambung SFTP';

  @override
  String get vaultChipLocked => 'Vault terkunci';

  @override
  String get vaultChipOpen => 'Vault terbuka';

  @override
  String get vaultChipLockedHint => 'Vault terkunci. Ketuk untuk membuka dengan biometrik.';

  @override
  String get vaultChipOpenHint => 'Vault terbuka. Ketuk untuk mengunci.';

  @override
  String get vaultChipAlwaysOpenHint => 'Vault terbuka permanen. Ketuk untuk keterangan.';

  @override
  String get vaultUnlockReason => 'Buka vault supaya host tersambung tanpa prompt';

  @override
  String get vaultUnlockedToast => 'Vault terbuka sampai layar mati';

  @override
  String get vaultLockedToast => 'Vault terkunci';

  @override
  String get vaultUnlockFailedToast => 'Vault tetap terkunci';

  @override
  String get vaultAlwaysOpenToast => 'Vault terbuka permanen. Matikan di Pengaturan, bagian Keamanan.';

  @override
  String get settingsSecuritySection => 'Keamanan';

  @override
  String get settingsVaultAlwaysOpenLabel => 'Jangan kunci vault';

  @override
  String get settingsVaultAlwaysOpenDesc =>
      'Host tersambung tanpa biometrik atau PIN. Siapa pun yang memegang HP yang sedang terbuka bisa menyambung ke semua server Anda.';

  @override
  String get vaultAlwaysOpenConfirmTitle => 'Jangan kunci vault?';

  @override
  String get vaultAlwaysOpenConfirmBody =>
      'Password dan kunci privat tetap terenkripsi, tetapi aplikasi akan memakainya tanpa meminta biometrik atau PIN. Bila HP hilang saat terbuka, server Anda ikut terbuka. Anda bisa mematikannya kapan saja.';

  @override
  String get vaultAlwaysOpenConfirmAction => 'Jangan kunci';

  @override
  String get vaultAlwaysOpenReason => 'Konfirmasi untuk tidak mengunci vault';

  @override
  String get vaultAlwaysOpenAuthFailed => 'Dibatalkan. Vault tetap terkunci.';

  @override
  String get settingsDangerTag => 'Berisiko';

  @override
  String get importAction => 'Impor profil';

  @override
  String get importTitle => 'Impor profil';

  @override
  String get importConfirm => 'Impor';

  @override
  String get importReadFailed => 'Berkas tidak bisa dibaca.';

  @override
  String get importNothing => 'Tidak ada profil yang bisa diimpor dari berkas ini.';

  @override
  String get importKeepNote => 'Profil yang sudah ada di HP tidak dihapus. Password dan kunci tidak ikut terimpor.';

  @override
  String importAdded(int n) {
    return '$n profil baru ditambahkan';
  }

  @override
  String importUpdated(int n) {
    return '$n profil diperbarui';
  }

  @override
  String importCopied(int n) {
    return '$n profil disimpan sebagai salinan';
  }

  @override
  String importSkipped(int n) {
    return '$n profil dilewati karena sudah ada';
  }

  @override
  String importRejected(int n) {
    return '$n entri tidak valid dan dilewati';
  }

  @override
  String importRejectedItem(int index, String name, String reason) {
    return '#$index $name: $reason';
  }

  @override
  String importAgentNote(int n) {
    return '$n profil memakai agen SSH dan perlu dilengkapi di HP sebelum bisa tersambung.';
  }

  @override
  String get importConflictLabel => 'Bila profil sudah ada di HP';

  @override
  String get importConflictSkip => 'Lewati';

  @override
  String get importConflictUpdate => 'Perbarui';

  @override
  String get importConflictCopy => 'Salinan';

  @override
  String importWarnJump(String name) {
    return '$name: jump host tidak ditemukan, dikosongkan.';
  }

  @override
  String importWarnKeyPath(String name) {
    return '$name: path kunci dari perangkat asal dibuang, impor kunci lagi di HP.';
  }

  @override
  String importDone(int n) {
    return 'Diimpor · $n profil';
  }

  @override
  String get importNoChange => 'Tidak ada perubahan';

  @override
  String get importFailed => 'Impor gagal. Daftar host tidak berubah.';

  @override
  String get hostFavoriteLabel => 'Favorit';

  @override
  String get exportAction => 'Ekspor profil';

  @override
  String get exportTitle => 'Ekspor profil';

  @override
  String get exportConfirm => 'Bagikan';

  @override
  String exportCount(int n) {
    return '$n profil akan diekspor';
  }

  @override
  String get exportNote =>
      'Berkas JSON ini bisa diimpor lagi di HP atau dimuat TermUL desktop. Menu bagikan Android akan terbuka: kirim ke aplikasi lain atau simpan ke penyimpanan. Password, passphrase, dan kunci tidak ikut.';

  @override
  String exportKeyConverted(int n) {
    return '$n profil memakai kunci yang tersimpan di HP. Di berkas ekspor metodenya menjadi agen SSH supaya desktop tetap bisa memuat berkas ini; lengkapi kuncinya di desktop.';
  }

  @override
  String get exportNothing => 'Belum ada profil untuk diekspor.';

  @override
  String get exportFailed => 'Ekspor gagal. Menu bagikan tidak bisa dibuka; coba lagi.';

  @override
  String get snippetsAdd => 'Snippet baru';

  @override
  String get snippetsSearchLabel => 'Cari snippet';

  @override
  String get snippetsSearchPlaceholder => 'Cari judul atau perintah';

  @override
  String get snippetsNoMatch => 'Tidak ada snippet yang cocok. Ubah kata kunci atau filter.';

  @override
  String get snippetsEmptyTitle => 'Belum ada snippet';

  @override
  String get snippetsEmptyBody =>
      'Simpan perintah yang sering dipakai di sini, lengkap dengan variabel yang diisi saat dipakai.';

  @override
  String get snippetsCorruptTitle => 'Daftar snippet rusak';

  @override
  String snippetsCorruptBody(String name) {
    return 'Berkas snippet tidak bisa dibaca dan disimpan sebagai $name. Aplikasi mulai dari daftar kosong; berkas lama tidak dihapus.';
  }

  @override
  String get snippetScopeAll => 'Semua host';

  @override
  String snippetVarCount(int count) {
    return '$count variabel';
  }

  @override
  String get snippetFavoriteLabel => 'Favorit';

  @override
  String get snippetDetailVariable => 'Isi nilai';

  @override
  String get snippetDetailRisky =>
      'Perintah berbahaya. Periksa dulu sebelum dipakai: tempel, periksa, lalu tekan Enter sendiri.';

  @override
  String get snippetDetailNotReady => 'Isi semua variabel untuk menempel atau menyalin.';

  @override
  String get snippetDetailCopy => 'Salin';

  @override
  String get snippetDetailEdit => 'Edit';

  @override
  String snippetCopied(int count) {
    return 'Disalin · $count karakter';
  }

  @override
  String get snippetEditorNewTitle => 'Snippet baru';

  @override
  String get snippetEditorEditTitle => 'Edit snippet';

  @override
  String get snippetFieldTitle => 'Judul';

  @override
  String get snippetFieldTitlePlaceholder => 'Mis. Cek config lalu reload Nginx';

  @override
  String snippetFieldCommand(String example) {
    return 'Perintah (boleh beberapa baris; variabel ditulis $example)';
  }

  @override
  String get snippetFieldCategory => 'Kategori';

  @override
  String get snippetFieldScope => 'Berlaku untuk';

  @override
  String get snippetScopeOneHost => 'Satu host';

  @override
  String get snippetScopePickTitle => 'Pilih host';

  @override
  String get snippetFavoriteToggle => 'Tandai favorit';

  @override
  String get snippetSaved => 'Snippet disimpan';

  @override
  String get snippetSaveFailed => 'Snippet tidak bisa disimpan. Coba lagi.';

  @override
  String snippetDeleteTitle(String title) {
    return 'Hapus $title?';
  }

  @override
  String get snippetDeleteBody => 'Snippet ini dihapus permanen dari perangkat.';

  @override
  String get snippetDeleted => 'Snippet dihapus';

  @override
  String get snippetDeleteFailed => 'Snippet tidak bisa dihapus. Coba lagi.';

  @override
  String get snippetCategoryNone => 'Tanpa kategori';

  @override
  String get snippetsManageCategories => 'Kelola kategori';

  @override
  String get categoryManagerTitle => 'Kelola kategori';

  @override
  String get categoryManagerEmpty => 'Belum ada kategori. Tambahkan satu untuk mengelompokkan snippet.';

  @override
  String categoryCount(int count) {
    return '$count snippet';
  }

  @override
  String get categoryAdd => 'Kategori baru';

  @override
  String categoryEditLabel(String name) {
    return 'Ubah $name';
  }

  @override
  String categoryDeleteLabel(String name) {
    return 'Hapus $name';
  }

  @override
  String get categoryNameLabel => 'Nama kategori';

  @override
  String get categoryNewTitle => 'Kategori baru';

  @override
  String get categoryRenameTitle => 'Ubah kategori';

  @override
  String get categoryNameTaken => 'Nama kategori sudah dipakai.';

  @override
  String categoryNameTooLong(int max) {
    return 'Nama kategori maksimal $max karakter.';
  }

  @override
  String categoryDeleteTitle(String name) {
    return 'Hapus kategori $name?';
  }

  @override
  String categoryDeleteBodyUsed(int count) {
    return '$count snippet di dalamnya dipindah ke Tanpa kategori; snippet tidak ikut terhapus.';
  }

  @override
  String get categoryDeleteBodyEmpty => 'Kategori ini dihapus dari perangkat.';

  @override
  String get categorySaved => 'Kategori disimpan';

  @override
  String get categoryDeleted => 'Kategori dihapus';

  @override
  String get categorySaveFailed => 'Kategori tidak bisa disimpan. Coba lagi.';

  @override
  String get categoryDeleteFailed => 'Kategori tidak bisa dihapus. Coba lagi.';

  @override
  String get categoryManagerHint =>
      'Tahan dan geser ikon titik di kiri untuk mengubah urutan. Urutan ini dipakai di filter dan di editor.';

  @override
  String categoryDragLabel(String name) {
    return 'Geser untuk mengurutkan $name';
  }

  @override
  String get categoryMoveFailed => 'Urutan kategori tidak bisa disimpan. Coba lagi.';

  @override
  String get snippetDangerousTag => 'berbahaya';

  @override
  String get snippetDangerousToggle => 'Tandai sebagai perintah berbahaya';

  @override
  String get snippetDangerousDesc => 'Setiap kali dipakai, aplikasi memperingatkan dulu dan meminta Anda memastikan.';

  @override
  String get snippetDangerousDescAuto =>
      'Perintah ini juga terdeteksi berbahaya (mis. rm -rf, dd, mkfs), jadi peringatan tetap muncul walau penanda ini mati.';

  @override
  String get snippetDangerWarnTitle => 'Perintah berbahaya';

  @override
  String get snippetDangerWarnBody =>
      'Perintah ini bisa merusak data atau layanan di server bila salah dipakai. Periksa isinya sebelum menyalin dan menjalankannya.';

  @override
  String get snippetDangerWarnConfirm => 'Tetap salin';

  @override
  String get snippetsSort => 'Urutkan snippet';

  @override
  String get snippetsSortDone => 'Selesai mengurutkan';

  @override
  String get snippetsSortHint =>
      'Tahan dan geser ikon titik di kiri untuk mengubah urutan snippet. Semua snippet tampil selama mengurutkan.';

  @override
  String snippetsSortDragLabel(String title) {
    return 'Geser untuk mengurutkan $title';
  }

  @override
  String get snippetMoveFailed => 'Urutan snippet tidak bisa disimpan. Coba lagi.';

  @override
  String snippetDeleteLabel(String title) {
    return 'Hapus $title';
  }

  @override
  String snippetPasteTo(String target) {
    return 'Tempel ke $target';
  }

  @override
  String get snippetPasteRun => 'Tempel & jalankan';

  @override
  String snippetPasted(String target) {
    return 'Ditempel ke $target · belum dijalankan';
  }

  @override
  String snippetRan(String target) {
    return 'Dijalankan di $target';
  }

  @override
  String get snippetDangerWarnPaste => 'Tetap tempel';

  @override
  String get keySnippetsAria => 'Snippet';

  @override
  String get snippetPickerEmpty => 'Belum ada snippet untuk host ini. Buat di tab Snippet.';

  @override
  String get snippetPanelManage => 'Kelola semua';
}
