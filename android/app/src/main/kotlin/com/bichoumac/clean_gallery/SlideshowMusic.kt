package com.bichoumac.clean_gallery

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.FlutterInjector
import io.flutter.plugin.common.MethodChannel

/**
 * Music of the slideshows: plays one track in a loop, and lets the user
 * pick a track from the phone with the system file picker.
 *
 * The picker needs no audio permission: the app is granted read access to
 * the one file picked, kept across restarts with a persistable permission
 * and released when no slideshow uses it any more.
 */
class SlideshowMusic(private val activity: Activity) {

    private val context: Context get() = activity.applicationContext

    /** The track playing, or `null`. */
    private var player: MediaPlayer? = null

    /** Reply of the file picker in progress, if any. */
    private var pending: MethodChannel.Result? = null

    /**
     * Plays [uri] (a document picked by the user) or the Flutter [asset]
     * (a bundled track) in a loop at [volume], replacing any track playing.
     * Replies `true` once it plays, `false` when the file cannot be read.
     */
    fun play(uri: String?, asset: String?, volume: Double, result: MethodChannel.Result) {
        stop()
        val created = MediaPlayer()
        try {
            created.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build(),
            )
            when {
                uri != null -> created.setDataSource(context, Uri.parse(uri))
                asset != null -> {
                    val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
                    context.assets.openFd(key).use {
                        created.setDataSource(it.fileDescriptor, it.startOffset, it.length)
                    }
                }
                else -> throw IllegalArgumentException("uri or asset is required")
            }
            created.isLooping = true
            created.setVolume(volume.toFloat(), volume.toFloat())
            created.setOnPreparedListener {
                if (player === it) it.start()
                result.success(player === it)
            }
            created.setOnErrorListener { it, _, _ ->
                if (player === it) stop()
                true
            }
            player = created
            created.prepareAsync()
        } catch (e: Exception) {
            // Missing file, revoked access or unreadable track.
            created.release()
            if (player === created) player = null
            result.success(false)
        }
    }

    /** Pauses the track; [resume] continues it. */
    fun pause() {
        player?.takeIf { it.isPlaying }?.pause()
    }

    /** Continues a paused track. */
    fun resume() {
        player?.start()
    }

    /** Sets the volume, from 0 to 1, for fading out. */
    fun setVolume(volume: Double) {
        player?.setVolume(volume.toFloat(), volume.toFloat())
    }

    /** Stops and releases the track. */
    fun stop() {
        player?.release()
        player = null
    }

    /**
     * Opens the system file picker for one audio file. Replies with the
     * document's `uri` and display `name`, or `null` when cancelled.
     */
    fun pick(result: MethodChannel.Result) {
        pending?.success(null)
        pending = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "audio/*"
        }
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQUEST_PICK)
        } catch (e: Exception) {
            pending = null
            result.success(null)
        }
    }

    /** Handles the picker's reply; `false` for other requests. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK) return false
        val result = pending ?: return true
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        try {
            context.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        } catch (e: SecurityException) {
            // Not persistable: it still plays until the app restarts.
        }
        result.success(mapOf("uri" to uri.toString(), "name" to displayName(uri)))
        return true
    }

    /** Gives back the read access to [uri], no longer used. */
    fun release(uri: String) {
        try {
            context.contentResolver.releasePersistableUriPermission(
                Uri.parse(uri),
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        } catch (e: SecurityException) {
            // Already released.
        }
    }

    /** Display name of the document [uri], or its last path segment. */
    private fun displayName(uri: Uri): String {
        try {
            context.contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) return cursor.getString(0) ?: ""
            }
        } catch (e: Exception) {
            // Fall back to the URI.
        }
        return uri.lastPathSegment.orEmpty()
    }

    private companion object {
        const val REQUEST_PICK = 4201
    }
}
