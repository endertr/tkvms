package com.example.takvimm

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import android.content.Intent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import java.util.Calendar
import android.util.Log
import com.google.android.gms.wearable.*
import androidx.annotation.NonNull
import org.json.JSONObject
import android.os.Handler
import android.os.Looper

class MainActivity: FlutterActivity(), MethodChannel.MethodCallHandler {
    private val CHANNEL = "prayer_times_widget"
    private val ALARM_CHANNEL = "com.example.takvimm/alarm"
    private val PERMISSION_REQUEST_CODE = 123
    private lateinit var alarmManager: AlarmManager
    private lateinit var channel: MethodChannel

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "sendToWear" -> {
                val prayerTimesData = call.argument<String>("prayerTimesData")
                if (prayerTimesData != null) {
                    sendDataToWear(prayerTimesData)
                    result.success(true)
                } else {
                    result.error("ERROR", "Prayer times data is null", null)
                }
            }
            "updateWidget" -> {
                try {
                    @Suppress("UNCHECKED_CAST")
                    val data = call.arguments as? Map<String, Any>
                    if (data != null) {
                        // Widget service'i başlat
                        val serviceIntent = Intent(this, WidgetUpdateService::class.java)
                        serviceIntent.putExtra("widgetData", HashMap(data))
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }

                        // Broadcast gönder
                        val broadcastIntent = Intent("UPDATE_WIDGET_DATA")
                        broadcastIntent.putExtra("widgetData", HashMap(data))
                        sendBroadcast(broadcastIntent)

                        // Widget'ları güncelle
                        val appWidgetManager = AppWidgetManager.getInstance(this)
                        val widgetComponent = ComponentName(this, PrayerTimesWidget::class.java)
                        val widgetIds = appWidgetManager.getAppWidgetIds(widgetComponent)
                        val updateIntent = Intent(this, PrayerTimesWidget::class.java)
                        updateIntent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        updateIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
                        sendBroadcast(updateIntent)

                        result.success(true)
                    } else {
                        result.error("INVALID_DATA", "Widget data is null", null)
                    }
                } catch (e: Exception) {
                    Log.e("MainActivity", "Widget update error: ${e.message}")
                    result.error("UPDATE_ERROR", e.message, null)
                }
            }
            "getIntent" -> {
                val fromWidget = intent?.getBooleanExtra("fromWidget", false) ?: false
                result.success(fromWidget)
            }
            "setAlarm" -> {
                val alarmSettingsList = call.arguments as? List<*> ?: listOf<Any>()
                setAlarms(alarmSettingsList)
                result.success(true)
            }
            "cancelAlarm" -> {
                cancelAlarm()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun initializeWidgetEngine() {
        val widgetEngine = FlutterEngine(applicationContext)
        widgetEngine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put("widget_engine", widgetEngine)
    }

    private fun checkPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val permissions = mutableListOf<String>()
            
            if (ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                permissions.add(Manifest.permission.POST_NOTIFICATIONS)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                if (ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.FOREGROUND_SERVICE_DATA_SYNC
                    ) != PackageManager.PERMISSION_GRANTED
                ) {
                    permissions.add(Manifest.permission.FOREGROUND_SERVICE_DATA_SYNC)
                }
            }

            if (permissions.isNotEmpty()) {
                ActivityCompat.requestPermissions(
                    this,
                    permissions.toTypedArray(),
                    PERMISSION_REQUEST_CODE
                )
            }
        }
    }

    private fun setupAlarmChannel() {
        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, ALARM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setAlarm" -> {
                    val alarmSettingsList = call.arguments as? List<*> ?: listOf<Any>()
                    setAlarms(alarmSettingsList)
                    result.success(true)
                }
                "cancelAlarm" -> {
                    cancelAlarm()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setAlarms(alarmSettingsList: List<*>) {
        // Önce tüm alarmları iptal et
        cancelAlarm()

        // Namaz vakti alarmlarını kur
        for (item in alarmSettingsList) {
            val settings = item as? Map<*, *> ?: continue
            
            // Vaktinde alarm
            if (settings["isOnTimeEnabled"] as? Boolean == true) {
                setAlarmForPrayer(settings, 0)
            }
            
            // Vaktinden önce alarm
            if (settings["isBeforeEnabled"] as? Boolean == true) {
                val offsetMinutes = settings["offsetMinutes"] as? Int ?: 0
                if (offsetMinutes > 0) {
                    setAlarmForPrayer(settings, -offsetMinutes)
                }
            }
        }

        // Özel alarm varsa onu da kur
        val customAlarm = alarmSettingsList.lastOrNull() as? Map<*, *>
        if (customAlarm != null && customAlarm["type"] == "custom" && customAlarm["enabled"] as? Boolean == true) {
            val time = customAlarm["time"] as? Map<*, *> ?: return
            val hour = time["hour"] as? Int ?: return
            val minute = time["minute"] as? Int ?: return
            
            setCustomAlarm(hour, minute)
        }
    }

    private fun setCustomAlarm(hour: Int, minute: Int) {
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            action = "com.example.takvimm.SET_ALARM"
            putExtra("prayerName", "Özel Alarm")
        }

        val calendar = Calendar.getInstance().apply {
            timeInMillis = System.currentTimeMillis()
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
        }

        if (calendar.timeInMillis <= System.currentTimeMillis()) {
            calendar.add(Calendar.DAY_OF_YEAR, 1)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            this,
            1000, // Özel alarm için farklı bir requestCode
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                calendar.timeInMillis,
                pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                calendar.timeInMillis,
                pendingIntent
            )
        }
    }

    private fun cancelAlarm() {
        // Tüm vakitler için önceden oluşturulmuş PendingIntent'leri iptal et
        val prayerNames = listOf("İmsak", "Güneş", "Öğle", "İkindi", "Akşam", "Yatsı")
        for (prayerName in prayerNames) {
            val requestCode = generateRequestCode(prayerName)
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                requestCode,
                Intent(this, AlarmReceiver::class.java),
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE // Sadece varsa al, yoksa oluşturma
            )
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel() // Gerekli
                Log.d("MainActivity", "Alarm cancelled for $prayerName")
            }
        }

        // AlarmReceiver'ı durdur (ses çalmayı durdurmak için)
        val alarmReceiver = AlarmReceiver()
        alarmReceiver.onDestroy()
    }

    private fun generateRequestCode(prayerName: String): Int {
        // Her vakit için benzersiz bir requestCode üret
        return when (prayerName) {
            "İmsak" -> 1
            "Güneş" -> 2
            "Öğle" -> 3
            "İkindi" -> 4
            "Akşam" -> 5
            "Yatsı" -> 6
            else -> 0 // Geçersiz durum
        }
    }

    private fun setAlarmForPrayer(settings: Map<*, *>, offsetMinutes: Int) {
        val prayerName = settings["prayerName"] as? String ?: return
        val prayerTime = settings["prayerTime"] as? String ?: return

        val (hours, minutes) = prayerTime.split(":").map { it.toInt() }

        val intent = Intent(this, AlarmReceiver::class.java).apply {
            action = "com.example.takvimm.SET_ALARM"
            putExtra("prayerName", prayerName)
        }

        val calendar = Calendar.getInstance().apply {
            timeInMillis = System.currentTimeMillis()
            set(Calendar.HOUR_OF_DAY, hours)
            set(Calendar.MINUTE, minutes)
            set(Calendar.SECOND, 0)
            add(Calendar.MINUTE, offsetMinutes)
        }

        if (calendar.timeInMillis <= System.currentTimeMillis()) {
            calendar.add(Calendar.DAY_OF_YEAR, 1)
        }

        val requestCode = generateRequestCode(prayerName) + 
            if (offsetMinutes != 0) 100 else 0 // Vaktinden önce alarmlar için farklı requestCode

        val pendingIntent = PendingIntent.getBroadcast(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                calendar.timeInMillis,
                pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                calendar.timeInMillis,
                pendingIntent
            )
        }

        Log.d("MainActivity", "Alarm set for $prayerName at ${calendar.time}")
    }

    override fun onResume() {
        super.onResume()
        // Widget'ları güncelle
        val widgetIntent = Intent(this, PrayerTimesWidget::class.java)
        widgetIntent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        val ids = AppWidgetManager.getInstance(this)
            .getAppWidgetIds(ComponentName(this, PrayerTimesWidget::class.java))
        widgetIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        sendBroadcast(widgetIntent)

        // WearOS verilerini güncelle
        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL)
            .invokeMethod("getPrayerTimes", null)
    }

    private fun sendDataToWear(prayerTimesJson: String) {
        try {
            Log.d("MainActivity", "WearOS'a gönderilen veri: $prayerTimesJson")
            val putDataReq = PutDataMapRequest.create("/prayer_times").run {
                dataMap.putString("prayer_times_data", prayerTimesJson)
                // Zaman damgası ekleyelim ki her güncelleme algılansın
                dataMap.putLong("timestamp", System.currentTimeMillis())
                asPutDataRequest()
            }
            
            Wearable.getDataClient(this).putDataItem(putDataReq)
                .addOnSuccessListener {
                    Log.d("MainActivity", "Veri başarıyla gönderildi")
                }
                .addOnFailureListener { e ->
                    Log.e("MainActivity", "Veri gönderme hatası: ${e.message}")
                    // Hata durumunda tekrar deneme
                    Handler(Looper.getMainLooper()).postDelayed({
                        sendDataToWear(prayerTimesJson)
                    }, 1000)
                }
        } catch (e: Exception) {
            Log.e("MainActivity", "Veri gönderme hatası: ${e.message}")
        }
    }
}
