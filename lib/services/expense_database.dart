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

    return await openDatabase(path, version: 2, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // Expenses table
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        supabase_id INTEGER,
        uuid TEXT,
        shop TEXT,
        category TEXT,
        items TEXT,
        total REAL,
        mode TEXT,
        bank TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    // Budget table
    await db.execute('''
      CREATE TABLE budget (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supabase_id INTEGER,
        uuid TEXT,
        date TEXT,
        total Real,
        mode TEXT,
        bank TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');
  }

  // ====================== EXPENSES ======================

  Future<int> insertExpense(Map<String, dynamic> expense) async {
    final db = await instance.database;
    return await db.insert('expenses', expense);
  }

  Future<List<Map<String, dynamic>>> getExpenses() async {
    final db = await instance.database;
    return await db.query('expenses', orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedExpenses() async {
    final db = await instance.database;
    return await db.query('expenses', where: 'synced = ?', whereArgs: [0]);
  }

  Future<void> markExpenseAsSynced(int id) async {
    final db = await instance.database;
    await db.update(
      'expenses',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateExpense(int id, Map<String, dynamic> values) async {
    final db = await instance.database;
    return await db.update(
      'expenses',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await instance.database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ====================== BUDGET ======================

  Future<int> insertBudget(Map<String, dynamic> budget) async {
    final db = await instance.database;
    return await db.insert('budget', budget);
  }

  Future<List<Map<String, dynamic>>> getBudget() async {
    final db = await instance.database;
    return await db.query('budget', orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedBudgets() async {
    final db = await instance.database;
    return await db.query('budget', where: 'synced = ?', whereArgs: [0]);
  }

  Future<void> markBudgetAsSynced(int id) async {
    final db = await instance.database;
    await db.update('budget', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateBudget(int id, Map<String, dynamic> values) async {
    final db = await instance.database;
    return await db.update('budget', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteBudget(int id) async {
    final db = await instance.database;
    return await db.delete('budget', where: 'id = ?', whereArgs: [id]);
  }
}
