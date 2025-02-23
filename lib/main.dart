import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_page.dart';
import 'services/database_helper.dart';
import 'widgets/location_dialog.dart';
import 'services/widget_service.dart';
import 'dart:convert'; // jsonEncode ve jsonDecode için

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);
  
  final widgetService = WidgetService();
  
  // Widget için MethodChannel'ı ayarla
  const platform = MethodChannel('prayer_times_widget');
  platform.setMethodCallHandler((call) async {
    if (call.method == 'getPrayerTimes') {
      try {
        final data = await widgetService.getPrayerTimesForWidget();
        return data;
      } catch (e) {
        print('Widget veri hatası: $e');
        return null;
      }
    }
    return null;
  });

  // Widget'tan gelen başlatma isteğini kontrol et
  final intent = await platform.invokeMethod<bool>('getIntent');
  final fromWidget = intent ?? false;
  
  if (fromWidget) {
    // Widget'tan geliyorsa, verileri güncelle ve uygulamayı kapatma
    try {
      final data = await widgetService.getPrayerTimesForWidget();
      await platform.invokeMethod('updateWidget', data);
      SystemNavigator.pop(); // Uygulamayı kapat
      return;
    } catch (e) {
      print('Widget güncelleme hatası: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Namaz Vakitleri',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _checkDatabase();
  }

  Future<void> _checkDatabase() async {
    final location = await _dbHelper.getSelectedLocation();
    
    if (mounted) {
      if (location == null) {
        // Konum seçili değilse dialog göster
        final result = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const LocationDialog(),
        );
        
        if (result == true) {
          // Konum seçildi ve kaydedildi
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      } else {
        // Konum zaten seçili, ana sayfaya git
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
