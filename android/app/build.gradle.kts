import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Kunci rilis dari android/key.properties (diabaikan git; keystore di %USERPROFILE%\.termul-release\, lihat
// docs/release.md). Semua jenis build (debug, profile, release) ditandatangani kunci ini supaya build uji yang dipasang
// lewat adb bisa menimpa aplikasi rilis di HP dan sebaliknya. Tanpa berkas itu (mis. hasil clone) debug dan profile
// memakai kunci debug, dan build rilis ditolak.
val releaseKey: Properties? = rootProject.file("key.properties").takeIf { it.exists() }?.let { props ->
    Properties().apply { props.inputStream().use { load(it) } }
}

// Versi seperti TermUL desktop: major.minor dari `version` di pubspec.yaml, angka ketiga = jumlah commit
// (`git rev-list --count HEAD`), versionCode = jumlah commit sehingga selalu naik. Working tree yang belum di-commit
// diberi akhiran `-dirty`; skrip rilis menolaknya. Tanpa git, nilai dari pubspec dipakai apa adanya.
fun git(vararg args: String): String? = try {
    providers.exec {
        commandLine("git", *args)
        workingDir = rootProject.projectDir.parentFile
        isIgnoreExitValue = true
    }.standardOutput.asText.get().trim()
} catch (e: Exception) {
    null
}
val commitCount: Int? = git("rev-list", "--count", "HEAD")?.toIntOrNull()
val dirtyTree: Boolean = !git("status", "--porcelain").isNullOrEmpty()
// Build uji lewat adb boleh dipasang berdampingan dengan aplikasi rilis: TERMUL_PREVIEW=true
// memakai application id terpisah dan nama yang jelas. Build biasa tetap memakai id rilis.
val previewBuild: Boolean = providers.environmentVariable("TERMUL_PREVIEW").orNull == "true"

android {
    namespace = "io.github.egateza.termul"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = if (previewBuild) "io.github.egateza.termul.preview" else "io.github.egateza.termul"
        manifestPlaceholders["appLabel"] = if (previewBuild) "TermUL Preview" else "TermUL"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Dikunci 24: local_auth butuh 24 (flutter_secure_storage 23). Keputusan tetap di CLAUDE.md.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        if (commitCount != null) {
            val base = flutter.versionName.split(".").take(2).joinToString(".")
            versionCode = commitCount
            versionName = "$base.$commitCount" + if (dirtyTree) "-dirty" else ""
        } else {
            versionCode = flutter.versionCode
            versionName = flutter.versionName
        }
    }

    signingConfigs {
        if (releaseKey != null) {
            create("release") {
                storeFile = file(releaseKey.getProperty("storeFile"))
                storePassword = releaseKey.getProperty("storePassword")
                keyAlias = releaseKey.getProperty("keyAlias")
                keyPassword = releaseKey.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        // `all` juga mengenai build type `profile` yang ditambahkan plugin Flutter.
        all {
            signingConfig = if (releaseKey != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// Build rilis tidak boleh jatuh ke kunci debug: APK seperti itu tidak bisa menjadi update aplikasi yang terpasang.
if (releaseKey == null) {
    tasks.configureEach {
        if (name == "assembleRelease" || name == "bundleRelease") {
            doFirst {
                throw GradleException(
                    "android/key.properties tidak ada: build rilis harus ditandatangani kunci rilis (docs/release.md)",
                )
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
