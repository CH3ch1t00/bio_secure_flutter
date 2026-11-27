import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sede_shift.dart';

class CompanyRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> companyDoc(String companyId) =>
      _db.collection('companies').doc(companyId);

  Future<Company?> getCompany(String companyId) async {
    if (companyId.isEmpty) return null;
    final snap = await companyDoc(companyId).get();
    if (!snap.exists) return null;
    return Company.fromMap(companyId, snap.data() ?? const {});
  }

  Stream<Company?> watchCompany(String companyId) {
    if (companyId.isEmpty) return Stream.value(null);
    return companyDoc(companyId).snapshots().map(
          (s) => s.exists ? Company.fromMap(companyId, s.data() ?? const {}) : null,
        );
  }

  /// Las reglas de Firestore solo permiten al admin modificar `name`,
  /// `horaEntrada` y `toleranciaMin` en `companies/{companyId}`. La creación y
  /// el borrado de empresas están deshabilitados desde el cliente.
  Future<void> updateCompany({
    required String companyId,
    required String name,
    required String horaEntrada,
    required int toleranciaMin,
  }) =>
      companyDoc(companyId).update({
        'name': name,
        'horaEntrada': horaEntrada,
        'toleranciaMin': toleranciaMin,
      });
}
