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
  String get connectNotAvailable => 'Sambungan belum tersedia di versi ini';
}
