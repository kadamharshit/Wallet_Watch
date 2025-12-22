import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('walletwatch.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          // future migrations
        }
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        supabase_id INTEGER,
        date TEXT NOT NULL,
        shop TEXT,
        category TEXT,
        items TEXT,
        total REAL,
        mode TEXT,
        bank TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE budget (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        supabase_id INTEGER,
        date TEXT,
        total REAL,
        mode TEXT,
        bank TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');
  }

  // ================= EXPENSES =================

  Future<int> insertExpense(Map<String, dynamic> expense) async {
    final db = await database;
    return await db.insert(
      'expenses',
      expense,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 🔁 UPSERT BY UUID (FIX FOR YOUR ERROR)
  Future<void> upsertExpenseByUuid(Map<String, dynamic> expense) async {
    final db = await database;

    final existing = await db.query(
      'expenses',
      where: 'uuid = ?',
      whereArgs: [expense['uuid']],
    );

    if (existing.isEmpty) {
      await db.insert('expenses', expense);
    } else {
      await db.update(
        'expenses',
        expense,
        where: 'uuid = ?',
        whereArgs: [expense['uuid']],
      );
    }
  }

  /// ✅ NO ARGUMENT REQUIRED
  Future<List<Map<String, dynamic>>> getExpenses() async {
    final db = await database;
    return await db.query('expenses', orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedExpenses() async {
    final db = await database;
    return await db.query('expenses', where: 'synced = ?', whereArgs: [0]);
  }

  Future<void> updateExpense(int id, Map<String, dynamic> values) async {
    final db = await database;
    await db.update('expenses', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteExpense(int id) async {
    final db = await database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ================= BUDGET =================

  Future<int> insertBudget(Map<String, dynamic> budget) async {
    final db = await database;
    return await db.insert(
      'budget',
      budget,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, dynamic>>> getBudget() async {
    final db = await database;
    return await db.query('budget', orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedBudgets() async {
    final db = await database;
    return await db.query('budget', where: 'synced = ?', whereArgs: [0]);
  }

  Future<bool> isLocalDatabaseEmpty() async {
    final db = await database;

    final expCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM expenses'),
    );

    final budgetCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM budget'),
    );

    return (expCount ?? 0) == 0 && (budgetCount ?? 0) == 0;
  }

  Future<void> updateBudget(int id, Map<String, dynamic> values) async {
    final db = await database;
    await db.update('budget', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteBudget(int id) async {
    final db = await database;
    await db.delete('budget', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllTables() async {
    final db = await database;
    await db.delete('expenses');
    await db.delete('budget');
  }
}
