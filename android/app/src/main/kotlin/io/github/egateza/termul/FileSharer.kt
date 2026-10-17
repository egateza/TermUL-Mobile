package io.github.egateza.termul

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import androidx.core.content.FileProvider
import java.io.File

/**
 * Membuka menu bagikan bawaan Android untuk satu berkas di folder `cache/share/` aplikasi (lihat
 * `res/xml/share_paths.xml`). Berkas diberikan sebagai content URI dengan izin baca sementara; aplikasi ini tidak
 * menyimpan salinan lain.
 */
object FileSharer {
    fun share(activity: Activity, path: String, name: String, mimeType: String, title: String?) {
        val file = File(path)
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.fileprovider", file)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, name)
            clipData = ClipData.newRawUri(name, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(Intent.createChooser(send, title))
    }
}
