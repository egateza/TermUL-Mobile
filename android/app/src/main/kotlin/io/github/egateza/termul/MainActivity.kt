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
    private var downloadsChannel: MethodChannel? = null
    private var reminderChannel: MethodChannel? = null
    private var updateChannel: MethodChannel? = null
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
        val downloads = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "io.github.egateza.termul/downloads")
        downloadsChannel = downloads
        downloads.setMethodCallHandler { call, result ->
            val name = call.argument<String>("name")
            if (name == null) {
                result.error("bad_args", "name wajib", null)
                return@setMethodCallHandler
            }
            val folder = call.argument<String>("folder")
            when (call.method) {
                "folderExists" -> Thread {
                    try {
                        val found = DownloadsSaver.folderExists(applicationContext, name)
                        runOnUiThread { result.success(found) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("exists_failed", e.javaClass.simpleName, null) }
                    }
                }.start()
                "exists" -> Thread {
                    try {
                        val found = DownloadsSaver.exists(applicationContext, name, folder)
                        runOnUiThread { result.success(found) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("exists_failed", e.javaClass.simpleName, null) }
                    }
                }.start()
                "save" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("bad_args", "path wajib", null)
                        return@setMethodCallHandler
                    }
                    val overwrite = call.argument<Boolean>("overwrite") ?: false
                    // Berkas bisa ratusan MB: salin di thread latar belakang, jawab di thread utama.
                    Thread {
                        try {
                            val saved = DownloadsSaver.save(applicationContext, path, name, overwrite, folder)
                            runOnUiThread {
                                result.success(
                                    mapOf("name" to saved.name, "location" to saved.location, "overwritten" to saved.overwritten),
                                )
                            }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("save_failed", e.javaClass.simpleName, null) }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
        val reminder = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "io.github.egateza.termul/reminder")
        reminderChannel = reminder
        reminder.setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> {
                    val at = call.argument<Number>("at")?.toLong()
                    val title = call.argument<String>("title")
                    val text = call.argument<String>("text")
                    val channelName = call.argument<String>("channelName")
                    if (at == null || title == null || text == null || channelName == null) {
                        result.error("bad_args", "at, title, text, dan channelName wajib", null)
                    } else {
                        StreakReminder.schedule(applicationContext, at, title, text, channelName)
                        result.success(null)
                    }
                }
                "cancel" -> {
                    StreakReminder.cancel(applicationContext)
                    result.success(null)
                }
                "scheduledAt" -> result.success(StreakReminder.scheduledAt(applicationContext))
                else -> result.notImplemented()
            }
        }
        val update = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "io.github.egateza.termul/update")
        updateChannel = update
        update.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "version" -> result.success(UpdateInstaller.version(applicationContext))
                    "canInstall" -> result.success(UpdateInstaller.canInstall(applicationContext))
                    "openInstallSettings" -> {
                        UpdateInstaller.openInstallSettings(this)
                        result.success(null)
                    }
                    "install" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("bad_args", "path wajib", null)
                        } else {
                            UpdateInstaller.install(this, path)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("update_failed", e.javaClass.simpleName, null)
            }
        }
        val share = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "io.github.egateza.termul/share")
        share.setMethodCallHandler { call, result ->
            if (call.method != "shareFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            val name = call.argument<String>("name")
            val mime = call.argument<String>("mimeType")
            if (path == null || name == null || mime == null) {
                result.error("bad_args", "path, name, dan mimeType wajib", null)
                return@setMethodCallHandler
            }
            try {
                FileSharer.share(this, path, name, mime, call.argument<String>("title"))
                result.success(null)
            } catch (e: Exception) {
                result.error("share_failed", e.javaClass.simpleName, null)
            }
        }
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
        downloadsChannel?.setMethodCallHandler(null)
        downloadsChannel = null
        reminderChannel?.setMethodCallHandler(null)
        reminderChannel = null
        updateChannel?.setMethodCallHandler(null)
        updateChannel = null
        channel?.setMethodCallHandler(null)
        channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun notificationsEnabled(): Boolean =
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).areNotificationsEnabled()
}
