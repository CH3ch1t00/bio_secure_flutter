import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user.dart';

class UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  DocumentReference<Map<String, dynamic>> userDoc(String uid) => _users.doc(uid);

  Future<BioUser?> getUser(String uid) async {
    final snap = await userDoc(uid).get();
    if (!snap.exists) return null;
    return BioUser.fromMap(uid, snap.data() ?? const {});
  }

  Stream<BioUser?> watchUser(String uid) => userDoc(uid).snapshots().map(
        (s) => s.exists ? BioUser.fromMap(uid, s.data() ?? const {}) : null,
      );

  Stream<List<BioUser>> watchEmployees(String companyId) {
    Query<Map<String, dynamic>> q = _users.where('role', isEqualTo: 'employee');
    if (companyId.isNotEmpty) {
      q = q.where('companyId', isEqualTo: companyId);
    }
    return q.snapshots().map(
          (s) => s.docs
              .map((d) => BioUser.fromMap(d.id, d.data()))
              .toList()
            ..sort((a, b) => a.fullName.compareTo(b.fullName)),
        );
  }

  Future<List<BioUser>> getEmployees(String companyId) async {
    Query<Map<String, dynamic>> q = _users.where('role', isEqualTo: 'employee');
    if (companyId.isNotEmpty) {
      q = q.where('companyId', isEqualTo: companyId);
    }
    final snap = await q.get();
    return snap.docs.map((d) => BioUser.fromMap(d.id, d.data())).toList();
  }

  Future<void> createUser(BioUser user) =>
      userDoc(user.uid).set(user.toMap(), SetOptions(merge: true));

  Future<void> updateUser(String uid, Map<String, dynamic> data) =>
      userDoc(uid).update(data);

  /// Las reglas solo permiten al propio usuario cambiar `phone`, `image` y
  /// `fcmToken`; el resto de campos los administra un admin.
  Future<void> updateProfile(BioUser user) => userDoc(user.uid).update({
        'phone': user.phone,
        'image': user.image,
        'fcmToken': user.fcmToken,
      });

  Future<void> setActive(String uid, bool isActive) =>
      updateUser(uid, {'isActive': isActive});

  Future<void> assignShift(String uid, String shiftId) =>
      updateUser(uid, {'shiftId': shiftId});

  Future<void> assignSede(String uid, String sedeId) =>
      updateUser(uid, {'sedeId': sedeId});

  Future<void> deleteUser(String uid) => userDoc(uid).delete();

  /// Crea automáticamente el perfil de un usuario de Google que entra por
  /// primera vez (las reglas permiten el auto-registro con role 'employee').
  /// El perfil queda sin empresa ni sede: un administrador debe asignarlas.
  Future<BioUser> ensureProfileFromAuth(User authUser) async {
    final existing = await getUser(authUser.uid);
    if (existing != null) return existing;

    final display = (authUser.displayName ?? '').trim();
    final parts = display.isEmpty ? <String>[] : display.split(RegExp(r'\s+'));
    final user = BioUser(
      uid: authUser.uid,
      firstName: parts.isNotEmpty ? parts.first : '',
      lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
      email: authUser.email ?? '',
      image: authUser.photoURL,
      role: 'employee',
      companyId: '',
    );
    await createUser(user);
    return user;
  }
}
