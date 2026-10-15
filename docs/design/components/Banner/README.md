Pesan sebaris berwarna nada untuk menjelaskan keadaan atau risiko di dalam layar.

**Anda menyediakan:** `tone` (`info`, `warn`, `risk`, `ice`, `ok`), `title` opsional, `children` (satu atau dua kalimat), `icon` untuk menimpa ikon bawaan dan `action` (biasanya satu `Button` `sm`).

- `risk` dipakai untuk tindakan yang bisa merugikan dan diumumkan sebagai peringatan; jelaskan baris atau perintah mana yang berisiko dan apa akibatnya.
- `warn` untuk koneksi terputus atau menunggu; `ice` untuk api beku; `ok` untuk hasil berhasil yang menetap.
- Banner tidak menggantikan toast: bila hanya konfirmasi sesaat, pakai `Toast`.
