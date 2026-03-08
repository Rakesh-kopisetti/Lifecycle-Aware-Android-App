import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

/// Database class for persisting application state using SQLite.
/// 
/// Database Name: app.db
/// Table: app_state
/// Schema:
/// - id: INTEGER PRIMARY KEY
/// - state_key: TEXT NOT NULL, UNIQUE
/// - state_value: TEXT NOT NULL
/// - last_updated: INTEGER NOT NULL (Unix timestamp)
class StateDatabase {
  static final StateDatabase _instance = StateDatabase._internal();
  
  factory StateDatabase() => _instance;
  
  StateDatabase._internal();

  Database? _database;

  /// Get the database instance, initializing if necessary
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'app.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDb,
      onUpgrade: _upgradeDb,
    );
  }

  /// Create the database tables
  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE app_state (
        id INTEGER PRIMARY KEY,
        state_key TEXT NOT NULL UNIQUE,
        state_value TEXT NOT NULL,
        last_updated INTEGER NOT NULL
      )
    ''');

    // Create index for faster lookups
    await db.execute('''
      CREATE INDEX idx_state_key ON app_state(state_key)
    ''');
  }

  /// Handle database upgrades
  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    // Handle future migrations here
    if (oldVersion < 1) {
      await _createDb(db, newVersion);
    }
  }

  /// Save a state value
  Future<void> saveState(String key, dynamic value) async {
    final db = await database;
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    String stringValue;
    if (value is String) {
      stringValue = value;
    } else if (value is Map || value is List) {
      stringValue = jsonEncode(value);
    } else {
      stringValue = value.toString();
    }

    await db.insert(
      'app_state',
      {
        'state_key': key,
        'state_value': stringValue,
        'last_updated': timestamp,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get a state value
  Future<String?> getState(String key) async {
    final db = await database;
    final result = await db.query(
      'app_state',
      columns: ['state_value'],
      where: 'state_key = ?',
      whereArgs: [key],
    );

    if (result.isNotEmpty) {
      return result.first['state_value'] as String?;
    }
    return null;
  }

  /// Get a state value as a specific type
  Future<T?> getStateAs<T>(String key) async {
    final value = await getState(key);
    if (value == null) return null;

    try {
      if (T == int) {
        return int.parse(value) as T;
      } else if (T == double) {
        return double.parse(value) as T;
      } else if (T == bool) {
        return (value.toLowerCase() == 'true') as T;
      } else if (T == Map<String, dynamic>) {
        return jsonDecode(value) as T;
      } else if (T == List<dynamic>) {
        return jsonDecode(value) as T;
      }
      return value as T;
    } catch (e) {
      print('Error parsing state value: $e');
      return null;
    }
  }

  /// Delete a state value
  Future<void> deleteState(String key) async {
    final db = await database;
    await db.delete(
      'app_state',
      where: 'state_key = ?',
      whereArgs: [key],
    );
  }

  /// Get all stored states
  Future<Map<String, String>> getAllStates() async {
    final db = await database;
    final result = await db.query('app_state');
    
    final states = <String, String>{};
    for (final row in result) {
      states[row['state_key'] as String] = row['state_value'] as String;
    }
    return states;
  }

  /// Clear all stored states
  Future<void> clearAllStates() async {
    final db = await database;
    await db.delete('app_state');
  }

  /// Get states that were updated after a specific timestamp
  Future<Map<String, String>> getStatesUpdatedAfter(DateTime timestamp) async {
    final db = await database;
    final unixTimestamp = timestamp.millisecondsSinceEpoch ~/ 1000;
    
    final result = await db.query(
      'app_state',
      where: 'last_updated > ?',
      whereArgs: [unixTimestamp],
    );
    
    final states = <String, String>{};
    for (final row in result) {
      states[row['state_key'] as String] = row['state_value'] as String;
    }
    return states;
  }

  /// Save form data to database
  Future<void> saveFormData(Map<String, dynamic> formData) async {
    await saveState('form_data', formData);
  }

  /// Get form data from database
  Future<Map<String, dynamic>?> getFormData() async {
    return await getStateAs<Map<String, dynamic>>('form_data');
  }

  /// Save scroll position
  Future<void> saveScrollPosition(String screenId, double position) async {
    final positions = await getScrollPositions();
    positions[screenId] = position;
    await saveState('scroll_positions', positions);
  }

  /// Get all scroll positions
  Future<Map<String, double>> getScrollPositions() async {
    final data = await getStateAs<Map<String, dynamic>>('scroll_positions');
    if (data == null) return {};
    return data.map((key, value) => MapEntry(key, (value as num).toDouble()));
  }

  /// Save navigation stack
  Future<void> saveNavigationStack(List<String> stack) async {
    await saveState('navigation_stack', stack);
  }

  /// Get navigation stack
  Future<List<String>> getNavigationStack() async {
    final data = await getStateAs<List<dynamic>>('navigation_stack');
    if (data == null) return [];
    return data.cast<String>();
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
