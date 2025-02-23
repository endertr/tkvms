package com.example.takvimm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class WidgetDataReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        
        if (intent.action == "UPDATE_WIDGET_DATA") {
            val serviceIntent = Intent(context, WidgetUpdateService::class.java)
            @Suppress("UNCHECKED_CAST")
            serviceIntent.putExtra("widgetData", intent.getSerializableExtra("widgetData") as? HashMap<String, Any>)
            context.startForegroundService(serviceIntent)
        }
    }
} 