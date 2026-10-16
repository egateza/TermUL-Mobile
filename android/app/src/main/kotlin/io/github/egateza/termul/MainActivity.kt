package io.github.egateza.termul

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (bukan FlutterActivity) dibutuhkan local_auth untuk prompt biometrik.
class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null
    private var screenChannel: MethodChannel? = null
    private var pendingNotificationResult: MethodChannel.Result? = null

    // Harus didaftarkan sebelum Activity mencapai STARTED, jadi sebagai properti.
    private val notificationPermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) {
            pendingNotificationResult?.success(notificationsEnabled())
            pendingNotificationResult = null
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "io.github.egateza.termul/keepalive")
        channel = ch
        KeepAliveService.onDisconnectAll = {
            runOnUiThread { ch.invokeMethod("disconnectAll", null) }
        }
        ScreenOffTracker.register(this)
        val screen = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "io.github.egateza.termul/screen")
        screenChannel = screen
        screen.setMethodCallHandler { call, result ->
            if (call.method == "screenOffCount") result.success(ScreenOffTracker.count) else result.notImplemented()
        }
        ScreenOffTracker.onScreenOff = { runOnUiThread { screen.invokeMethod("screenOff", null) } }
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    val intent = Intent(this, KeepAliveService::class.java)
                        .setAction(KeepAliveService.ACTION_UPDATE)
                        .putExtra(KeepAliveService.EXTRA_TITLE, call.argument<String>("title"))
                        .putExtra(KeepAliveService.EXTRA_TEXT, call.argument<String>("text"))
                        .putExtra(KeepAliveService.EXTRA_ACTION_LABEL, call.argument<String>("actionLabel"))
                        .putExtra(KeepAliveService.EXTRA_CHANNEL_NAME, call.argument<String>("channelName"))
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
                        else startService(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        // Mis. ForegroundServiceStartNotAllowedException bila aplikasi tidak terlihat.
                        result.error("start_failed", e.javaClass.simpleName, null)
                    }
                }
                "stop" -> {
                    // stopService tidak membuat service baru bila belum berjalan.
                    stopService(Intent(this, KeepAliveService::class.java))
                    result.success(null)
                }
                "notificationsEnabled" -> result.success(notificationsEnabled())
                "requestNotifications" -> {
                    if (notificationsEnabled() || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                        result.success(notificationsEnabled())
                    } else if (pendingNotificationResult != null) {
                        result.error("busy", "Permintaan izin sedang berjalan", null)
                    } else {
                        pendingNotificationResult = result
                        notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
                    }
                }
                "openAppSettings" -> {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        .setData(Uri.fromParts("package", packageName, null))
                    startActivity(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        KeepAliveService.onDisconnectAll = null
        ScreenOffTracker.onScreenOff = null
        screenChannel?.setMethodCallHandler(null)
        screenChannel = null
        channel?.setMethodCallHandler(null)
        channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun notificationsEnabled(): Boolean =
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).areNotificationsEnabled()
}
