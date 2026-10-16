package io.github.egateza.termul

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter

/**
 * Mencatat layar mati (`ACTION_SCREEN_OFF`) selama proses hidup. Dart memakainya untuk melepas rahasia yang
 * dipegang di memori (pengguna sudah tidak memakai aplikasi). Penghitung disimpan di sisi Kotlin supaya tetap benar
 * walau Dart sedang dibekukan saat layar mati: Dart membandingkan nilainya saat kembali. Receiver didaftarkan di
 * konteks aplikasi sekali per proses, jadi tidak bergantung pada hidup Activity.
 */
object ScreenOffTracker {
    @Volatile
    var count: Int = 0
        private set

    /** Dipanggil di thread utama saat layar mati; diisi Activity selama engine Flutter hidup. */
    @Volatile
    var onScreenOff: (() -> Unit)? = null

    private var registered = false

    @Synchronized
    fun register(context: Context) {
        if (registered) return
        registered = true
        context.applicationContext.registerReceiver(
            object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    if (intent.action != Intent.ACTION_SCREEN_OFF) return
                    count++
                    onScreenOff?.invoke()
                }
            },
            IntentFilter(Intent.ACTION_SCREEN_OFF),
        )
    }
}
