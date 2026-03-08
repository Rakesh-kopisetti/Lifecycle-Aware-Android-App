import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../managers/lifecycle_manager.dart';

/// Service for logging lifecycle events to a text file
class LifecycleEventLogger {
  static final LifecycleEventLogger _instance = LifecycleEventLogger._internal();
  
  factory LifecycleEventLogger() => _instance;
  
  LifecycleEventLogger._internal();

  /// Get the log file path
  Future<File> get _logFile async {
    final directory = await getApplicationDocumentsDirectory();
    final appDataDir = Directory('${directory.path}/app_data');
    if (!await appDataDir.exists()) {
      await appDataDir.create(recursive: true);
    }
    return File('${appDataDir.path}/lifecycle_events.log');
  }

  /// Log a lifecycle event to the file
  /// Format: [ISO8601_timestamp] [event_type] [additional_metadata_json]
  Future<void> logEvent(LifecycleEvent event) async {
    try {
      final file = await _logFile;
      final metadataJson = jsonEncode(event.metadata);
      final logLine = '[${event.timestamp.toIso8601String()}] [${event.eventType}] $metadataJson\n';
      
      await file.writeAsString(logLine, mode: FileMode.append);
    } catch (e) {
      // Silently fail if logging fails - don't crash the app
      print('Error logging lifecycle event: $e');
    }
  }

  /// Log a custom event
  Future<void> logCustomEvent(String eventType, Map<String, dynamic> metadata) async {
    final event = LifecycleEvent(
      timestamp: DateTime.now(),
      eventType: eventType,
      metadata: metadata,
    );
    await logEvent(event);
  }

  /// Read all logged events from the file
  Future<List<String>> readAllEvents() async {
    try {
      final file = await _logFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        return content.split('\n').where((line) => line.isNotEmpty).toList();
      }
    } catch (e) {
      print('Error reading lifecycle events: $e');
    }
    return [];
  }

  /// Clear all logged events
  Future<void> clearLog() async {
    try {
      final file = await _logFile;
      if (await file.exists()) {
        await file.writeAsString('');
      }
    } catch (e) {
      print('Error clearing lifecycle log: $e');
    }
  }

  /// Get log file size in bytes
  Future<int> getLogSize() async {
    try {
      final file = await _logFile;
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      print('Error getting log size: $e');
    }
    return 0;
  }
}
