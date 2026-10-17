package io.github.egateza.termul

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileInputStream

/**
 * Menyalin berkas hasil unduhan SFTP ke folder Unduhan/TermUL.
 *
 * Android 10 (API 29) ke atas: MediaStore (`Download/TermUL`), tanpa izin penyimpanan. Berkas ditandai
 * IS_PENDING selama disalin supaya aplikasi lain tidak melihat berkas setengah jadi, dan entri dihapus bila
 * penyalinan gagal. Nama kembar diberi akhiran " (1)" oleh MediaStore sendiri; nama akhirnya dikembalikan.
 *
 * Di bawah API 29 (minSdk 24): folder Unduhan publik butuh izin penyimpanan, jadi berkas disimpan di folder
 * Unduhan khusus aplikasi (`Android/data/.../files/Download/TermUL`). Jalur ini belum diuji di perangkat.
 */
object DownloadsSaver {
    const val FOLDER = "TermUL"

    data class Saved(val name: String, val location: String)

    fun save(context: Context, sourcePath: String, displayName: String): Saved {
        val source = File(sourcePath)
        require(source.isFile) { "Berkas sumber tidak ada" }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) saveToMediaStore(context, source, displayName)
        else saveToAppFolder(context, source, displayName)
    }

    private fun mimeOf(name: String): String {
        val ext = name.substringAfterLast('.', "").lowercase()
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: "application/octet-stream"
    }

    private fun saveToMediaStore(context: Context, source: File, displayName: String): Saved {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeOf(displayName))
            put(MediaStore.MediaColumns.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/$FOLDER")
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("MediaStore menolak membuat berkas")
        try {
            resolver.openOutputStream(uri, "w")!!.use { out ->
                FileInputStream(source).use { it.copyTo(out, 256 * 1024) }
            }
            val done = ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }
            resolver.update(uri, done, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
        var finalName = displayName
        resolver.query(uri, arrayOf(MediaStore.MediaColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst()) finalName = c.getString(0) ?: displayName
        }
        return Saved(finalName, "Unduhan/$FOLDER")
    }

    private fun saveToAppFolder(context: Context, source: File, displayName: String): Saved {
        val base = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            ?: throw IllegalStateException("Penyimpanan tidak tersedia")
        val dir = File(base, FOLDER).apply { mkdirs() }
        var target = File(dir, displayName)
        var n = 1
        val stem = displayName.substringBeforeLast('.', displayName)
        val ext = displayName.substringAfterLast('.', "")
        while (target.exists()) {
            target = File(dir, if (ext.isEmpty()) "$stem ($n)" else "$stem ($n).$ext")
            n++
        }
        try {
            source.copyTo(target)
        } catch (e: Exception) {
            target.delete()
            throw e
        }
        return Saved(target.name, "Android/data/${context.packageName}/files/Download/$FOLDER")
    }
}
