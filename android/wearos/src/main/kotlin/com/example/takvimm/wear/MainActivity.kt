package com.example.takvimm.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import android.widget.TextView
import androidx.wear.widget.BoxInsetLayout
import com.google.android.gms.wearable.*
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*
import android.util.Log
import android.widget.ProgressBar
import android.content.Intent
import android.view.View
import android.view.InputDevice
import android.view.MotionEvent
import android.view.View.OnGenericMotionListener
import androidx.wear.widget.WearableLinearLayoutManager
import androidx.wear.widget.WearableRecyclerView
import android.view.GestureDetector
import android.view.GestureDetector.SimpleOnGestureListener

class MainActivity : ComponentActivity(), DataClient.OnDataChangedListener {
    private lateinit var timeProgressBar: ProgressBar
    private lateinit var currentTimeHourMin: TextView
    private lateinit var currentTimeSec: TextView
    private lateinit var locationText: TextView
    private lateinit var remainingTime: TextView
    private lateinit var nextPrayerLabel: TextView
    private var updateTimer: Timer? = null
    private var clockTimer: Timer? = null  // Saat için ayrı timer
    private var currentPrayerTimes: String = ""
    private lateinit var gestureDetector: GestureDetector
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        initializeViews()
        
        // Veri dinleyicisini başlat
        try {
            Wearable.getDataClient(this).addListener(this)
            checkExistingData()
        } catch (e: Exception) {
            Log.e("WearOS", "Veri dinleyici hatası: ${e.message}")
            locationText.text = "Bağlantı hatası"
        }
        
        // Saati güncelle
        startTimeUpdates()
        
        setupRotaryInput()

        // Gesture detector'ı ayarla
        gestureDetector = GestureDetector(this, object : SimpleOnGestureListener() {
            override fun onFling(e1: MotionEvent?, e2: MotionEvent, velocityX: Float, velocityY: Float): Boolean {
                if (e1 != null) {
                    val diffX = e2.x - e1.x
                    if (Math.abs(diffX) > 100 && Math.abs(velocityX) > 100) {
                        if (diffX > 0) {
                            // Sağa kaydırma - CircularActivity'ye geç
                            startActivity(Intent(this@MainActivity, CircularActivity::class.java))
                            overridePendingTransition(R.anim.slide_in_left, R.anim.slide_out_right)
                            finish()
                            return true
                        }
                    }
                }
                return false
            }
        })
    }

    private fun initializeViews() {
        timeProgressBar = findViewById(R.id.timeProgressBar)
        currentTimeHourMin = findViewById(R.id.currentTimeHourMin)
        currentTimeSec = findViewById(R.id.currentTimeSec)
        locationText = findViewById(R.id.locationText)
        remainingTime = findViewById(R.id.remainingTime)
        nextPrayerLabel = findViewById(R.id.nextPrayerLabel)
        
        // Başlangıç metni
        locationText.text = "Yükleniyor..."
        currentTimeHourMin.text = "--:--"
        currentTimeSec.text = ":--"
        remainingTime.text = "--:--:--"
        nextPrayerLabel.text = "--:--"
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
            Log.d("WearOS", "Veri değişikliği algılandı")
            dataEvents.forEach { event ->
                if (event.type == DataEvent.TYPE_CHANGED) {
                    val dataItem = event.dataItem
                    if (dataItem.uri.path == "/prayer_times") {
                        val dataMap = DataMapItem.fromDataItem(dataItem).dataMap
                        val prayerTimesJson = dataMap.getString("prayer_times_data")
                        val timestamp = dataMap.getLong("timestamp")
                        Log.d("WearOS", "Alınan veri: $prayerTimesJson (timestamp: $timestamp)")
                        
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
            val location = data.getString("location")
            val prayers = mapOf(
                "İmsak" to data.getString("fajr"),
                "Güneş" to data.getString("tulu"),
                "Öğle" to data.getString("zuhr"),
                "İkindi" to data.getString("asr"),
                "Akşam" to data.getString("maghrib"),
                "Yatsı" to data.getString("isha")
            )

            locationText.text = location
            val (_, nextPrayer, remainingTimeStr, progress) = calculateNextPrayer(prayers)
            
            // Sonraki vakit etiketini güncelle
            nextPrayerLabel.text = "${nextPrayer.first} vaktine"
            remainingTime.text = remainingTimeStr
            timeProgressBar.progress = progress

            // Timer'ı başlat
            startCountdownTimer(prayers)

        } catch (e: Exception) {
            Log.e("WearOS", "Veri parse hatası: ${e.message}")
            locationText.text = "Hata"
            remainingTime.text = "--:--:--"
        }
    }

    private fun calculateNextPrayer(prayers: Map<String, String>): Quadruple<Pair<String, String>, Pair<String, String>, String, Int> {
        val timeFormat = SimpleDateFormat("HH:mm", Locale("tr"))
        val currentTime = timeFormat.format(Calendar.getInstance().time)
        
        val prayersList = prayers.toList()
        
        for (i in prayersList.indices) {
            if (currentTime < prayersList[i].second) {
                val currentPrayer = if (i == 0) prayersList.last() else prayersList[i - 1]
                val nextPrayer = prayersList[i]
                val remainingTime = calculateRemainingTime(nextPrayer.second)
                val progress = calculateProgress(currentPrayer.second, nextPrayer.second, currentTime)
                return Quadruple(currentPrayer, nextPrayer, remainingTime, progress)
            }
        }
        
        // Eğer tüm vakitler geçmişse, yarının ilk vakti
        val currentPrayer = prayersList.last()
        val nextPrayer = prayersList.first()
        val remainingTime = calculateRemainingTime(nextPrayer.second)
        val progress = calculateProgress(currentPrayer.second, nextPrayer.second, currentTime)
        return Quadruple(currentPrayer, nextPrayer, remainingTime, progress)
    }

    private fun calculateRemainingTime(prayerTime: String): String {
        try {
            val timeFormat = SimpleDateFormat("HH:mm", Locale("tr"))
            val now = Calendar.getInstance()
            val prayerTimeCal = Calendar.getInstance()
            
            timeFormat.parse(prayerTime)?.let { date ->
                prayerTimeCal.time = date
                prayerTimeCal.set(
                    now.get(Calendar.YEAR),
                    now.get(Calendar.MONTH),
                    now.get(Calendar.DAY_OF_MONTH)
                )
            }

            if (now.after(prayerTimeCal)) {
                prayerTimeCal.add(Calendar.DAY_OF_MONTH, 1)
            }

            val diffMillis = prayerTimeCal.timeInMillis - now.timeInMillis
            val hours = diffMillis / (60 * 60 * 1000)
            val minutes = (diffMillis / (60 * 1000)) % 60
            val seconds = (diffMillis / 1000) % 60

            return String.format("%02d:%02d:%02d", hours, minutes, seconds)
        } catch (e: Exception) {
            return "--:--:--"
        }
    }

    private fun calculateProgress(currentPrayerTime: String, nextPrayerTime: String, currentTime: String): Int {
        try {
            val timeFormat = SimpleDateFormat("HH:mm", Locale("tr"))
            val current = timeFormat.parse(currentTime)?.time ?: return 0
            val start = timeFormat.parse(currentPrayerTime)?.time ?: return 0
            var end = timeFormat.parse(nextPrayerTime)?.time ?: return 0
            
            if (end < start) {
                end += 24 * 60 * 60 * 1000
            }
            
            val total = end - start
            val elapsed = current - start
            return ((elapsed.toFloat() / total.toFloat()) * 100).toInt().coerceIn(0, 100)
        } catch (e: Exception) {
            return 0
        }
    }

    private fun startCountdownTimer(prayers: Map<String, String>) {
        updateTimer?.cancel()
        updateTimer = Timer()
        updateTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                runOnUiThread {
                    val (_, nextPrayer, remainingTimeStr, progress) = calculateNextPrayer(prayers)
                    // Timer'da da sonraki vakit etiketini güncelle
                    nextPrayerLabel.text = "${nextPrayer.first} vaktine"
                    remainingTime.text = remainingTimeStr
                    timeProgressBar.progress = progress
                }
            }
        }, 0, 1000)
    }

    private fun startTimeUpdates() {
        clockTimer?.cancel()
        clockTimer = Timer()
        clockTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                runOnUiThread {
                    val calendar = Calendar.getInstance()
                    val hourMin = String.format("%02d:%02d", 
                        calendar.get(Calendar.HOUR_OF_DAY),
                        calendar.get(Calendar.MINUTE))
                    val sec = String.format(":%02d", 
                        calendar.get(Calendar.SECOND))
                    
                    currentTimeHourMin.text = hourMin
                    currentTimeSec.text = sec
                }
            }
        }, 0, 1000)
    }

    data class Quadruple<A, B, C, D>(val first: A, val second: B, val third: C, val fourth: D)

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
        updateTimer?.cancel()
        clockTimer?.cancel()  // Clock timer'ı da temizle
        updateTimer = null
        clockTimer = null
        Wearable.getDataClient(this).removeListener(this)
    }

    private fun setupRotaryInput() {
        window.decorView.setOnGenericMotionListener { _, event ->
            if (event.action == MotionEvent.ACTION_SCROLL) {
                val delta = event.getAxisValue(MotionEvent.AXIS_SCROLL)
                if (delta < 0) {
                    // Saat yönünde çevrildi - CircularActivity'ye geç
                    startActivity(Intent(this, CircularActivity::class.java))
                    overridePendingTransition(R.anim.slide_in_left, R.anim.slide_out_right)
                    finish()
                } else if (delta > 0) {
                    // Saat yönünün tersine çevrildi - PrayerTimesActivity'ye geç
                    startActivity(Intent(this, PrayerTimesActivity::class.java))
                    overridePendingTransition(R.anim.slide_in_right, R.anim.slide_out_left)
                    finish()
                }
                true
            } else {
                false
            }
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        return gestureDetector.onTouchEvent(event) || super.onTouchEvent(event)
    }
} 