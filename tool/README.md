# Skrip bantu

- `gen_tokens.py <tokens.json> <keluaran.dart>`: menghasilkan `lib/core/theme/termul_tokens.g.dart` dari `docs/design/tokens.json`.
  Contoh: `python tool/gen_tokens.py docs/design/tokens.json lib/core/theme/termul_tokens.g.dart`.
- `gen_licenses.py <folder-proyek> <keluaran.md>`: memeriksa lisensi semua paket di `pubspec.lock` (berkas LICENSE di pub cache dan tag pub.dev) dan menulis `docs/licenses.md`. Jalur pub cache di dalamnya masih tertulis `D:\dev\pub-cache`; ubah sesuai mesin.
- `ssh_test_server/setup.sh` dan `teardown.sh`: server SSH uji sementara di WSL (jalankan di dalam distro sebagai root). Kredensial dibuat acak dan ditulis hanya ke folder keluaran yang Anda tunjuk; jangan pernah ke repo. Hapus dengan `teardown.sh`.
