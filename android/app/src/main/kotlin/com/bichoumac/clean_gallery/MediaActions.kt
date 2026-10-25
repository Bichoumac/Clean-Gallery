package com.bichoumac.clean_gallery

import android.app.Activity
import android.content.ClipData
import android.content.ContentUris
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Handler
import android.provider.MediaStore
import androidx.core.content.FileProvider
import androidx.exifinterface.media.ExifInterface
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executor

/**
 * Actions that change media or hand it to other apps: system favorites,
 * permanent deletion and sharing. Used by [MainActivity]; documented in
 * `docs/platform-android.md`.
 *
 * Favorites and deletion go through MediaStore requests
 * (`createFavoriteRequest`, `createDeleteRequest`): one system confirmation
 * for the whole batch, or none when the app holds "Media management".
 */
class MediaActions(
    private val activity: Activity,
    private val worker: Executor,
    private val mainHandler: Handler,
) {
    /** Reply of the MediaStore request currently shown, if any. */
    private var pendingRequest: MethodChannel.Result? = null

    /**
     * Sets `IS_FAVORITE` of the given items. Replies `true` when applied,
     * `false` when the user declined, `busy` if another request is open.
     */
    fun setFavorite(items: List<Item>, favorite: Boolean, result: MethodChannel.Result) {
        launchRequest(
            REQUEST_FAVORITE,
            result,
        ) { MediaStore.createFavoriteRequest(activity.contentResolver, items.map(::uriOf), favorite) }
    }

    /**
     * Deletes the given items for good. Replies `true` when deleted,
     * `false` when the user declined, `busy` if another request is open.
     */
    fun delete(items: List<Item>, result: MethodChannel.Result) {
        launchRequest(
            REQUEST_DELETE,
            result,
        ) { MediaStore.createDeleteRequest(activity.contentResolver, items.map(::uriOf)) }
    }

    /**
     * Opens the system share sheet for the given items.
     *
     * With [removeLocation], photos are shared as temporary copies without
     * GPS data: JPEG, PNG and WebP keep their other metadata, other formats
     * (HEIC…) are re-encoded as JPEG without metadata. Videos are shared as
     * they are; the Dart side warns before. Replies `null` once the sheet is
     * open.
     */
    fun share(items: List<Item>, removeLocation: Boolean, result: MethodChannel.Result) {
        worker.execute {
            try {
                val dir = File(activity.cacheDir, SHARE_DIR).apply {
                    deleteRecursively()
                    mkdirs()
                }
                val uris = items.map { item ->
                    if (removeLocation && !item.isVideo) copyWithoutLocation(item, dir) else uriOf(item)
                }
                mainHandler.post {
                    activity.startActivity(Intent.createChooser(shareIntent(items, uris), null))
                    result.success(null)
                }
            } catch (e: Exception) {
                mainHandler.post { result.error("share_failed", e.message, null) }
            }
        }
    }

    /** Delivers the outcome of a MediaStore request to the waiting call. */
    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != REQUEST_FAVORITE && requestCode != REQUEST_DELETE) return false
        pendingRequest?.success(resultCode == Activity.RESULT_OK)
        pendingRequest = null
        return true
    }

    private fun launchRequest(
        requestCode: Int,
        result: MethodChannel.Result,
        create: () -> android.app.PendingIntent,
    ) {
        if (pendingRequest != null) {
            result.error("busy", "Another media request is open", null)
            return
        }
        try {
            val intent = create()
            pendingRequest = result
            activity.startIntentSenderForResult(intent.intentSender, requestCode, null, 0, 0, 0)
        } catch (e: Exception) {
            pendingRequest = null
            result.error("request_failed", e.message, null)
        }
    }

    private fun copyWithoutLocation(item: Item, dir: File): Uri {
        val source = uriOf(item)
        val mime = item.mimeType.lowercase()
        val file: File
        if (mime in EXIF_WRITABLE) {
            file = File(dir, "${item.id}.${mime.substringAfter('/')}")
            activity.contentResolver.openInputStream(source)!!.use { input ->
                file.outputStream().use { input.copyTo(it) }
            }
            val exif = ExifInterface(file)
            for (tag in GPS_TAGS) exif.setAttribute(tag, null)
            exif.saveAttributes()
        } else {
            // Formats ExifInterface cannot write (HEIC…): re-encode without
            // any metadata. ImageDecoder applies the EXIF orientation.
            file = File(dir, "${item.id}.jpg")
            val bitmap = ImageDecoder.decodeBitmap(
                ImageDecoder.createSource(activity.contentResolver, source),
            ) { decoder, _, _ -> decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE }
            file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 95, it) }
            bitmap.recycle()
        }
        return FileProvider.getUriForFile(activity, "${activity.packageName}.share", file)
    }

    private fun shareIntent(items: List<Item>, uris: List<Uri>): Intent {
        val type = when {
            items.all { it.isVideo } -> "video/*"
            items.none { it.isVideo } -> "image/*"
            else -> "*/*"
        }
        val intent = if (uris.size == 1) {
            Intent(Intent.ACTION_SEND).putExtra(Intent.EXTRA_STREAM, uris.first())
        } else {
            Intent(Intent.ACTION_SEND_MULTIPLE)
                .putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(uris))
        }
        return intent.apply {
            setType(type)
            // ClipData carries the read grant for every URI.
            clipData = ClipData.newRawUri(null, uris.first()).also { clip ->
                uris.drop(1).forEach { clip.addItem(ClipData.Item(it)) }
            }
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
    }

    private fun uriOf(item: Item): Uri = ContentUris.withAppendedId(
        if (item.isVideo) {
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        },
        item.id,
    )

    /** A MediaStore item as sent by Dart. */
    data class Item(val id: Long, val isVideo: Boolean, val mimeType: String) {
        companion object {
            /** Parses `{id, video, mimeType}` maps from the channel. */
            fun listFrom(raw: List<Map<String, Any?>>?): List<Item> = raw.orEmpty().map {
                Item(
                    id = (it["id"] as String).toLong(),
                    isVideo = it["video"] == true,
                    mimeType = it["mimeType"] as? String ?: "",
                )
            }
        }
    }

    private companion object {
        const val REQUEST_FAVORITE = 4101
        const val REQUEST_DELETE = 4102

        /** Cache sub-folder for shared copies, emptied before each share. */
        const val SHARE_DIR = "share"

        /** Formats whose metadata ExifInterface can rewrite in place. */
        val EXIF_WRITABLE = setOf("image/jpeg", "image/png", "image/webp")

        /** Every GPS tag ExifInterface knows. */
        val GPS_TAGS = listOf(
            ExifInterface.TAG_GPS_VERSION_ID,
            ExifInterface.TAG_GPS_LATITUDE,
            ExifInterface.TAG_GPS_LATITUDE_REF,
            ExifInterface.TAG_GPS_LONGITUDE,
            ExifInterface.TAG_GPS_LONGITUDE_REF,
            ExifInterface.TAG_GPS_ALTITUDE,
            ExifInterface.TAG_GPS_ALTITUDE_REF,
            ExifInterface.TAG_GPS_TIMESTAMP,
            ExifInterface.TAG_GPS_DATESTAMP,
            ExifInterface.TAG_GPS_SATELLITES,
            ExifInterface.TAG_GPS_STATUS,
            ExifInterface.TAG_GPS_MEASURE_MODE,
            ExifInterface.TAG_GPS_DOP,
            ExifInterface.TAG_GPS_SPEED,
            ExifInterface.TAG_GPS_SPEED_REF,
            ExifInterface.TAG_GPS_TRACK,
            ExifInterface.TAG_GPS_TRACK_REF,
            ExifInterface.TAG_GPS_IMG_DIRECTION,
            ExifInterface.TAG_GPS_IMG_DIRECTION_REF,
            ExifInterface.TAG_GPS_MAP_DATUM,
            ExifInterface.TAG_GPS_DEST_LATITUDE,
            ExifInterface.TAG_GPS_DEST_LATITUDE_REF,
            ExifInterface.TAG_GPS_DEST_LONGITUDE,
            ExifInterface.TAG_GPS_DEST_LONGITUDE_REF,
            ExifInterface.TAG_GPS_DEST_BEARING,
            ExifInterface.TAG_GPS_DEST_BEARING_REF,
            ExifInterface.TAG_GPS_DEST_DISTANCE,
            ExifInterface.TAG_GPS_DEST_DISTANCE_REF,
            ExifInterface.TAG_GPS_PROCESSING_METHOD,
            ExifInterface.TAG_GPS_AREA_INFORMATION,
            ExifInterface.TAG_GPS_DIFFERENTIAL,
            ExifInterface.TAG_GPS_H_POSITIONING_ERROR,
        )
    }
}
