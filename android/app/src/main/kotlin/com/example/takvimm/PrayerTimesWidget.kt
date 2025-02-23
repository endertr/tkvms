package com.example.takvimm

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import android.util.Log
import android.os.Build
import java.text.SimpleDateFormat
import java.util.*

class PrayerTimesWidget : AppWidgetProvider() {
    companion object {
        private const val CHANNEL = "prayer_times_widget"
        private const val ENGINE_ID = "widget_engine"

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val widgetComponent = ComponentName(context, PrayerTimesWidget::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(widgetComponent)
            
            val updateIntent = Intent(context, PrayerTimesWidget::class.java)
            updateIntent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            updateIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
            context.sendBroadcast(updateIntent)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        Log.d("PrayerTimesWidget", "onUpdate called with ${appWidgetIds.size} widgets")
        
        // Start the WidgetUpdateService
        val serviceIntent = Intent(context, WidgetUpdateService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
        
        // Update each widget instance
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        val intent = Intent(context, WidgetUpdateService::class.java)
        context.startForegroundService(intent)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        context.stopService(Intent(context, WidgetUpdateService::class.java))
        FlutterEngineCache.getInstance().remove(ENGINE_ID)
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        Log.d("PrayerTimesWidget", "updateAppWidget called for widget $appWidgetId")
        
        val views = RemoteViews(context.packageName, R.layout.prayer_times_widget)
        
        // Ana uygulamayı açmak için Intent oluştur
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        views.setOnClickPendingIntent(R.id.widget_layout, pendingIntent)

        // Varsayılan değerleri ayarla
        views.setTextViewText(R.id.locationText, "Yükleniyor...")
        views.setTextViewText(R.id.dateText, SimpleDateFormat("dd MMMM yyyy", Locale("tr")).format(Date()))
        views.setTextViewText(R.id.nextPrayerText, "Veriler güncelleniyor...")
        views.setTextViewText(R.id.fajrTime, "İmsak\n--:--")
        views.setTextViewText(R.id.tuluTime, "Güneş\n--:--")
        views.setTextViewText(R.id.zuhrTime, "Öğle\n--:--")
        views.setTextViewText(R.id.asrTime, "İkindi\n--:--")
        views.setTextViewText(R.id.maghribTime, "Akşam\n--:--")
        views.setTextViewText(R.id.ishaTime, "Yatsı\n--:--")
        
        appWidgetManager.updateAppWidget(appWidgetId, views)

        try {
            val engine = FlutterEngineCache.getInstance().get(ENGINE_ID)
                ?: FlutterEngine(context).also {
                    it.dartExecutor.executeDartEntrypoint(
                        io.flutter.embedding.engine.dart.DartExecutor.DartEntrypoint.createDefault()
                    )
                    FlutterEngineCache.getInstance().put(ENGINE_ID, it)
                }

            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod("getPrayerTimes", null, object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        Log.d("PrayerTimesWidget", "getPrayerTimes success: $result")
                        @Suppress("UNCHECKED_CAST")
                        val data = result as? Map<String, Any>
                        
                        if (data != null) {
                            val serviceIntent = Intent(context, WidgetUpdateService::class.java)
                            serviceIntent.putExtra("widgetData", HashMap(data))
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                context.startForegroundService(serviceIntent)
                            } else {
                                context.startService(serviceIntent)
                            }
                        }
                    }

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        Log.e("PrayerTimesWidget", "Error: $errorMessage")
                    }

                    override fun notImplemented() {
                        Log.e("PrayerTimesWidget", "Method not implemented")
                    }
                })
        } catch (e: Exception) {
            Log.e("PrayerTimesWidget", "Exception: ${e.message}")
        }
    }

    // Saat:dakika formatındaki string'i milisaniyeye çevir
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
} 