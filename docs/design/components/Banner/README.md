Pesan sebaris berwarna nada untuk menjelaskan keadaan atau risiko di dalam layar.

**Anda menyediakan:** `tone` (`info`, `warn`, `risk`, `ice`, `ok`), `title` opsional, `children` (satu atau dua kalimat), `icon` untuk menimpa ikon bawaan dan `action` (biasanya satu `Button` `sm`).

- `risk` dipakai untuk tindakan yang bisa merugikan dan diumumkan sebagai peringatan; jelaskan baris atau perintah mana yang berisiko dan apa akibatnya.
- `warn` untuk koneksi terputus atau menunggu; `ice` untuk api beku; `ok` untuk hasil berhasil yang menetap.
- Banner tidak menggantikan toast: bila hanya konfirmasi sesaat, pakai `Toast`.
- Layar pendek (tinggi kurang dari 480px, mis. landscape; tambahan): susunan mendatar, `action` di kanan teks, padding 10px. Bila keyboard terbuka, hanya `title` dan `action` (padding vertikal 4px); `children` disembunyikan sampai keyboard ditutup. Digambar di prototipe 2n.
