package com.bichoumac.clean_gallery

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Hosts the Flutter engine and exposes the `clean_gallery/platform` channel.
 *
 * Only features that the Flutter packages do not cover live here. The Dart
 * side of this channel is `AndroidPlatformBridge`; the method contract is
 * documented in `docs/platform-android.md`.
 */
class MainActivity : FlutterActivity() {

    /** Runs MediaStore queries off the main thread. */
    private val worker = Executors.newSingleThreadExecutor()

    /** Delivers results back on the main thread, as Flutter requires. */
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Thumbnails and previews from MediaStore's thumbnail cache. */
    private val thumbnails by lazy { ThumbnailLoader(contentResolver, mainHandler) }

    /** Favorites, permanent deletion and sharing. */
    private val actions by lazy { MediaActions(this, worker, mainHandler) }

    /** Registers the platform channel once the engine is ready. */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::handle)
    }

    /** Dispatches a method call from Dart and replies with its result. */
    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isMediaManagementGranted" -> result.success(isMediaManagementGranted())
            "openMediaManagementSettings" -> {
                openMediaManagementSettings()
                result.success(null)
            }
            "sdkVersion" -> result.success(Build.VERSION.SDK_INT)
            "mediaSizes" -> {
                val ids = call.argument<List<String>>("ids").orEmpty()
                worker.execute {
                    try {
                        val sizes = mediaSizes(ids)
                        mainHandler.post { result.success(sizes) }
                    } catch (e: SecurityException) {
                        mainHandler.post { result.error("permission", e.message, null) }
                    }
                }
            }
            "albumSummaries" -> worker.execute {
                try {
                    val excluded = call.argument<List<Number>>("excluded")
                        .orEmpty().map { it.toLong() }
                    val summaries = albumSummaries(excluded)
                    mainHandler.post { result.success(summaries) }
                } catch (e: SecurityException) {
                    mainHandler.post { result.error("permission", e.message, null) }
                }
            }
            "thumbnail" -> {
                val id = call.argument<String>("id")?.toLongOrNull()
                val width = call.argument<Int>("width")
                val height = call.argument<Int>("height")
                if (id == null || width == null || height == null) {
                    result.error("bad_arguments", "id, width and height are required", null)
                } else {
                    val isVideo = call.argument<Boolean>("video") == true
                    thumbnails.load(id, isVideo, width, height, result)
                }
            }
            "setFavorite" -> actions.setFavorite(
                MediaActions.Item.listFrom(call.argument("items")),
                call.argument<Boolean>("favorite") == true,
                result,
            )
            "deleteMedia" -> actions.delete(
                MediaActions.Item.listFrom(call.argument("items")),
                result,
            )
            "share" -> actions.share(
                MediaActions.Item.listFrom(call.argument("items")),
                call.argument<Boolean>("removeLocation") == true,
                result,
            )
            else -> result.notImplemented()
        }
    }

    /**
     * Whether the app holds the "Media management" special permission.
     *
     * Always `false` below Android 12, where the permission does not exist.
     */
    private fun isMediaManagementGranted(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        return MediaStore.canManageMedia(this)
    }

    /**
     * Opens the system screen that grants "Media management" to this app.
     *
     * Does nothing below Android 12. If the device has no handler for the
     * intent, the call is silently ignored and the app keeps working with
     * MediaStore confirmation prompts.
     */
    private fun openMediaManagementSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val intent = Intent(Settings.ACTION_REQUEST_MANAGE_MEDIA).apply {
            data = Uri.parse("package:$packageName")
        }
        if (intent.resolveActivity(packageManager) != null) {
            startActivity(intent)
        }
    }

    /**
     * File sizes in bytes of the MediaStore items with the given [ids].
     *
     * Queried by chunks of 500 ids to stay below SQLite's limit on bound
     * parameters. Items that no longer exist are missing from the result.
     */
    private fun mediaSizes(ids: List<String>): Map<String, Long> {
        val sizes = HashMap<String, Long>(ids.size)
        val uri = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)
        val projection = arrayOf(MediaStore.MediaColumns._ID, MediaStore.MediaColumns.SIZE)
        for (chunk in ids.chunked(500)) {
            val selection = "${MediaStore.MediaColumns._ID} IN (${chunk.joinToString(",") { "?" }})"
            contentResolver.query(uri, projection, selection, chunk.toTypedArray(), null)?.use { cursor ->
                val idColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
                val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)
                while (cursor.moveToNext()) {
                    sizes[cursor.getLong(idColumn).toString()] = cursor.getLong(sizeColumn)
                }
            }
        }
        return sizes
    }

    /**
     * One entry per folder (MediaStore bucket) containing photos or videos:
     * `{id, name, count, coverId, coverIsVideo, coverWidth, coverHeight,
     * coverModified}`, largest folder first.
     *
     * A single pass over the library, newest first, so the first item met in
     * each folder is its cover. This replaces one count query and one path
     * listing per folder. Items whose id is in `excluded` (the app trash)
     * are left out.
     */
    private fun albumSummaries(excluded: List<Long>): List<Map<String, Any?>> {
        val uri = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)
        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.BUCKET_ID,
            MediaStore.MediaColumns.BUCKET_DISPLAY_NAME,
            MediaStore.Files.FileColumns.MEDIA_TYPE,
            MediaStore.MediaColumns.WIDTH,
            MediaStore.MediaColumns.HEIGHT,
            MediaStore.MediaColumns.ORIENTATION,
            MediaStore.MediaColumns.DATE_MODIFIED,
        )
        val selection = "${MediaStore.Files.FileColumns.MEDIA_TYPE} IN (" +
            "${MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE}, " +
            "${MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO}) " +
            "AND ${MediaStore.MediaColumns.BUCKET_ID} IS NOT NULL" +
            // Trashed items; ids are numbers, inlined to avoid SQLite's limit
            // on bound parameters.
            if (excluded.isEmpty()) "" else
                " AND ${MediaStore.MediaColumns._ID} NOT IN (${excluded.joinToString(",")})"
        // Same capture date as the timelines (see AndroidMediaSource).
        val sortOrder = "CASE WHEN datetaken > 0 THEN datetaken / 1000 " +
            "ELSE date_added END DESC"
        val folders = LinkedHashMap<String, MutableMap<String, Any?>>()
        contentResolver.query(uri, projection, selection, null, sortOrder)?.use { c ->
            val id = c.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
            val bucket = c.getColumnIndexOrThrow(MediaStore.MediaColumns.BUCKET_ID)
            val name = c.getColumnIndexOrThrow(MediaStore.MediaColumns.BUCKET_DISPLAY_NAME)
            val type = c.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MEDIA_TYPE)
            val width = c.getColumnIndexOrThrow(MediaStore.MediaColumns.WIDTH)
            val height = c.getColumnIndexOrThrow(MediaStore.MediaColumns.HEIGHT)
            val orientation = c.getColumnIndexOrThrow(MediaStore.MediaColumns.ORIENTATION)
            val modified = c.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_MODIFIED)
            while (c.moveToNext()) {
                val bucketId = c.getString(bucket) ?: continue
                val folder = folders[bucketId]
                if (folder != null) {
                    folder["count"] = (folder["count"] as Int) + 1
                    continue
                }
                // First item of the folder: the newest, used as its cover.
                val rotated = c.getInt(orientation) % 180 != 0
                folders[bucketId] = mutableMapOf(
                    "id" to bucketId,
                    "name" to (c.getString(name) ?: ""),
                    "count" to 1,
                    "coverId" to c.getLong(id).toString(),
                    "coverIsVideo" to
                        (c.getInt(type) == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO),
                    "coverWidth" to if (rotated) c.getInt(height) else c.getInt(width),
                    "coverHeight" to if (rotated) c.getInt(width) else c.getInt(height),
                    "coverModified" to c.getLong(modified),
                )
            }
        }
        return folders.values.sortedByDescending { it["count"] as Int }
    }

    /** Routes the result of MediaStore favorite and delete requests. */
    @Deprecated("Activity API used by MediaStore requests")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!actions.onActivityResult(requestCode, resultCode)) {
            @Suppress("DEPRECATION")
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    /** Stops the worker thread with the activity. */
    override fun onDestroy() {
        worker.shutdown()
        thumbnails.shutdown()
        super.onDestroy()
    }

    private companion object {
        /** Name of the MethodChannel shared with the Dart side. */
        const val CHANNEL = "clean_gallery/platform"
    }
}
