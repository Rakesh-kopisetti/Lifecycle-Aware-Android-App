import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../database/state_database.dart';
import '../services/lifecycle_event_logger.dart';

/// State snapshot containing all app state
class StateSnapshot {
  final List<String> navigationStack;
  final Map<String, dynamic> formData;
  final Map<String, double> scrollPositions;
  final DateTime timestamp;
  final Map<String, dynamic> additionalData;

  StateSnapshot({
    required this.navigationStack,
    required this.formData,
    required this.scrollPositions,
    required this.timestamp,
    this.additionalData = const {},
  });

  Map<String, dynamic> toJson() => {
    'navigationStack': navigationStack,
    'formData': formData,
    'scrollPositions': scrollPositions,
    'timestamp': timestamp.toIso8601String(),
    'additionalData': additionalData,
  };

  factory StateSnapshot.fromJson(Map<String, dynamic> json) => StateSnapshot(
    navigationStack: List<String>.from(json['navigationStack'] ?? []),
    formData: Map<String, dynamic>.from(json['formData'] ?? {}),
    scrollPositions: (json['scrollPositions'] as Map<String, dynamic>?)?.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    ) ?? {},
    timestamp: DateTime.parse(json['timestamp'] as String),
    additionalData: Map<String, dynamic>.from(json['additionalData'] ?? {}),
  );

  StateSnapshot copyWith({
    List<String>? navigationStack,
    Map<String, dynamic>? formData,
    Map<String, double>? scrollPositions,
    DateTime? timestamp,
    Map<String, dynamic>? additionalData,
  }) => StateSnapshot(
    navigationStack: navigationStack ?? this.navigationStack,
    formData: formData ?? this.formData,
    scrollPositions: scrollPositions ?? this.scrollPositions,
    timestamp: timestamp ?? this.timestamp,
    additionalData: additionalData ?? this.additionalData,
  );
}

/// Manager for state recovery after process death.
/// 
/// Snapshot Location: app_data/state_snapshot.json
class StateRecoveryManager with ChangeNotifier {
  static final StateRecoveryManager _instance = StateRecoveryManager._internal();
  
  factory StateRecoveryManager() => _instance;
  
  StateRecoveryManager._internal();

  /// Snapshot file name
  static const String snapshotFileName = 'state_snapshot.json';

  /// Current state snapshot
  StateSnapshot? _currentSnapshot;
  StateSnapshot? get currentSnapshot => _currentSnapshot;

  /// Database instance for persistent storage
  final StateDatabase _database = StateDatabase();

  /// Event logger
  final LifecycleEventLogger _logger = LifecycleEventLogger();

  /// Last save timestamp
  DateTime? _lastSaveTimestamp;
  DateTime? get lastSaveTimestamp => _lastSaveTimestamp;

  /// Is recovery in progress
  bool _isRecovering = false;
  bool get isRecovering => _isRecovering;

  /// Initialize the state recovery manager
  Future<void> initialize() async {
    // Try to restore from snapshot on initialization
    await restoreFromSnapshot();
  }

  /// Restore state from snapshot file
  /// 
  /// This method reads the state_snapshot.json file and restores:
  /// - Navigation stack
  /// - Form data
  /// - Scroll positions
  Future<bool> restoreFromSnapshot() async {
    _isRecovering = true;
    notifyListeners();

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/app_data/$snapshotFileName');
      
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final json = jsonDecode(content) as Map<String, dynamic>;
          _currentSnapshot = StateSnapshot.fromJson(json);

          // Restore to database as well
          if (_currentSnapshot != null) {
            await _database.saveNavigationStack(_currentSnapshot!.navigationStack);
            await _database.saveFormData(_currentSnapshot!.formData);
            for (final entry in _currentSnapshot!.scrollPositions.entries) {
              await _database.saveScrollPosition(entry.key, entry.value);
            }
          }

          await _logger.logCustomEvent('state_restored', {
            'snapshotTimestamp': _currentSnapshot?.timestamp.toIso8601String(),
            'navigationStackSize': _currentSnapshot?.navigationStack.length ?? 0,
            'formDataKeys': _currentSnapshot?.formData.keys.toList() ?? [],
            'scrollPositionKeys': _currentSnapshot?.scrollPositions.keys.toList() ?? [],
          });

          _isRecovering = false;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      print('Error restoring from snapshot: $e');
      await _logger.logCustomEvent('state_restore_failed', {
        'error': e.toString(),
      });
    }

    _isRecovering = false;
    notifyListeners();
    return false;
  }

  /// Save current state to snapshot file
  Future<bool> saveSnapshot({
    List<String>? navigationStack,
    Map<String, dynamic>? formData,
    Map<String, double>? scrollPositions,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Build the snapshot from provided data or from database
      final snapshot = StateSnapshot(
        navigationStack: navigationStack ?? await _database.getNavigationStack(),
        formData: formData ?? await _database.getFormData() ?? {},
        scrollPositions: scrollPositions ?? await _database.getScrollPositions(),
        timestamp: DateTime.now(),
        additionalData: additionalData ?? {},
      );

      _currentSnapshot = snapshot;

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final appDataDir = Directory('${directory.path}/app_data');
      if (!await appDataDir.exists()) {
        await appDataDir.create(recursive: true);
      }
      
      final file = File('${appDataDir.path}/$snapshotFileName');
      await file.writeAsString(jsonEncode(snapshot.toJson()));

      // Also save to database for redundancy
      await _database.saveNavigationStack(snapshot.navigationStack);
      await _database.saveFormData(snapshot.formData);
      for (final entry in snapshot.scrollPositions.entries) {
        await _database.saveScrollPosition(entry.key, entry.value);
      }

      _lastSaveTimestamp = DateTime.now();

      await _logger.logCustomEvent('state_snapshot_saved', {
        'timestamp': DateTime.now().toIso8601String(),
        'navigationStackSize': snapshot.navigationStack.length,
        'formDataKeys': snapshot.formData.keys.toList(),
        'scrollPositionKeys': snapshot.scrollPositions.keys.toList(),
      });

      notifyListeners();
      return true;
    } catch (e) {
      print('Error saving snapshot: $e');
      await _logger.logCustomEvent('state_snapshot_failed', {
        'error': e.toString(),
      });
      return false;
    }
  }

  /// Update navigation stack
  Future<void> updateNavigationStack(List<String> stack) async {
    if (_currentSnapshot != null) {
      _currentSnapshot = _currentSnapshot!.copyWith(navigationStack: stack);
    } else {
      _currentSnapshot = StateSnapshot(
        navigationStack: stack,
        formData: {},
        scrollPositions: {},
        timestamp: DateTime.now(),
      );
    }
    await _database.saveNavigationStack(stack);
    notifyListeners();
  }

  /// Update form data
  Future<void> updateFormData(Map<String, dynamic> formData) async {
    if (_currentSnapshot != null) {
      _currentSnapshot = _currentSnapshot!.copyWith(formData: formData);
    } else {
      _currentSnapshot = StateSnapshot(
        navigationStack: [],
        formData: formData,
        scrollPositions: {},
        timestamp: DateTime.now(),
      );
    }
    await _database.saveFormData(formData);
    notifyListeners();
  }

  /// Update a single form field
  Future<void> updateFormField(String key, dynamic value) async {
    final currentFormData = _currentSnapshot?.formData ?? {};
    currentFormData[key] = value;
    await updateFormData(currentFormData);
  }

  /// Update scroll position for a screen
  Future<void> updateScrollPosition(String screenId, double position) async {
    final currentPositions = Map<String, double>.from(_currentSnapshot?.scrollPositions ?? {});
    currentPositions[screenId] = position;
    
    if (_currentSnapshot != null) {
      _currentSnapshot = _currentSnapshot!.copyWith(scrollPositions: currentPositions);
    } else {
      _currentSnapshot = StateSnapshot(
        navigationStack: [],
        formData: {},
        scrollPositions: currentPositions,
        timestamp: DateTime.now(),
      );
    }
    await _database.saveScrollPosition(screenId, position);
    notifyListeners();
  }

  /// Clear all saved state
  Future<void> clearState() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/app_data/$snapshotFileName');
      
      if (await file.exists()) {
        await file.delete();
      }

      await _database.clearAllStates();
      
      _currentSnapshot = null;
      _lastSaveTimestamp = null;

      await _logger.logCustomEvent('state_cleared', {});

      notifyListeners();
    } catch (e) {
      print('Error clearing state: $e');
    }
  }

  /// Check if there is a snapshot available
  Future<bool> hasSnapshot() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/app_data/$snapshotFileName');
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Get the snapshot file size
  Future<int> getSnapshotSize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/app_data/$snapshotFileName');
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      print('Error getting snapshot size: $e');
    }
    return 0;
  }

  /// Schedule periodic snapshots
  void startPeriodicSave(Duration interval) {
    Future.delayed(interval, () async {
      await saveSnapshot();
      startPeriodicSave(interval);
    });
  }
}
