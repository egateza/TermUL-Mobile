package io.github.egateza.termul

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.net.Uri
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
 * penyalinan gagal. Nama kembar diberi akhiran " (1)" oleh MediaStore bila pemanggil tidak meminta menimpa.
 *
 * Menimpa hanya bisa untuk berkas yang dibuat aplikasi ini (MediaStore membatasi Unduhan menurut pemilik); `exists`
 * dan menimpa pun hanya "melihat" berkas milik aplikasi ini. Berkas bernama sama milik aplikasi lain tidak terlihat,
 * jadi MediaStore menamainya " (1)" sendiri.
 *
 * Di bawah API 29 (minSdk 24): folder Unduhan publik butuh izin penyimpanan, jadi berkas disimpan di folder
 * Unduhan khusus aplikasi (`Android/data/.../files/Download/TermUL`). Jalur ini belum diuji di perangkat.
 */
object DownloadsSaver {
    const val FOLDER = "TermUL"
    private const val RELATIVE = "Download/$FOLDER/"

    data class Saved(val name: String, val location: String, val overwritten: Boolean)

    fun exists(context: Context, displayName: String): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) findExisting(context, displayName) != null
        else File(appDir(context), displayName).exists()

    fun save(context: Context, sourcePath: String, displayName: String, overwrite: Boolean): Saved {
        val source = File(sourcePath)
        require(source.isFile) { "Berkas sumber tidak ada" }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) saveToMediaStore(context, source, displayName, overwrite)
        else saveToAppFolder(context, source, displayName, overwrite)
    }

    private fun mimeOf(name: String): String {
        val ext = name.substringAfterLast('.', "").lowercase()
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: "application/octet-stream"
    }

    private fun findExisting(context: Context, displayName: String): Uri? {
        val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
        context.contentResolver.query(
            collection,
            arrayOf(MediaStore.MediaColumns._ID),
            "${MediaStore.MediaColumns.DISPLAY_NAME}=? AND ${MediaStore.MediaColumns.RELATIVE_PATH}=?",
            arrayOf(displayName, RELATIVE),
            null,
        )?.use { c ->
            if (c.moveToFirst()) return ContentUris.withAppendedId(collection, c.getLong(0))
        }
        return null
    }

    private fun saveToMediaStore(context: Context, source: File, displayName: String, overwrite: Boolean): Saved {
        val resolver = context.contentResolver
        if (overwrite) {
            val existing = findExisting(context, displayName)
            if (existing != null) {
                try {
                    // "wt": potong lalu tulis ulang. Gagal (bukan milik kita) -> jatuh ke berkas baru bernomor.
                    resolver.openOutputStream(existing, "wt")!!.use { out ->
                        FileInputStream(source).use { it.copyTo(out, 256 * 1024) }
                    }
                    return Saved(displayName, "Unduhan/$FOLDER", true)
                } catch (e: SecurityException) {
                    // lanjut ke penyimpanan sebagai berkas baru
                } catch (e: java.io.IOException) {
                    // berkas lama mungkin sebagian tertimpa; simpan hasil baru sebagai berkas bernomor
                }
            }
        }
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
        return Saved(finalName, "Unduhan/$FOLDER", false)
    }

    private fun appDir(context: Context): File {
        val base = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            ?: throw IllegalStateException("Penyimpanan tidak tersedia")
        return File(base, FOLDER).apply { mkdirs() }
    }

    private fun saveToAppFolder(context: Context, source: File, displayName: String, overwrite: Boolean): Saved {
        val dir = appDir(context)
        var target = File(dir, displayName)
        val overwritten = overwrite && target.exists()
        var n = 1
        val stem = displayName.substringBeforeLast('.', displayName)
        val ext = displayName.substringAfterLast('.', "")
        while (!overwrite && target.exists()) {
            target = File(dir, if (ext.isEmpty()) "$stem ($n)" else "$stem ($n).$ext")
            n++
        }
        try {
            source.copyTo(target, overwrite = overwrite)
        } catch (e: Exception) {
            if (!overwritten) target.delete()
            throw e
        }
        return Saved(target.name, "Android/data/${context.packageName}/files/Download/$FOLDER", overwritten)
    }
}
