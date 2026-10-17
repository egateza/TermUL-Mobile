/// Kunci publik Ed25519 (Base64, 32 byte) untuk memverifikasi `manifest.json.sig` rilis. Pasangan kunci privatnya hanya
/// ada di mesin rilis (`%USERPROFILE%\.termul-release\mobile-update-signing.key`, di luar repo) dan terpisah dari kunci
/// update TermUL desktop. Mengganti nilai ini berarti instalasi lama menolak semua rilis baru (lihat `docs/release.md`,
/// "Kunci penandatangan manifest").
const updatePublicKey = 'fyel7MndsgYV5a7Y06PWjsrNG0MdO0yN2VsDwUS1cVw=';
