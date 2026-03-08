import 'package:flutter/material.dart';
import '../managers/lifecycle_manager.dart';
import '../managers/state_recovery_manager.dart';
import '../services/foreground_service.dart';
import '../services/alarm_service.dart';
import '../utils/configuration_handler.dart';
import '../workers/background_workers.dart';
import '../database/state_database.dart';

/// Main application state provider that coordinates all managers
class AppStateProvider with ChangeNotifier {
  static final AppStateProvider _instance = AppStateProvider._internal();
  
  factory AppStateProvider() => _instance;
  
  AppStateProvider._internal();

  /// Managers
  final LifecycleManager lifecycleManager = LifecycleManager();
  final StateRecoveryManager stateRecoveryManager = StateRecoveryManager();
  final ForegroundServiceManager foregroundServiceManager = ForegroundServiceManager();
  final AlarmService alarmService = AlarmService();
  final ConfigurationHandler configurationHandler = ConfigurationHandler();
  final StateDatabase database = StateDatabase();

  /// Initialization state
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Error state
  String? _lastError;
  String? get lastError => _lastError;

  /// Theme mode
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  /// Initialize all managers
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize lifecycle manager
      lifecycleManager.initialize();
      lifecycleManager.addListener(notifyListeners);

      // Initialize foreground service
      await foregroundServiceManager.initialize();
      foregroundServiceManager.addListener(notifyListeners);

      // Initialize alarm service
      await alarmService.initialize();
      alarmService.addListener(notifyListeners);

      // Initialize state recovery
      await stateRecoveryManager.initialize();
      stateRecoveryManager.addListener(notifyListeners);

      // Initialize configuration handler
      configurationHandler.addListener(notifyListeners);

      // Initialize WorkManager
      await BackgroundWorkers.initialize();
      await BackgroundWorkers.scheduleAllTasks();

      _isInitialized = true;
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      print('Initialization error: $e');
      notifyListeners();
    }
  }

  /// Change theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await configurationHandler.onThemeChanged(mode);
    notifyListeners();
  }

  /// Toggle theme between light and dark
  Future<void> toggleTheme() async {
    final newMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }

  /// Save current app state
  Future<void> saveState() async {
    await stateRecoveryManager.saveSnapshot();
  }

  /// Clear all state
  Future<void> clearAllState() async {
    await stateRecoveryManager.clearState();
    await database.clearAllStates();
    lifecycleManager.clearEvents();
    lifecycleManager.resetStatistics();
    await configurationHandler.clearChanges();
    notifyListeners();
  }

  /// Dispose all managers
  @override
  void dispose() {
    lifecycleManager.removeListener(notifyListeners);
    foregroundServiceManager.removeListener(notifyListeners);
    alarmService.removeListener(notifyListeners);
    stateRecoveryManager.removeListener(notifyListeners);
    configurationHandler.removeListener(notifyListeners);
    super.dispose();
  }
}
