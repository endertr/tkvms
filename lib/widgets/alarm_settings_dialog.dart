import 'package:flutter/material.dart';
import '../models/alarm_settings.dart';

class AlarmSettingsDialog extends StatefulWidget {
  final Map<String, AlarmSettings> alarmSettings;
  final Map<String, dynamic>? customAlarm;
  final String? initialPrayerName;
  final bool showOnlyInitialPrayer;

  const AlarmSettingsDialog({
    Key? key, 
    required this.alarmSettings,
    this.customAlarm,
    this.initialPrayerName,
    this.showOnlyInitialPrayer = false,
  }) : super(key: key);

  @override
  State<AlarmSettingsDialog> createState() => _AlarmSettingsDialogState();
}

class _AlarmSettingsDialogState extends State<AlarmSettingsDialog> {
  late Map<String, AlarmSettings> _alarmSettings;
  TimeOfDay? _customAlarmTime;
  bool _isCustomAlarmEnabled = false;
  String? _expandedTile;

  @override
  void initState() {
    super.initState();
    if (widget.showOnlyInitialPrayer && widget.initialPrayerName != null) {
      _alarmSettings = {
        widget.initialPrayerName!: widget.alarmSettings[widget.initialPrayerName!]!,
      };
      _expandedTile = widget.initialPrayerName;
    } else {
      _alarmSettings = Map.from(widget.alarmSettings);
      _expandedTile = widget.initialPrayerName;
    }
    
    if (widget.customAlarm != null) {
      _isCustomAlarmEnabled = widget.customAlarm!['enabled'] ?? false;
      _customAlarmTime = widget.customAlarm!['time'] as TimeOfDay?;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.showOnlyInitialPrayer ? 
        '${widget.initialPrayerName} Alarm Ayarları' : 
        'Alarm Ayarları'
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._alarmSettings.entries.map((entry) => _buildAlarmSettingTile(
              entry.key, 
              entry.value,
              isInitiallyExpanded: true,
            )),
            if (!widget.showOnlyInitialPrayer) ...[
              const Divider(),
              _buildCustomAlarmTile(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        TextButton(
          onPressed: () {
            final Map<String, AlarmSettings> resultSettings;
            if (widget.showOnlyInitialPrayer) {
              resultSettings = Map.from(widget.alarmSettings);
              resultSettings[widget.initialPrayerName!] = _alarmSettings[widget.initialPrayerName!]!;
            } else {
              resultSettings = _alarmSettings;
            }

            Navigator.pop(context, {
              'settings': resultSettings,
              'customAlarm': !widget.showOnlyInitialPrayer && _isCustomAlarmEnabled && _customAlarmTime != null
                  ? {
                      'enabled': _isCustomAlarmEnabled,
                      'time': _customAlarmTime,
                    }
                  : null,
            });
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }

  Widget _buildAlarmSettingTile(String prayerName, AlarmSettings settings, {bool isInitiallyExpanded = false}) {
    return ExpansionTile(
      initiallyExpanded: isInitiallyExpanded,
      title: Row(
        children: [
          Text(prayerName),
          Switch(
            value: settings.isEnabled,
            onChanged: (value) {
              setState(() {
                _alarmSettings[prayerName] = settings.copyWith(isEnabled: value);
              });
            },
          ),
        ],
      ),
      children: [
        CheckboxListTile(
          title: const Text('Vaktinde'),
          value: settings.isOnTimeEnabled,
          onChanged: settings.isEnabled
              ? (value) {
                  setState(() {
                    _alarmSettings[prayerName] = settings.copyWith(
                      isOnTimeEnabled: value ?? false,
                    );
                  });
                }
              : null,
        ),
        CheckboxListTile(
          title: const Text('Öncesinde'),
          value: settings.isBeforeEnabled,
          onChanged: settings.isEnabled
              ? (value) {
                  setState(() {
                    _alarmSettings[prayerName] = settings.copyWith(
                      isBeforeEnabled: value ?? false,
                    );
                  });
                }
              : null,
        ),
        if (settings.isBeforeEnabled && settings.isEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Text('Dakika: '),
                Expanded(
                  child: Slider(
                    value: settings.offsetMinutes.clamp(5, 60).toDouble(),
                    min: 5,
                    max: 60,
                    divisions: 11,
                    label: settings.offsetMinutes.toString(),
                    onChanged: (value) {
                      setState(() {
                        _alarmSettings[prayerName] = settings.copyWith(
                          offsetMinutes: value.round(),
                        );
                      });
                    },
                  ),
                ),
                Text('${settings.offsetMinutes.clamp(5, 60)} dk'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCustomAlarmTile() {
    return ListTile(
      title: Row(
        children: [
          const Text('Özel Alarm'),
          Switch(
            value: _isCustomAlarmEnabled,
            onChanged: (value) {
              setState(() {
                _isCustomAlarmEnabled = value;
                if (value && _customAlarmTime == null) {
                  _customAlarmTime = TimeOfDay.now();
                }
              });
            },
          ),
        ],
      ),
      subtitle: _isCustomAlarmEnabled
          ? TextButton(
              onPressed: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _customAlarmTime ?? TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() {
                    _customAlarmTime = time;
                  });
                }
              },
              child: Text(_customAlarmTime != null
                  ? '${_customAlarmTime!.format(context)}'
                  : 'Saat seç'),
            )
          : null,
    );
  }
} 