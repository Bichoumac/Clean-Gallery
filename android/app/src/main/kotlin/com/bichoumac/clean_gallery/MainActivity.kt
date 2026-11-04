package com.bichoumac.clean_gallery

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import android.view.WindowManager
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
     * Hashes file contents for exact duplicates and renders the thumbnails
     * of similar photos, apart from [worker] so that long reads never delay
     * index syncs or favorite requests.
     */
    private val hasher = Executors.newSingleThreadExecutor()

    /** Delivers results back on the main thread, as Flutter requires. */
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Thumbnails and previews from MediaStore's thumbnail cache. */
    private val thumbnails by lazy { ThumbnailLoader(applicationContext, mainHandler) }

    /** MediaStore reads for the app's media index. */
    private val mediaIndex by lazy { MediaIndex(applicationContext) }

    /** Writes photos edited in the editor. */
    private val photoSaver by lazy { PhotoSaver(applicationContext) }

    /** Favorites, permanent deletion and sharing. */
    private val actions by lazy { MediaActions(this, worker, mainHandler) }

    /** Music of the slideshows and the audio file picker. */
    private val music by lazy { SlideshowMusic(this) }

    /** Channel telling Dart that a memory or ritual notification was tapped. */
    private var reminderChannel: MethodChannel? = null

    /**
     * Payload of the notification that opened the app, kept until Dart is
     * ready to read it (`takeReminderPayload`).
     */
    private var launchPayload: String? = null

    /** Registers the platform channel once the engine is ready. */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::handle)
        reminderChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, REMINDER_CHANNEL)
        launchPayload = intent?.getStringExtra(Reminders.EXTRA_PAYLOAD)
    }

    /** A notification tapped while the app runs: tells Dart at once. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val payload = intent.getStringExtra(Reminders.EXTRA_PAYLOAD) ?: return
        reminderChannel?.invokeMethod("reminderTapped", payload)
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
            "mediaMetadata" -> {
                val id = call.argument<String>("id")?.toLongOrNull()
                if (id == null) {
                    result.error("bad_arguments", "id is required", null)
                } else {
                    val isVideo = call.argument<Boolean>("video") == true
                    onWorker(result) { mediaIndex.metadata(id, isVideo) }
                }
            }
            "contentHashes" -> {
                val items = MediaActions.Item.listFrom(call.argument("items"))
                    .map { it.id to it.isVideo }
                onWorker(result, hasher) { mediaIndex.contentHashes(items) }
            }
            "locations" -> {
                val items = MediaActions.Item.listFrom(call.argument("items"))
                    .map { it.id to it.isVideo }
                onWorker(result) { mediaIndex.locations(items) }
            }
            "grayThumbnails" -> {
                val ids = call.argument<List<String>>("ids").orEmpty()
                    .mapNotNull { it.toLongOrNull() }
                val side = call.argument<Int>("side") ?: 128
                onWorker(result, hasher) { mediaIndex.grayThumbnails(ids, side) }
            }
            "thumbnail" -> {
                val id = call.argument<String>("id")?.toLongOrNull()
                val width = call.argument<Int>("width")
                val height = call.argument<Int>("height")
                if (id == null || width == null || height == null) {
                    result.error("bad_arguments", "id, width and height are required", null)
                } else {
                    val isVideo = call.argument<Boolean>("video") == true
                    val fromFile = call.argument<Boolean>("fromFile") == true
                    thumbnails.load(id, isVideo, width, height, fromFile, result)
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
            "saveEditedPhoto" -> {
                val id = call.argument<String>("id")?.toLongOrNull()
                val width = call.argument<Int>("width")
                val height = call.argument<Int>("height")
                val rgba = call.argument<ByteArray>("rgba")
                if (id == null || width == null || height == null || rgba == null) {
                    result.error("bad_arguments", "id, width, height and rgba are required", null)
                } else {
                    onWorker(result) { photoSaver.save(id, width, height, rgba) }
                }
            }
            "openMap" -> {
                val latitude = call.argument<Double>("latitude")
                val longitude = call.argument<Double>("longitude")
                if (latitude == null || longitude == null) {
                    result.error("bad_arguments", "latitude and longitude are required", null)
                } else {
                    result.success(openMap(latitude, longitude))
                }
            }
            "setKeepScreenOn" -> {
                if (call.argument<Boolean>("on") == true) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(null)
            }
            "musicPlay" -> music.play(
                call.argument<String>("uri"),
                call.argument<String>("asset"),
                call.argument<Double>("volume") ?: 1.0,
                result,
            )
            "musicPause" -> {
                music.pause()
                result.success(null)
            }
            "musicResume" -> {
                music.resume()
                result.success(null)
            }
            "musicVolume" -> {
                music.setVolume(call.argument<Double>("volume") ?: 1.0)
                result.success(null)
            }
            "musicStop" -> {
                music.stop()
                result.success(null)
            }
            "pickMusic" -> music.pick(result)
            "releaseMusic" -> {
                call.argument<String>("uri")?.let(music::release)
                result.success(null)
            }
            "scheduleReminders" -> {
                Reminders.schedule(applicationContext, Reminders.Reminder.listFrom(call.argument("reminders")))
                result.success(null)
            }
            "canNotify" -> result.success(Reminders.canNotify(applicationContext))
            "takeReminderPayload" -> {
                result.success(launchPayload)
                launchPayload = null
            }
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
     * Opens the user's map app at [latitude], [longitude] with a `geo:` URI,
     * with a pin. Returns `false` when no app handles it.
     */
    private fun openMap(latitude: Double, longitude: Double): Boolean {
        val point = "$latitude,$longitude"
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("geo:$point?q=$point"))
        return try {
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    /**
     * Runs a MediaStore query on [executor] (the worker thread by default)
     * and replies on the main thread. A revoked media permission is reported as a `permission` error,
     * any other failure as a `failed` error.
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
            } catch (e: Exception) {
                // Always reply: a call left unanswered blocks the Dart side.
                mainHandler.post { result.error("failed", e.message, null) }
            }
        }
    }

    /** Routes the result of MediaStore requests and of the audio file picker. */
    @Deprecated("Activity API used by MediaStore requests")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!actions.onActivityResult(requestCode, resultCode) &&
            !music.onActivityResult(requestCode, resultCode, data)
        ) {
            @Suppress("DEPRECATION")
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    /** Stops the worker thread with the activity. */
    override fun onDestroy() {
        worker.shutdown()
        hasher.shutdownNow()
        mediaIndex.shutdown()
        thumbnails.shutdown()
        music.stop()
        super.onDestroy()
    }

    private companion object {
        /** Name of the MethodChannel shared with the Dart side. */
        const val CHANNEL = "clean_gallery/platform"

        /** Channel from Kotlin to Dart for tapped notifications. */
        const val REMINDER_CHANNEL = "clean_gallery/reminders"
    }
}
