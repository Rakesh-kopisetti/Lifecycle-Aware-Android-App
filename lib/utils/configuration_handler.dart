import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../managers/lifecycle_manager.dart';

/// Configuration change types
enum ConfigChangeType {
  orientation,
  theme,
  locale,
  fontScale,
}

/// Represents a configuration change event
class ConfigChange {
  final ConfigChangeType type;
  final String oldValue;
  final String newValue;
  final DateTime timestamp;

  ConfigChange({
    required this.type,
    required this.oldValue,
    required this.newValue,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'oldValue': oldValue,
    'newValue': newValue,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ConfigChange.fromJson(Map<String, dynamic> json) => ConfigChange(
    type: ConfigChangeType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => ConfigChangeType.orientation,
    ),
    oldValue: json['oldValue'] as String,
    newValue: json['newValue'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}

/// Handler for configuration changes.
/// Logs all configuration changes to app_data/config_changes.json
class ConfigurationHandler with ChangeNotifier {
  static final ConfigurationHandler _instance = ConfigurationHandler._internal();
  
  factory ConfigurationHandler() => _instance;
  
  ConfigurationHandler._internal();

  /// Log file name
  static const String logFileName = 'config_changes.json';

  /// Current orientation
  Orientation? _currentOrientation;
  Orientation? get currentOrientation => _currentOrientation;

  /// Current theme mode
  ThemeMode _currentThemeMode = ThemeMode.system;
  ThemeMode get currentThemeMode => _currentThemeMode;

  /// Current locale
  Locale? _currentLocale;
  Locale? get currentLocale => _currentLocale;

  /// Current text scale factor
  double _currentFontScale = 1.0;
  double get currentFontScale => _currentFontScale;

  /// List of configuration changes
  final List<ConfigChange> _changes = [];
  List<ConfigChange> get changes => List.unmodifiable(_changes);

  /// Lifecycle manager reference
  final LifecycleManager _lifecycleManager = LifecycleManager();

  /// Called when orientation changes
  Future<void> onOrientationChanged(Orientation newOrientation) async {
    if (_currentOrientation != null && _currentOrientation != newOrientation) {
      final change = ConfigChange(
        type: ConfigChangeType.orientation,
        oldValue: _currentOrientation!.name,
        newValue: newOrientation.name,
        timestamp: DateTime.now(),
      );
      
      await _logChange(change);
      _lifecycleManager.onConfigurationChanged(
        'orientation',
        _currentOrientation!.name,
        newOrientation.name,
      );
    }
    
    _currentOrientation = newOrientation;
    notifyListeners();
  }

  /// Called when theme changes
  Future<void> onThemeChanged(ThemeMode newThemeMode) async {
    if (_currentThemeMode != newThemeMode) {
      final change = ConfigChange(
        type: ConfigChangeType.theme,
        oldValue: _currentThemeMode.name,
        newValue: newThemeMode.name,
        timestamp: DateTime.now(),
      );
      
      await _logChange(change);
      _lifecycleManager.onConfigurationChanged(
        'theme',
        _currentThemeMode.name,
        newThemeMode.name,
      );
    }
    
    _currentThemeMode = newThemeMode;
    notifyListeners();
  }

  /// Called when locale changes
  Future<void> onLocaleChanged(Locale newLocale) async {
    if (_currentLocale != null && _currentLocale != newLocale) {
      final oldLocaleStr = '${_currentLocale!.languageCode}_${_currentLocale!.countryCode ?? ''}';
      final newLocaleStr = '${newLocale.languageCode}_${newLocale.countryCode ?? ''}';
      
      final change = ConfigChange(
        type: ConfigChangeType.locale,
        oldValue: oldLocaleStr,
        newValue: newLocaleStr,
        timestamp: DateTime.now(),
      );
      
      await _logChange(change);
      _lifecycleManager.onConfigurationChanged(
        'locale',
        oldLocaleStr,
        newLocaleStr,
      );
    }
    
    _currentLocale = newLocale;
    notifyListeners();
  }

  /// Called when font scale changes
  Future<void> onFontScaleChanged(double newFontScale) async {
    if (_currentFontScale != newFontScale) {
      final change = ConfigChange(
        type: ConfigChangeType.fontScale,
        oldValue: _currentFontScale.toString(),
        newValue: newFontScale.toString(),
        timestamp: DateTime.now(),
      );
      
      await _logChange(change);
      _lifecycleManager.onConfigurationChanged(
        'fontScale',
        _currentFontScale.toString(),
        newFontScale.toString(),
      );
    }
    
    _currentFontScale = newFontScale;
    notifyListeners();
  }

  /// Log a configuration change to file
  Future<void> _logChange(ConfigChange change) async {
    _changes.insert(0, change);
    
    // Keep only the last 50 changes in memory
    if (_changes.length > 50) {
      _changes.removeLast();
    }

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
          logData = {'changes': []};
        }
      } else {
        logData = {'changes': []};
      }

      final changes = logData['changes'] as List<dynamic>;
      changes.add(change.toJson());

      // Keep only the last 100 changes in file
      if (changes.length > 100) {
        changes.removeRange(0, changes.length - 100);
      }

      await file.writeAsString(jsonEncode(logData));
    } catch (e) {
      print('Error logging configuration change: $e');
    }
  }

  /// Read all logged configuration changes
  Future<List<ConfigChange>> getLoggedChanges() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/app_data/$logFileName');
      
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final logData = jsonDecode(content) as Map<String, dynamic>;
          final changes = logData['changes'] as List<dynamic>;
          return changes.map((c) => ConfigChange.fromJson(c as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      print('Error reading configuration changes: $e');
    }
    return [];
  }

  /// Clear all logged changes
  Future<void> clearChanges() async {
    _changes.clear();
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/app_data/$logFileName');
      
      if (await file.exists()) {
        await file.writeAsString(jsonEncode({'changes': []}));
      }
    } catch (e) {
      print('Error clearing configuration changes: $e');
    }
    
    notifyListeners();
  }

  /// Initialize with current values
  void initializeWithValues({
    Orientation? orientation,
    ThemeMode? themeMode,
    Locale? locale,
    double? fontScale,
  }) {
    if (orientation != null) _currentOrientation = orientation;
    if (themeMode != null) _currentThemeMode = themeMode;
    if (locale != null) _currentLocale = locale;
    if (fontScale != null) _currentFontScale = fontScale;
  }
}
