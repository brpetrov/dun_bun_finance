import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dun_bun_finance/models/analysis_suggestion.dart';
import 'package:dun_bun_finance/services/auth_service.dart';

class FirestoreService {
  static final _firestore = FirebaseFirestore.instance;

  static DocumentReference get _userDoc =>
      _firestore.collection('users').doc(AuthService.currentUser!.uid);

  // --- EXPENSES ---

  static CollectionReference get _expensesCol =>
      _userDoc.collection('expenses');

  static Future<void> createExpense(String name, double cost, bool isLoan,
      String? loanStartDate, String? loanEndDate,
      {String category = 'Other',
      String expenseType = 'bill',
      bool isVariable = false,
      double? interestRate}) async {
    await _expensesCol.add({
      'name': name,
      'cost': cost,
      'category': category,
      'expenseType': expenseType,
      'isVariable': isVariable,
      'interestRate': interestRate,
      'isLoan': isLoan,
      'loanStartDate': loanStartDate,
      'loanEndDate': loanEndDate,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<List<Map<String, dynamic>>> getExpenses() async {
    final snapshot = await _expensesCol.orderBy('createdAt').get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      data['category'] ??= 'Other';
      data['expenseType'] ??= 'bill';
      data['isVariable'] ??= false;

      // Normalize Timestamps to ISO strings
      final rawCreatedAt = data['createdAt'];
      if (rawCreatedAt is Timestamp) {
        data['createdAt'] = rawCreatedAt.toDate().toIso8601String();
      }
      final rawUpdatedAt = data['updatedAt'];
      if (rawUpdatedAt is Timestamp) {
        data['updatedAt'] = rawUpdatedAt.toDate().toIso8601String();
      } else if (rawUpdatedAt == null) {
        data['updatedAt'] = data['createdAt'];
      }

      return data;
    }).toList();
  }

  static Future<void> updateExpense(
      String docId, Map<String, dynamic> data) async {
    await _expensesCol.doc(docId).update(data);
  }

  static Future<void> markExpenseReviewed(String docId) async {
    await _expensesCol.doc(docId).update({
      'lastNegotiatedAt': DateTime.now().toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteExpense(String docId) async {
    await _expensesCol.doc(docId).delete();
  }

  // --- MIGRATION ---

  static String _classifyExpenseType(Map<String, dynamic> data) {
    if (data['isLoan'] == true) return 'debt';

    final name = (data['name'] ?? '').toString().toLowerCase();
    final category = (data['category'] ?? 'Other').toString();

    // Savings-like items
    if (name.contains('investment') ||
        name.contains('emergency fund') ||
        name.contains('saving')) {
      return 'savings';
    }

    // Budget-like items
    if (category == 'Food & Groceries' ||
        category == 'Entertainment' ||
        category == 'Health & Fitness') {
      return 'budget';
    }

    // Name-based budget detection
    if (name.contains('food') ||
        name.contains('fuel') ||
        name.contains('cat monthly')) {
      return 'budget';
    }

    // Everything else is a bill
    return 'bill';
  }

  static Future<int> migrateExpenseTypes() async {
    final snapshot = await _expensesCol.get();
    final batch = _firestore.batch();
    int count = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['expenseType'] != null) continue;

      final expenseType = _classifyExpenseType(data);
      batch.update(doc.reference, {
        'expenseType': expenseType,
        'isVariable': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      count++;
    }

    if (count > 0) await batch.commit();
    return count;
  }

  // --- POTS ---

  static CollectionReference get _potsCol => _userDoc.collection('pots');

  static Future<void> createPot(String name, int percentage) async {
    await _potsCol.add({
      'name': name,
      'percentage': percentage,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<List<Map<String, dynamic>>> getPots() async {
    final snapshot = await _potsCol.orderBy('createdAt').get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  static Future<void> updatePot(
      String docId, Map<String, dynamic> data) async {
    await _potsCol.doc(docId).update(data);
  }

  static Future<void> deletePot(String docId) async {
    await _potsCol.doc(docId).delete();
  }

  // --- APPLY AI SUGGESTIONS ---

  static Future<int> applyAnalysisSuggestions(
      List<AnalysisSuggestion> suggestions) async {
    final batch = _firestore.batch();
    int count = 0;

    for (final s in suggestions) {
      if (!s.accepted) continue;

      switch (s.type) {
        case SuggestionType.missing:
          if (s.suggestedName != null && s.suggestedCost != null) {
            batch.set(_expensesCol.doc(), {
              'name': s.suggestedName,
              'cost': s.suggestedCost,
              'category': s.suggestedCategory ?? 'Other',
              'expenseType': 'bill',
              'isVariable': false,
              'isLoan': s.suggestedIsLoan,
              'loanStartDate': null,
              'loanEndDate': null,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            count++;
          }
        case SuggestionType.mismatch:
          if (s.matchedExpenseId != null && s.suggestedCost != null) {
            batch.update(_expensesCol.doc(s.matchedExpenseId!), {
              'cost': s.suggestedCost,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            count++;
          }
        case SuggestionType.phantom:
          if (s.matchedExpenseId != null) {
            batch.delete(_expensesCol.doc(s.matchedExpenseId!));
            count++;
          }
        case SuggestionType.insight:
          break;
      }
    }

    if (count > 0) await batch.commit();
    return count;
  }

  // --- USER PROFILE ---

  static Future<Map<String, dynamic>?> getUserProfile() async {
    final doc = await _userDoc.get();
    if (!doc.exists) return null;
    return doc.data() as Map<String, dynamic>?;
  }

  static Future<void> createUserProfile(String displayName) async {
    await _userDoc.set({
      'displayName': displayName,
      'role': 'user',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<String> getUserRole() async {
    final profile = await getUserProfile();
    final role = (profile?['role'] as String?) ?? 'user';
    if (profile == null || profile['role'] == null) {
      await _userDoc.set({'role': role}, SetOptions(merge: true));
    }
    return role;
  }

  // --- MONTHLY SNAPSHOTS ---

  static CollectionReference get _snapshotsCol =>
      _userDoc.collection('monthly_snapshots');

  /// Upserts a snapshot for the given month key (format: 'YYYY-MM').
  static Future<void> saveMonthlySnapshot({
    required String month,
    required double totalExpenses,
    required Map<String, double> subtotalsByType,
    required double income,
  }) async {
    await _snapshotsCol.doc(month).set({
      'month': month,
      'totalExpenses': totalExpenses,
      'subtotalsByType': subtotalsByType,
      'income': income,
      'savedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<List<Map<String, dynamic>>> getMonthlySnapshots() async {
    final snapshot =
        await _snapshotsCol.orderBy('month', descending: false).get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // --- MAINTENANCE ---

  static CollectionReference get _maintenanceCol =>
      _userDoc.collection('maintenance');

  static Future<void> createMaintenanceItem({
    required String name,
    required String category,
    required String description,
    required int frequencyMonths,
    required String? nextDueDate,
  }) async {
    await _maintenanceCol.add({
      'name': name,
      'category': category,
      'description': description,
      'frequencyMonths': frequencyMonths,
      'lastDoneDate': null,
      'nextDueDate': nextDueDate,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> createMaintenanceItems(
      List<Map<String, dynamic>> items) async {
    final batch = _firestore.batch();
    for (final item in items) {
      batch.set(_maintenanceCol.doc(), {
        ...item,
        'lastDoneDate': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  static Future<List<Map<String, dynamic>>> getMaintenanceItems() async {
    final snapshot = await _maintenanceCol.orderBy('createdAt').get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      // Normalize Timestamps to ISO strings
      for (final key in ['nextDueDate', 'lastDoneDate', 'createdAt']) {
        final raw = data[key];
        if (raw is Timestamp) {
          data[key] = raw.toDate().toIso8601String();
        }
      }
      return data;
    }).toList();
  }

  static Future<void> updateMaintenanceItem(
      String docId, Map<String, dynamic> data) async {
    await _maintenanceCol.doc(docId).update(data);
  }

  static Future<void> markMaintenanceDone(
      String docId, int frequencyMonths) async {
    final now = DateTime.now();
    final nextDue =
        DateTime(now.year, now.month + frequencyMonths, now.day);
    await _maintenanceCol.doc(docId).update({
      'lastDoneDate': now.toIso8601String(),
      'nextDueDate': nextDue.toIso8601String(),
    });
  }

  static Future<void> deleteMaintenanceItem(String docId) async {
    await _maintenanceCol.doc(docId).delete();
  }

  static Future<bool> hasMaintenanceItems() async {
    final snapshot = await _maintenanceCol.limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  // --- CLEAR ALL ---

  static Future<void> clearAll() async {
    final expenses = await _expensesCol.get();
    for (final doc in expenses.docs) {
      await doc.reference.delete();
    }
    final pots = await _potsCol.get();
    for (final doc in pots.docs) {
      await doc.reference.delete();
    }
  }

  // --- DELETE ACCOUNT DATA ---

  /// Deletes all subcollections and the user profile document.
  static Future<void> deleteUserData() async {
    final expensesDocs = await _expensesCol.get();
    for (final doc in expensesDocs.docs) {
      await doc.reference.delete();
    }
    final potsDocs = await _potsCol.get();
    for (final doc in potsDocs.docs) {
      await doc.reference.delete();
    }
    final snapshotDocs = await _snapshotsCol.get();
    for (final doc in snapshotDocs.docs) {
      await doc.reference.delete();
    }
    final maintenanceDocs = await _maintenanceCol.get();
    for (final doc in maintenanceDocs.docs) {
      await doc.reference.delete();
    }
    await _userDoc.delete();
  }
}
