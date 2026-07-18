package com.zbooma.zawolfhr

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/** Keeps the alarm audible until the employee taps the Stop action. */
class PersonalAlarmService : Service() {
    companion object {
        const val ACTION_RING = "com.zbooma.zawolfhr.action.RING_WORK_ALARM"
        const val ACTION_STOP = "com.zbooma.zawolfhr.action.STOP_WORK_ALARM"
        private const val CHANNEL_ID = "zawolf_work_alarm_v2"
        const val NOTIFICATION_ID = 7431
    }

    private var player: MediaPlayer? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopAlarm()
            stopSelf()
            return START_NOT_STICKY
        }

        val message = intent?.getStringExtra(PersonalAlarmScheduler.EXTRA_MESSAGE)
            ?: "منبه الدوام - ZaWolf HR"
        createChannel()
        startForeground(NOTIFICATION_ID, buildNotification(message))
        ring()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopAlarm()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun ring() {
        if (player?.isPlaying == true) return
        player = MediaPlayer.create(applicationContext, R.raw.wolf_alarm)?.apply {
            isLooping = true
            start()
        }
    }

    private fun stopAlarm() {
        player?.let {
            if (it.isPlaying) it.stop()
            it.release()
        }
        player = null
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "منبه الدوام",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "منبه الدوام اليومي"
            // The service owns the looping alarm sound so Stop can silence it
            // immediately on every Android vendor implementation.
            setSound(null, null)
            enableVibration(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(message: String) = NotificationCompat.Builder(this, CHANNEL_ID)
        .setSmallIcon(R.mipmap.launcher_icon)
        .setContentTitle("منبه الدوام")
        .setContentText(message)
        .setCategory(NotificationCompat.CATEGORY_ALARM)
        .setPriority(NotificationCompat.PRIORITY_MAX)
        .setOngoing(true)
        .setAutoCancel(false)
        .addAction(
            android.R.drawable.ic_media_pause,
            "إيقاف المنبه",
            PendingIntent.getBroadcast(
                this,
                7432,
                Intent(this, PersonalAlarmStopReceiver::class.java).apply {
                    action = ACTION_STOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ),
        )
        .build()
}
