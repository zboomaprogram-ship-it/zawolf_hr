package com.zbooma.zawolfhr

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat
import java.util.Calendar

/**
 * A real daily work alarm owned by ZaWolf HR. It does not depend on whichever
 * Clock application happens to be installed by the phone manufacturer.
 */
class PersonalAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val userId = intent.getStringExtra(PersonalAlarmScheduler.EXTRA_USER_ID) ?: return
        val hour = intent.getIntExtra(PersonalAlarmScheduler.EXTRA_HOUR, 8)
        val minute = intent.getIntExtra(PersonalAlarmScheduler.EXTRA_MINUTE, 45)
        val message = intent.getStringExtra(PersonalAlarmScheduler.EXTRA_MESSAGE) ?: "منبه الدوام - ZaWolf HR"

        if (!PersonalAlarmScheduler.isEnabled(context, userId)) return

        // Queue tomorrow before ringing, so a terminated app does not lose the
        // following workday's alarm.
        PersonalAlarmScheduler.schedule(context, userId, hour, minute, message)

        val serviceIntent = Intent(context, PersonalAlarmService::class.java).apply {
            action = PersonalAlarmService.ACTION_RING
            putExtra(PersonalAlarmScheduler.EXTRA_MESSAGE, message)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(context, serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}

object PersonalAlarmScheduler {
    const val EXTRA_USER_ID = "userId"
    const val EXTRA_HOUR = "hour"
    const val EXTRA_MINUTE = "minute"
    const val EXTRA_MESSAGE = "message"
    private const val PREFS = "zawolf_personal_alarm"
    private const val ENABLED_PREFIX = "enabled_"

    fun schedule(context: Context, userId: String, hour: Int, minute: Int, message: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean("$ENABLED_PREFIX$userId", true)
            .apply()

        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour.coerceIn(0, 23))
            set(Calendar.MINUTE, minute.coerceIn(0, 59))
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val operation = pendingIntent(context, userId, hour, minute, message)
        val showIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.let { launch ->
                PendingIntent.getActivity(
                    context,
                    requestCode(userId),
                    launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            }
        val alarmClockInfo = AlarmManager.AlarmClockInfo(
            calendar.timeInMillis,
            showIntent ?: operation,
        )
        alarmManager.setAlarmClock(alarmClockInfo, operation)
    }

    fun cancel(context: Context, userId: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean("$ENABLED_PREFIX$userId", false)
            .apply()
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent(context, userId, 0, 0, ""))
        context.stopService(Intent(context, PersonalAlarmService::class.java))
    }

    fun isEnabled(context: Context, userId: String): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean("$ENABLED_PREFIX$userId", false)

    private fun pendingIntent(
        context: Context,
        userId: String,
        hour: Int,
        minute: Int,
        message: String,
    ): PendingIntent {
        val intent = Intent(context, PersonalAlarmReceiver::class.java).apply {
            action = "com.zbooma.zawolfhr.PERSONAL_ALARM.$userId"
            putExtra(EXTRA_USER_ID, userId)
            putExtra(EXTRA_HOUR, hour)
            putExtra(EXTRA_MINUTE, minute)
            putExtra(EXTRA_MESSAGE, message)
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode(userId),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun requestCode(userId: String): Int = userId.hashCode() and 0x7fffffff
}
