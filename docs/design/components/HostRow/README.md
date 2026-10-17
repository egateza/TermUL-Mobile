Baris daftar satu host: titik status, nama, user@alamat dan status.

**Anda menyediakan:** `name`, `target` (mis. `deploy@10.0.1.11`), `status` (`online`, `offline`, `busy`), `latency` (ms, hanya saat online) dan `href` atau `onClick`.

- Seluruh baris adalah target sentuh, minimal 64px.
- Nama memakai `title`, alamat memakai gaya mono redup, status memakai mono 12px dengan kata ("online · 18 ms", "tidak terjangkau").
- Urutan dan pengelompokan (Produksi, Staging, Lab) diatur oleh daftar, bukan baris.
- Host favorit (tambahan, 2026-10-17): bintang terisi `accent` 14px di sebelah kanan nama (ikon `star`, nama tetap terpotong dengan elipsis, bintang tidak). Nama aksesibilitas baris memuat kata "Favorit" setelah nama. Prop `favorite` (bawaan salah).
