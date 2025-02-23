import 'package:flutter/material.dart';
import '../models/alarm_settings.dart';

class PrayerAlarmDialog extends StatefulWidget {
  final String prayerName;
  final String prayerTime;
  final AlarmSettings settings;

  const PrayerAlarmDialog({
    Key? key,
    required this.prayerName,
    required this.prayerTime,
    required this.settings,
  }) : super(key: key);

  @override
  State<PrayerAlarmDialog> createState() => _PrayerAlarmDialogState();
}

class _PrayerAlarmDialogState extends State<PrayerAlarmDialog> {
  late AlarmSettings _settings;
  static const Color primaryTurquoise = Color(0xFF40E0D0);

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Color(0xFF1A4B4B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            if (_settings.isEnabled) _buildContent(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryTurquoise.withOpacity(0.1),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alarm, color: primaryTurquoise),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.prayerName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.prayerTime,
                      style: TextStyle(
                        color: primaryTurquoise,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          SwitchListTile(
            value: _settings.isEnabled,
            onChanged: (bool value) {
              setState(() {
                _settings = AlarmSettings(
                  isEnabled: value,
                  isOnTimeEnabled: value && !_settings.isEnabled ? true : _settings.isOnTimeEnabled,
                  isBeforeEnabled: _settings.isBeforeEnabled,
                  offsetMinutes: _settings.offsetMinutes,
                );
              });
            },
            activeColor: primaryTurquoise,
            title: Text(
              'Alarmı Aç',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildAlarmOption(
            'Vaktinde',
            _settings.isOnTimeEnabled,
            (value) {
              setState(() {
                _settings = _settings.copyWith(isOnTimeEnabled: value ?? false);
              });
            },
          ),
          SizedBox(height: 8),
          _buildAlarmOption(
            'Öncesinde',
            _settings.isBeforeEnabled,
            (value) {
              setState(() {
                _settings = _settings.copyWith(isBeforeEnabled: value ?? false);
              });
            },
          ),
          if (_settings.isBeforeEnabled) ...[
            SizedBox(height: 16),
            _buildOffsetSlider(),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'İptal',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _settings),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryTurquoise,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Kaydet'),
          ),
        ],
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
      ),
    );
  }

  Widget _buildOffsetSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ne kadar önce?',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 8),
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
                  value: _settings.offsetMinutes.toDouble(),
                  min: 5,
                  max: 60,
                  divisions: 11,
                  label: '${_settings.offsetMinutes} dk',
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(
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
                '${_settings.offsetMinutes}dk',
                style: TextStyle(
                  color: primaryTurquoise,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
} 