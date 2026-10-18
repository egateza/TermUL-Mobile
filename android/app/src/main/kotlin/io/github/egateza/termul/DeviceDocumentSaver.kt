package io.github.egateza.termul

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.activity.result.ActivityResult
import java.io.IOException

/** Menulis data ekspor ke dokumen yang dipilih pengguna melalui Storage Access Framework. */
object DeviceDocumentSaver {
    fun createIntent(name: String, mimeType: String): Intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
        addCategory(Intent.CATEGORY_OPENABLE)
        type = mimeType
        putExtra(Intent.EXTRA_TITLE, name)
    }

    fun write(activity: Activity, result: ActivityResult, bytes: ByteArray): Boolean {
        if (result.resultCode != Activity.RESULT_OK) return false
        val uri: Uri = result.data?.data ?: throw IOException("Dokumen tujuan tidak tersedia")
        val output = activity.contentResolver.openOutputStream(uri, "w")
            ?: throw IOException("Dokumen tujuan tidak bisa dibuka")
        output.use { it.write(bytes) }
        return true
    }
}
