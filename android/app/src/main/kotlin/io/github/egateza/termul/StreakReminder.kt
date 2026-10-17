package io.github.egateza.termul

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

/**
 * Pengingat streak harian (Pengaturan > Streak > "Pengingat harian"). Dart menentukan waktu berikutnya (pukul 20.00
 * hari ini bila hari ini belum dihitung, selain itu besok) dan teksnya; di sini hanya alarm dan notifikasinya.
 *
 * Alarm memakai `setAndAllowWhileIdle` (inexact, tetap jalan saat Doze, tanpa izin alarm tepat waktu; lihat
 * developer.android.com "Schedule alarms"). Setelah berbunyi, alarm memasang dirinya lagi 24 jam kemudian, jadi
 * pengingat tetap datang tiap hari sampai aplikasi dibuka lagi dan Dart menjadwalkan ulang. Alarm hilang saat HP
 * dimatikan; [StreakReminderReceiver] memasangnya lagi setelah `BOOT_COMPLETED`.
 */
object StreakReminder {
    private const val PREFS = "streak_reminder"
    private const val KEY_AT = "at"
    private const val KEY_TITLE = "title"
    private const val KEY_TEXT = "text"
    private const val KEY_CHANNEL = "channel"
    private const val CHANNEL_ID = "pengingat_streak"
    private const val NOTIFICATION_ID = 2001
    private const val DAY_MS = 24L * 60 * 60 * 1000
    const val ACTION_REMIND = "io.github.egateza.termul.STREAK_REMIND"

    fun schedule(context: Context, atMillis: Long, title: String, text: String, channelName: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong(KEY_AT, atMillis)
            .putString(KEY_TITLE, title)
            .putString(KEY_TEXT, text)
            .putString(KEY_CHANNEL, channelName)
            .apply()
        arm(context, atMillis)
        setBootReceiver(context, true)
        // Aplikasi dibuka: pengingat yang masih tampil sudah tidak perlu.
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(NOTIFICATION_ID)
    }

    fun cancel(context: Context) {
        alarmManager(context).cancel(pendingIntent(context))
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
        setBootReceiver(context, false)
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(NOTIFICATION_ID)
    }

    /** Waktu alarm berikutnya yang tersimpan; 0 bila tidak ada. */
    fun scheduledAt(context: Context): Long =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong(KEY_AT, 0L)

    /** Alarm berbunyi: tampilkan notifikasi lalu pasang lagi untuk hari berikutnya. */
    internal fun fire(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val at = prefs.getLong(KEY_AT, 0L)
        if (at == 0L) return
        show(
            context,
            prefs.getString(KEY_TITLE, "").orEmpty(),
            prefs.getString(KEY_TEXT, "").orEmpty(),
            prefs.getString(KEY_CHANNEL, "").orEmpty(),
        )
        rearm(context)
    }

    /** Setelah HP menyala lagi atau alarm berbunyi: pasang alarm di waktu yang sama berikutnya di masa depan. */
    internal fun rearm(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        var at = prefs.getLong(KEY_AT, 0L)
        if (at == 0L) return
        val now = System.currentTimeMillis()
        while (at <= now) at += DAY_MS
        prefs.edit().putLong(KEY_AT, at).apply()
        arm(context, at)
    }

    private fun arm(context: Context, atMillis: Long) {
        alarmManager(context).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pendingIntent(context))
    }

    private fun show(context: Context, title: String, text: String, channelName: String) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!manager.areNotificationsEnabled()) return
        val builder: Notification.Builder
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, channelName, NotificationManager.IMPORTANCE_DEFAULT)
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
                    context, 2, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
            )
        }
        builder
            .setSmallIcon(R.drawable.ic_stat_streak)
            .setContentTitle(title)
            .setContentText(text)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_REMINDER)
        try {
            manager.notify(NOTIFICATION_ID, builder.build())
        } catch (e: SecurityException) {
            // Izin notifikasi dicabut di antara pemeriksaan dan pengiriman: lewati.
        }
    }

    private fun alarmManager(context: Context) = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private fun pendingIntent(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, StreakReminderReceiver::class.java).setAction(ACTION_REMIND),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

    private fun setBootReceiver(context: Context, enabled: Boolean) {
        context.packageManager.setComponentEnabledSetting(
            ComponentName(context, StreakReminderReceiver::class.java),
            if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP,
        )
    }
}

/** Menerima alarm pengingat dan `BOOT_COMPLETED` (hanya aktif selama pengingat terjadwal). */
class StreakReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            StreakReminder.ACTION_REMIND -> StreakReminder.fire(context)
            Intent.ACTION_BOOT_COMPLETED -> StreakReminder.rearm(context)
        }
    }
}
