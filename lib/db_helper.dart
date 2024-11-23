import 'package:dun_bun_finance/expense.dart';
import 'package:dun_bun_finance/models/pot.dart';
import 'package:sqflite/sqflite.dart' as sql;
import 'package:path_provider/path_provider.dart';

class SQLHelper {
  // Update createTables to include new fields for the `expenses` table
  static Future<void> createTables(sql.Database database) async {
    await database.execute("""
      CREATE TABLE expenses(
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        name TEXT,
        cost REAL,
        isLoan BIT DEFAULT 0,
        loanStartDate TEXT,
        loanEndDate TEXT,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    """);

    await database.execute("""
      CREATE TABLE pots(
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        name TEXT,
        percentage INT,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    """);
  }

  static Future<void> alterExpensesTable() async {
    final db = await SQLHelper.db();
    try {
      // Add isLoan column with a default value of 0
      await db
          .execute('ALTER TABLE expenses ADD COLUMN isLoan INTEGER DEFAULT 0');
      // Add loanStartDate column
      await db.execute('ALTER TABLE expenses ADD COLUMN loanStartDate TEXT');
      // Add loanEndDate column
      await db.execute('ALTER TABLE expenses ADD COLUMN loanEndDate TEXT');
      print("Columns added successfully to expenses table.");
    } catch (e) {
      print("Error altering table: $e");
    }
  }

  // Open database or create it
  static Future<sql.Database> db() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/dun_bun_finance.db';

    return sql.openDatabase(
      path,
      version: 2, // Incremented version to trigger table schema updates
      onCreate: (sql.Database database, int version) async {
        await createTables(database);
      },
    );
  }

  // EXPENSE Logic
  static Future<int> createExpense(String name, double cost, bool isLoan,
      String? loanStartDate, String? loanEndDate) async {
    final db = await SQLHelper.db();
    final data = {
      'name': name,
      'cost': cost,
      'isLoan': isLoan ? 1 : 0, // Convert boolean to integer for SQLite
      'loanStartDate': loanStartDate,
      'loanEndDate': loanEndDate,
    };
    final id = await db.insert(
      'expenses',
      data,
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
    return id;
  }

  static Future<List<Map<String, dynamic>>> getExpenses() async {
    final db = await SQLHelper.db();
    return db.query('expenses', orderBy: 'id');
  }

  static Future<Expense> getExpense(int id) async {
    final db = await SQLHelper.db();
    final data = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
    return Expense.fromJson(data.first);
  }

  static Future<int> updateExpense(Expense expense) async {
    try {
      final db = await SQLHelper.db();
      final data = expense.toJson();
      return db.update(
        'expenses',
        data,
        where: 'id = ?',
        whereArgs: [expense.id],
      );
    } catch (e) {
      throw Exception('Error updating expense: $e');
    }
  }

  static Future<void> deleteExpense(int id) async {
    final db = await SQLHelper.db();
    await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // POT Logic
  static Future<int> createPot(String name, int percentage) async {
    final db = await SQLHelper.db();
    final data = {'name': name, 'percentage': percentage};
    final id = await db.insert(
      'pots',
      data,
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
    return id;
  }

  static Future<List<Map<String, dynamic>>> getPots() async {
    final db = await SQLHelper.db();
    return db.query('pots', orderBy: 'id');
  }

  static Future<Pot> getPot(int id) async {
    final db = await SQLHelper.db();
    final data = await db.query(
      'pots',
      where: 'id = ?',
      whereArgs: [id],
    );
    return Pot.fromJson(data.first);
  }

  static Future<int> updatePot(Pot pot) async {
    final db = await SQLHelper.db();
    final data = pot.toJson();
    return db.update(
      'pots',
      data,
      where: 'id = ?',
      whereArgs: [pot.id],
    );
  }

  static Future<void> deletePot(int id) async {
    final db = await SQLHelper.db();
    await db.delete(
      'pots',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
