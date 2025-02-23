//import 'package:shared_preferences/shared_preferences.dart'; // Artık kullanılmıyor
import '../models/alarm_settings.dart';
//import 'dart:convert'; // Artık kullanılmıyor
import 'database_helper.dart';

class AlarmService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<Map<String, AlarmSettings>> loadAlarmSettings() async {
    try {
      final List<Map<String, dynamic>> dbSettings = await _dbHelper.getAlarmSettingsFromDb();
      print('Veritabanından yüklenen alarm ayarları: $dbSettings');

      // Varsayılan ayarları oluştur
      final Map<String, AlarmSettings> settings = {
        'İMSAK': AlarmSettings(),
        'GÜNEŞ': AlarmSettings(),
        'ÖĞLE': AlarmSettings(),
        'İKİNDİ': AlarmSettings(),
        'AKŞAM': AlarmSettings(),
        'YATSI': AlarmSettings(),
      };

      // Veritabanından gelen ayarları işle
      for (var dbSetting in dbSettings) {
        final prayerName = dbSetting['prayerName'].toString().toUpperCase();
        if (settings.containsKey(prayerName)) {
          // offsetMinutes değerini 5-60 aralığında sınırla
          final offsetMinutes = (dbSetting['offsetMinutes'] as int? ?? 5).clamp(5, 60);
          
          settings[prayerName] = AlarmSettings(
            isEnabled: dbSetting['isEnabled'] == 1,
            isOnTimeEnabled: dbSetting['isOnTimeEnabled'] == 1,
            isBeforeEnabled: dbSetting['isBeforeEnabled'] == 1,
            offsetMinutes: offsetMinutes, // Sınırlanmış değeri kullan
            time: dbSetting['time'] ?? '',
          );
        }
      }

      print('İşlenmiş alarm ayarları: $settings');
      return settings;
    } catch (e) {
      print('Alarm ayarları yüklenirken hata: $e');
      // Hata durumunda varsayılan ayarları döndür
      return {
        'İMSAK': AlarmSettings(),
        'GÜNEŞ': AlarmSettings(),
        'ÖĞLE': AlarmSettings(),
        'İKİNDİ': AlarmSettings(),
        'AKŞAM': AlarmSettings(),
        'YATSI': AlarmSettings(),
      };
    }
  }

  Future<void> saveAlarmSettings(Map<String, AlarmSettings> settings) async {
    try {
      for (var entry in settings.entries) {
        await _dbHelper.updateAlarmSetting(
          entry.key,
          entry.value,
        );
      }
      print('Alarm ayarları kaydedildi: $settings');
    } catch (e) {
      print('Alarm ayarları kaydedilirken hata: $e');
      throw Exception('Alarm ayarları kaydedilemedi: $e');
    }
  }
} 