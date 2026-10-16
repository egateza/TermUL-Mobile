Baris pengaturan untuk mengubah satu angka dalam rentang kecil dengan dua tombol, kurangi dan tambah (ukuran font, tinggi baris).

**Anda menyediakan:** `label`, `valueText` (nilai dengan satuannya), `decrementLabel`, `incrementLabel`, `onDecrement` dan `onIncrement`.

- Dua tombol persegi 44px (`tap-min`) dengan radius `radius-md`, isian `surface-raised`, tepi `line`; menekan = isian `accent-bg` dan tepi `accent`. Baris minimal `row-min` (56px), dengan tepi atas 1px `line` sebagai pemisah dalam kartu.
- Nilai di antara tombol bergaya `key` (mono) dan memuat satuannya: "13 px", "1,3×". Angka saja tidak cukup.
- Di batas rentang, tombol yang tak bisa dilanjutkan nonaktif (opasitas 0,4; `onDecrement` atau `onIncrement` kosong). Jangan menjepit diam-diam.
- Label tombol menyebut arah dan objeknya ("Kecilkan font", "Rapatkan baris"), bukan "−" atau "+". Nilai diumumkan ke pembaca layar saat berubah.
- Perubahan berlaku seketika dan tersimpan; tidak ada tombol "Simpan". Tampilkan pratinjau di atas baris bila hasilnya visual.
- Rentang dan langkah yang dipakai aplikasi: ukuran font 8 sampai 24 px langkah 1 (bawaan 13); tinggi baris 1,0 sampai 2,0 langkah 0,1 (bawaan 1,3).
- Belum ada di `bundle.js` dan `index.d.ts` (kode web). Rujukan visualnya adalah baris "Ukuran font" dan "Tinggi baris" di prototipe `Settings`.
