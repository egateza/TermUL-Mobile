# TermUL Mobile

Klien SSH pribadi untuk Android, dibuat dengan Flutter. Pendampingnya adalah TermUL desktop (`egateza/TermUL`).

- Android saja (`minSdk` 24). iOS tidak diuji dan tidak didukung.
- Aturan proyek dan keputusan tetap: [CLAUDE.md](CLAUDE.md).
- Rencana implementasi: [docs/implementation-plan.md](docs/implementation-plan.md).
- Dokumentasi desain dan hasil spike: [docs/design/](docs/design/) (asal: [SUMBER.md](docs/design/SUMBER.md)).
- Lisensi dependensi: [docs/licenses.md](docs/licenses.md).

## Menjalankan

```
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter run            # HP Android fisik, bukan emulator, untuk jaringan, keyboard, dan biometrik
```

Jangan memasukkan kredensial server, kunci privat, atau token ke repo, termasuk contoh dan tes.
