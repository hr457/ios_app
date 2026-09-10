import 'dart:convert'; // Trigger Refresh
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database?> get database async {
    if (kIsWeb) return null; // Sqflite not supported on web
    if (_database != null) return _database!;
    try {
      _database = await _initDatabase();
      return _database!;
    } catch (e) {
      debugPrint("Database Init Error: $e");
      return null;
    }
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'safl_tracking.db');
    return await openDatabase(
      path,
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE pending_visits (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              data TEXT,
              photo_path TEXT,
              timestamp TEXT,
              is_synced INTEGER DEFAULT 0
            )
          ''');
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE location_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            latitude REAL,
            longitude REAL,
            timestamp TEXT,
            is_synced INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE attendance (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            punch_in TEXT,
            punch_out TEXT,
            date TEXT,
            is_synced INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            case_no TEXT,
            remark TEXT,
            due_date TEXT,
            from_user TEXT,
            to_user TEXT,
            status TEXT DEFAULT 'pending',
            created_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE pending_visits (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            data TEXT,
            photo_path TEXT,
            timestamp TEXT,
            is_synced INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  // --- Visit Persistence ---
  Future<int> insertPendingVisit(Map<String, dynamic> data, String? photoPath) async {
    final db = await database;
    if (db == null) return -1;
    return await db.insert('pending_visits', {
      'data': jsonEncode(data),
      'photo_path': photoPath,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getUnsyncedVisits() async {
    final db = await database;
    if (db == null) return [];
    return await db.query('pending_visits', where: 'is_synced = 0');
  }

  Future<void> deletePendingVisit(int id) async {
    final db = await database;
    if (db == null) return;
    await db.delete('pending_visits', where: 'id = ?', whereArgs: [id]);
  }

  // --- Task Methods ---
  Future<int> insertTask(Map<String, dynamic> task) async {
    final db = await database;
    if (db == null) return -1;
    return await db.insert('tasks', task);
  }

  Future<List<Map<String, dynamic>>> getTasks(String userName) async {
    final db = await database;
    if (db == null) return [];
    return await db.query('tasks', where: 'to_user = ?', whereArgs: [userName], orderBy: 'due_date ASC');
  }

  Future<void> updateTaskStatus(int id, String status) async {
    final db = await database;
    if (db == null) return;
    await db.update('tasks', {'status': status}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertLocation(double lat, double lng) async {
    final db = await database;
    if (db == null) return;
    await db.insert('location_logs', {
      'latitude': lat,
      'longitude': lng,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getUnsyncedLocations() async {
    final db = await database;
    if (db == null) return [];
    return await db.query('location_logs', where: 'is_synced = 0');
  }

  Future<void> markLocationsSynced(List<int> ids) async {
    final db = await database;
    if (db == null) return;
    await db.update('location_logs', {'is_synced': 1},
        where: 'id IN (${ids.join(',')})');
  }
  
  Future<void> logAttendance(String type) async {
    final db = await database;
    if (db == null) return;
    await db.insert('attendance', {
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
