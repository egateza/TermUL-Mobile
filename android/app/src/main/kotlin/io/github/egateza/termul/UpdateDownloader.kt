package io.github.egateza.termul

import android.app.DownloadManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import java.io.File

/**
 * Unduhan APK pembaruan lewat DownloadManager sistem, supaya tetap berjalan walau aplikasi ditutup atau prosesnya
 * dimatikan. Berkas ditulis ke `Android/data/<paket>/files/update/` (DownloadManager tidak bisa menulis ke cache
 * internal). Berkas ini belum dipercaya: Dart menyalinnya ke `cache/update/` sambil memeriksa ukuran dan SHA-256
 * dari manifest bertanda tangan, lalu memeriksa paket dan sertifikat sebelum penginstal dibuka.
 *
 * Satu unduhan aktif dicatat di SharedPreferences (id, versionCode, nama berkas) supaya bisa ditemukan lagi setelah
 * aplikasi dibuka ulang.
 */
object UpdateDownloader {
    private const val PREFS = "termul_update_download"
    private const val KEY_ID = "id"
    private const val KEY_CODE = "versionCode"
    private const val KEY_VERSION = "version"
    private const val KEY_DONE_TITLE = "doneTitle"
    private const val KEY_DONE_TEXT = "doneText"
    private const val KEY_CHANNEL = "channel"
    private const val FOLDER = "update"
    private const val CHANNEL_ID = "pembaruan"
    private const val NOTIFICATION_ID = 31

    private fun manager(context: Context) = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /**
     * Memulai unduhan [url] sebagai [fileName]; unduhan sebelumnya (bila ada) dibatalkan dan berkasnya dihapus.
     * [doneTitle]/[doneText]/[channelName]: teks notifikasi "siap dipasang" (sudah dilokalkan di Dart).
     */
    fun enqueue(
        context: Context,
        url: String,
        fileName: String,
        title: String,
        versionCode: Int,
        version: String,
        doneTitle: String,
        doneText: String,
        channelName: String,
    ): Long {
        require(url.startsWith("https://")) { "hanya https" }
        require(fileName.isNotEmpty() && !fileName.contains('/') && !fileName.contains("..")) { "nama berkas" }
        remove(context)
        val dir = context.getExternalFilesDir(FOLDER) ?: throw IllegalStateException("penyimpanan tidak tersedia")
        File(dir, fileName).delete()
        val request = DownloadManager.Request(Uri.parse(url))
            .setTitle(title)
            // Notifikasi sistem hanya selama berjalan: notifikasi "selesai" bawaannya bisa membuka penginstal tanpa
            // pemeriksaan checksum dan sertifikat; notifikasi selesai dipasang sendiri oleh [DoneReceiver].
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
            .setDestinationInExternalFilesDir(context, FOLDER, fileName)
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(true)
        val id = manager(context).enqueue(request)
        prefs(context).edit()
            .putLong(KEY_ID, id)
            .putInt(KEY_CODE, versionCode)
            .putString(KEY_VERSION, version)
            .putString(KEY_DONE_TITLE, doneTitle)
            .putString(KEY_DONE_TEXT, doneText)
            .putString(KEY_CHANNEL, channelName)
            .apply()
        return id
    }

    /**
     * Keadaan unduhan yang dicatat, atau null bila tidak ada. `status`: pending, running, paused, done, failed, atau
     * missing (dihapus dari DownloadManager, mis. lewat aplikasi Unduhan). `reason`: kode alasan DownloadManager.
     */
    fun active(context: Context): Map<String, Any?>? {
        val p = prefs(context)
        val id = p.getLong(KEY_ID, -1L)
        if (id < 0) return null
        val base = mapOf<String, Any?>("versionCode" to p.getInt(KEY_CODE, 0))
        manager(context).query(DownloadManager.Query().setFilterById(id)).use { c ->
            if (c == null || !c.moveToFirst()) return base + ("status" to "missing")
            val status = when (c.getInt(c.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))) {
                DownloadManager.STATUS_PENDING -> "pending"
                DownloadManager.STATUS_RUNNING -> "running"
                DownloadManager.STATUS_PAUSED -> "paused"
                DownloadManager.STATUS_SUCCESSFUL -> "done"
                else -> "failed"
            }
            val local = c.getString(c.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI))
            val path = local?.let { Uri.parse(it).path }
            return base + mapOf(
                "status" to status,
                "received" to c.getLong(c.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)),
                "total" to c.getLong(c.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)),
                "reason" to c.getInt(c.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON)),
                "path" to path?.takeIf { insideFolder(context, it) },
            )
        }
    }

    /** Membatalkan unduhan yang dicatat (DownloadManager ikut menghapus berkasnya) dan notifikasi selesainya. */
    fun remove(context: Context) {
        val p = prefs(context)
        val id = p.getLong(KEY_ID, -1L)
        if (id >= 0) manager(context).remove(id)
        p.edit().clear().apply()
        context.getExternalFilesDir(FOLDER)?.listFiles()?.forEach { it.delete() }
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(NOTIFICATION_ID)
    }

    private fun insideFolder(context: Context, path: String): Boolean {
        val dir = context.getExternalFilesDir(FOLDER)?.canonicalFile ?: return false
        return File(path).canonicalFile.parentFile == dir
    }

    /** Unduhan selesai saat aplikasi mungkin tertutup: beri tahu bahwa versi baru tinggal diperiksa dan dipasang. */
    private fun notifyDone(context: Context, id: Long) {
        val p = prefs(context)
        if (p.getLong(KEY_ID, -1L) != id) return
        val info = active(context) ?: return
        if (info["status"] != "done") return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!manager.areNotificationsEnabled()) return
        val builder: Notification.Builder
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, p.getString(KEY_CHANNEL, "Pembaruan"), NotificationManager.IMPORTANCE_DEFAULT)
            )
            builder = Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            builder = Notification.Builder(context)
        }
        val open = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
        }
        if (open != null) {
            builder.setContentIntent(
                PendingIntent.getActivity(
                    context, 3, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
            )
        }
        builder
            .setSmallIcon(R.drawable.ic_stat_termul)
            .setColor(context.getColor(R.color.termul_accent))
            .setContentTitle(p.getString(KEY_DONE_TITLE, ""))
            .setContentText(p.getString(KEY_DONE_TEXT, ""))
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_STATUS)
        try {
            manager.notify(NOTIFICATION_ID, builder.build())
        } catch (e: SecurityException) {
            // Izin notifikasi dicabut: lewati, status tetap terlihat di Pengaturan.
        }
    }

    /**
     * `DOWNLOAD_COMPLETE` dikirim DownloadManager ke paket ini walau aplikasi tertutup. Siaran palsu dari aplikasi
     * lain tidak berdampak: id dicocokkan dengan unduhan yang dicatat dan statusnya ditanyakan ke DownloadManager.
     */
    class DoneReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != DownloadManager.ACTION_DOWNLOAD_COMPLETE) return
            val id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L)
            if (id >= 0) notifyDone(context, id)
        }
    }
}
