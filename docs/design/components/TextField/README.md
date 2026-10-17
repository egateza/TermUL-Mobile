Kolom input satu baris dengan label, ikon awal opsional dan tepi `line-strong`.

**Anda menyediakan:** `label` (wajib; `hideLabel` untuk menyembunyikannya secara visual tetapi tetap dibaca pembaca layar), `value` atau `defaultValue`, `placeholder`, `onChange`, `icon` opsional dan `mono` untuk isi teknis (variabel, host, perintah).

- Tinggi 48px; fokus menampilkan cincin `accent`.
- Placeholder memakai `ink-faint`; jangan memakainya untuk informasi penting.
- Pencarian: `icon="search"`, `hideLabel`, placeholder yang menyebut apa yang dicari.
- Pencarian (tambahan, 2026-10-17): selama kolom berisi teks, tombol **x** 44px (`aria-label` "Hapus pencarian") muncul menempel di pojok kanan kolom; mengetuknya mengosongkan kolom dan menampilkan daftar penuh lagi, fokus dan keyboard tetap. Berlaku untuk semua kolom pencarian (Host, Snippet). Di aplikasi Flutter: parameter `clearLabel` pada `TermulTextField`; belum ada di komponen web. Prototipe `Main` dan `Snippets` memuatnya (ketik sesuatu di kolom cari); `MainLandscape` statis dan tidak memperlihatkannya.
