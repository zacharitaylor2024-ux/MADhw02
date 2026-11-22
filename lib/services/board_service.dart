import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BoardService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  User get _user => FirebaseAuth.instance.currentUser!;

  CollectionReference<Map<String, dynamic>> get _messages => _db.collection('messages');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages() =>
      _messages.orderBy('createdAt', descending: true).snapshots();

  /// Generate once per user tap; reuse the same ID for a retry of the same tap.
  String newRequestId() => _messages.doc().id;

  /// Transaction + stable ID: retries/double invocations create at most one doc.
  /// Note: transactions require network access; they cannot queue offline.
  Future<void> createOnce({required String requestId, required String text}) async {
    final clean = text.trim();
    if (clean.isEmpty || clean.length > 500) throw ArgumentError('Message must be 1–500 characters.');
    final ref = _messages.doc(requestId);
    await _db.runTransaction((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists) return;
      tx.set(ref, {
        'text': clean,
        'authorUid': _user.uid,
        'authorName': (_user.displayName?.trim().isNotEmpty ?? false)
            ? _user.displayName!.trim() : (_user.email ?? 'Member'),
        'createdAt': FieldValue.serverTimestamp(),
        'editedAt': null,
      });
    });
  }

  Future<void> editMessage(String id, String text) async {
    final clean = text.trim();
    if (clean.isEmpty || clean.length > 500) throw ArgumentError('Message must be 1–500 characters.');
    await _messages.doc(id).update({'text': clean, 'editedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteMessage(String id) => _messages.doc(id).delete();

  /// Used for the Spice #4 demonstration: same request ID submitted twice.
  Future<void> demonstrateDuplicate(String text) async {
    final id = newRequestId();
    await Future.wait([
      createOnce(requestId: id, text: text),
      createOnce(requestId: id, text: text),
    ]);
  }
}
