/// Jenis rahasia per profil. Kode 1 sampai 4 sama dengan desktop (`SecretType` di modul vault) dan tidak
/// boleh diubah urutannya. Kode 5 hanya ada di mobile: di desktop kunci privat berupa berkas (`privateKeyPath`),
/// di HP isinya disimpan di vault. Bila `vault.bin` kelak dibagi, desktop harus mentoleransi kode asing.
enum SecretType {
  loginPassword(1, 'LOGIN_PASSWORD'),
  keyPassphrase(2, 'KEY_PASSPHRASE'),
  sudoPassword(3, 'SUDO_PASSWORD'),
  rootPassword(4, 'ROOT_PASSWORD'),
  privateKeyPem(5, 'PRIVATE_KEY_PEM');

  const SecretType(this.code, this.wire);

  final int code;

  /// Nama yang ikut dihash menjadi nama kunci penyimpanan.
  final String wire;
}
