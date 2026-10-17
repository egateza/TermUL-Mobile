Bar navigasi bawah dengan ikon dan label untuk tab utama aplikasi.

**Anda menyediakan:** `items` (`[{id, label, icon, href?, badge?, dot?, highlight?}]`), `active` (id aktif) dan `onSelect(id)` bila tab bukan tautan.

- Lima tab: Host, Sesi (dengan lencana jumlah sesi, terminal dan SFTP), Snippet, Streak, Pengaturan (tab SFTP dihapus 2026-10-17; Streak ditambah 2026-10-17, sebelum Pengaturan). Tab aktif memakai `accent` dan `aria-current="page"`.
- Tinggi item minimal 56px; label tidak lebih dari satu kata.
- Layar terminal tidak memakai bar ini agar ruang terminal maksimal.
- Landscape (tambahan): varian **rel** vertikal di sisi kiri dengan item dan perilaku yang sama, tab dipusatkan, lebar 80px, tinggi tab minimal 48px, tepi kanan 1px `line`; bar bawah hanya di potret (prototipe 1b; landscape tidak aktif, aplikasi hanya potret). Rel dan bar disembunyikan selagi keyboard terbuka.
- Tambahan (2026-10-17, permintaan pemilik): item boleh punya `highlight` (warna sorot). Ikonnya selalu berwarna itu, dan labelnya berwarna itu saat tab aktif (tidak aktif tetap `ink-muted`). Hanya tab **Streak** yang memakainya: merah api `#FF4D2E` (`level-3`) supaya mencolok dibanding tab lain. Tab lain tetap memakai `accent`. Isi tab Streak adalah layar Streak (prototipe 8); chip streak di header Host juga membuka tab ini. Layar "Segera hadir" (prototipe 15) tidak dipakai lagi.
- Tambahan (2026-10-18): item boleh punya `dot`, **lencana titik** tanpa angka: lingkaran 10px `accent` bertepi 2px `ground` di kanan atas ikon. Dipakai tab **Pengaturan** selama ada versi baru yang belum dipasang (prototipe 6c dan 6d). Titik tidak menyampaikan status sendirian: nama aksesibilitas tab menjadi "Pengaturan, pembaruan tersedia", dan Pengaturan menulis statusnya dengan kata. Lencana angka (`badge`) didahulukan bila keduanya ada.
