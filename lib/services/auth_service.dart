import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Email/password authentication and Firestore user profile bootstrap.
class AuthService {
  static const String defaultAdminUid = 'I4SDf49xt1gwaySstJy9QWQOnuA3';

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    String? adminUid,
  }) : _adminUid =
           (adminUid ??
                   const String.fromEnvironment(
                     'ADMIN_UID',
                     defaultValue: defaultAdminUid,
                   ))
               .trim(),
    _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final String _adminUid;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// UID מוגדר ב־`ADMIN_UID` / ברירת מחדל (ללא רווחים).
  String get configuredAdminUid => _adminUid;

  /// האם [uid] הוא אדמין "קשיח" (לא תלוי ב־Firestore `isAdmin`).
  bool matchesConfiguredAdminUid(String? uid) {
    return uid != null && _adminUid.isNotEmpty && uid == _adminUid;
  }

  bool isAdmin() => matchesConfiguredAdminUid(_auth.currentUser?.uid);

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Creates the auth user, then a `users/{uid}` document. Rolls back auth if Firestore fails.
  Future<void> signUp({required String email, required String password}) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      return;
    }
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      await user.delete();
      rethrow;
    } catch (_) {
      await user.delete();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
