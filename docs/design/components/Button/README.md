Tombol teks dengan empat varian dan tiga ukuran.

**Anda menyediakan:** `children` (label), `variant` (`primary`, `secondary`, `ghost`, `danger`), `size` (`lg` 52px, `md` 48px, `sm` 44px), `icon` opsional, `href` bila berupa tautan, dan `onClick`.

- Satu `primary` per layar atau sheet. Di dialog berisiko, jadikan pilihan aman (Batal, Batalkan koneksi) sebagai `primary`, dan tindakan berisiko `danger` atau `secondary`.
- `lg` untuk tombol di dasar layar dan sheet; `md` di form; `sm` di baris yang padat. Tidak ada ukuran di bawah 44px.
- Label singkat, tanpa titik; sebut tindakannya ("Tempel", "Salin sebagai satu baris").
- `disabled` menurunkan opasitas menjadi 0,4; jelaskan alasannya di teks bantu bila tidak jelas.
