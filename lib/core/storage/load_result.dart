/// Hasil memuat penyimpanan. [quarantinedPath] terisi bila berkas rusak dipindahkan dan penyimpanan
/// dimulai dari kosong; UI wajib memberi tahu pengguna supaya mulai-dari-kosong tidak tampak seperti data hilang.
class LoadResult {
  const LoadResult({this.quarantinedPath});

  final String? quarantinedPath;

  bool get hadCorruptFile => quarantinedPath != null;
}
