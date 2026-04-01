import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dun_bun_finance/services/auth_service.dart';

class FirestoreService {
  static final _firestore = FirebaseFirestore.instance;

  static DocumentReference get _userDoc =>
      _firestore.collection('users').doc(AuthService.currentUser!.uid);

  // --- EXPENSES ---

  static CollectionReference get _expensesCol =>
      _userDoc.collection('expenses');

  static Future<void> createExpense(String name, double cost, bool isLoan,
      String? loanStartDate, String? loanEndDate) async {
    await _expensesCol.add({
      'name': name,
      'cost': cost,
      'isLoan': isLoan,
      'loanStartDate': loanStartDate,
      'loanEndDate': loanEndDate,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<List<Map<String, dynamic>>> getExpenses() async {
    final snapshot = await _expensesCol.orderBy('createdAt').get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  static Future<void> updateExpense(String docId, Map<String, dynamic> data) async {
    await _expensesCol.doc(docId).update(data);
  }

  static Future<void> deleteExpense(String docId) async {
    await _expensesCol.doc(docId).delete();
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

  static Future<void> updatePot(String docId, Map<String, dynamic> data) async {
    await _potsCol.doc(docId).update(data);
  }

  static Future<void> deletePot(String docId) async {
    await _potsCol.doc(docId).delete();
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
}
