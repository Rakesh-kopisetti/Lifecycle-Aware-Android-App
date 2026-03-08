import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../services/lifecycle_event_logger.dart';

/// Enum representing the app lifecycle states
enum AppLifecycleState {
  resumed,
  paused,
  inactive,
  detached,
  hidden,
}

/// LifecycleManager class that encapsulates lifecycle event handling logic.
/// This class observes and responds to app lifecycle events provided by
/// the Flutter framework's WidgetsBindingObserver.
class LifecycleManager with WidgetsBindingObserver, ChangeNotifier {
  static final LifecycleManager _instance = LifecycleManager._internal();
  
  factory LifecycleManager() => _instance;
  
  LifecycleManager._internal();

  /// Current lifecycle state
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  AppLifecycleState get lifecycleState => _lifecycleState;

  /// Timestamp of the last pause event
  DateTime? _lastPauseTimestamp;
  DateTime? get lastPauseTimestamp => _lastPauseTimestamp;

  /// Count of configuration changes
  int _configurationChangeCount = 0;
  int get configurationChangeCount => _configurationChangeCount;

  /// Time spent in resumed state (in seconds)
  int _totalResumedTime = 0;
  int get totalResumedTime => _totalResumedTime;

  /// Time spent in background (in seconds)
  int _totalBackgroundTime = 0;
  int get totalBackgroundTime => _totalBackgroundTime;

  /// Last resume timestamp for tracking resumed time
  DateTime? _lastResumeTimestamp;

  /// List of lifecycle events for timeline
  final List<LifecycleEvent> _events = [];
  List<LifecycleEvent> get events => List.unmodifiable(_events);

  /// Logger for persisting events
  final LifecycleEventLogger _logger = LifecycleEventLogger();

  /// Callback listeners
  final List<VoidCallback> _lifecycleListeners = [];

  /// Initialize the lifecycle manager
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    _lastResumeTimestamp = DateTime.now();
    _addEvent('app_started', {'state': 'resumed'});
  }

  /// Dispose the lifecycle manager
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Add a lifecycle listener
  void addLifecycleListener(VoidCallback listener) {
    _lifecycleListeners.add(listener);
  }

  /// Remove a lifecycle listener
  void removeLifecycleListener(VoidCallback listener) {
    _lifecycleListeners.remove(listener);
  }

  /// Notify all lifecycle listeners
  void _notifyLifecycleListeners() {
    for (final listener in _lifecycleListeners) {
      listener();
    }
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(ui.AppLifecycleState state) {
    switch (state) {
      case ui.AppLifecycleState.resumed:
        onAppResumed();
        break;
      case ui.AppLifecycleState.paused:
        onAppPaused();
        break;
      case ui.AppLifecycleState.inactive:
        onAppInactive();
        break;
      case ui.AppLifecycleState.detached:
        onAppDetached();
        break;
      case ui.AppLifecycleState.hidden:
        onAppHidden();
        break;
    }
    _notifyLifecycleListeners();
  }

  /// Called when the app is resumed (visible and responding to user input)
  void onAppResumed() {
    final previousState = _lifecycleState;
    _lifecycleState = AppLifecycleState.resumed;
    _lastResumeTimestamp = DateTime.now();

    // Calculate background time if coming from paused state
    if (_lastPauseTimestamp != null) {
      final backgroundDuration = DateTime.now().difference(_lastPauseTimestamp!);
      _totalBackgroundTime += backgroundDuration.inSeconds;
    }

    _addEvent('app_resumed', {
      'previousState': previousState.name,
      'backgroundDuration': _lastPauseTimestamp != null 
          ? DateTime.now().difference(_lastPauseTimestamp!).inSeconds 
          : 0,
    });
  }

  /// Called when the app is paused (not visible but might be in memory)
  void onAppPaused() {
    _lifecycleState = AppLifecycleState.paused;
    _lastPauseTimestamp = DateTime.now();

    // Calculate resumed time
    if (_lastResumeTimestamp != null) {
      final resumedDuration = DateTime.now().difference(_lastResumeTimestamp!);
      _totalResumedTime += resumedDuration.inSeconds;
    }

    _addEvent('app_paused', {
      'resumedDuration': _lastResumeTimestamp != null 
          ? DateTime.now().difference(_lastResumeTimestamp!).inSeconds 
          : 0,
    });
  }

  /// Called when the app is inactive (transitioning between states)
  void onAppInactive() {
    _lifecycleState = AppLifecycleState.inactive;
    _addEvent('app_inactive', {});
  }

  /// Called when the app is detached (about to be terminated)
  void onAppDetached() {
    _lifecycleState = AppLifecycleState.detached;
    _addEvent('app_detached', {});
  }

  /// Called when the app is hidden
  void onAppHidden() {
    _lifecycleState = AppLifecycleState.hidden;
    _addEvent('app_hidden', {});
  }

  /// Increment configuration change count
  void onConfigurationChanged(String changeType, String oldValue, String newValue) {
    _configurationChangeCount++;
    _addEvent('config_changed', {
      'type': changeType,
      'oldValue': oldValue,
      'newValue': newValue,
    });
  }

  /// Add an event to the timeline and log it
  void _addEvent(String eventType, Map<String, dynamic> metadata) {
    final event = LifecycleEvent(
      timestamp: DateTime.now(),
      eventType: eventType,
      metadata: metadata,
    );
    _events.insert(0, event);
    
    // Keep only the last 100 events in memory
    if (_events.length > 100) {
      _events.removeLast();
    }

    // Log to file
    _logger.logEvent(event);
  }

  /// Clear all events
  void clearEvents() {
    _events.clear();
    notifyListeners();
  }

  /// Get the current state as a string
  String get lifecycleStateString => _lifecycleState.name;

  /// Reset all statistics
  void resetStatistics() {
    _configurationChangeCount = 0;
    _totalResumedTime = 0;
    _totalBackgroundTime = 0;
    _lastPauseTimestamp = null;
    _lastResumeTimestamp = DateTime.now();
    notifyListeners();
  }
}

/// Represents a lifecycle event
class LifecycleEvent {
  final DateTime timestamp;
  final String eventType;
  final Map<String, dynamic> metadata;

  LifecycleEvent({
    required this.timestamp,
    required this.eventType,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'eventType': eventType,
    'metadata': metadata,
  };

  factory LifecycleEvent.fromJson(Map<String, dynamic> json) => LifecycleEvent(
    timestamp: DateTime.parse(json['timestamp'] as String),
    eventType: json['eventType'] as String,
    metadata: Map<String, dynamic>.from(json['metadata'] as Map),
  );
}
