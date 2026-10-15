Permukaan terminal yang menampilkan baris berwarna: prompt, path, teks, output redup, bahaya, teks terpilih dan kursor.

**Anda menyediakan:** `lines` (`[{parts:[{t, tone}], cursor?}]` dengan `tone` `prompt`, `path`, `text`, `muted`, `danger`, `selected`), `fontSize` (10-20) dan `dim` untuk meredupkan saat koneksi terputus.

- Komponen ini untuk tampilan statis (pratinjau, dialog, dokumentasi); terminal sungguhan dirender oleh mesin terminal, yang memakai token `terminal-*` yang sama.
- Teks terpilih memakai `terminal-selection` dan menimpa semua warna dengan `terminal-selection-ink`.
- Latar `ground-deep`; teks biasa `terminal-ink`.
