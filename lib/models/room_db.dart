import 'dart:io' show Platform;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

class RoomDb {
  static Database? _db;

  static Future<void> init() async {
    if (_db != null) return;
    // On desktop (Windows/Linux/Mac) initialize ffi database factory.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      ffi.sqfliteFfiInit();
      databaseFactory = ffi.databaseFactoryFfi;
    }

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'hotel_manager.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS room_base_info (
            room_number TEXT PRIMARY KEY,
            capacity INTEGER,
            price_per_night INTEGER DEFAULT 80,
            price_hourly REAL DEFAULT 12.5,
            amenities TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS room_status (
            room_number TEXT PRIMARY KEY,
            status TEXT DEFAULT '空闲',
            guest_name TEXT,
            id_card TEXT,
            contact TEXT,
            check_in_time DATETIME,
            check_out_time DATETIME,
            deposit INTEGER DEFAULT 0,
            details TEXT,
            FOREIGN KEY (room_number) REFERENCES room_base_info (room_number)
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS room_usage_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            room_number TEXT,
            guest_name TEXT,
            id_card TEXT,
            contact TEXT,
            check_in_time DATETIME,
            check_out_time DATETIME,
            total_amount INTEGER
          )
        ''');
      },
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );

    // Ensure tables exist even if the database file was created earlier
    // with a broken schema. This makes init idempotent and avoids
    // "no such table" errors when migrating from an older/invalid DB.
    if (_db != null) {
      await _db!.execute('''
        CREATE TABLE IF NOT EXISTS room_base_info (
          room_number TEXT PRIMARY KEY,
          capacity INTEGER,
          price_per_night INTEGER DEFAULT 80,
          price_hourly REAL DEFAULT 12.5,
          amenities TEXT
        )
      ''');
      await _db!.execute('''
        CREATE TABLE IF NOT EXISTS room_status (
          room_number TEXT PRIMARY KEY,
          status TEXT DEFAULT '空闲',
          guest_name TEXT,
          id_card TEXT,
          contact TEXT,
          check_in_time DATETIME,
          check_out_time DATETIME,
          deposit INTEGER DEFAULT 0,
          details TEXT,
          FOREIGN KEY (room_number) REFERENCES room_base_info (room_number)
        )
      ''');
      await _db!.execute('''
        CREATE TABLE IF NOT EXISTS room_usage_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          room_number TEXT,
          guest_name TEXT,
          id_card TEXT,
          contact TEXT,
          check_in_time DATETIME,
          check_out_time DATETIME,
          total_amount INTEGER
        )
      ''');
      // Ensure foreign keys are enabled for this connection as well.
      await _db!.execute('PRAGMA foreign_keys = ON');
      // Run lightweight migrations: add missing columns to existing tables.
      try {
        final statusCols = (await _db!.rawQuery('PRAGMA table_info(room_status)'))
            .map((r) => r['name'] as String?)
            .whereType<String>()
            .toSet();
        if (!statusCols.contains('deposit')) {
          await _db!.execute(
              'ALTER TABLE room_status ADD COLUMN deposit INTEGER DEFAULT 0');
        }
        if (!statusCols.contains('details')) {
          await _db!.execute('ALTER TABLE room_status ADD COLUMN details TEXT');
        }
        if (!statusCols.contains('check_in_time')) {
          await _db!.execute(
              'ALTER TABLE room_status ADD COLUMN check_in_time DATETIME');
        }
        if (!statusCols.contains('check_out_time')) {
          await _db!.execute(
              'ALTER TABLE room_status ADD COLUMN check_out_time DATETIME');
        }
      } catch (e) {
        // If migration fails, don't crash the app here; caller can decide next steps.
      }
    }
  }


  static Future<void> initData() async {
    final db = _db;
    if (db == null) return;
    // Check if there are any rooms; if not, insert some default rooms
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM room_base_info'));
    if ((count ?? 0) == 0) {
      final batch = db.batch();
      for (int i = 201; i <= 208; i++) {
        final rn = i.toString();
        batch.insert('room_base_info', {
          'room_number': rn,
          'capacity': 2,
          'price_per_night': 80,
          'price_hourly': 12.5,
          'amenities': '空调,电视,吹风机,拖鞋*2,毛巾*2,牙膏*2',
        });
        batch.insert('room_status', {
          'room_number': rn,
          'status': '空闲',
          'deposit': 0,
        });
      }
      await batch.commit(noResult: true);
    }
  }
  static Future<Map<String, String>> getAllStatuses() async {
    final db = _db;
    if (db == null) return {};
    final rows = await db.query('room_status');
    final map = <String, String>{};
    for (final r in rows) {
      final rn = r['room_number'] as String?;
      final st = r['status'] as String? ?? '空闲';
      if (rn != null) map[rn] = st;
    }
    return map;
  }

  static Future<String?> getStatus(String roomNumber) async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.query('room_status',
        where: 'room_number = ?', whereArgs: [roomNumber], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['status'] as String? ?? '空闲';
  }

  /// Return merged room base info and status rows.
  static Future<List<Map<String, dynamic>>> getAllRooms() async {
    final db = _db;
    if (db == null) return [];
    final rows = await db.rawQuery('''
      SELECT b.room_number, b.capacity, b.price_per_night, b.price_hourly, b.amenities,
             s.status, s.guest_name, s.id_card ,s.contact ,s.check_in_time, s.check_out_time, s.deposit
      FROM room_base_info b
      LEFT JOIN room_status s ON b.room_number = s.room_number
      ORDER BY b.room_number
    ''');
    return rows;
  }

  static Future<void> setStatus(
    String roomNumber,
    String status, {
    String? guestName,
    String? idCard,
    String? contact,
  }) async {
    final db = _db;
    if (db == null) return;
    await db.insert(
      'room_status',
      {
        'room_number': roomNumber,
        'status': status,
        'guest_name': guestName,
        'id_card': idCard,
        'contact': contact,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> setGuestInfo(String roomNumber,
      {String? guestName, String? idCard, String? contact}) async {
    final db = _db;
    if (db == null) return;
    // Try to update; if not exists, insert
    final existing = await db.query('room_status',
        where: 'room_number = ?', whereArgs: [roomNumber], limit: 1);
    if (existing.isNotEmpty) {
      await db.update(
        'room_status',
        {
          if (guestName != null) 'guest_name': guestName,
          if (idCard != null) 'id_card': idCard,
          if (contact != null) 'contact': contact,
        },
        where: 'room_number = ?',
        whereArgs: [roomNumber],
      );
    } else {
      await db.insert('room_status', {
        'room_number': roomNumber,
        'status': '空闲',
        'guest_name': guestName,
        'id_card': idCard,
        'contact': contact,
      });
    }
  }

  
}
