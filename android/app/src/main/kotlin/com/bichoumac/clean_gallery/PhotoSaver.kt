package com.bichoumac.clean_gallery

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.provider.MediaStore
import androidx.exifinterface.media.ExifInterface
import java.io.IOException
import java.nio.ByteBuffer

/**
 * Saves an edited photo as a new JPEG next to its original. The pixels come
 * from the editor, which renders the edit at full resolution with the same
 * code as its preview; this class only encodes them, inserts the photo with
 * MediaStore and copies the original's EXIF tags. The original is never
 * changed.
 */
class PhotoSaver(private val context: Context) {
    private val resolver = context.contentResolver

    /**
     * Writes [rgba] ([width] × [height] opaque pixels, 4 bytes each) as a
     * new photo in the folder of photo [id], with its capture date and EXIF
     * tags (orientation set to normal, new size). Returns the new photo's
     * MediaStore id.
     */
    fun save(id: Long, width: Int, height: Int, rgba: ByteArray): String {
        require(rgba.size == width * height * 4) { "expected $width × $height RGBA pixels" }
        var source = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
        // The GPS tags are only readable from the original with this.
        if (context.checkSelfPermission(Manifest.permission.ACCESS_MEDIA_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            source = MediaStore.setRequireOriginal(source)
        }
        val exif = resolver.openInputStream(source)?.use { ExifInterface(it) }
            ?: throw IOException("cannot read $id")
        val image = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        // ARGB_8888 holds its bytes as R, G, B, A: the editor's order.
        image.copyPixelsFromBuffer(ByteBuffer.wrap(rgba))
        return insert(id, image, exif)
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
