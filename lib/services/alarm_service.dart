import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:uuid/uuid.dart';
import 'lifecycle_event_logger.dart';

/// Represents a scheduled alarm
class ScheduledAlarm {
  final String id;
  final DateTime scheduledTime;
  final bool triggered;
  final DateTime createdAt;

  ScheduledAlarm({
    required this.id,
    required this.scheduledTime,
    required this.triggered,
    required this.createdAt,
  });

  ScheduledAlarm copyWith({
    String? id,
    DateTime? scheduledTime,
    bool? triggered,
    DateTime? createdAt,
  }) => ScheduledAlarm(
    id: id ?? this.id,
    scheduledTime: scheduledTime ?? this.scheduledTime,
    triggered: triggered ?? this.triggered,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'scheduledTime': scheduledTime.toIso8601String(),
    'triggered': triggered,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ScheduledAlarm.fromJson(Map<String, dynamic> json) => ScheduledAlarm(
    id: json['id'] as String,
    scheduledTime: DateTime.parse(json['scheduledTime'] as String),
    triggered: json['triggered'] as bool,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// Service for scheduling exact alarms using the native Android AlarmManager.
/// 
/// Log File Location: app_data/scheduled_alarms.json
class AlarmService with ChangeNotifier {
  static final AlarmService _instance = AlarmService._internal();
  
  factory AlarmService() => _instance;
  
  AlarmService._internal();

  /// Platform channel for native alarm functionality
  static const MethodChannel _channel = MethodChannel('com.lifecyclemaster/alarm_service');

  /// Log file name
  static const String logFileName = 'scheduled_alarms.json';

  /// Local notifications plugin
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  /// List of scheduled alarms
  final List<ScheduledAlarm> _alarms = [];
  List<ScheduledAlarm> get alarms => List.unmodifiable(_alarms);

  /// Event logger
  final LifecycleEventLogger _logger = LifecycleEventLogger();

  /// UUID generator
  final Uuid _uuid = const Uuid();

  /// Initialize the alarm service
  Future<void> initialize() async {
    // Initialize timezone data
    tz_data.initializeTimeZones();

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Request notification permissions on Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Load stored alarms
    await _loadAlarms();

    // Set up platform channel handler for alarm triggers
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Handle incoming method calls from native code
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAlarmTriggered':
        final AlarmId = call.arguments['alarmId'] as String;
        await _onAlarmTriggered(AlarmId);
        return true;
      default:
        throw PlatformException(
          code: 'NotImplemented',
          message: 'Method ${call.method} not implemented',
        );
    }
  }

  /// Handle notification response
  void _onNotificationResponse(NotificationResponse response) {
    // Handle notification tap
    print('Notification tapped: ${response.payload}');
  }

  /// Schedule an exact alarm
  Future<String> scheduleExactAlarm({
    required DateTime alarmTime,
    String? alarmId,
    String? title,
    String? body,
  }) async {
    final id = alarmId ?? _uuid.v4();
    
    try {
      // Create alarm entry
      final alarm = ScheduledAlarm(
        id: id,
        scheduledTime: alarmTime,
        triggered: false,
        createdAt: DateTime.now(),
      );

      _alarms.add(alarm);
      await _saveAlarms();

      // Try to schedule via platform channel (native Android AlarmManager)
      try {
        await _channel.invokeMethod('scheduleExactAlarm', {
          'alarmId': id,
          'alarmTime': alarmTime.millisecondsSinceEpoch,
          'title': title ?? 'Scheduled Alarm',
          'body': body ?? 'Your scheduled alarm has triggered!',
        });
      } catch (e) {
        // Fall back to local notifications if native implementation not available
        await _scheduleLocalNotification(alarm, title, body);
      }

      await _logger.logCustomEvent('alarm_scheduled', {
        'alarmId': id,
        'scheduledTime': alarmTime.toIso8601String(),
      });

      notifyListeners();
      return id;
    } catch (e) {
      print('Error scheduling alarm: $e');
      rethrow;
    }
  }

  /// Schedule a local notification as fallback
  Future<void> _scheduleLocalNotification(
    ScheduledAlarm alarm,
    String? title,
    String? body,
  ) async {
    final notificationId = alarm.id.hashCode;
    
    await _notificationsPlugin.zonedSchedule(
      notificationId,
      title ?? 'Scheduled Alarm',
      body ?? 'Your scheduled alarm has triggered!',
      tz.TZDateTime.from(alarm.scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm_channel',
          'Alarms',
          channelDescription: 'Notification channel for scheduled alarms',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: alarm.id,
    );
  }

  /// Called when an alarm is triggered
  Future<void> _onAlarmTriggered(String alarmId) async {
    final index = _alarms.indexWhere((a) => a.id == alarmId);
    if (index != -1) {
      _alarms[index] = _alarms[index].copyWith(triggered: true);
      await _saveAlarms();

      await _logger.logCustomEvent('alarm_triggered', {
        'alarmId': alarmId,
        'triggeredAt': DateTime.now().toIso8601String(),
      });

      notifyListeners();
    }
  }

  /// Cancel a scheduled alarm
  Future<void> cancelAlarm(String alarmId) async {
    try {
      // Try to cancel via platform channel
      try {
        await _channel.invokeMethod('cancelAlarm', {
          'alarmId': alarmId,
        });
      } catch (e) {
        // Cancel local notification
        await _notificationsPlugin.cancel(alarmId.hashCode);
      }

      _alarms.removeWhere((a) => a.id == alarmId);
      await _saveAlarms();

      await _logger.logCustomEvent('alarm_cancelled', {
        'alarmId': alarmId,
      });

      notifyListeners();
    } catch (e) {
      print('Error cancelling alarm: $e');
    }
  }

  /// Cancel all scheduled alarms
  Future<void> cancelAllAlarms() async {
    try {
      // Cancel all via platform channel
      try {
        await _channel.invokeMethod('cancelAllAlarms');
      } catch (e) {
        // Cancel all local notifications
        await _notificationsPlugin.cancelAll();
      }

      _alarms.clear();
      await _saveAlarms();

      await _logger.logCustomEvent('all_alarms_cancelled', {});

      notifyListeners();
    } catch (e) {
      print('Error cancelling all alarms: $e');
    }
  }

  /// Load alarms from storage
  Future<void> _loadAlarms() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/app_data/$logFileName');
      
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final data = jsonDecode(content) as Map<String, dynamic>;
          final alarmsList = data['alarms'] as List<dynamic>;
          _alarms.clear();
          _alarms.addAll(
            alarmsList.map((a) => ScheduledAlarm.fromJson(a as Map<String, dynamic>)),
          );
        }
      }
    } catch (e) {
      print('Error loading alarms: $e');
    }
  }

  /// Save alarms to storage
  Future<void> _saveAlarms() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final appDataDir = Directory('${directory.path}/app_data');
      if (!await appDataDir.exists()) {
        await appDataDir.create(recursive: true);
      }
      
      final file = File('${appDataDir.path}/$logFileName');
      final data = {
        'alarms': _alarms.map((a) => a.toJson()).toList(),
      };
      
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print('Error saving alarms: $e');
    }
  }

  /// Get pending alarms (not triggered yet)
  List<ScheduledAlarm> get pendingAlarms =>
      _alarms.where((a) => !a.triggered && a.scheduledTime.isAfter(DateTime.now())).toList();

  /// Get triggered alarms
  List<ScheduledAlarm> get triggeredAlarms =>
      _alarms.where((a) => a.triggered).toList();
}
