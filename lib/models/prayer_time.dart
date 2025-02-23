class PrayerTime {
  final int dayOfYear;
  final String fajr;
  final String tulu;
  final String zuhr;
  final String asr;
  final String maghrib;
  final String isha;

  PrayerTime({
    required this.dayOfYear,
    required this.fajr,
    required this.tulu,
    required this.zuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  factory PrayerTime.fromJson(Map<String, dynamic> json) {
    return PrayerTime(
      dayOfYear: json['DayOfYear'],
      fajr: json['Fajr'],
      tulu: json['Tulu'],
      zuhr: json['Zuhr'],
      asr: json['Asr'],
      maghrib: json['Maghrib'],
      isha: json['Isha'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dayOfYear': dayOfYear,
      'fajr': fajr,
      'tulu': tulu,
      'zuhr': zuhr,
      'asr': asr,
      'maghrib': maghrib,
      'isha': isha,
    };
  }
} 