import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

/// Background workers implementation using WorkManager.
/// 
/// Defines three distinct background tasks:
/// - syncDataTask: Runs every 15 minutes for data synchronization
/// - cleanupTask: Runs daily for cleanup operations
/// - healthCheckTask: Runs every 30 minutes for health monitoring
class BackgroundWorkers {
  static const String syncDataTaskName = 'syncDataTask';
  static const String cleanupTaskName = 'cleanupTask';
  static const String healthCheckTaskName = 'healthCheckTask';

  /// Log file path for worker executions
  static const String logFileName = 'worker_executions.json';

  /// Initialize the WorkManager
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  }

  /// Schedule all background tasks
  static Future<void> scheduleAllTasks() async {
    // Schedule syncDataTask - runs every 15 minutes
    await Workmanager().registerPeriodicTask(
      'sync-data-task-unique-id',
      syncDataTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(seconds: 10),
    );

    // Schedule cleanupTask - runs daily (24 hours)
    await Workmanager().registerPeriodicTask(
      'cleanup-task-unique-id',
      cleanupTaskName,
      frequency: const Duration(hours: 24),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 1),
    );

    // Schedule healthCheckTask - runs every 30 minutes
    await Workmanager().registerPeriodicTask(
      'health-check-task-unique-id',
      healthCheckTaskName,
      frequency: const Duration(minutes: 30),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(seconds: 30),
    );
  }

  /// Cancel all scheduled tasks
  static Future<void> cancelAllTasks() async {
    await Workmanager().cancelAll();
  }

  /// Cancel a specific task
  static Future<void> cancelTask(String taskName) async {
    await Workmanager().cancelByUniqueName(taskName);
  }

  /// Run a one-time task immediately
  static Future<void> runTaskNow(String taskName) async {
    await Workmanager().registerOneOffTask(
      '${taskName}_immediate_${DateTime.now().millisecondsSinceEpoch}',
      taskName,
    );
  }

  /// Log task execution to JSON file
  static Future<void> logExecution({
    required String taskName,
    required bool success,
    required int durationMs,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final appDataDir = Directory('${directory.path}/app_data');
      if (!await appDataDir.exists()) {
        await appDataDir.create(recursive: true);
      }
      
      final file = File('${appDataDir.path}/$logFileName');
      
      Map<String, dynamic> logData;
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          logData = jsonDecode(content);
        } else {
          logData = {'executions': []};
        }
      } else {
        logData = {'executions': []};
      }

      final executions = logData['executions'] as List<dynamic>;
      executions.add({
        'taskName': taskName,
        'timestamp': DateTime.now().toIso8601String(),
        'success': success,
        'duration_ms': durationMs,
      });

      // Keep only the last 100 executions
      if (executions.length > 100) {
        executions.removeRange(0, executions.length - 100);
      }

      await file.writeAsString(jsonEncode(logData));
    } catch (e) {
      print('Error logging worker execution: $e');
    }
  }

  /// Read all logged executions
  static Future<List<Map<String, dynamic>>> getExecutions() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/app_data/$logFileName');
      
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final logData = jsonDecode(content) as Map<String, dynamic>;
          final executions = logData['executions'] as List<dynamic>;
          return executions.cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      print('Error reading worker executions: $e');
    }
    return [];
  }

  /// Clear execution log
  static Future<void> clearExecutionLog() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/app_data/$logFileName');
      
      if (await file.exists()) {
        await file.writeAsString(jsonEncode({'executions': []}));
      }
    } catch (e) {
      print('Error clearing worker executions: $e');
    }
  }
}

/// Callback dispatcher for background task execution
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    final stopwatch = Stopwatch()..start();
    bool success = false;

    try {
      switch (taskName) {
        case BackgroundWorkers.syncDataTaskName:
          success = await _executeSyncDataTask();
          break;
        case BackgroundWorkers.cleanupTaskName:
          success = await _executeCleanupTask();
          break;
        case BackgroundWorkers.healthCheckTaskName:
          success = await _executeHealthCheckTask();
          break;
        default:
          print('Unknown task: $taskName');
          success = false;
      }
    } catch (e) {
      print('Error executing task $taskName: $e');
      success = false;
    }

    stopwatch.stop();

    // Log the execution
    await BackgroundWorkers.logExecution(
      taskName: taskName,
      success: success,
      durationMs: stopwatch.elapsedMilliseconds,
    );

    return success;
  });
}

/// Execute the syncDataTask
Future<bool> _executeSyncDataTask() async {
  try {
    // Simulate data sync by writing a timestamp
    final directory = await getApplicationDocumentsDirectory();
    final appDataDir = Directory('${directory.path}/app_data');
    if (!await appDataDir.exists()) {
      await appDataDir.create(recursive: true);
    }
    
    final syncFile = File('${appDataDir.path}/last_sync.json');
    await syncFile.writeAsString(jsonEncode({
      'lastSync': DateTime.now().toIso8601String(),
      'status': 'completed',
      'itemsSynced': 0, // Simulated
    }));

    return true;
  } catch (e) {
    print('Sync task error: $e');
    return false;
  }
}

/// Execute the cleanupTask
Future<bool> _executeCleanupTask() async {
  try {
    // Perform cleanup operations
    final directory = await getApplicationDocumentsDirectory();
    final appDataDir = Directory('${directory.path}/app_data');
    
    if (await appDataDir.exists()) {
      // Clean up old log files (keep only recent ones)
      final files = await appDataDir.list().toList();
      for (final entity in files) {
        if (entity is File) {
          final stat = await entity.stat();
          final age = DateTime.now().difference(stat.modified);
          // Remove files older than 30 days (except important ones)
          if (age.inDays > 30 && !_isImportantFile(entity.path)) {
            await entity.delete();
          }
        }
      }
    }

    // Log cleanup completion
    final cleanupFile = File('${appDataDir.path}/last_cleanup.json');
    await cleanupFile.writeAsString(jsonEncode({
      'lastCleanup': DateTime.now().toIso8601String(),
      'status': 'completed',
    }));

    return true;
  } catch (e) {
    print('Cleanup task error: $e');
    return false;
  }
}

/// Execute the healthCheckTask
Future<bool> _executeHealthCheckTask() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final appDataDir = Directory('${directory.path}/app_data');
    if (!await appDataDir.exists()) {
      await appDataDir.create(recursive: true);
    }

    // Perform health checks
    final healthData = {
      'timestamp': DateTime.now().toIso8601String(),
      'checks': {
        'database': true, // Simplified - would actually check database
        'storage': true,
        'memory': true,
      },
      'status': 'healthy',
    };

    final healthFile = File('${appDataDir.path}/health_status.json');
    await healthFile.writeAsString(jsonEncode(healthData));

    return true;
  } catch (e) {
    print('Health check task error: $e');
    return false;
  }
}

/// Check if a file should be kept during cleanup
bool _isImportantFile(String path) {
  final importantFiles = [
    'worker_executions.json',
    'lifecycle_events.log',
    'config_changes.json',
    'scheduled_alarms.json',
    'state_snapshot.json',
  ];
  
  return importantFiles.any((name) => path.endsWith(name));
}
