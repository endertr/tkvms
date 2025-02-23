import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/material.dart';
import '../models/prayer_time.dart';
import '../models/alarm_settings.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'prayer_times.db');
    
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    print('Veritabanı tabloları oluşturuluyor...');
    
    await db.execute('''
      CREATE TABLE prayer_times(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        districtId INTEGER,
        year INTEGER,
        dayOfYear INTEGER,
        fajr TEXT,
        tulu TEXT,
        zuhr TEXT,
        asr TEXT,
        maghrib TEXT,
        isha TEXT
      )
    ''');
    print('prayer_times tablosu oluşturuldu');

    await db.execute('''
      CREATE TABLE selected_location(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        districtId INTEGER,
        year INTEGER
      )
    ''');
    print('selected_location tablosu oluşturuldu');

    await db.execute('''
      CREATE TABLE location_details(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        districtId INTEGER,
        districtName TEXT,
        cityName TEXT,
        countryName TEXT
      )
    ''');
    print('location_details tablosu oluşturuldu');

    await db.execute('''
      CREATE TABLE alarm_settings (
        prayerName TEXT PRIMARY KEY,
        isEnabled INTEGER,
        isOnTimeEnabled INTEGER,
        isBeforeEnabled INTEGER,
        offsetMinutes INTEGER,
        time TEXT
      )
    ''');
    print('alarm_settings tablosu oluşturuldu');

    await db.execute('''
      CREATE TABLE custom_alarm (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        isEnabled INTEGER,
        hour INTEGER,
        minute INTEGER
      )
    ''');
    print('custom_alarm tablosu oluşturuldu');

    // Varsayılan alarm ayarlarını ekle
    await db.transaction((txn) async {
      for (String prayerName in ['İmsak', 'Güneş', 'Öğle', 'İkindi', 'Akşam', 'Yatsı']) {
        await txn.insert(
          'alarm_settings',
          {
            'prayerName': prayerName,
            'isEnabled': 0,
            'isOnTimeEnabled': 0,
            'isBeforeEnabled': 0,
            'offsetMinutes': 0,
            'time': '',
          },
        );
      }
    });
    print('Varsayılan alarm ayarları eklendi');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Veritabanı güncelleniyor... $oldVersion -> $newVersion');
    
    if (oldVersion < 4) {
      // Eski alarm_settings tablosunu sil ve yeniden oluştur
      await db.execute('DROP TABLE IF EXISTS alarm_settings');
      
      await db.execute('''
        CREATE TABLE alarm_settings (
          prayerName TEXT PRIMARY KEY,
          isEnabled INTEGER,
          isOnTimeEnabled INTEGER,
          isBeforeEnabled INTEGER,
          offsetMinutes INTEGER,
          time TEXT
        )
      ''');
      print('alarm_settings tablosu yeniden oluşturuldu');

      // Varsayılan alarm ayarlarını ekle
      await db.transaction((txn) async {
        for (String prayerName in ['İmsak', 'Güneş', 'Öğle', 'İkindi', 'Akşam', 'Yatsı']) {
          await txn.insert(
            'alarm_settings',
            {
              'prayerName': prayerName,
              'isEnabled': 0,
              'isOnTimeEnabled': 0,
              'isBeforeEnabled': 0,
              'offsetMinutes': 0,
              'time': '',
            },
          );
        }
      });
      print('Varsayılan alarm ayarları yeniden eklendi');
    }
  }

  Future<void> savePrayerTimes(List<PrayerTime> prayerTimes, int districtId, int year) async {
    final Database db = await database;
    final batch = db.batch();

    for (var prayerTime in prayerTimes) {
      batch.insert('prayer_times', {
        'districtId': districtId,
        'year': year,
        ...prayerTime.toMap(),
      });
    }

    await batch.commit();
  }

  Future<void> saveSelectedLocation(int districtId, int year) async {
    final Database db = await database;
    await db.delete('selected_location');
    await db.insert('selected_location', {
      'districtId': districtId,
      'year': year,
    });
  }

  Future<Map<String, dynamic>?> getSelectedLocation() async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('selected_location');
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<List<PrayerTime>> getPrayerTimes(int districtId, int year) async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'prayer_times',
      where: 'districtId = ? AND year = ?',
      whereArgs: [districtId, year],
    );

    return List.generate(maps.length, (i) {
      return PrayerTime(
        dayOfYear: maps[i]['dayOfYear'],
        fajr: maps[i]['fajr'],
        tulu: maps[i]['tulu'],
        zuhr: maps[i]['zuhr'],
        asr: maps[i]['asr'],
        maghrib: maps[i]['maghrib'],
        isha: maps[i]['isha'],
      );
    });
  }

  Future<Map<String, dynamic>?> getLocationDetails() async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'location_details',
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<void> saveLocationDetails({
    required int districtId,
    required String districtName,
    required String cityName,
    required String countryName,
  }) async {
    final Database db = await database;
    await db.delete('location_details');
    await db.insert('location_details', {
      'districtId': districtId,
      'districtName': districtName,
      'cityName': cityName,
      'countryName': countryName,
    });
  }

  Future<List<Map<String, dynamic>>> getAlarmSettingsFromDb() async {
    final db = await database;
    return await db.query('alarm_settings');
  }

  Future<void> updateAlarmSetting(String prayerName, AlarmSettings settings) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        // Önce mevcut ayarı kontrol et
        final existing = await txn.query(
          'alarm_settings',
          where: 'prayerName = ?',
          whereArgs: [prayerName],
        );

        final Map<String, dynamic> settingsMap = {
          'prayerName': prayerName,
          'isEnabled': settings.isEnabled ? 1 : 0,
          'isOnTimeEnabled': settings.isOnTimeEnabled ? 1 : 0,
          'isBeforeEnabled': settings.isBeforeEnabled ? 1 : 0,
          'offsetMinutes': settings.offsetMinutes,
          'time': settings.time,
        };

        if (existing.isEmpty) {
          // Yeni kayıt ekle
          await txn.insert('alarm_settings', settingsMap);
        } else {
          // Mevcut kaydı güncelle
          await txn.update(
            'alarm_settings',
            settingsMap,
            where: 'prayerName = ?',
            whereArgs: [prayerName],
          );
        }
      });
      print('Alarm ayarı başarıyla güncellendi: $prayerName -> $settings');
    } catch (e) {
      print('Alarm ayarı güncellenirken hata: $e');
      throw Exception('Alarm ayarı güncellenemedi: $e');
    }
  }

  Future<void> saveCustomAlarm(bool isEnabled, TimeOfDay time) async {
    final db = await database;
    await db.delete('custom_alarm');
    await db.insert('custom_alarm', {
      'isEnabled': isEnabled ? 1 : 0,
      'hour': time.hour,
      'minute': time.minute,
    });
  }

  Future<Map<String, dynamic>?> getCustomAlarm() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query('custom_alarm');
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Map<String, AlarmSettings> getDefaultSettings() {
    return {
      'İmsak': AlarmSettings(isEnabled: false, time: ''),
      'Güneş': AlarmSettings(isEnabled: false, time: ''),
      'Öğle': AlarmSettings(isEnabled: false, time: ''),
      'İkindi': AlarmSettings(isEnabled: false, time: ''),
      'Akşam': AlarmSettings(isEnabled: false, time: ''),
      'Yatsı': AlarmSettings(isEnabled: false, time: ''),
    };
  }
} 