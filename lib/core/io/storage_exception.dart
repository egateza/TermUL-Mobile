/// Galat penyimpanan berkas (baca, tulis, atau karantina). Pesannya aman ditampilkan; tidak memuat isi berkas.
class StorageException implements Exception {
  const StorageException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'StorageException: $message${cause == null ? '' : ' ($cause)'}';
}
