import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> register({required String email, required String password,
    required String firstName, required String lastName}) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(), password: password);
    final user = credential.user!;
    try {
      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'role': 'member',
        'registrationDateTime': FieldValue.serverTimestamp(),
      });
      await user.updateDisplayName('${firstName.trim()} ${lastName.trim()}');
    } catch (_) {
      // Do not leave a partly registered profile that can reach the board.
      // If deletion fails, the user can re-sign-in and ask an admin to repair it.
      try { await user.delete(); } catch (_) { await _auth.signOut(); }
      rethrow;
    }
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> signOut() => _auth.signOut();
}

String friendlyError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'email-already-in-use': return 'That email is already registered.';
      case 'invalid-email': return 'Enter a valid email address.';
      case 'weak-password': return 'Use a stronger password (at least 6 characters).';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found': return 'Incorrect email or password.';
      case 'network-request-failed': return 'Network unavailable. Try again.';
    }
  }
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Permission denied by Firestore security rules.';
  }
  return 'Something went wrong: $error';
}
