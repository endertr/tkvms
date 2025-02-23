import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/prayer_time.dart';
import '../services/database_helper.dart';
import '../widgets/location_dialog.dart';
import 'location_selector.dart';
import 'package:flutter/services.dart';
import '../widgets/alarm_settings_dialog.dart';
import '../models/alarm_settings.dart';
import '../services/alarm_service.dart';
import 'package:hijri/hijri_calendar.dart';
import '../screens/alarm_settings_page.dart';
import '../widgets/prayer_alarm_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AlarmService _alarmService = AlarmService();
  List<PrayerTime> prayerTimes = [];
  DateTime selectedDate = DateTime.now();
  PrayerTime? currentDayPrayers;
  Timer? _timer;
  String nextPrayerName = '';
  Duration? timeUntilNextPrayer;
  Map<String, dynamic>? locationDetails;
  static const platform = MethodChannel('prayer_times_widget');
  static const alarmChannel = MethodChannel('com.example.takvimm/alarm');
  Map<String, AlarmSettings> _alarmSettings = {};
  Map<String, dynamic>? _customAlarm;

  // Turkuaz renk paleti
  static const Color primaryTurquoise = Color(0xFF40E0D0);
  static const Color darkTurquoise = Color(0xFF00CED1);
  static const Color lightTurquoise = Color(0xFF7FFFD4);
  static const Color backgroundTurquoise = Color(0xFF1A4B4B);

  // Hicri tarih için değişken
  late String _hijriDate;

  @override
  void initState() {
    super.initState();
    _loadPrayerTimes();
    _loadLocationDetails();
    _startTimer();
    _loadAlarmSettings();
    _loadCustomAlarm();
    _updateHijriDate();
    
    // Hicri tarihi günlük olarak güncelle
    Timer.periodic(const Duration(hours: 1), (timer) {
      _updateHijriDate();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateNextPrayerTime();
    });
  }

  void _updateNextPrayerTime() {
    if (currentDayPrayers == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final prayerTimes = [
      {'name': 'İmsak', 'time': _parseTime(currentDayPrayers!.fajr)},
      {'name': 'Güneş', 'time': _parseTime(currentDayPrayers!.tulu)},
      {'name': 'Öğle', 'time': _parseTime(currentDayPrayers!.zuhr)},
      {'name': 'İkindi', 'time': _parseTime(currentDayPrayers!.asr)},
      {'name': 'Akşam', 'time': _parseTime(currentDayPrayers!.maghrib)},
      {'name': 'Yatsı', 'time': _parseTime(currentDayPrayers!.isha)},
    ];

    DateTime nextPrayer = _parseTime(currentDayPrayers!.fajr).add(const Duration(days: 1));
    String nextName = 'İmsak';

    for (var prayer in prayerTimes) {
      final prayerTime = prayer['time'] as DateTime;
      if (prayerTime.isAfter(now)) {
        nextPrayer = prayerTime;
        nextName = prayer['name'] as String;
        break;
      }
    }

    setState(() {
      timeUntilNextPrayer = nextPrayer.difference(now);
      nextPrayerName = nextName;
    });
  }

  DateTime _parseTime(String timeStr) {
    final now = DateTime.now();
    final parts = timeStr.split(':');
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  Future<void> _loadPrayerTimes() async {
    final location = await _dbHelper.getSelectedLocation();
    if (location != null) {
      final times = await _dbHelper.getPrayerTimes(
        location['districtId'],
        location['year'],
      );
      setState(() {
        prayerTimes = times;
        _updateCurrentDayPrayers();
      });
      _loadLocationDetails();
    }
  }

  Future<void> _loadLocationDetails() async {
    final details = await _dbHelper.getLocationDetails();
    setState(() {
      locationDetails = details;
    });
  }

  void _updateCurrentDayPrayers() {
    final dayOfYear = int.parse(DateFormat('D').format(selectedDate));
    currentDayPrayers = prayerTimes.firstWhere(
      (prayer) => prayer.dayOfYear == dayOfYear,
      orElse: () => PrayerTime(
        dayOfYear: dayOfYear,
        fajr: '--:--',
        tulu: '--:--',
        zuhr: '--:--',
        asr: '--:--',
        maghrib: '--:--',
        isha: '--:--',
      ),
    );
    _updateNextPrayerTime();
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '';
    int hours = duration.inHours;
    int minutes = duration.inMinutes.remainder(60);
    int seconds = duration.inSeconds.remainder(60);
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildPrayerTimeItemNew(String name, String time, IconData icon, bool isActive) {
    // Vakit adını normalize et
    final normalizedName = name.toUpperCase();
    // Alarm ayarlarındaki karşılığını bul
    final alarmSetting = _alarmSettings[normalizedName];
    // Alarm durumunu kontrol et
    final hasAlarm = alarmSetting?.isEnabled == true && 
                     (alarmSetting?.isOnTimeEnabled == true || 
                      alarmSetting?.isBeforeEnabled == true);

    return GestureDetector(
      onTap: () {
        _showAlarmSettingsDialog(
          normalizedName,
          time,
          true,
        );
      },
      child: Center(  
        child: SizedBox(
          width: 240,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? primaryTurquoise.withOpacity(0.2) : Colors.black38,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  ":",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 12),
                      Icon(
                        Icons.alarm,
                        size: 18,
                        color: hasAlarm 
                          ? primaryTurquoise 
                          : Colors.white.withOpacity(0.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _updateWidget() async {
    try {
      await platform.invokeMethod('updateWidget');
    } catch (e) {
      print('Widget güncelleme hatası: $e');
    }
  }

  void _showLocationDialog() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const LocationDialog(),
    );

    if (result == true) {
      setState(() {
        _loadPrayerTimes();
      });
      _updateWidget();
    }
  }

  Future<void> _loadAlarmSettings() async {
    try {
      final settings = await _alarmService.loadAlarmSettings();
      print('Yüklenen alarm ayarları: $settings');
      if (mounted) {
        setState(() {
          _alarmSettings = settings;
        });
      }
    } catch (e) {
      print('Alarm ayarları yüklenirken hata: $e');
    }
  }

  Future<void> _showAlarmSettingsDialog(
    String? prayerName,
    String? prayerTime,
    bool showOnlyInitialPrayer,
  ) async {
    try {
      if (showOnlyInitialPrayer && prayerName != null && prayerTime != null) {
        // Tek vakit için popup dialog göster
        final settings = _alarmSettings[prayerName] ?? AlarmSettings();
        final result = await showDialog<AlarmSettings>(
          context: context,
          builder: (context) => PrayerAlarmDialog(
            prayerName: prayerName,
            prayerTime: prayerTime,
            settings: settings,
          ),
        );

        if (result != null) {
          final newSettings = Map<String, AlarmSettings>.from(_alarmSettings);
          newSettings[prayerName] = result;
          await _alarmService.saveAlarmSettings(newSettings);
          setState(() {
            _alarmSettings = newSettings;
          });
        }
      } else {
        // Genel alarm ayarları sayfasını göster
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlarmSettingsPage(
              alarmSettings: _alarmSettings,
              customAlarm: _customAlarm,
            ),
          ),
        );
        
        if (result != null) {
          final newSettings = result['settings'] as Map<String, AlarmSettings>;
          final newCustomAlarm = result['customAlarm'] as Map<String, dynamic>?;
          
          await _alarmService.saveAlarmSettings(newSettings);
          if (newCustomAlarm != null) {
            await _dbHelper.saveCustomAlarm(
              newCustomAlarm['enabled'] as bool,
              newCustomAlarm['time'] as TimeOfDay,
            );
          }
          
          setState(() {
            _alarmSettings = newSettings;
            _customAlarm = newCustomAlarm;
          });
        }
      }
    } catch (e) {
      print('Alarm ayarları hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<void> _loadCustomAlarm() async {
    final customAlarm = await _dbHelper.getCustomAlarm();
    if (customAlarm != null) {
      setState(() {
        _customAlarm = {
          'enabled': customAlarm['isEnabled'] == 1,
          'time': TimeOfDay(
            hour: customAlarm['hour'],
            minute: customAlarm['minute'],
          ),
        };
      });
    } else {
      setState(() {
        _customAlarm = null;
      });
    }
  }

  // Hicri ayın Türkçe karşılığını döndüren fonksiyon
  String _getHijriMonthName(int month) {
    const months = [
      'Muharrem',
      'Safer',
      'Rebiülevvel',
      'Rebiülahir',
      'Cemaziyelevvel',
      'Cemaziyelahir',
      'Recep',
      'Şaban',
      'Ramazan',
      'Şevval',
      'Zilkade',
      'Zilhicce'
    ];
    return months[month - 1];
  }

  // Hicri tarihi güncelleyen fonksiyon
  void _updateHijriDate() {
    try {
      HijriCalendar.setLocal('tr');
      final now = DateTime.now();
      final hijri = HijriCalendar();
      hijri.gregorianToHijri(now.year, now.month, now.day);
      setState(() {
        _hijriDate = '${hijri.hDay} ${_getHijriMonthName(hijri.hMonth)} ${hijri.hYear}';
      });
    } catch (e) {
      print('Hicri tarih hesaplama hatası: $e');
      setState(() {
        _hijriDate = ''; // Hata durumunda boş string göster
      });
    }
  }

  // Progress değerini hesaplayan fonksiyon
  double _calculateProgress() {
    if (timeUntilNextPrayer == null) return 0;
    
    final now = DateTime.now();
    final currentPrayerTime = _getCurrentPrayerTime();
    final nextPrayerTime = _getNextPrayerTime();
    
    if (currentPrayerTime == null || nextPrayerTime == null) return 0;
    
    final totalDuration = nextPrayerTime.difference(currentPrayerTime);
    final elapsedDuration = now.difference(currentPrayerTime);
    
    // Geçen süreyi ters çevirerek progress bar'ı geriye doğru sayar
    return 1 - (elapsedDuration.inSeconds / totalDuration.inSeconds);
  }

  // Şu anki vaktin zamanını döndüren fonksiyon
  DateTime? _getCurrentPrayerTime() {
    if (currentDayPrayers == null) return null;
    
    final now = DateTime.now();
    final prayerTimes = [
      {'name': 'İmsak', 'time': _parseTime(currentDayPrayers!.fajr)},
      {'name': 'Güneş', 'time': _parseTime(currentDayPrayers!.tulu)},
      {'name': 'Öğle', 'time': _parseTime(currentDayPrayers!.zuhr)},
      {'name': 'İkindi', 'time': _parseTime(currentDayPrayers!.asr)},
      {'name': 'Akşam', 'time': _parseTime(currentDayPrayers!.maghrib)},
      {'name': 'Yatsı', 'time': _parseTime(currentDayPrayers!.isha)},
    ];

    DateTime? currentPrayerTime;
    for (var prayer in prayerTimes) {
      final time = prayer['time'] as DateTime;
      if (time.isAfter(now)) {
        break;
      }
      currentPrayerTime = time;
    }
    
    return currentPrayerTime ?? _parseTime(currentDayPrayers!.isha);
  }

  // Bir sonraki vaktin zamanını döndüren fonksiyon
  DateTime? _getNextPrayerTime() {
    if (currentDayPrayers == null) return null;
    
    final now = DateTime.now();
    final prayerTimes = [
      {'name': 'İmsak', 'time': _parseTime(currentDayPrayers!.fajr)},
      {'name': 'Güneş', 'time': _parseTime(currentDayPrayers!.tulu)},
      {'name': 'Öğle', 'time': _parseTime(currentDayPrayers!.zuhr)},
      {'name': 'İkindi', 'time': _parseTime(currentDayPrayers!.asr)},
      {'name': 'Akşam', 'time': _parseTime(currentDayPrayers!.maghrib)},
      {'name': 'Yatsı', 'time': _parseTime(currentDayPrayers!.isha)},
    ];

    for (var prayer in prayerTimes) {
      final time = prayer['time'] as DateTime;
      if (time.isAfter(now)) {
        return time;
      }
    }
    
    // Eğer tüm vakitler geçmişse, yarının imsak vaktini döndür
    return _parseTime(currentDayPrayers!.fajr).add(const Duration(days: 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundTurquoise,
      body: SafeArea(
        child: Column(
          children: [
            // Hicri tarih
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                _hijriDate,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ),
            
            // Ortadaki büyük daire
            Expanded(
              flex: 2,
              child: Container(
                padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Arka plan dairesi
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: darkTurquoise.withOpacity(0.1),
                        ),
                      ),
                      // Progress bar
                      CircularProgressIndicator(
                        value: _calculateProgress(),
                        strokeWidth: 12,
                        backgroundColor: darkTurquoise.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(primaryTurquoise),
                      ),
                      // İçerik
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 0),
                          Text(
                            nextPrayerName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 0),
                          Text(
                            'vaktine',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 0),
                          Text(
                            _formatDuration(timeUntilNextPrayer),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Konum bilgisi ile vakitler listesi arasına SizedBox ekleyelim
            SizedBox(height: 10),

            // Konum bilgisi - Tıklanabilir
            GestureDetector(
              onTap: _showLocationDialog,
              child: Container(
                margin: EdgeInsets.symmetric(vertical: 4),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: darkTurquoise.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, color: primaryTurquoise, size: 18),
                    SizedBox(width: 6),
                    Text(
                      locationDetails != null 
                        ? '${locationDetails!['districtName']}, ${locationDetails!['cityName']}' 
                        : 'Konum Seçiniz',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_drop_down, color: primaryTurquoise, size: 18),
                  ],
                ),
              ),
            ),

            // Namaz vakitleri listesi
            Expanded(
              flex: 6,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 4),
                child: Column(
                  children: currentDayPrayers != null ? [
                    SizedBox(height: 10), // Üst boşluk ekleyelim
                    _buildPrayerTimeItemNew(
                      'İMSAK',
                      currentDayPrayers!.fajr,
                      Icons.nightlight_round,
                      nextPrayerName == 'İmsak'
                    ),
                    SizedBox(height: 8),
                    _buildPrayerTimeItemNew(
                      'GÜNEŞ',
                      currentDayPrayers!.tulu,
                      Icons.wb_sunny_outlined,
                      nextPrayerName == 'Güneş'
                    ),
                    SizedBox(height: 8),
                    _buildPrayerTimeItemNew(
                      'ÖĞLE',
                      currentDayPrayers!.zuhr,
                      Icons.light_mode,
                      nextPrayerName == 'Öğle'
                    ),
                    SizedBox(height: 8),
                    _buildPrayerTimeItemNew(
                      'İKİNDİ',
                      currentDayPrayers!.asr,
                      Icons.wb_sunny,
                      nextPrayerName == 'İkindi'
                    ),
                    SizedBox(height: 8),
                    _buildPrayerTimeItemNew(
                      'AKŞAM',
                      currentDayPrayers!.maghrib,
                      Icons.wb_twilight,
                      nextPrayerName == 'Akşam'
                    ),
                    SizedBox(height: 8),
                    _buildPrayerTimeItemNew(
                      'YATSI',
                      currentDayPrayers!.isha,
                      Icons.nights_stay,
                      nextPrayerName == 'Yatsı'
                    ),
                  ] : [],
                ),
              ),
            ),

            // Logo ve Butonlar
            Container(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 100,
                      height: 30,
                      fit: BoxFit.contain,
                    ),
                  ),
                  // Alt navigasyon çubuğu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(Icons.access_time, 'Namaz Vakitleri', true),
                      _buildNavItem(Icons.alarm, 'Alarm Ayarları', false),
                      _buildNavItem(Icons.settings, 'Ayarlar', false),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        switch (label) {
          case 'Alarm Ayarları':
            _showAlarmSettingsDialog(null, null, false);
            break;
          case 'Namaz Vakitleri':
            // Zaten ana sayfadayız
            break;
          case 'Ayarlar':
            // Ayarlar sayfası için
            break;
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? primaryTurquoise : Colors.white54,
            size: 24,
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? primaryTurquoise : Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
} 