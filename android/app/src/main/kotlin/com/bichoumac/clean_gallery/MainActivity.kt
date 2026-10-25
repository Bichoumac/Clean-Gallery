package com.bichoumac.clean_gallery

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter engine and exposes the `clean_gallery/platform` channel.
 *
 * Only features that the Flutter packages do not cover live here. The Dart
 * side of this channel is `AndroidPlatformBridge`; the method contract is
 * documented in `docs/platform-android.md`.
 */
class MainActivity : FlutterActivity() {

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

    private companion object {
        /** Name of the MethodChannel shared with the Dart side. */
        const val CHANNEL = "clean_gallery/platform"
    }
}
