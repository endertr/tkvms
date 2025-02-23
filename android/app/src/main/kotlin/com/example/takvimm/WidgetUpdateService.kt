package com.example.takvimm

import android.app.*
import android.content.Intent
import android.os.IBinder
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Handler
import android.os.Looper
import android.os.Build
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import java.text.SimpleDateFormat
import java.util.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import android.util.Log
import android.graphics.Color

class WidgetUpdateService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val NOTIFICATION_CHANNEL_ID = "widget_service_channel"
    private val NOTIFICATION_ID = 1
    private val updateIntervalMillis = 1000L // 1 saniye
    private var lastWidgetData: Map<String, Any>? = null
    private val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
    private val dataReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "UPDATE_WIDGET_DATA") {
                @Suppress("UNCHECKED_CAST")
                lastWidgetData = intent.getSerializableExtra("widgetData") as? Map<String, Any>
                Log.d("WidgetService", "Received data: $lastWidgetData")
                updateWidget()
            }
        }
    }

    private val updateRunnable = object : Runnable {
        override fun run() {
            updateWidget()
            handler.postDelayed(this, updateIntervalMillis)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        
        // Android 14+ için receiver flags eklendi
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            Context.RECEIVER_NOT_EXPORTED
        } else {
            0
        }
        
        registerReceiver(
            dataReceiver,
            IntentFilter("UPDATE_WIDGET_DATA"),
            flags
        )
        
        handler.post(updateRunnable)
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(dataReceiver)
        handler.removeCallbacks(updateRunnable)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("WidgetUpdateService", "onStartCommand called")
        intent?.let {
            @Suppress("UNCHECKED_CAST")
            lastWidgetData = it.getSerializableExtra("widgetData") as? Map<String, Any>
            Log.d("WidgetUpdateService", "Received data: $lastWidgetData")
            updateWidget()
        }
        return START_STICKY
    }

    private fun calculateRemainingTime(prayerTime: String): String {
        try {
            val now = Calendar.getInstance()
            val prayerTimeCal = Calendar.getInstance()
            
            val prayerTimeParts = timeFormat.parse(prayerTime)?.let { date ->
                prayerTimeCal.time = date
                prayerTimeCal.set(
                    now.get(Calendar.YEAR),
                    now.get(Calendar.MONTH),
                    now.get(Calendar.DAY_OF_MONTH)
                )
            }

            // Eğer vakit geçmişse, bir sonraki güne ayarla
            if (now.after(prayerTimeCal)) {
                prayerTimeCal.add(Calendar.DAY_OF_MONTH, 1)
            }

            val diffMillis = prayerTimeCal.timeInMillis - now.timeInMillis
            val hours = diffMillis / (60 * 60 * 1000)
            val minutes = (diffMillis / (60 * 1000)) % 60
            val seconds = (diffMillis / 1000) % 60

            return String.format("%02d:%02d:%02d", hours, minutes, seconds)
        } catch (e: Exception) {
            Log.e("WidgetService", "Time calculation error: ${e.message}")
            return "--:--:--"
        }
    }

    private fun getCurrentPrayer(data: Map<String, Any>): String {
        val timeFormat = SimpleDateFormat("HH:mm", Locale("tr"))
        val currentTime = timeFormat.format(Calendar.getInstance().time)
        
        val prayers = listOf(
            "İmsak" to (data["fajr"] as? String ?: ""),
            "Güneş" to (data["tulu"] as? String ?: ""),
            "Öğle" to (data["zuhr"] as? String ?: ""),
            "İkindi" to (data["asr"] as? String ?: ""),
            "Akşam" to (data["maghrib"] as? String ?: ""),
            "Yatsı" to (data["isha"] as? String ?: "")
        )
        
        for (i in prayers.indices) {
            if (currentTime < prayers[i].second) {
                return if (i == 0) prayers.last().first else prayers[i - 1].first
            }
        }
        return prayers.last().first
    }

    private fun updateWidget() {
        val appWidgetManager = AppWidgetManager.getInstance(this)
        val widgetComponent = ComponentName(this, PrayerTimesWidget::class.java)
        val views = RemoteViews(packageName, R.layout.prayer_times_widget)

        lastWidgetData?.let { data ->
            try {
                Log.d("WidgetService", "Updating widget with data: $data")
                
                // Widget'ı güncelle
                views.setTextViewText(R.id.locationText, data["location"] as? String ?: "Konum seçilmedi")
                views.setTextViewText(R.id.dateText, data["date"] as? String ?: 
                    SimpleDateFormat("dd MMMM yyyy", Locale("tr")).format(Date()))
                
                // Bir sonraki namaz vaktini ve geri sayımı hesapla
                val currentPrayer = getCurrentPrayer(data)
                val prayers = listOf(
                    "İmsak" to (data["fajr"] as? String ?: ""),
                    "Güneş" to (data["tulu"] as? String ?: ""),
                    "Öğle" to (data["zuhr"] as? String ?: ""),
                    "İkindi" to (data["asr"] as? String ?: ""),
                    "Akşam" to (data["maghrib"] as? String ?: ""),
                    "Yatsı" to (data["isha"] as? String ?: "")
                )
                
                // Şu anki vakitten sonraki vakti bul
                val currentIndex = prayers.indexOfFirst { it.first == currentPrayer }
                val nextIndex = (currentIndex + 1) % prayers.size
                val nextPrayer = prayers[nextIndex]
                
                // Geri sayımı hesapla
                val remainingTime = calculateRemainingTime(nextPrayer.second)
                val countdownText = "${nextPrayer.first} vaktine: $remainingTime"
                
                views.setTextViewText(R.id.nextPrayerText, countdownText)
                
                // Vakit metinlerini ayarla
                views.setTextViewText(R.id.fajrTime, (data["fajr"] as? String ?: "--:--").toString())
                views.setTextViewText(R.id.tuluTime, (data["tulu"] as? String ?: "--:--").toString())
                views.setTextViewText(R.id.zuhrTime, (data["zuhr"] as? String ?: "--:--").toString())
                views.setTextViewText(R.id.asrTime, (data["asr"] as? String ?: "--:--").toString())
                views.setTextViewText(R.id.maghribTime, (data["maghrib"] as? String ?: "--:--").toString())
                views.setTextViewText(R.id.ishaTime, (data["isha"] as? String ?: "--:--").toString())

                // Progress bar için hesaplama
                val now = Calendar.getInstance()
                val currentTime = now.timeInMillis
                val nextPrayerTime = parseTime(nextPrayer.second)
                val previousPrayerTime = if (currentIndex >= 0) {
                    parseTime(prayers[currentIndex].second)
                } else {
                    parseTime(prayers.last().second) - 24 * 60 * 60 * 1000
                }

                val totalDuration = nextPrayerTime - previousPrayerTime
                val elapsedDuration = currentTime - previousPrayerTime
                val progress = ((elapsedDuration.toFloat() / totalDuration.toFloat()) * 100).toInt().coerceIn(0, 100)

                views.setProgressBar(R.id.timeProgressBar, 100, progress, false)
                
                // Aktif vakti belirle
                val currentPrayerId = mapOf(
                    "İmsak" to R.id.fajrTime,
                    "Güneş" to R.id.tuluTime,
                    "Öğle" to R.id.zuhrTime,
                    "İkindi" to R.id.asrTime,
                    "Akşam" to R.id.maghribTime,
                    "Yatsı" to R.id.ishaTime
                )[currentPrayer]

                // Önce tüm vakitleri normal renge çevir
                currentPrayerId?.let { id ->
                    views.setTextColor(id, Color.WHITE)
                }

                // Aktif vakti turkuaz yap
                currentPrayerId?.let { id ->
                    views.setTextColor(id, Color.parseColor("#40E0D0"))
                }

                appWidgetManager.updateAppWidget(widgetComponent, views)
                Log.d("WidgetService", "Widget updated successfully with countdown: $countdownText")
            } catch (e: Exception) {
                Log.e("WidgetService", "Error updating widget: ${e.message}")
                showErrorState(views, appWidgetManager, widgetComponent)
            }
        } ?: run {
            Log.d("WidgetService", "No data available, showing default state")
            showErrorState(views, appWidgetManager, widgetComponent)
        }
    }

    private fun parseTime(timeStr: String): Long {
        if (timeStr == "--:--") return 0L
        
        val parts = timeStr.split(":")
        val hour = parts[0].toInt()
        val minute = parts[1].toInt()
        
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        
        return calendar.timeInMillis
    }

    private fun showErrorState(views: RemoteViews, appWidgetManager: AppWidgetManager, widgetComponent: ComponentName) {
        views.setTextViewText(R.id.locationText, "Konum seçilmedi")
        views.setTextViewText(R.id.dateText, SimpleDateFormat("dd MMMM yyyy", Locale("tr")).format(Date()))
        views.setTextViewText(R.id.nextPrayerText, "Lütfen konum seçin")
        
        views.setTextViewText(R.id.fajrTime, "İmsak\n--:--")
        views.setTextViewText(R.id.tuluTime, "Güneş\n--:--")
        views.setTextViewText(R.id.zuhrTime, "Öğle\n--:--")
        views.setTextViewText(R.id.asrTime, "İkindi\n--:--")
        views.setTextViewText(R.id.maghribTime, "Akşam\n--:--")
        views.setTextViewText(R.id.ishaTime, "Yatsı\n--:--")
        
        // Hata durumunda tüm vakitleri beyaz yap
        val prayerIds = listOf(
            R.id.fajrTime,
            R.id.tuluTime,
            R.id.zuhrTime,
            R.id.asrTime,
            R.id.maghribTime,
            R.id.ishaTime
        )
        
        prayerIds.forEach { id ->
            views.setTextColor(id, Color.WHITE)
        }
        
        appWidgetManager.updateAppWidget(widgetComponent, views)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Namaz Vakitleri Widget Servisi",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Widget güncellemesi için gerekli servis"
                setShowBadge(false)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val notificationIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Namaz Vakitleri Widget")
            .setContentText("Widget güncelleniyor")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setShowWhen(false)
            .setSilent(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    fun updateWidgetData(data: Map<String, Any>) {
        lastWidgetData = data
    }
} 