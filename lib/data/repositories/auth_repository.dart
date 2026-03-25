import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pedidosapp/data/field_keys.dart';
import 'package:pedidosapp/data/firestore_collections.dart';

/// Acceso a Firebase Auth y documento de usuario en Firestore.
/// Las pantallas llaman aquí en lugar de usar [FirebaseAuth] / [FirebaseFirestore] directo.
class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  FirebaseApp get firebaseApp => _auth.app;

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  Future<User?> reloadAuthenticatedUser(User user) async {
    await user.reload();
    return _auth.currentUser;
  }

  /// Rol en `users/{uid}`; por defecto `client`.
  Future<String> getRoleForUid(String uid) async {
    final doc =
        await _firestore.collection(FirestoreCollections.users).doc(uid).get();
    if (!doc.exists || doc.data() == null) return 'client';
    final data = doc.data()!;
    return (data[FirestoreFields.role] as String?) ?? 'client';
  }

  Future<void> createClientProfile({
    required String uid,
    required String email,
  }) {
    return _firestore.collection(FirestoreCollections.users).doc(uid).set({
      FirestoreFields.email: email,
      FirestoreFields.role: 'client',
      FirestoreFields.createdAt: FieldValue.serverTimestamp(),
    });
  }

  void setLanguageCode(String languageCode) {
    _auth.setLanguageCode(languageCode);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    setLanguageCode('es');
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> sendEmailVerification(User user) async {
    setLanguageCode('es');
    await user.sendEmailVerification();
  }
}
