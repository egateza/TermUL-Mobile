Bar navigasi bawah dengan ikon dan label untuk tab utama aplikasi.

**Anda menyediakan:** `items` (`[{id, label, icon, href?, badge?}]`), `active` (id aktif) dan `onSelect(id)` bila tab bukan tautan.

- Lima tab: Host, Sesi (dengan lencana jumlah sesi), SFTP, Snippet, Pengaturan. Tab aktif memakai `accent` dan `aria-current="page"`.
- Tinggi item minimal 56px; label tidak lebih dari satu kata.
- Layar terminal tidak memakai bar ini agar ruang terminal maksimal.
- Landscape (tambahan): varian **rel** vertikal di sisi kiri dengan item dan perilaku yang sama, tab dipusatkan, lebar 80px, tinggi tab minimal 48px, tepi kanan 1px `line`; bar bawah hanya di potret (prototipe 1b). Rel dan bar disembunyikan selagi keyboard terbuka.
