package com.bichoumac.clean_gallery

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * Notifications at set times for memories and rituals, with no background
 * work (ADR 0027).
 *
 * The app hands over the next notifications, each with its time, title,
 * text and payload; they are kept in the app's preferences. One inexact
 * alarm is set for the earliest. When it rings, [ReminderReceiver] shows the
 * notifications due and sets the alarm for the next one. Nothing here reads
 * photos or the database: the slideshow is built by the app when the
 * notification is tapped.
 */
object Reminders {

    /** One notification to show at [at] (epoch milliseconds). */
    data class Reminder(
        val id: Int,
        val at: Long,
        val title: String,
        val body: String,
        val payload: String,
    ) {
        fun toJson(): JSONObject = JSONObject()
            .put("id", id)
            .put("at", at)
            .put("title", title)
            .put("body", body)
            .put("payload", payload)

        companion object {
            fun fromJson(json: JSONObject) = Reminder(
                id = json.getInt("id"),
                at = json.getLong("at"),
                title = json.getString("title"),
                body = json.getString("body"),
                payload = json.getString("payload"),
            )

            /** Reminders from the maps sent over the channel. */
            fun listFrom(raw: Any?): List<Reminder> =
                (raw as? List<*>).orEmpty().mapNotNull { entry ->
                    val map = entry as? Map<*, *> ?: return@mapNotNull null
                    Reminder(
                        id = (map["id"] as? Number)?.toInt() ?: return@mapNotNull null,
                        at = (map["at"] as? Number)?.toLong() ?: return@mapNotNull null,
                        title = map["title"] as? String ?: "",
                        body = map["body"] as? String ?: "",
                        payload = map["payload"] as? String ?: "",
                    )
                }
        }
    }

    /** Intent extra carrying the payload of a tapped notification. */
    const val EXTRA_PAYLOAD = "com.bichoumac.clean_gallery.REMINDER_PAYLOAD"

    /** Late notifications older than this are dropped rather than shown. */
    private const val MAX_LATE_MS = 6 * 60 * 60 * 1000L

    private const val PREFERENCES = "reminders"
    private const val KEY_LIST = "list"
    private const val CHANNEL_ID = "slideshows"
    private const val ACTION_ALARM = "com.bichoumac.clean_gallery.REMINDER_ALARM"

    /** Replaces every pending notification with [reminders]. */
    fun schedule(context: Context, reminders: List<Reminder>) {
        save(context, reminders.sortedBy { it.at })
        arm(context)
    }

    /**
     * Shows the notifications due at [now], drops them, and sets the alarm
     * for the next one. Called when the alarm rings and after a reboot.
     */
    fun deliverDue(context: Context, now: Long = System.currentTimeMillis()) {
        val all = load(context)
        val (due, later) = all.partition { it.at <= now + 60_000 }
        for (reminder in due) {
            if (now - reminder.at <= MAX_LATE_MS) show(context, reminder)
        }
        save(context, later)
        arm(context)
    }

    /** Whether the user lets the app show notifications. */
    fun canNotify(context: Context): Boolean =
        NotificationManagerCompat.from(context).areNotificationsEnabled()

    /** Sets one inexact alarm for the earliest pending notification. */
    private fun arm(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val intent = PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, ReminderReceiver::class.java).setAction(ACTION_ALARM),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val next = load(context).minByOrNull { it.at }
        if (next == null) {
            alarms.cancel(intent)
        } else {
            // Inexact: no "Alarms & reminders" permission needed; Android
            // may deliver it a few minutes late.
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next.at, intent)
        }
    }

    private fun show(context: Context, reminder: Reminder) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.reminder_channel),
                NotificationManager.IMPORTANCE_DEFAULT,
            ),
        )
        val open = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra(EXTRA_PAYLOAD, reminder.payload)
        val tap = PendingIntent.getActivity(
            context,
            reminder.id,
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_clean_gallery)
            .setContentTitle(reminder.title)
            .setContentText(reminder.body)
            .setContentIntent(tap)
            .setAutoCancel(true)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(reminder.id, notification)
        } catch (e: SecurityException) {
            // Notifications not allowed: the memory card still shows in the app.
        }
    }

    private fun load(context: Context): List<Reminder> {
        val text = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .getString(KEY_LIST, null) ?: return emptyList()
        return try {
            val array = JSONArray(text)
            (0 until array.length()).map { Reminder.fromJson(array.getJSONObject(it)) }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun save(context: Context, reminders: List<Reminder>) {
        val array = JSONArray()
        reminders.forEach { array.put(it.toJson()) }
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_LIST, array.toString())
            .apply()
    }
}

/**
 * Wakes for the [Reminders] alarm, and after a reboot or an app update to
 * set it again (alarms do not survive either). Only reads the list of
 * pending notifications; never photos or the database.
 */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Reminders.deliverDue(context)
    }
}
