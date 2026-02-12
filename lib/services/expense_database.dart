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
      version: 6,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 4) {
          await db.execute('''
        CREATE TABLE shopping_list (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          uuid TEXT UNIQUE,
          shop TEXT,
          items TEXT,
          created_at TEXT
        )
      ''');
        }

        if (oldVersion < 5) {
          await db.execute('ALTER TABLE expenses ADD COLUMN user_id TEXT');
          await db.execute('ALTER TABLE budget ADD COLUMN user_id TEXT');
        }

        if (oldVersion < 6) {
          await db.execute('''
        CREATE TABLE IF NOT EXISTS user_profile (
          user_id TEXT PRIMARY KEY,
          name TEXT,
          email TEXT,
          mobile TEXT,
          dob TEXT
        )
      ''');
        }
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE expenses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT UNIQUE,
  user_id TEXT,
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
  user_id TEXT,
  supabase_id INTEGER,
  date TEXT,
  total REAL,
  mode TEXT,
  bank TEXT,
  synced INTEGER DEFAULT 0
)
''');
    await db.execute('''
      CREATE TABLE shopping_list (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT unique,
      shop TEXT,
      items TEXT,     --JSON
      created_at TEXT
      )
    ''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS user_profile (
  user_id TEXT PRIMARY KEY,
  name TEXT,
  email TEXT,
  mobile TEXT,
  dob TEXT
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

  // UPSERT BY UUID (FIX FOR YOUR ERROR)
  Future<void> upsertExpenseByUuid(Map<String, dynamic> expense) async {
    final db = await database;

    final existing = await db.query(
      'expenses',
      where: 'uuid = ? AND user_id = ?',
      whereArgs: [expense['uuid'], expense['user_id']],
    );

    if (existing.isEmpty) {
      await db.insert('expenses', expense);
    } else {
      await db.update(
        'expenses',
        expense,
        where: 'uuid = ? AND user_id = ?',
        whereArgs: [expense['uuid'], expense['user_id']],
      );
    }
  }

  // NO ARGUMENT REQUIRED
  Future<List<Map<String, dynamic>>> getExpenses(String userId) async {
    final db = await database;

    return await db.query(
      'expenses',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedExpenses(String userId) async {
    final db = await database;

    return await db.query(
      'expenses',
      where: 'synced = ? AND user_id = ?',
      whereArgs: [0, userId],
    );
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

  Future<List<Map<String, dynamic>>> getBudget(String userId) async {
    final db = await database;

    return await db.query(
      'budget',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedBudgets(String userId) async {
    final db = await database;

    return await db.query(
      'budget',
      where: 'synced = ? AND user_id = ?',
      whereArgs: [0, userId],
    );
  }

  Future<List<String>> getUserBanks(String userId) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
    SELECT DISTINCT bank 
    FROM budget 
    WHERE user_id = ? 
      AND bank IS NOT NULL 
      AND bank != ''
    ORDER BY bank ASC
  ''',
      [userId],
    );

    return result.map((e) => e['bank'] as String).toList();
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

  //---------------- Recent Travel Expense ----------------------
  Future<List<Map<String, dynamic>>> getRecentTravelExpenses({
    int limit = 5,
  }) async {
    final db = await database;
    return await db.query(
      'expenses',
      where: 'category = ?',
      whereArgs: ['Travel'],
      orderBy: 'date DESC',
      limit: limit,
    );
  }

  //------------------ Shopping List -------------------------------
  Future<int> insertShoppingList(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(
      'shopping_list',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getActiveShoppingList() async {
    final db = await database;
    final res = await db.query(
      'shopping_list',
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> deleteShoppingList(int id) async {
    final db = await database;
    await db.delete('shopping_list', where: 'id=?', whereArgs: [id]);
  }

  Future<void> clearShoppingList() async {
    final db = await database;
    await db.delete('shopping_list');
  }

  //  --------------USER DATA-----------
  Future<void> upsertUserProfile(Map<String, dynamic> profile) async {
    final db = await database;

    await db.insert(
      'user_profile',
      profile,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final db = await database;

    final res = await db.query(
      'user_profile',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    return res.isEmpty ? null : res.first;
  }
}
