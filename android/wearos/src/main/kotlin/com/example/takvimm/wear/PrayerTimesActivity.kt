package com.example.takvimm.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import android.widget.TextView
import android.view.View
import android.view.MotionEvent
import android.view.InputDevice
import android.view.View.OnGenericMotionListener
import android.content.Intent
import android.util.Log
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.Wearable
import org.json.JSONObject
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataMapItem
import androidx.wear.widget.WearableRecyclerView
import androidx.wear.widget.WearableLinearLayoutManager
import android.view.GestureDetector
import android.view.GestureDetector.SimpleOnGestureListener
import java.util.*
import java.text.SimpleDateFormat

class PrayerTimesActivity : ComponentActivity(), DataClient.OnDataChangedListener {
    private lateinit var locationText: TextView
    private lateinit var dateText: TextView
    private lateinit var fajrTime: TextView
    private lateinit var sunriseTime: TextView
    private lateinit var dhuhrTime: TextView
    private lateinit var asrTime: TextView
    private lateinit var maghribTime: TextView
    private lateinit var ishaTime: TextView
    private lateinit var gestureDetector: GestureDetector

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_prayer_times)

        initializeViews()
        setupRotaryInput()

        try {
            Wearable.getDataClient(this).addListener(this)
            checkExistingData()
        } catch (e: Exception) {
            Log.e("WearOS", "Veri dinleyici hatası: ${e.message}")
            locationText.text = "Bağlantı hatası"
        }

        // Gesture detector'ı ayarla
        gestureDetector = GestureDetector(this, object : SimpleOnGestureListener() {
            override fun onFling(e1: MotionEvent?, e2: MotionEvent, velocityX: Float, velocityY: Float): Boolean {
                if (e1 != null) {
                    val diffX = e2.x - e1.x
                    if (Math.abs(diffX) > 100 && Math.abs(velocityX) > 100) {
                        if (diffX < 0) {
                            // Sola kaydırma - CircularActivity'ye geç
                            startActivity(Intent(this@PrayerTimesActivity, CircularActivity::class.java))
                            overridePendingTransition(R.anim.slide_in_right, R.anim.slide_out_left)
                            finish()
                            return true
                        }
                    }
                }
                return false
            }
        })
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        return if (gestureDetector.onTouchEvent(event)) {
            true
        } else {
            super.onTouchEvent(event)
        }
    }

    private fun initializeViews() {
        locationText = findViewById(R.id.locationText)
        dateText = findViewById(R.id.dateText)
        fajrTime = findViewById(R.id.fajrTime)
        sunriseTime = findViewById(R.id.sunriseTime)
        dhuhrTime = findViewById(R.id.dhuhrTime)
        asrTime = findViewById(R.id.asrTime)
        maghribTime = findViewById(R.id.maghribTime)
        ishaTime = findViewById(R.id.ishaTime)

        // Tarihi ayarla
        updateDateText()
    }

    private fun updateDateText() {
        val calendar = Calendar.getInstance()
        val dateFormat = SimpleDateFormat("dd MMMM EEEE", Locale("tr"))
        dateText.text = dateFormat.format(calendar.time)
    }

    private fun checkExistingData() {
        Wearable.getDataClient(this).getDataItems()
            .addOnSuccessListener { dataItems ->
                dataItems.forEach { dataItem ->
                    if (dataItem.uri.path == "/prayer_times") {
                        DataMapItem.fromDataItem(dataItem)
                            .dataMap
                            .getString("prayer_times_data")?.let { data ->
                                updateUIWithPrayerTimes(data)
                            }
                    }
                }
            }
    }

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        try {
            dataEvents.forEach { event ->
                if (event.type == DataEvent.TYPE_CHANGED) {
                    val dataItem = event.dataItem
                    if (dataItem.uri.path == "/prayer_times") {
                        val dataMap = DataMapItem.fromDataItem(dataItem).dataMap
                        val prayerTimesJson = dataMap.getString("prayer_times_data")
                        
                        if (prayerTimesJson != null) {
                            runOnUiThread {
                                updateUIWithPrayerTimes(prayerTimesJson)
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("WearOS", "Veri işleme hatası: ${e.message}")
        }
    }

    private fun updateUIWithPrayerTimes(jsonData: String) {
        try {
            val data = JSONObject(jsonData)
            locationText.text = data.getString("location")
            updateDateText()
            
            fajrTime.text = data.getString("fajr")
            sunriseTime.text = data.getString("tulu")
            dhuhrTime.text = data.getString("zuhr")
            asrTime.text = data.getString("asr")
            maghribTime.text = data.getString("maghrib")
            ishaTime.text = data.getString("isha")
        } catch (e: Exception) {
            Log.e("WearOS", "Veri parse hatası: ${e.message}")
            locationText.text = "Hata"
            dateText.text = ""
        }
    }

    override fun onResume() {
        super.onResume()
        Wearable.getDataClient(this).addListener(this)
    }

    override fun onPause() {
        super.onPause()
        Wearable.getDataClient(this).removeListener(this)
    }

    override fun onDestroy() {
        super.onDestroy()
        Wearable.getDataClient(this).removeListener(this)
    }

    private fun setupRotaryInput() {
        window.decorView.setOnGenericMotionListener { _, event ->
            if (event.action == MotionEvent.ACTION_SCROLL) {
                val delta = event.getAxisValue(MotionEvent.AXIS_SCROLL)
                if (delta < 0) {
                    // Saat yönünde çevrildi - MainActivity'ye geç
                    startActivity(Intent(this, MainActivity::class.java))
                    overridePendingTransition(R.anim.slide_in_left, R.anim.slide_out_right)
                    finish()
                } else if (delta > 0) {
                    // Saat yönünün tersine çevrildi - CircularActivity'ye geç
                    startActivity(Intent(this, CircularActivity::class.java))
                    overridePendingTransition(R.anim.slide_in_right, R.anim.slide_out_left)
                    finish()
                }
                true
            } else {
                false
            }
        }
    }
} 