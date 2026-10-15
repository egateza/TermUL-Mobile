Chip kecil di header Daftar host: api mini dan jumlah hari, berformat `Nx` atau `N/3` pada dua hari pertama.

**Anda menyediakan:** `count`, `state` (`aktif`, `bara`, `padam`, `beku`, `hangus`) dan `href` atau `onClick` (biasanya membuka layar Streak).

- Angka mengikuti desktop: `11x` untuk streak aktif, `2/3` untuk bara (belum dihitung sebagai streak).
- Warna: tier untuk aktif (`level-n`), `chip-ember` untuk bara, `chip-gray` untuk padam dan hangus, `chip-ice` untuk beku (dengan latar `ice-bg`).
- Nama aksesibilitas menyebut state dalam kata ("Streak 23 hari, api membeku"). Api di dalamnya dekoratif (tidak dibaca).
- Target sentuh minimal 44px; ketukan membuka layar Streak tempat api bisa diketuk untuk dinyalakan atau dipecahkan esnya.
