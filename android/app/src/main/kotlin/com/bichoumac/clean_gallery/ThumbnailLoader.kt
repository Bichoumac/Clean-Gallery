package com.bichoumac.clean_gallery

import android.content.ContentResolver
import android.content.ContentUris
import android.graphics.Bitmap
import android.os.Handler
import android.provider.MediaStore
import android.util.Size
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.util.concurrent.LinkedBlockingDeque
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

/**
 * Loads thumbnails and screen-sized previews from MediaStore's own
 * thumbnail cache (`ContentResolver.loadThumbnail`), the cache the system
 * gallery uses, and returns raw RGBA pixels.
 *
 * Requests are served **last in, first out**: when the user scrolls far,
 * the thumbnails now on screen are loaded before the ones scrolled past.
 * Beyond [MAX_PENDING] waiting requests, the oldest are dropped and answered
 * with a `dropped` error; Flutter requests them again if they come back on
 * screen.
 */
class ThumbnailLoader(
    private val resolver: ContentResolver,
    private val mainHandler: Handler,
) {
    private val queue = LinkedBlockingDeque<Runnable>()

    private val pool = ThreadPoolExecutor(
        THREADS, THREADS, 30, TimeUnit.SECONDS, queue,
    )

    /**
     * Loads the image of MediaStore item [id] fitting in [width] × [height]
     * pixels and replies with `{width, height, rowBytes, pixels}`, where
     * `pixels` is RGBA 8888.
     *
     * Errors: `not_found` if the item or its thumbnail cannot be read,
     * `dropped` if the request was dropped from the queue.
     */
    fun load(
        id: Long,
        isVideo: Boolean,
        width: Int,
        height: Int,
        result: MethodChannel.Result,
    ) {
        val job = Job(result) { decode(id, isVideo, width, height) }
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

    private fun decode(id: Long, isVideo: Boolean, width: Int, height: Int): Map<String, Any> {
        val collection = if (isVideo) {
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }
        val uri = ContentUris.withAppendedId(collection, id)
        val loaded = resolver.loadThumbnail(uri, Size(width, height), null)
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
