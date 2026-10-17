<#
.SYNOPSIS
  Build, tandatangani, dan terbitkan rilis TermUL Mobile ke GitHub Releases (padanan tools\release.ps1 TermUL desktop).

.DESCRIPTION
  1. Memeriksa: catatan rilis ada, working tree bersih, commit sudah di-push, tag v<versi> belum ada.
  2. flutter build apk --release (versi = major.minor dari pubspec.yaml + jumlah commit; lihat android/app/build.gradle.kts).
  3. Memastikan versi di dalam APK sama, dan APK ditandatangani kunci rilis (sidik jari sertifikat di bawah), bukan debug.
  4. tool/release_manifest.dart: manifest.json + manifest.json.sig (Ed25519) + termul-mobile-<versi>.apk di build\release.
  5. gh release create v<versi> dengan ketiga aset tersebut.

  Butuh: Flutter di PATH, GitHub CLI (winget install GitHub.cli; gh auth login), android\key.properties dengan keystore
  rilis, dan private key manifest di ~\.termul-release\mobile-update-signing.key (atau env TERMUL_MOBILE_UPDATE_KEY).
  Jangan memanggil skrip ini dengan 2>&1: di Windows PowerShell 5.1 stderr perintah native menjadi galat.

.EXAMPLE
  .\tool\release.ps1 -NotesFile C:\tmp\notes.txt
  .\tool\release.ps1 -NotesFile C:\tmp\notes.txt -Draft   # periksa dulu di GitHub, lalu Publish manual
#>
param(
    [Parameter(Mandatory = $true)][string]$NotesFile,
    [switch]$Draft,
    [switch]$AllowDirty
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# SHA-256 sertifikat kunci rilis (publik; sama dengan docs/release.md). Diganti hanya bila kunci rilis diganti.
$expectedCert = '6fb45512fac9368cd5c2cc50344b9b79b7bb89d70d126687ab4af45cb76b8c54'

function Fail([string]$message) {
    Write-Host "GAGAL: $message" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $NotesFile)) { Fail "File catatan rilis tidak ada: $NotesFile" }
$NotesFile = (Resolve-Path $NotesFile).Path
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Fail "GitHub CLI (gh) belum terpasang: winget install GitHub.cli, lalu gh auth login"
}
if (-not (Test-Path (Join-Path $root 'android\key.properties'))) {
    Fail "android\key.properties tidak ada: build rilis butuh keystore rilis (docs/release.md)"
}

# Versi = jumlah commit: rilis harus dari commit yang bersih dan sudah di-push
$dirty = git status --porcelain
if ($dirty -and -not $AllowDirty) { Fail "Working tree belum bersih. Commit dulu (atau -AllowDirty untuk uji)." }
$commit = (git rev-parse HEAD).Trim()
$remoteBranches = git branch -r --contains $commit
if (-not $remoteBranches) { Fail "Commit $commit belum ada di remote. git push dulu." }
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne 'master') {
    Write-Host "Peringatan: rilis dari branch '$branch', bukan master. Versi (jumlah commit) bisa lebih kecil dari rilis sebelumnya dan ditolak sebagai downgrade." -ForegroundColor Yellow
}

$count = [int](git rev-list --count HEAD).Trim()
$pubspec = Select-String -Path (Join-Path $root 'pubspec.yaml') -Pattern '^version:\s*(\d+)\.(\d+)' | Select-Object -First 1
if (-not $pubspec) { Fail "Tidak bisa membaca version di pubspec.yaml" }
$version = "$($pubspec.Matches[0].Groups[1].Value).$($pubspec.Matches[0].Groups[2].Value).$count"
$tag = "v$version"
if (git ls-remote --tags origin "refs/tags/$tag") { Fail "Tag $tag sudah ada. Buat commit baru (versi naik), lalu ulangi." }

& flutter build apk --release
if ($LASTEXITCODE -ne 0) { Fail "flutter build apk --release gagal" }
$apk = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) { Fail "APK tidak ditemukan: $apk" }

# Android SDK: ANDROID_HOME, ANDROID_SDK_ROOT, atau sdk.dir di android\local.properties
$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
if (-not $sdk) {
    $line = Select-String -Path (Join-Path $root 'android\local.properties') -Pattern '^sdk\.dir=(.*)$' | Select-Object -First 1
    if ($line) { $sdk = $line.Matches[0].Groups[1].Value -replace '\\\\', '\' -replace '\\:', ':' }
}
if (-not $sdk -or -not (Test-Path $sdk)) { Fail "Android SDK tidak ditemukan (set ANDROID_HOME)" }
$buildTools = Get-ChildItem (Join-Path $sdk 'build-tools') -Directory | Sort-Object { [version]($_.Name -replace '[^0-9.].*$', '') } | Select-Object -Last 1
if (-not $buildTools) { Fail "build-tools tidak ada di $sdk" }

# Versi di dalam APK harus sama dengan yang akan diterbitkan
$badging = & (Join-Path $buildTools.FullName 'aapt2.exe') dump badging $apk | Select-String '^package:' | Select-Object -First 1
if (-not $badging) { Fail "aapt2 tidak bisa membaca APK" }
$apkCode = [regex]::Match($badging.Line, "versionCode='(\d+)'").Groups[1].Value
$apkName = [regex]::Match($badging.Line, "versionName='([^']*)'").Groups[1].Value
if ($apkCode -ne "$count") { Fail "versionCode APK $apkCode, seharusnya $count" }
if ($apkName -ne $version -and -not $AllowDirty) { Fail "versionName APK $apkName, seharusnya $version" }

# Tanda tangan rilis, bukan debug
$certs = & (Join-Path $buildTools.FullName 'apksigner.bat') verify --print-certs $apk
if ($LASTEXITCODE -ne 0) { Fail "apksigner verify gagal" }
$digests = @($certs | Select-String 'certificate SHA-256 digest: ([0-9a-f]+)' | ForEach-Object { $_.Matches[0].Groups[1].Value })
if ($digests.Count -ne 1 -or $digests[0] -ne $expectedCert) {
    Fail "APK tidak ditandatangani kunci rilis (sertifikat: $($digests -join ', ')). Periksa android\key.properties."
}
Write-Host "APK $version (versionCode $count) ditandatangani kunci rilis" -ForegroundColor Green

$out = Join-Path $root 'build\release'
& dart run tool/release_manifest.dart publish --apk $apk --version $version --code $count --notes $NotesFile --out $out --commit $commit
if ($LASTEXITCODE -ne 0) { Fail "release_manifest publish gagal" }
& dart run tool/release_manifest.dart verify --dir $out
if ($LASTEXITCODE -ne 0) { Fail "release_manifest verify gagal" }

$assets = @(Get-ChildItem $out -File | ForEach-Object { $_.FullName })
Write-Host "Menerbitkan $tag ($($assets.Count) aset) dari commit $commit"
$ghArgs = @('release', 'create', $tag) + $assets + @('--title', "TermUL Mobile $version", '--notes-file', $NotesFile,
    '--target', $commit)
if ($Draft) { $ghArgs += '--draft' }
& gh @ghArgs
if ($LASTEXITCODE -ne 0) { Fail "gh release create gagal" }
Write-Host "Selesai: $tag" -ForegroundColor Green
