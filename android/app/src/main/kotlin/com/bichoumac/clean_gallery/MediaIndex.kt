package com.bichoumac.clean_gallery

import android.Manifest
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.MediaStore
import android.util.Size
import androidx.exifinterface.media.ExifInterface
import java.io.IOException
import java.security.MessageDigest
import java.util.concurrent.Callable
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors

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

    /** Renders the thumbnails of [grayThumbnails], several at once. */
    private val thumbnailPool = Executors.newFixedThreadPool(THUMBNAIL_THREADS)

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
        // MediaStore renders missing thumbnails from the full file: a few
        // threads keep several decodes going at once.
        val tasks = ids.map { id -> Callable { id to grayThumbnail(id, side) } }
        val thumbnails = HashMap<String, Map<String, Any>>(ids.size)
        for (future in thumbnailPool.invokeAll(tasks)) {
            val (id, image) = try {
                future.get()
            } catch (e: ExecutionException) {
                continue
            }
            if (image != null) thumbnails[id.toString()] = image
        }
        return thumbnails
    }

    /**
     * Grayscale thumbnail of photo [id] for [grayThumbnails], or `null` when
     * MediaStore cannot render it. Any failure on one photo leaves only that
     * photo out, so a single odd file never stops the similar photo search.
     */
    private fun grayThumbnail(id: Long, side: Int): Map<String, Any>? {
        val itemUri = ContentUris.withAppendedId(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            id,
        )
        val loaded = try {
            resolver.loadThumbnail(itemUri, Size(side, side), null)
        } catch (e: IOException) {
            return null
        } catch (e: RuntimeException) {
            // SecurityException, undecodable image, provider failure.
            return null
        } catch (e: OutOfMemoryError) {
            return null
        }
        // Hardware bitmaps cannot be read back; copy to a software bitmap.
        val bitmap = if (loaded.config == Bitmap.Config.ARGB_8888) {
            loaded
        } else {
            loaded.copy(Bitmap.Config.ARGB_8888, false).also { loaded.recycle() }
                ?: return null
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
        return mapOf(
            "width" to width,
            "height" to height,
            "pixels" to gray,
        )
    }

    /**
     * Camera metadata of item [id] for the viewer's info panel: `make`,
     * `model`, `lens` (strings), `iso` (int), `aperture` (f-number),
     * `exposure` (seconds), `focalLength` and `focalLength35` (mm),
     * `latitude` and `longitude` (degrees). Missing values are left out;
     * videos only have a location.
     *
     * Reads the file's EXIF header, not the whole file. The location needs
     * `ACCESS_MEDIA_LOCATION`: without it Android hides the GPS tags and
     * the map is empty.
     */
    fun metadata(id: Long, isVideo: Boolean): Map<String, Any> {
        val base = if (isVideo) {
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }
        var itemUri = ContentUris.withAppendedId(base, id)
        val located = context.checkSelfPermission(Manifest.permission.ACCESS_MEDIA_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        if (located) itemUri = MediaStore.setRequireOriginal(itemUri)
        return if (isVideo) videoMetadata(itemUri) else photoMetadata(itemUri)
    }

    /**
     * Location of each of [items] (MediaStore id, and whether it is a
     * video), by id: `[latitude, longitude]` in degrees. Items without a
     * location, or that cannot be read, are left out.
     *
     * Reads only file headers (EXIF, or the video's metadata), for the
     * map. Needs `ACCESS_MEDIA_LOCATION`: without it Android hides the GPS
     * tags, so a [SecurityException] is thrown rather than reporting every
     * item as having no location.
     */
    fun locations(items: List<Pair<Long, Boolean>>): Map<String, List<Double>> {
        if (context.checkSelfPermission(Manifest.permission.ACCESS_MEDIA_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            throw SecurityException("ACCESS_MEDIA_LOCATION is not granted")
        }
        val locations = HashMap<String, List<Double>>()
        for ((id, isVideo) in items) {
            val base = if (isVideo) {
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            } else {
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            }
            val itemUri = MediaStore.setRequireOriginal(ContentUris.withAppendedId(base, id))
            try {
                val values = if (isVideo) videoMetadata(itemUri) else photoLocation(itemUri)
                val latitude = values["latitude"] as? Double
                val longitude = values["longitude"] as? Double
                if (latitude != null && longitude != null) {
                    locations[id.toString()] = listOf(latitude, longitude)
                }
            } catch (e: IOException) {
                // Unreadable or deleted meanwhile: no location.
            } catch (e: SecurityException) {
                // Access withdrawn for this item: no location.
            } catch (e: RuntimeException) {
                // A malformed header (MediaMetadataRetriever throws these).
            }
        }
        return locations
    }

    /** GPS position of the photo at [itemUri], for [locations]. */
    private fun photoLocation(itemUri: Uri): Map<String, Any> {
        val exif = resolver.openInputStream(itemUri)?.use { ExifInterface(it) }
            ?: return emptyMap()
        val (latitude, longitude) = exif.latLong ?: return emptyMap()
        // 0, 0 is what some apps write when they have no fix.
        if (latitude == 0.0 && longitude == 0.0) return emptyMap()
        return mapOf("latitude" to latitude, "longitude" to longitude)
    }

    /** EXIF values of the photo at [itemUri], for [metadata]. */
    private fun photoMetadata(itemUri: Uri): Map<String, Any> {
        val exif = resolver.openInputStream(itemUri)?.use { ExifInterface(it) }
            ?: return emptyMap()
        val values = HashMap<String, Any>()
        fun text(key: String, tag: String) {
            exif.getAttribute(tag)?.trim()?.takeIf { it.isNotEmpty() }?.let { values[key] = it }
        }
        fun number(key: String, tag: String) {
            val value = exif.getAttributeDouble(tag, 0.0)
            if (value > 0) values[key] = value
        }
        text("make", ExifInterface.TAG_MAKE)
        text("model", ExifInterface.TAG_MODEL)
        text("lens", ExifInterface.TAG_LENS_MODEL)
        exif.getAttributeInt(ExifInterface.TAG_PHOTOGRAPHIC_SENSITIVITY, 0)
            .takeIf { it > 0 }?.let { values["iso"] = it }
        number("aperture", ExifInterface.TAG_F_NUMBER)
        number("exposure", ExifInterface.TAG_EXPOSURE_TIME)
        number("focalLength", ExifInterface.TAG_FOCAL_LENGTH)
        number("focalLength35", ExifInterface.TAG_FOCAL_LENGTH_IN_35MM_FILM)
        exif.latLong?.let { (latitude, longitude) ->
            // 0, 0 is what some apps write when they have no fix.
            if (latitude != 0.0 || longitude != 0.0) {
                values["latitude"] = latitude
                values["longitude"] = longitude
            }
        }
        return values
    }

    /** Location of the video at [itemUri], for [metadata]. */
    private fun videoMetadata(itemUri: Uri): Map<String, Any> {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(context, itemUri)
            // ISO 6709, e.g. "+48.8566+002.3522/".
            val location = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_LOCATION)
                ?: return emptyMap()
            val match = ISO_6709.find(location) ?: return emptyMap()
            val latitude = match.groupValues[1].toDouble()
            val longitude = match.groupValues[2].toDouble()
            if (latitude == 0.0 && longitude == 0.0) return emptyMap()
            return mapOf("latitude" to latitude, "longitude" to longitude)
        } finally {
            retriever.release()
        }
    }

    /** Stops the threads of [grayThumbnails]. */
    fun shutdown() {
        thumbnailPool.shutdownNow()
    }

    private companion object {
        /**
         * Thumbnails rendered at once by [grayThumbnails]. On the Galaxy A54,
         * 4 read about 13 % faster than 2 and the grid stayed fluid; MediaStore
         * itself is the limit, so more would not help much.
         */
        const val THUMBNAIL_THREADS = 4

        /** Latitude and longitude at the start of an ISO 6709 location. */
        val ISO_6709 = Regex("""^([+-]\d+(?:\.\d+)?)([+-]\d+(?:\.\d+)?)""")

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
