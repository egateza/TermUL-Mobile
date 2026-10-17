package io.github.egateza.termul

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Foreground service yang hanya menahan proses aplikasi supaya tidak berstatus cached selama ada sesi SSH
 * aktif (Android membekukan proses cached lalu menutup soket TCP-nya). Service ini tidak membuka sambungan
 * apa pun; soket tetap milik kode Dart. Seluruh teks dikirim dari Dart (sudah berbahasa Indonesia).
 *
 * START_NOT_STICKY: bila proses dimatikan sistem, sesi di Dart ikut hilang, jadi service tidak boleh bangkit
 * sendiri tanpa sesi.
 */
class KeepAliveService : Service() {
    companion object {
        const val ACTION_UPDATE = "io.github.egateza.termul.KEEPALIVE_UPDATE"
        const val ACTION_STOP = "io.github.egateza.termul.KEEPALIVE_STOP"
        const val ACTION_DISCONNECT_ALL = "io.github.egateza.termul.KEEPALIVE_DISCONNECT_ALL"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_ACTION_LABEL = "actionLabel"
        const val EXTRA_CHANNEL_NAME = "channelName"
        private const val CHANNEL_ID = "sesi_aktif"
        private const val NOTIFICATION_ID = 1001

        /** Diisi MainActivity selama mesin Flutter hidup; dipanggil saat pengguna mengetuk "Putuskan semua". */
        @Volatile
        var onDisconnectAll: (() -> Unit)? = null
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_UPDATE -> showForeground(intent)
            ACTION_DISCONNECT_ALL -> {
                onDisconnectAll?.invoke()
                stopSelfClean()
            }
            else -> stopSelfClean() // ACTION_STOP atau mulai ulang tanpa perintah
        }
        return START_NOT_STICKY
    }

    private fun stopSelfClean() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun showForeground(intent: Intent) {
        val title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
        val text = intent.getStringExtra(EXTRA_TEXT).orEmpty()
        val actionLabel = intent.getStringExtra(EXTRA_ACTION_LABEL).orEmpty()
        val channelName = intent.getStringExtra(EXTRA_CHANNEL_NAME).orEmpty()
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val builder: Notification.Builder
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Saluran terpisah, prioritas rendah (tanpa bunyi), sesuai android.md.
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, channelName, NotificationManager.IMPORTANCE_LOW)
            )
            builder = Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            builder = Notification.Builder(this).setPriority(Notification.PRIORITY_LOW)
        }

        val flagsImmutable = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        val open = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
        }
        if (open != null) builder.setContentIntent(PendingIntent.getActivity(this, 0, open, flagsImmutable))
        val disconnect = Intent(this, KeepAliveService::class.java).setAction(ACTION_DISCONNECT_ALL)
        val disconnectIntent = PendingIntent.getService(this, 1, disconnect, flagsImmutable)

        builder
            .setSmallIcon(R.drawable.ic_stat_termul)
            .setColor(getColor(R.color.termul_accent))
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .addAction(Notification.Action.Builder(null, actionLabel, disconnectIntent).build())
        val notification = builder.build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }
}
