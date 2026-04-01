// DEPRECATED — replaced by FirestoreService. Kept for reference only.
// import 'package:dun_bun_finance/models/expense.dart';
// import 'package:dun_bun_finance/models/pot.dart';
// import 'package:sqflite/sqflite.dart' as sql;
// import 'package:path_provider/path_provider.dart';
//
// class SQLHelper {
//   static Future<void> createTables(sql.Database database) async {
//     await database.execute("""
//       CREATE TABLE expenses(
//         id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
//         name TEXT,
//         cost REAL,
//         isLoan BIT DEFAULT 0,
//         loanStartDate TEXT,
//         loanEndDate TEXT,
//         created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
//       )
//     """);
//     await database.execute("""
//       CREATE TABLE pots(
//         id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
//         name TEXT,
//         percentage INT,
//         created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
//       )
//     """);
//   }
//
//   static Future<sql.Database> db() async {
//     final directory = await getApplicationDocumentsDirectory();
//     final path = '${directory.path}/dun_bun_finance.db';
//     return sql.openDatabase(path, version: 2, onCreate: (db, v) => createTables(db));
//   }
//
//   static Future<int> createExpense(String name, double cost, bool isLoan, String? loanStartDate, String? loanEndDate) async {
//     final db = await SQLHelper.db();
//     return db.insert('expenses', {'name': name, 'cost': cost, 'isLoan': isLoan ? 1 : 0, 'loanStartDate': loanStartDate, 'loanEndDate': loanEndDate}, conflictAlgorithm: sql.ConflictAlgorithm.replace);
//   }
//   static Future<List<Map<String, dynamic>>> getExpenses() async => (await SQLHelper.db()).query('expenses', orderBy: 'id');
//   static Future<int> updateExpense(Expense expense) async => (await SQLHelper.db()).update('expenses', expense.toJson(), where: 'id = ?', whereArgs: [expense.id]);
//   static Future<void> deleteExpense(int id) async => (await SQLHelper.db()).delete('expenses', where: 'id = ?', whereArgs: [id]);
//
//   static Future<int> createPot(String name, int percentage) async => (await SQLHelper.db()).insert('pots', {'name': name, 'percentage': percentage}, conflictAlgorithm: sql.ConflictAlgorithm.replace);
//   static Future<List<Map<String, dynamic>>> getPots() async => (await SQLHelper.db()).query('pots', orderBy: 'id');
//   static Future<int> updatePot(Pot pot) async => (await SQLHelper.db()).update('pots', pot.toJson(), where: 'id = ?', whereArgs: [pot.id]);
//   static Future<void> deletePot(int id) async => (await SQLHelper.db()).delete('pots', where: 'id = ?', whereArgs: [id]);
// }
