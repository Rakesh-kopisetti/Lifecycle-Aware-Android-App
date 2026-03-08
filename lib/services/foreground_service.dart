import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lifecycle_event_logger.dart';

/// Foreground Service implementation for performing long-running tasks.
/// 
/// Service Name: LifecycleMasterForegroundService
/// Notification Channel ID: foreground_service_channel
/// Persistent Data Key: service_total_uptime_seconds
class ForegroundServiceManager with ChangeNotifier {
  static final ForegroundServiceManager _instance = ForegroundServiceManager._internal();
  
  factory ForegroundServiceManager() => _instance;
  
  ForegroundServiceManager._internal();

  /// Key for storing total uptime in SharedPreferences
  static const String uptimeKey = 'service_total_uptime_seconds';
  
  /// Notification channel ID
  static const String channelId = 'foreground_service_channel';
  
  /// Service name
  static const String serviceName = 'LifecycleMasterForegroundService';

  /// Whether the service is currently running
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// Current session uptime in seconds
  int _sessionUptime = 0;
  int get sessionUptime => _sessionUptime;

  /// Total historical uptime in seconds
  int _totalUptime = 0;
  int get totalUptime => _totalUptime;

  /// Listeners for uptime updates
  final List<VoidCallback> _listeners = [];

  /// Event logger
  final LifecycleEventLogger _logger = LifecycleEventLogger();

  /// Initialize the foreground task service
  Future<void> initialize() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: channelId,
        channelName: 'Lifecycle Master Service',
        channelDescription: 'Notification channel for tracking app uptime',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    // Load total uptime from SharedPreferences
    await _loadTotalUptime();
  }

  /// Load total uptime from SharedPreferences
  Future<void> _loadTotalUptime() async {
    final prefs = await SharedPreferences.getInstance();
    _totalUptime = prefs.getInt(uptimeKey) ?? 0;
  }

  /// Save total uptime to SharedPreferences
  Future<void> _saveTotalUptime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(uptimeKey, _totalUptime + _sessionUptime);
  }

  /// Add a listener for uptime updates
  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Remove a listener
  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Start the foreground service
  Future<bool> startService() async {
    if (_isRunning) return true;

    try {
      // Request necessary permissions
      final isPermissionGranted = await FlutterForegroundTask.checkNotificationPermission();
      if (isPermissionGranted != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      // Start the foreground task
      final result = await FlutterForegroundTask.startService(
        notificationTitle: 'Lifecycle Master Service',
        notificationText: 'Tracking uptime: ${_formatUptime(_sessionUptime)}',
        callback: startCallback,
      );

      if (result is ServiceRequestSuccess) {
        _isRunning = true;
        _sessionUptime = 0;
        
        await _logger.logCustomEvent('foreground_service_started', {
          'serviceName': serviceName,
          'channelId': channelId,
        });

        _notifyListeners();
        return true;
      }
    } catch (e) {
      // Log error but don't crash
      debugPrint('Error starting foreground service: $e');
    }
    return false;
  }

  /// Stop the foreground service
  Future<bool> stopService() async {
    if (!_isRunning) return true;

    try {
      final result = await FlutterForegroundTask.stopService();
      
      if (result is ServiceRequestSuccess) {
        _isRunning = false;
        
        // Save total uptime
        await _saveTotalUptime();
        _totalUptime += _sessionUptime;
        
        await _logger.logCustomEvent('foreground_service_stopped', {
          'serviceName': serviceName,
          'sessionUptime': _sessionUptime,
          'totalUptime': _totalUptime,
        });

        _sessionUptime = 0;
        _notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error stopping foreground service: $e');
    }
    return false;
  }

  /// Update the notification with current uptime
  Future<void> updateNotification(int uptimeSeconds) async {
    _sessionUptime = uptimeSeconds;
    _notifyListeners();
    
    if (_isRunning) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Lifecycle Master Service',
        notificationText: 'Tracking uptime: ${_formatUptime(uptimeSeconds)}',
      );
    }
  }

  /// Format uptime as HH:MM:SS
  String _formatUptime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Get formatted session uptime
  String get formattedSessionUptime => _formatUptime(_sessionUptime);

  /// Get formatted total uptime
  String get formattedTotalUptime => _formatUptime(_totalUptime + _sessionUptime);

  /// Check if the service is running
  Future<bool> checkIsRunning() async {
    _isRunning = await FlutterForegroundTask.isRunningService;
    return _isRunning;
  }

  /// Reset total uptime
  Future<void> resetTotalUptime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(uptimeKey, 0);
    _totalUptime = 0;
    _sessionUptime = 0;
    _notifyListeners();
  }
}

/// The callback function for the foreground task
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(UptimeTaskHandler());
}

/// Task handler that runs in the background
class UptimeTaskHandler extends TaskHandler {
  int _uptimeSeconds = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _uptimeSeconds = 0;
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _uptimeSeconds++;
    
    // Update the notification every second
    FlutterForegroundTask.updateService(
      notificationTitle: 'Lifecycle Master Service',
      notificationText: 'Tracking uptime: ${_formatUptime(_uptimeSeconds)}',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Save the session uptime
    final prefs = await SharedPreferences.getInstance();
    final totalUptime = prefs.getInt(ForegroundServiceManager.uptimeKey) ?? 0;
    await prefs.setInt(ForegroundServiceManager.uptimeKey, totalUptime + _uptimeSeconds);
  }

  @override
  void onNotificationButtonPressed(String id) {
    // Handle notification button press
  }

  @override
  void onNotificationPressed() {
    // Handle notification press - can navigate to app
  }

  String _formatUptime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
