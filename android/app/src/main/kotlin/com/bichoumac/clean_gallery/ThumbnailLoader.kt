package com.bichoumac.clean_gallery

import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.provider.MediaStore
import android.util.Size
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.util.concurrent.LinkedBlockingDeque
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import kotlin.math.roundToInt

/**
 * Loads grid thumbnails from MediaStore's own thumbnail cache
 * (`ContentResolver.loadThumbnail`), the cache the system gallery uses, and
 * the viewer's screen-sized previews from the photo files
 * (`ImageDecoder`), and returns raw RGBA pixels.
 *
 * Videos without a MediaStore thumbnail fall back to the cover picture
 * embedded in the file, then to the frame at 10 % of the video.
 *
 * Requests are served **last in, first out**: when the user scrolls far,
 * the thumbnails now on screen are loaded before the ones scrolled past.
 * Beyond [MAX_PENDING] waiting requests, the oldest are dropped and answered
 * with a `dropped` error; Flutter requests them again if they come back on
 * screen.
 */
class ThumbnailLoader(
    private val context: Context,
    private val mainHandler: Handler,
) {
    private val resolver = context.contentResolver

    private val queue = LinkedBlockingDeque<Runnable>()

    private val pool = ThreadPoolExecutor(
        THREADS, THREADS, 30, TimeUnit.SECONDS, queue,
    )

    /**
     * Loads the image of MediaStore item [id] fitting in [width] × [height]
     * pixels and replies with `{width, height, rowBytes, pixels}`, where
     * `pixels` is RGBA 8888. With [fromFile], a photo is decoded from its
     * file instead of MediaStore's cache: slower, but sharp at any size.
     *
     * Errors: `not_found` if the item or its thumbnail cannot be read,
     * `dropped` if the request was dropped from the queue.
     */
    fun load(
        id: Long,
        isVideo: Boolean,
        width: Int,
        height: Int,
        fromFile: Boolean,
        result: MethodChannel.Result,
    ) {
        val job = Job(result) { decode(id, isVideo, width, height, fromFile) }
        synchronized(queue) {
            // Newest first: put the job at the head of the queue.
            queue.offerFirst(job)
            while (queue.size > MAX_PENDING) {
                (queue.pollLast() as? Job)?.drop()
            }
        }
        // Wake a worker; the executor takes jobs from the head of the queue.
        pool.prestartAllCoreThreads()
    }

    /** Stops the worker threads. */
    fun shutdown() {
        pool.shutdownNow()
    }

    private fun decode(
        id: Long,
        isVideo: Boolean,
        width: Int,
        height: Int,
        fromFile: Boolean,
    ): Map<String, Any> {
        val collection = if (isVideo) {
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }
        val uri = ContentUris.withAppendedId(collection, id)
        val loaded = try {
            if (fromFile && !isVideo) {
                decodeScaled(uri, width, height)
            } else {
                resolver.loadThumbnail(uri, Size(width, height), null)
            }
        } catch (e: Exception) {
            if (!isVideo) throw e
            videoFallback(uri, width, height) ?: throw e
        }
        // Hardware bitmaps cannot be read back; copy to a software bitmap.
        val bitmap = if (loaded.config == Bitmap.Config.ARGB_8888) {
            loaded
        } else {
            loaded.copy(Bitmap.Config.ARGB_8888, false).also { loaded.recycle() }
        }
        val buffer = ByteBuffer.allocate(bitmap.rowBytes * bitmap.height)
        bitmap.copyPixelsToBuffer(buffer)
        val reply = mapOf(
            "width" to bitmap.width,
            "height" to bitmap.height,
            "rowBytes" to bitmap.rowBytes,
            "pixels" to buffer.array(),
        )
        bitmap.recycle()
        return reply
    }

    /**
     * Photo [uri] decoded from its file so that its longest side matches the
     * longest side of [width] × [height] (never upscaled), for the viewer.
     * MediaStore's thumbnails stop at 512 pixels on Samsung phones: asking
     * `loadThumbnail` for more returns them as they are, blurry once
     * stretched to the screen.
     */
    private fun decodeScaled(uri: Uri, width: Int, height: Int): Bitmap {
        val source = ImageDecoder.createSource(resolver, uri)
        return ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            // Longest sides only: the requested size may not follow the
            // photo's EXIF rotation, which the decoder applies.
            val own = maxOf(info.size.width, info.size.height)
            val scale = minOf(1.0, maxOf(width, height).toDouble() / own)
            if (scale < 1.0) {
                decoder.setTargetSize(
                    maxOf(1, (info.size.width * scale).roundToInt()),
                    maxOf(1, (info.size.height * scale).roundToInt()),
                )
            }
        }
    }

    /**
     * Picture for a video MediaStore has no thumbnail for: the cover
     * embedded in the file if there is one, otherwise the frame at 10 % of
     * the duration (past black intro frames), fitting in [width] × [height].
     */
    private fun videoFallback(uri: Uri, width: Int, height: Int): Bitmap? {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(context, uri)
            retriever.embeddedPicture?.let { bytes ->
                decodeSampled(bytes, width, height)?.let { return it }
            }
            val durationMs = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull() ?: 0L
            val timeUs = durationMs * 1000 / 10
            return retriever.getScaledFrameAtTime(
                timeUs,
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
                width,
                height,
            )
        } catch (e: Exception) {
            return null
        } finally {
            retriever.release()
        }
    }

    /** Decodes [bytes] at the smallest power-of-two size covering the target. */
    private fun decodeSampled(bytes: ByteArray, width: Int, height: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= width && bounds.outHeight / (sample * 2) >= height) {
            sample *= 2
        }
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
    }

    /** One request: runs [work] and replies once on the main thread. */
    private inner class Job(
        private val result: MethodChannel.Result,
        private val work: () -> Map<String, Any>,
    ) : Runnable {
        override fun run() {
            try {
                val reply = work()
                mainHandler.post { result.success(reply) }
            } catch (e: Exception) {
                mainHandler.post { result.error("not_found", e.message, null) }
            }
        }

        fun drop() {
            mainHandler.post { result.error("dropped", null, null) }
        }
    }

    private companion object {
        /** Parallel decodes; MediaStore thumbnails are mostly I/O bound. */
        const val THREADS = 4

        /** Waiting requests kept; older ones are dropped. */
        const val MAX_PENDING = 200
    }
}
