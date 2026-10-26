package com.bichoumac.clean_gallery

import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.provider.MediaStore
import android.util.Size
import java.io.IOException
import java.security.MessageDigest

/**
 * Reads MediaStore for the app's media index (`MediaIndex` on the Dart side).
 *
 * A sync is two steps: [snapshot] lists every photo and video with its
 * revision (`GENERATION_MODIFIED`), then [describe] reads the full metadata
 * of the items that are new or changed. Both run on a worker thread.
 */
class MediaIndex(private val context: Context) {

    private val resolver = context.contentResolver

    private val uri = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)

    /**
     * `{version, ids, revisions}`: the MediaStore version and, newest first,
     * the id and `GENERATION_MODIFIED` of every photo and video, as two
     * `LongArray`s of the same length.
     *
     * The version changes when MediaStore rebuilds its database, which can
     * reassign ids.
     */
    fun snapshot(): Map<String, Any> {
        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.GENERATION_MODIFIED,
        )
        var ids = LongArray(0)
        var revisions = LongArray(0)
        resolver.query(uri, projection, MEDIA_ONLY, null, NEWEST_FIRST)?.use { c ->
            val id = c.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
            val generation =
                c.getColumnIndexOrThrow(MediaStore.MediaColumns.GENERATION_MODIFIED)
            ids = LongArray(c.count)
            revisions = LongArray(c.count)
            var i = 0
            while (c.moveToNext() && i < ids.size) {
                ids[i] = c.getLong(id)
                revisions[i] = c.getLong(generation)
                i++
            }
            if (i < ids.size) {
                ids = ids.copyOf(i)
                revisions = revisions.copyOf(i)
            }
        }
        return mapOf(
            "version" to MediaStore.getVersion(context),
            "ids" to ids,
            "revisions" to revisions,
        )
    }

    /**
     * Full metadata of the items with the given [ids], one map per item:
     * `{id, bucketId, bucketName, relativePath, name, mimeType, video,
     * size, width, height, takenAt, dateTaken, added, modified, duration,
     * favorite, revision}`.
     *
     * Width and height are swapped for rotated photos. `takenAt` is in
     * milliseconds (`DATE_TAKEN`, or `DATE_ADDED` when unset); `dateTaken`
     * is the raw `DATE_TAKEN` in milliseconds, 0 when unset; `added` and
     * `modified` are in seconds, `duration` in milliseconds. Items that no
     * longer exist are left out.
     */
    fun describe(ids: List<Long>): List<Map<String, Any?>> {
        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.BUCKET_ID,
            MediaStore.MediaColumns.BUCKET_DISPLAY_NAME,
            MediaStore.MediaColumns.RELATIVE_PATH,
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.MIME_TYPE,
            MediaStore.Files.FileColumns.MEDIA_TYPE,
            MediaStore.MediaColumns.SIZE,
            MediaStore.MediaColumns.WIDTH,
            MediaStore.MediaColumns.HEIGHT,
            MediaStore.MediaColumns.ORIENTATION,
            MediaStore.MediaColumns.DATE_TAKEN,
            MediaStore.MediaColumns.DATE_ADDED,
            MediaStore.MediaColumns.DATE_MODIFIED,
            MediaStore.MediaColumns.DURATION,
            MediaStore.MediaColumns.IS_FAVORITE,
            MediaStore.MediaColumns.GENERATION_MODIFIED,
        )
        val items = ArrayList<Map<String, Any?>>(ids.size)
        // Ids are numbers, inlined to avoid SQLite's limit on bound parameters.
        for (chunk in ids.chunked(CHUNK)) {
            val selection = "$MEDIA_ONLY AND ${MediaStore.MediaColumns._ID} IN " +
                "(${chunk.joinToString(",")})"
            resolver.query(uri, projection, selection, null, null)?.use { c ->
                val id = c.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
                val bucketId = c.getColumnIndexOrThrow(MediaStore.MediaColumns.BUCKET_ID)
                val bucketName =
                    c.getColumnIndexOrThrow(MediaStore.MediaColumns.BUCKET_DISPLAY_NAME)
                val path = c.getColumnIndexOrThrow(MediaStore.MediaColumns.RELATIVE_PATH)
                val name = c.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
                val mime = c.getColumnIndexOrThrow(MediaStore.MediaColumns.MIME_TYPE)
                val type = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MEDIA_TYPE)
                val size = c.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)
                val width = c.getColumnIndexOrThrow(MediaStore.MediaColumns.WIDTH)
                val height = c.getColumnIndexOrThrow(MediaStore.MediaColumns.HEIGHT)
                val orientation = c.getColumnIndexOrThrow(MediaStore.MediaColumns.ORIENTATION)
                val taken = c.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_TAKEN)
                val added = c.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_ADDED)
                val modified = c.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_MODIFIED)
                val duration = c.getColumnIndexOrThrow(MediaStore.MediaColumns.DURATION)
                val favorite = c.getColumnIndexOrThrow(MediaStore.MediaColumns.IS_FAVORITE)
                val generation =
                    c.getColumnIndexOrThrow(MediaStore.MediaColumns.GENERATION_MODIFIED)
                while (c.moveToNext()) {
                    val rotated = c.getInt(orientation) % 180 != 0
                    val takenAt = c.getLong(taken)
                    items.add(
                        mapOf(
                            "id" to c.getLong(id).toString(),
                            "bucketId" to c.getString(bucketId),
                            "bucketName" to (c.getString(bucketName) ?: ""),
                            "relativePath" to c.getString(path),
                            "name" to c.getString(name),
                            "mimeType" to c.getString(mime),
                            "video" to
                                (c.getInt(type) == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO),
                            "size" to c.getLong(size),
                            "width" to if (rotated) c.getInt(height) else c.getInt(width),
                            "height" to if (rotated) c.getInt(width) else c.getInt(height),
                            // Same capture date as photo_manager's createDateTime.
                            "takenAt" to if (takenAt > 0) takenAt else c.getLong(added) * 1000,
                            "dateTaken" to takenAt,
                            "added" to c.getLong(added),
                            "modified" to c.getLong(modified),
                            "duration" to c.getLong(duration),
                            "favorite" to (c.getInt(favorite) == 1),
                            "revision" to c.getLong(generation),
                        ),
                    )
                }
            }
        }
        return items
    }

    /**
     * SHA-256 of the content of [items] (MediaStore id, and whether it is a
     * video), as lowercase hex, by id. Items that cannot be read are left
     * out.
     *
     * Reads each file once, in 1 MB blocks, through its Images or Video
     * URI, which the media permissions cover; used for exact duplicates.
     */
    fun contentHashes(items: List<Pair<Long, Boolean>>): Map<String, String> {
        val hashes = HashMap<String, String>(items.size)
        val buffer = ByteArray(1 shl 20)
        for ((id, isVideo) in items) {
            val collection = if (isVideo) {
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            } else {
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            }
            val itemUri = ContentUris.withAppendedId(collection, id)
            try {
                val digest = MessageDigest.getInstance("SHA-256")
                resolver.openInputStream(itemUri)?.use { input ->
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        digest.update(buffer, 0, read)
                    }
                    hashes[id.toString()] = digest.digest().joinToString("") {
                        "%02x".format(it)
                    }
                }
            } catch (e: IOException) {
                // Unreadable or deleted meanwhile: no hash.
            } catch (e: SecurityException) {
                // Access withdrawn for this item: no hash.
            }
        }
        return hashes
    }

    /**
     * Grayscale thumbnails of the photos with MediaStore [ids], fitting in
     * [side] × [side] pixels, by id: `{width, height, pixels}`, where
     * `pixels` holds one brightness byte (0–255) per pixel, row by row.
     * Photos without a readable thumbnail are left out.
     *
     * Rendered by MediaStore's thumbnail cache, like the grid: the original
     * file is never decoded in full. Used for similar photos.
     */
    fun grayThumbnails(ids: List<Long>, side: Int): Map<String, Map<String, Any>> {
        val thumbnails = HashMap<String, Map<String, Any>>(ids.size)
        for (id in ids) {
            val itemUri = ContentUris.withAppendedId(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                id,
            )
            val loaded = try {
                resolver.loadThumbnail(itemUri, Size(side, side), null)
            } catch (e: IOException) {
                continue
            } catch (e: SecurityException) {
                continue
            } catch (e: IllegalArgumentException) {
                // Undecodable image.
                continue
            }
            // Hardware bitmaps cannot be read back; copy to a software bitmap.
            val bitmap = if (loaded.config == Bitmap.Config.ARGB_8888) {
                loaded
            } else {
                loaded.copy(Bitmap.Config.ARGB_8888, false).also { loaded.recycle() }
            }
            val width = bitmap.width
            val height = bitmap.height
            val colors = IntArray(width * height)
            bitmap.getPixels(colors, 0, width, 0, 0, width, height)
            bitmap.recycle()
            val gray = ByteArray(colors.size)
            for (i in colors.indices) {
                val c = colors[i]
                val r = (c shr 16) and 0xFF
                val g = (c shr 8) and 0xFF
                val b = c and 0xFF
                gray[i] = ((299 * r + 587 * g + 114 * b) / 1000).toByte()
            }
            thumbnails[id.toString()] = mapOf(
                "width" to width,
                "height" to height,
                "pixels" to gray,
            )
        }
        return thumbnails
    }

    private companion object {
        /** Ids per MediaStore query in [describe]. */
        const val CHUNK = 1000

        /** Photos and videos only. */
        const val MEDIA_ONLY = "${MediaStore.Files.FileColumns.MEDIA_TYPE} IN (" +
            "${MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE}, " +
            "${MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO})"

        /**
         * Newest first, by the same capture date as the timelines:
         * `DATE_TAKEN` (milliseconds) when set, otherwise `DATE_ADDED`.
         */
        const val NEWEST_FIRST = "CASE WHEN datetaken > 0 THEN datetaken / 1000 " +
            "ELSE date_added END DESC, ${MediaStore.MediaColumns._ID} DESC"
    }
}
