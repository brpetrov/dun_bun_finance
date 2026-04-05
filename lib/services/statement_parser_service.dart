import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:dun_bun_finance/models/statement_transaction.dart';

class StatementParserService {
  static Future<List<StatementTransaction>> parseFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final extension = fileName.split('.').last.toLowerCase();
    if (extension == 'csv') {
      return parseCsvBytes(bytes);
    }
    throw FormatException('Unsupported file type: .$extension');
  }

  static Future<List<StatementTransaction>> parseCsvBytes(
    Uint8List bytes,
  ) async {
    final content = _decodeBytes(bytes).replaceFirst('\uFEFF', '');
    return _parseCsvContent(content);
  }

  static List<StatementTransaction> _parseCsvContent(String content) {
    final rows = const CsvToListConverter(eol: '\n').convert(content);
    if (rows.isEmpty) throw const FormatException('Empty CSV file');

    final headers =
        rows.first.map((h) => h.toString().toLowerCase().trim()).toList();

    // Detect if this is a Monzo export (has 'type' and 'name' and 'money out' columns)
    final typeCol = _findColumn(headers, ['type']);
    final nameCol = _findColumn(headers, ['name']);
    final moneyOutCol = _findColumn(headers, ['money out']);

    if (typeCol != null && nameCol != null && moneyOutCol != null) {
      return _parseMonzo(rows, headers, typeCol, nameCol, moneyOutCol);
    }

    return _parseGeneric(rows, headers);
  }

  static String _decodeBytes(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  // --- Monzo-specific parser ---

  static const _monzoIgnoreTypes = {
    'pot transfer',
    'bacs (direct credit)',
    'rewards',
  };

  static List<StatementTransaction> _parseMonzo(
    List<List<dynamic>> rows,
    List<String> headers,
    int typeCol,
    int nameCol,
    int moneyOutCol,
  ) {
    final dateCol = _findColumn(headers, ['date']);
    final categoryCol = _findColumn(headers, ['category']);
    final transactions = <StatementTransaction>[];

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= moneyOutCol) continue;

      final type = row[typeCol].toString().toLowerCase().trim();

      // Skip non-expense transaction types.
      if (_monzoIgnoreTypes.contains(type)) continue;
      if (type == 'flex') continue;

      // Skip income categories.
      final category = categoryCol != null && categoryCol < row.length
          ? row[categoryCol].toString().toLowerCase().trim()
          : '';
      if (category == 'income' || category == 'savings') continue;

      final name = row[nameCol].toString().trim();
      if (name.isEmpty) continue;

      // Use Money Out column and skip empty values, credits, or refunds.
      final moneyOut = _parseAmount(row[moneyOutCol].toString());
      if (moneyOut == null || moneyOut == 0) continue;
      final amount = moneyOut.abs();

      DateTime? date;
      if (dateCol != null && dateCol < row.length) {
        date = _parseDate(row[dateCol].toString().trim());
      }

      transactions.add(StatementTransaction(
        description: name,
        amount: amount,
        date: date,
      ));
    }

    if (transactions.isEmpty) {
      throw const FormatException('No transactions found in this CSV');
    }
    return transactions;
  }

  // --- Generic parser for other banks ---

  static List<StatementTransaction> _parseGeneric(
    List<List<dynamic>> rows,
    List<String> headers,
  ) {
    final dateCol = _findColumn(headers, [
      'date',
      'transaction date',
      'posting date',
      'value date',
    ]);
    final descCol = _findColumn(headers, [
      'description',
      'narrative',
      'details',
      'transaction description',
      'memo',
      'reference',
      'name',
    ]);
    final amountCol = _findColumn(headers, ['amount', 'value']);
    final debitCol = _findColumn(headers, [
      'debit',
      'money out',
      'paid out',
      'debit amount',
      'withdrawal',
    ]);

    if (descCol == null) {
      throw const FormatException(
        'Could not detect a description column in this CSV',
      );
    }
    if (amountCol == null && debitCol == null) {
      throw const FormatException(
        'Could not detect an amount or debit column in this CSV',
      );
    }

    final transactions = <StatementTransaction>[];

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= descCol) continue;

      final description = row[descCol].toString().trim();
      if (description.isEmpty) continue;

      double? amount;
      if (debitCol != null && debitCol < row.length) {
        amount = _parseAmount(row[debitCol].toString());
        if (amount != null) amount = amount.abs();
      } else if (amountCol != null && amountCol < row.length) {
        amount = _parseAmount(row[amountCol].toString());
        if (amount != null && amount < 0) amount = amount.abs();
      }

      if (amount == null || amount == 0) continue;

      DateTime? date;
      if (dateCol != null && dateCol < row.length) {
        date = _parseDate(row[dateCol].toString().trim());
      }

      transactions.add(StatementTransaction(
        description: description,
        amount: amount,
        date: date,
      ));
    }

    if (transactions.isEmpty) {
      throw const FormatException('No transactions found in this CSV');
    }
    return transactions;
  }

  // --- Helpers ---

  static int? _findColumn(List<String> headers, List<String> candidates) {
    for (final candidate in candidates) {
      final index = headers.indexWhere((h) => h.contains(candidate));
      if (index != -1) return index;
    }
    return null;
  }

  static double? _parseAmount(String raw) {
    final cleaned = raw
        .replaceAll('\u00A3', '')
        .replaceAll('Â£', '')
        .replaceAll('\$', '')
        .replaceAll('\u20AC', '')
        .replaceAll('â‚¬', '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  static DateTime? _parseDate(String raw) {
    // Try UK format DD/MM/YYYY first (most common in bank exports)
    final parts = raw.split(RegExp(r'[/\-.]'));
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        final fullYear = year < 100 ? 2000 + year : year;
        try {
          return DateTime(fullYear, month, day);
        } catch (_) {
          return null;
        }
      }
    }

    // Fallback to ISO format (2024-01-15)
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }
}
