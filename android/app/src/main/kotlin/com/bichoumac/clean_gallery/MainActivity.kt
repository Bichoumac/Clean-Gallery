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
import java.util.concurrent.ExecutorService
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

    /**
     * Hashes file contents for exact duplicates, apart from [worker] so that
     * long reads never delay index syncs or favorite requests.
     */
    private val hasher = Executors.newSingleThreadExecutor()

    /** Delivers results back on the main thread, as Flutter requires. */
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Thumbnails and previews from MediaStore's thumbnail cache. */
    private val thumbnails by lazy { ThumbnailLoader(applicationContext, mainHandler) }

    /** MediaStore reads for the app's media index. */
    private val mediaIndex by lazy { MediaIndex(applicationContext) }

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
            "mediaSnapshot" -> onWorker(result) { mediaIndex.snapshot() }
            "mediaDetails" -> {
                val ids = call.argument<List<String>>("ids").orEmpty()
                    .mapNotNull { it.toLongOrNull() }
                onWorker(result) { mediaIndex.describe(ids) }
            }
            "contentHashes" -> {
                val items = MediaActions.Item.listFrom(call.argument("items"))
                    .map { it.id to it.isVideo }
                onWorker(result, hasher) { mediaIndex.contentHashes(items) }
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
     * Runs a MediaStore query on [executor] (the worker thread by default)
     * and replies on the main thread. A revoked media permission is reported as a `permission` error.
     */
    private fun onWorker(
        result: MethodChannel.Result,
        executor: ExecutorService = worker,
        query: () -> Any,
    ) {
        executor.execute {
            try {
                val value = query()
                mainHandler.post { result.success(value) }
            } catch (e: SecurityException) {
                mainHandler.post { result.error("permission", e.message, null) }
            }
        }
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
        hasher.shutdownNow()
        thumbnails.shutdown()
        super.onDestroy()
    }

    private companion object {
        /** Name of the MethodChannel shared with the Dart side. */
        const val CHANNEL = "clean_gallery/platform"
    }
}
