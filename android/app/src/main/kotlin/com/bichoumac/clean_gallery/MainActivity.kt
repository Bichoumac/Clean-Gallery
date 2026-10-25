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

    /** Stops the worker thread with the activity. */
    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }

    private companion object {
        /** Name of the MethodChannel shared with the Dart side. */
        const val CHANNEL = "clean_gallery/platform"
    }
}
