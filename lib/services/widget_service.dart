import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'database_helper.dart';
import '../models/prayer_time.dart';
import 'dart:convert';

class WidgetService {
  static const platform = MethodChannel('prayer_times_widget');
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Bu metodu dışarıdan erişilebilir yapalım
  static final WidgetService _instance = WidgetService._internal();
  factory WidgetService() => _instance;
  WidgetService._internal();

  Future<Map<String, dynamic>> getPrayerTimesForWidget() async {
    try {
      final db = await _dbHelper.database;
      final location = await _dbHelper.getLocationDetails();
      final selectedLocation = await _dbHelper.getSelectedLocation();
      
      if (location == null || selectedLocation == null) {
        print('Widget Service: Konum bilgisi bulunamadı');
        return getDefaultWidgetData();
      }

      final prayerTimes = await _dbHelper.getPrayerTimes(
        selectedLocation['districtId'],
        DateTime.now().year,
      );

      if (prayerTimes.isEmpty) {
        print('Widget Service: Namaz vakitleri bulunamadı');
        return getDefaultWidgetData();
      }

      final today = DateTime.now();
      final dayOfYear = int.parse(DateFormat('D').format(today));
      final todayPrayers = prayerTimes.firstWhere(
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

      final data = {
        'location': '${location['districtName']}, ${location['cityName']}',
        'fajr': todayPrayers.fajr,
        'tulu': todayPrayers.tulu,
        'zuhr': todayPrayers.zuhr,
        'asr': todayPrayers.asr,
        'maghrib': todayPrayers.maghrib,
        'isha': todayPrayers.isha,
      };

      // WearOS'a veri gönder
      try {
        print('WearOS\'a gönderilen veri: ${jsonEncode(data)}');
        await platform.invokeMethod('sendToWear', {
          'prayerTimesData': jsonEncode(data)
        });
      } catch (e) {
        print('WearOS veri gönderme hatası: $e');
      }

      return data;
    } catch (e) {
      print('Widget Service Error: $e');
      return getDefaultWidgetData();
    }
  }

  Map<String, dynamic> getDefaultWidgetData() {
    return {
      'location': 'Konum seçilmedi',
      'date': DateFormat('dd MMMM yyyy', 'tr_TR').format(DateTime.now()),
      'nextPrayerName': '-',
      'nextPrayerTime': '--:--',
      'fajr': '--:--',
      'tulu': '--:--',
      'zuhr': '--:--',
      'asr': '--:--',
      'maghrib': '--:--',
      'isha': '--:--',
    };
  }

  Map<String, String> _calculateNextPrayer(PrayerTime prayers) {
    final now = DateTime.now();
    final currentTime = DateFormat('HH:mm').format(now);
    
    final prayerList = [
      {'name': 'İmsak', 'time': prayers.fajr},
      {'name': 'Güneş', 'time': prayers.tulu},
      {'name': 'Öğle', 'time': prayers.zuhr},
      {'name': 'İkindi', 'time': prayers.asr},
      {'name': 'Akşam', 'time': prayers.maghrib},
      {'name': 'Yatsı', 'time': prayers.isha},
    ];

    // Şu anki vakitten sonraki ilk vakti bul
    for (var prayer in prayerList) {
      if (currentTime.compareTo(prayer['time']!) < 0) {
        return {
          'name': prayer['name']!,
          'time': prayer['time']!,
        };
      }
    }

    // Eğer tüm vakitler geçmişse, yarının imsak vaktini göster
    return {
      'name': 'İmsak',
      'time': prayers.fajr,
    };
  }
} 