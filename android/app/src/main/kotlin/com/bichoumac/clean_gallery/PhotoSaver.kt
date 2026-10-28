package com.bichoumac.clean_gallery

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.provider.MediaStore
import androidx.exifinterface.media.ExifInterface
import java.io.IOException
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Saves an edited photo as a new JPEG, with the same geometry and colors as
 * the editor's preview (`paintEdit` in `editor_screen.dart`): EXIF
 * orientation, then quarter turns, flip, color matrix, pencil strokes, and
 * the crop. The original is never changed.
 */
class PhotoSaver(private val context: Context) {
    private val resolver = context.contentResolver

    /** One pencil line: points in fractions of the rotated photo. */
    data class Stroke(val color: Int, val width: Double, val points: List<Double>)

    /**
     * Writes photo [id] edited as a new photo in the same folder, with the
     * same capture date and the original's EXIF tags (orientation set to
     * normal, new size). [crop] is `left, top, right, bottom` in fractions
     * of the rotated photo; [matrix] the 20 numbers of a 4 × 5 color
     * matrix. Returns the new photo's MediaStore id.
     */
    fun save(
        id: Long,
        quarterTurns: Int,
        flipped: Boolean,
        crop: List<Double>,
        matrix: List<Double>,
        strokes: List<Stroke>,
    ): String {
        var source = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
        // The GPS tags are only readable from the original with this.
        if (context.checkSelfPermission(Manifest.permission.ACCESS_MEDIA_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            source = MediaStore.setRequireOriginal(source)
        }
        val exif = resolver.openInputStream(source)?.use { ExifInterface(it) }
            ?: throw IOException("cannot read $id")
        val bitmap = upright(decode(source), exif.rotationDegrees, exif.isFlipped)

        // Size of the photo once turned, and the crop in its pixels.
        val turned = quarterTurns % 2 == 1
        val width = if (turned) bitmap.height else bitmap.width
        val height = if (turned) bitmap.width else bitmap.height
        val left = (crop[0] * width).roundToInt().coerceIn(0, width - 1)
        val top = (crop[1] * height).roundToInt().coerceIn(0, height - 1)
        val right = (crop[2] * width).roundToInt().coerceIn(left + 1, width)
        val bottom = (crop[3] * height).roundToInt().coerceIn(top + 1, height)

        val out = Bitmap.createBitmap(right - left, bottom - top, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        canvas.translate(-left.toFloat(), -top.toFloat())
        canvas.save()
        canvas.translate(width / 2f, height / 2f)
        if (flipped) canvas.scale(-1f, 1f)
        canvas.rotate(90f * quarterTurns)
        val paint = Paint(Paint.FILTER_BITMAP_FLAG).apply {
            colorFilter = ColorMatrixColorFilter(ColorMatrix(FloatArray(20) { matrix[it].toFloat() }))
        }
        canvas.drawBitmap(bitmap, -bitmap.width / 2f, -bitmap.height / 2f, paint)
        canvas.restore()
        bitmap.recycle()

        val shorter = min(width, height).toFloat()
        for (stroke in strokes) {
            val pen = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = stroke.color
                style = Paint.Style.STROKE
                strokeWidth = (stroke.width * shorter).toFloat()
                strokeCap = Paint.Cap.ROUND
                strokeJoin = Paint.Join.ROUND
            }
            val path = Path()
            for (i in stroke.points.indices step 2) {
                val x = (stroke.points[i] * width).toFloat()
                val y = (stroke.points[i + 1] * height).toFloat()
                if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
                // A single tap draws a dot: a line too short to see, with
                // round caps.
                if (stroke.points.size == 2) path.lineTo(x + 0.01f, y)
            }
            canvas.drawPath(path, pen)
        }

        return insert(id, out, exif)
    }

    /**
     * Decodes [uri], halved as many times as needed to stay under
     * [MAX_PIXELS], so a large photo cannot run out of memory.
     */
    private fun decode(uri: android.net.Uri): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        var sample = 1
        while (bounds.outWidth.toLong() * bounds.outHeight / (sample.toLong() * sample) > MAX_PIXELS) {
            sample *= 2
        }
        val options = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        return resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, options) }
            ?: throw IOException("cannot decode $uri")
    }

    /** [bitmap] turned and mirrored as its EXIF orientation says. */
    private fun upright(bitmap: Bitmap, degrees: Int, mirrored: Boolean): Bitmap {
        if (degrees == 0 && !mirrored) return bitmap
        val transform = Matrix().apply {
            if (mirrored) postScale(-1f, 1f)
            postRotate(degrees.toFloat())
        }
        val turned = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, transform, true)
        if (turned != bitmap) bitmap.recycle()
        return turned
    }

    /** Inserts [image] as a JPEG next to photo [id], with its EXIF tags. */
    private fun insert(id: Long, image: Bitmap, exif: ExifInterface): String {
        val original = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
        var folder = "Pictures/"
        var name = "IMG_$id"
        var dateTaken: Long? = null
        resolver.query(
            original,
            arrayOf(
                MediaStore.Images.Media.RELATIVE_PATH,
                MediaStore.Images.Media.DISPLAY_NAME,
                MediaStore.Images.Media.DATE_TAKEN,
            ),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                cursor.getString(0)?.let { folder = it }
                cursor.getString(1)?.let { name = it.substringBeforeLast('.') }
                if (!cursor.isNull(2)) dateTaken = cursor.getLong(2)
            }
        }
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, "${name}_edited_${System.currentTimeMillis() / 1000}.jpg")
            put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
            put(MediaStore.Images.Media.RELATIVE_PATH, folder)
            dateTaken?.let { put(MediaStore.Images.Media.DATE_TAKEN, it) }
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IOException("cannot create the photo")
        try {
            resolver.openOutputStream(uri)?.use { image.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, it) }
                ?: throw IOException("cannot write the photo")
            resolver.openFileDescriptor(uri, "rw")?.use { descriptor ->
                val copy = ExifInterface(descriptor.fileDescriptor)
                for (tag in KEPT_TAGS) {
                    exif.getAttribute(tag)?.let { copy.setAttribute(tag, it) }
                }
                copy.setAttribute(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL.toString())
                copy.setAttribute(ExifInterface.TAG_IMAGE_WIDTH, image.width.toString())
                copy.setAttribute(ExifInterface.TAG_IMAGE_LENGTH, image.height.toString())
                copy.setAttribute(ExifInterface.TAG_SOFTWARE, "Clean Gallery")
                copy.saveAttributes()
            }
            resolver.update(uri, ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        } finally {
            image.recycle()
        }
        return ContentUris.parseId(uri).toString()
    }

    private companion object {
        /** Largest photo decoded in full: 40 MP, 160 MB of pixels. */
        const val MAX_PIXELS = 40_000_000L

        const val JPEG_QUALITY = 95

        /** EXIF tags copied from the original: camera, settings, dates, place. */
        val KEPT_TAGS = listOf(
            ExifInterface.TAG_MAKE,
            ExifInterface.TAG_MODEL,
            ExifInterface.TAG_LENS_MAKE,
            ExifInterface.TAG_LENS_MODEL,
            ExifInterface.TAG_DATETIME,
            ExifInterface.TAG_DATETIME_ORIGINAL,
            ExifInterface.TAG_DATETIME_DIGITIZED,
            ExifInterface.TAG_OFFSET_TIME,
            ExifInterface.TAG_OFFSET_TIME_ORIGINAL,
            ExifInterface.TAG_OFFSET_TIME_DIGITIZED,
            ExifInterface.TAG_SUBSEC_TIME_ORIGINAL,
            ExifInterface.TAG_F_NUMBER,
            ExifInterface.TAG_APERTURE_VALUE,
            ExifInterface.TAG_EXPOSURE_TIME,
            ExifInterface.TAG_EXPOSURE_BIAS_VALUE,
            ExifInterface.TAG_PHOTOGRAPHIC_SENSITIVITY,
            ExifInterface.TAG_FOCAL_LENGTH,
            ExifInterface.TAG_FOCAL_LENGTH_IN_35MM_FILM,
            ExifInterface.TAG_FLASH,
            ExifInterface.TAG_WHITE_BALANCE,
            ExifInterface.TAG_METERING_MODE,
            ExifInterface.TAG_GPS_VERSION_ID,
            ExifInterface.TAG_GPS_LATITUDE,
            ExifInterface.TAG_GPS_LATITUDE_REF,
            ExifInterface.TAG_GPS_LONGITUDE,
            ExifInterface.TAG_GPS_LONGITUDE_REF,
            ExifInterface.TAG_GPS_ALTITUDE,
            ExifInterface.TAG_GPS_ALTITUDE_REF,
            ExifInterface.TAG_GPS_TIMESTAMP,
            ExifInterface.TAG_GPS_DATESTAMP,
        )
    }
}
