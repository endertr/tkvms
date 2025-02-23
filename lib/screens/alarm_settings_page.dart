import 'package:flutter/material.dart';
import '../models/alarm_settings.dart';
import '../services/alarm_service.dart';

class AlarmSettingsPage extends StatefulWidget {
  final Map<String, AlarmSettings> alarmSettings;
  final Map<String, dynamic>? customAlarm;

  const AlarmSettingsPage({
    Key? key,
    required this.alarmSettings,
    this.customAlarm,
  }) : super(key: key);

  @override
  State<AlarmSettingsPage> createState() => _AlarmSettingsPageState();
}

class _AlarmSettingsPageState extends State<AlarmSettingsPage> {
  late Map<String, AlarmSettings> _alarmSettings;
  TimeOfDay? _customAlarmTime;
  bool _isCustomAlarmEnabled = false;

  // Turkuaz renk paleti
  static const Color primaryTurquoise = Color(0xFF40E0D0);
  static const Color darkTurquoise = Color(0xFF00CED1);
  static const Color lightTurquoise = Color(0xFF7FFFD4);
  static const Color backgroundTurquoise = Color(0xFF1A4B4B);

  @override
  void initState() {
    super.initState();
    _alarmSettings = Map.from(widget.alarmSettings);
    
    if (widget.customAlarm != null) {
      _isCustomAlarmEnabled = widget.customAlarm!['enabled'] ?? false;
      _customAlarmTime = widget.customAlarm!['time'] as TimeOfDay?;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundTurquoise,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Alarm Ayarları',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w300,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              _buildSectionTitle('Namaz Vakitleri'),
              ..._alarmSettings.entries.map((entry) => _buildAlarmCard(entry.key, entry.value)),
              SizedBox(height: 24),
              _buildSectionTitle('Özel Alarm'),
              _buildCustomAlarmCard(),
              SizedBox(height: 100), // Alt buton için boşluk
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    backgroundTurquoise.withOpacity(0),
                    backgroundTurquoise,
                  ],
                ),
              ),
              padding: EdgeInsets.all(20),
              child: _buildSaveButton(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16, left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAlarmCard(String prayerName, AlarmSettings settings) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: settings.isEnabled 
            ? primaryTurquoise.withOpacity(0.3) 
            : Colors.transparent,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          listTileTheme: ListTileThemeData(
            dense: true,
            horizontalTitleGap: 0.0,
          ),
        ),
        child: ExpansionTile(
          title: Row(
            children: [
              Icon(
                Icons.alarm,
                color: settings.isEnabled ? primaryTurquoise : Colors.white30,
                size: 20,
              ),
              SizedBox(width: 12),
              Text(
                prayerName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          trailing: Switch(
            value: settings.isEnabled,
            onChanged: (bool value) {
              setState(() {
                final newSettings = AlarmSettings(
                  isEnabled: value,
                  isOnTimeEnabled: value && !settings.isEnabled ? true : settings.isOnTimeEnabled,
                  isBeforeEnabled: settings.isBeforeEnabled,
                  offsetMinutes: settings.offsetMinutes,
                );
                _alarmSettings[prayerName] = newSettings;
              });
            },
            activeColor: primaryTurquoise,
            activeTrackColor: primaryTurquoise.withOpacity(0.3),
          ),
          children: [
            if (settings.isEnabled)
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    _buildAlarmOption(
                      'Vaktinde',
                      settings.isOnTimeEnabled,
                      (value) {
                        setState(() {
                          _alarmSettings[prayerName] = settings.copyWith(
                            isOnTimeEnabled: value ?? false,
                          );
                        });
                      },
                    ),
                    SizedBox(height: 8),
                    _buildAlarmOption(
                      'Öncesinde',
                      settings.isBeforeEnabled,
                      (value) {
                        setState(() {
                          _alarmSettings[prayerName] = settings.copyWith(
                            isBeforeEnabled: value ?? false,
                          );
                        });
                      },
                    ),
                    if (settings.isBeforeEnabled) ...[
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: primaryTurquoise,
                                inactiveTrackColor: Colors.white10,
                                thumbColor: primaryTurquoise,
                                overlayColor: primaryTurquoise.withOpacity(0.2),
                                trackHeight: 2,
                              ),
                              child: Slider(
                                value: settings.offsetMinutes.clamp(5, 60).toDouble(),
                                min: 5,
                                max: 60,
                                divisions: 11,
                                label: '${settings.offsetMinutes} dk',
                                onChanged: (value) {
                                  setState(() {
                                    _alarmSettings[prayerName] = settings.copyWith(
                                      offsetMinutes: value.round(),
                                    );
                                  });
                                },
                              ),
                            ),
                          ),
                          Container(
                            width: 48,
                            child: Text(
                              '${settings.offsetMinutes}dk',
                              style: TextStyle(
                                color: primaryTurquoise,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmOption(String title, bool value, Function(bool?) onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CheckboxListTile(
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 15,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: primaryTurquoise,
        checkColor: Colors.black,
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildCustomAlarmCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isCustomAlarmEnabled 
            ? primaryTurquoise.withOpacity(0.3) 
            : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.alarm_add,
              color: _isCustomAlarmEnabled ? primaryTurquoise : Colors.white30,
              size: 20,
            ),
            title: Text(
              'Özel Alarm',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Switch(
              value: _isCustomAlarmEnabled,
              onChanged: (value) {
                setState(() {
                  _isCustomAlarmEnabled = value;
                  if (value && _customAlarmTime == null) {
                    _customAlarmTime = TimeOfDay.now();
                  }
                });
              },
              activeColor: primaryTurquoise,
              activeTrackColor: primaryTurquoise.withOpacity(0.3),
            ),
          ),
          if (_isCustomAlarmEnabled)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: InkWell(
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _customAlarmTime ?? TimeOfDay.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: primaryTurquoise,
                            surface: backgroundTurquoise,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (time != null) {
                    setState(() {
                      _customAlarmTime = time;
                    });
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Saat Seç',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        _customAlarmTime != null
                            ? _customAlarmTime!.format(context)
                            : '--:--',
                        style: TextStyle(
                          color: primaryTurquoise,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: () {
        Navigator.pop(context, {
          'settings': _alarmSettings,
          'customAlarm': _isCustomAlarmEnabled && _customAlarmTime != null
              ? {
                  'enabled': _isCustomAlarmEnabled,
                  'time': _customAlarmTime,
                }
              : null,
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryTurquoise,
        foregroundColor: Colors.black,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: Text(
        'Kaydet',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
} 