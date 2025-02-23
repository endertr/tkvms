package com.example.takvimm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.NotificationManager
import android.app.NotificationChannel
import android.os.Build
import androidx.core.app.NotificationCompat
import android.app.PendingIntent
import android.util.Log
import android.media.MediaPlayer
import android.net.Uri

class AlarmReceiver : BroadcastReceiver() {

    companion object {
        const val NOTIFICATION_CHANNEL_ID = "alarm_channel"
        const val NOTIFICATION_ID = 2
    }

    private var mediaPlayer: MediaPlayer? = null

    override fun onReceive(context: Context, intent: Intent) {
        Log.d("AlarmReceiver", "Alarm received!")
        val prayerName = intent.getStringExtra("prayerName") ?: "Namaz Vakti"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Namaz Vakti Alarmı",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Namaz vakti için alarm bildirimi"
            }

            val notificationManager = context.getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }

        val notificationIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            notificationIntent,
            PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setContentTitle(prayerName)
            .setContentText("$prayerName geldi!")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, notification)

        val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(android.os.VibrationEffect.createOneShot(500, android.os.VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(500)
        }

        // MP3 çalma (prayerName'e göre özelleştirilmiş)
        try {
            val soundResourceName = when (prayerName) {
                "İmsak" -> "imsak_sound" // assets/raw/imsak_sound.mp3
                "Güneş" -> "gunes_sound" // assets/raw/gunes_sound.mp3
                "Öğle" -> "ogle_sound"   // assets/raw/ogle_sound.mp3
                "İkindi" -> "ikindi_sound" // assets/raw/ikindi_sound.mp3
                "Akşam" -> "aksam_sound"  // assets/raw/aksam_sound.mp3
                "Yatsı" -> "yatsi_sound"  // assets/raw/yatsi_sound.mp3
                else -> "alarm_sound"    // assets/raw/alarm_sound.mp3 (varsayılan)
            }

            val soundUri = Uri.parse("android.resource://${context.packageName}/raw/$soundResourceName")
            mediaPlayer = MediaPlayer().apply {
                setDataSource(context, soundUri)
                setAudioAttributes(
                    android.media.AudioAttributes.Builder()
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(android.media.AudioAttributes.USAGE_ALARM)
                        .build()
                )
                prepare()
                start()
            }

        } catch (e: Exception) {
            Log.e("AlarmReceiver", "Error playing sound: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun stopMediaPlayer() {
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (e: Exception) {
            Log.e("AlarmReceiver", "Error stopping media player: ${e.message}")
        }
    }

    fun onDestroy() {
        stopMediaPlayer()
    }
} 