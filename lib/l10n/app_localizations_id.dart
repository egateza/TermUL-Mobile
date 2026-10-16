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
  String get hostsOpenSettings => 'Pengaturan';

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
}
