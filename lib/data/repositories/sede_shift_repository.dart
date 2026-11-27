import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sede_shift.dart';

class SedeRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String companyId) =>
      _db.collection('companies').doc(companyId).collection('sedes');

  Stream<List<Sede>> watchSedes(String companyId) => _col(companyId)
      .snapshots()
      .map((s) {
    final list = s.docs.map((d) => Sede.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return list;
  });

  Future<void> upsert(String companyId, Sede sede) async {
    final data = {
      ...sede.toMap(),
      if (sede.id.isEmpty) 'creadaEn': FieldValue.serverTimestamp(),
    };
    if (sede.id.isEmpty) {
      await _col(companyId).add(data);
    } else {
      await _col(companyId).doc(sede.id).set(data, SetOptions(merge: true));
    }
  }

  Future<void> delete(String companyId, String id) =>
      _col(companyId).doc(id).delete();
}

class ShiftRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String companyId) =>
      _db.collection('companies').doc(companyId).collection('shifts');

  Stream<List<Shift>> watchShifts(String companyId) => _col(companyId)
      .snapshots()
      .map((s) {
    final list = s.docs.map((d) => Shift.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => a.startTime.compareTo(b.startTime));
    return list;
  });

  Future<void> upsert(String companyId, Shift shift) async {
    final data = shift.toMap();
    if (shift.id.isEmpty) {
      await _col(companyId).add(data);
    } else {
      await _col(companyId).doc(shift.id).set(data, SetOptions(merge: true));
    }
  }

  Future<void> delete(String companyId, String id) =>
      _col(companyId).doc(id).delete();
}
