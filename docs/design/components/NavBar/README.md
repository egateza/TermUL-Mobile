Bar navigasi bawah dengan ikon dan label untuk tab utama aplikasi.

**Anda menyediakan:** `items` (`[{id, label, icon, href?, badge?}]`), `active` (id aktif) dan `onSelect(id)` bila tab bukan tautan.

- Empat tab: Host, Sesi (dengan lencana jumlah sesi, terminal dan SFTP), Snippet, Pengaturan (tab SFTP dihapus 2026-10-17). Tab aktif memakai `accent` dan `aria-current="page"`.
- Tinggi item minimal 56px; label tidak lebih dari satu kata.
- Layar terminal tidak memakai bar ini agar ruang terminal maksimal.
- Landscape (tambahan): varian **rel** vertikal di sisi kiri dengan item dan perilaku yang sama, tab dipusatkan, lebar 80px, tinggi tab minimal 48px, tepi kanan 1px `line`; bar bawah hanya di potret (prototipe 1b; landscape tidak aktif, aplikasi hanya potret). Rel dan bar disembunyikan selagi keyboard terbuka.
