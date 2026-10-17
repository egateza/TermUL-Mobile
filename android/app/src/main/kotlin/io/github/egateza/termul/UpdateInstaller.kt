package io.github.egateza.termul

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File

/**
 * Pembaruan dari GitHub Releases: versi terpasang, izin "Pasang aplikasi tidak dikenal", dan membuka penginstal
 * sistem untuk APK di `cache/update/` (lihat `res/xml/share_paths.xml`). Android selalu meminta konfirmasi pengguna
 * dan menolak APK yang tanda tangannya berbeda dari aplikasi terpasang.
 */
object UpdateInstaller {
    private const val APK_MIME = "application/vnd.android.package-archive"

    fun version(context: Context): Map<String, Any> {
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.packageManager.getPackageInfo(context.packageName, android.content.pm.PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(context.packageName, 0)
        }
        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode.toInt()
        } else {
            @Suppress("DEPRECATION")
            info.versionCode
        }
        return mapOf("name" to (info.versionName ?: "?"), "code" to code)
    }

    /** Android 7 (API 24-25) memakai saklar global "Sumber tidak dikenal"; penginstal menanyakannya sendiri. */
    fun canInstall(context: Context): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.packageManager.canRequestPackageInstalls() else true

    fun openInstallSettings(activity: Activity) {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}"))
        } else {
            Intent(Settings.ACTION_SECURITY_SETTINGS)
        }
        activity.startActivity(intent)
    }

    fun install(activity: Activity, path: String) {
        val file = File(path)
        val folder = File(activity.cacheDir, "update").canonicalFile
        require(file.canonicalFile.parentFile == folder) { "APK di luar cache/update" }
        require(file.isFile) { "APK tidak ada" }
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.fileprovider", file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, APK_MIME)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(intent)
    }
}
