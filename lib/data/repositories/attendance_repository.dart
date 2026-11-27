import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/attendance.dart';
import '../models/user.dart';

/// Excepción de negocio con mensaje listo para mostrar al usuario.
class AttendanceException implements Exception {
  final String message;
  AttendanceException(this.message);
  @override
  String toString() => message;
}

class AttendanceRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('attendances');

  // ---------------------------------------------------------------------------
  // Lecturas en tiempo real
  // ---------------------------------------------------------------------------

  Stream<List<Attendance>> watchToday(String companyId) {
    final today = _today();
    return _col
        .where('companyId', isEqualTo: companyId)
        .where('date', isEqualTo: today)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => Attendance.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => b.checkIn.compareTo(a.checkIn));
      return list;
    });
  }

  Stream<List<Attendance>> watchAll(String companyId) {
    return _col.where('companyId', isEqualTo: companyId).snapshots().map((s) {
      final list = s.docs.map((d) => Attendance.fromMap(d.id, d.data())).toList();
      list.sort(_byDateDesc);
      return list;
    });
  }

  Stream<List<Attendance>> watchByUser(String userId) {
    return _col.where('userId', isEqualTo: userId).snapshots().map((s) {
      final list = s.docs.map((d) => Attendance.fromMap(d.id, d.data())).toList();
      list.sort(_byDateDesc);
      return list;
    });
  }

  Stream<Attendance?> watchTodayForUser(String userId) {
    final today = _today();
    return _col
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: today)
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isEmpty ? null : Attendance.fromMap(s.docs.first.id, s.docs.first.data()));
  }

  Future<Attendance?> todayForUser(String userId) async {
    final snap = await _col
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: _today())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Attendance.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  // ---------------------------------------------------------------------------
  // Escritura (schema compatible con firestore.rules)
  // ---------------------------------------------------------------------------

  /// Registra el check-in del empleado con todos los campos que validan las
  /// reglas de Firestore. Calcula el estado (PUNTUAL/TARDANZA) usando el turno
  /// asignado y, si no existe, la hora de entrada de la empresa.
  Future<Attendance> registerCheckIn({
    required BioUser user,
    required double latitude,
    required double longitude,
    required double accuracy,
    String type = 'HUELLA',
    bool isMock = false,
    Future<void> Function()? confirm,
  }) async {
    if (user.companyId.isEmpty) {
      throw AttendanceException(
        'Tu perfil no tiene empresa asignada. Contacta al administrador.',
      );
    }
    if (user.sedeId == null || user.sedeId!.isEmpty) {
      throw AttendanceException(
        'Tu perfil no tiene sede asignada. Contacta al administrador.',
      );
    }
    if (accuracy < 0 || accuracy > 50) {
      throw AttendanceException(
        'GPS con baja precisión (${accuracy.toStringAsFixed(1)} m). '
        'Sal al aire libre e inténtalo de nuevo.',
      );
    }

    final existing = await todayForUser(user.uid);
    if (existing != null) {
      throw AttendanceException('Ya registraste tu entrada hoy a las ${existing.checkIn}.');
    }

    final now = DateTime.now();
    final date = DateFormat('dd/MM/yyyy').format(now);
    final checkIn = DateFormat('HH:mm').format(now);
    final docId = '${user.uid}_${DateFormat('yyyyMMdd').format(now)}';

    final sede = await _sede(user.companyId, user.sedeId!);
    final distance = _distanceMeters(latitude, longitude, sede?.lat, sede?.lng);

    if (sede != null && sede.lat != null && sede.lng != null) {
      if (distance > sede.radioMetros) {
        throw AttendanceException(
          'Estás a $distance m de ${sede.nombre} (máximo ${sede.radioMetros} m). '
          'Acércate a la sede para marcar.',
        );
      }
    }

    final status = await _computeStatus(user, now);

    // La biometría se pide al final, cuando ya validamos GPS, sede y duplicados.
    await confirm?.call();

    final attendance = Attendance(
      id: docId,
      userId: user.uid,
      companyId: user.companyId,
      sedeId: user.sedeId!,
      userName: user.fullName,
      date: date,
      checkIn: checkIn,
      checkOut: '',
      status: status,
      type: type,
      location: sede?.nombre ?? 'Sede',
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      distanceMeters: distance,
      requestId: const Uuid().v4(),
      marcadoPor: user.uid,
      clientMockFlag: isMock,
    );

    await _col.doc(docId).set({
      ...attendance.toCreateMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return attendance;
  }

  Future<void> registerCheckOut(String docId) async {
    await _col.doc(docId).update({
      'checkOut': DateFormat('HH:mm').format(DateTime.now()),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createAttendance(Attendance a) async {
    final id = a.id.isNotEmpty
        ? a.id
        : '${a.userId}_${a.date.replaceAll('/', '')}';
    await _col.doc(id).set({
      ...a.toCreateMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCheckOut(String id, String checkOut) async {
    await _col.doc(id).update({
      'checkOut': checkOut,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _today() => DateFormat('dd/MM/yyyy').format(DateTime.now());

  int _byDateDesc(Attendance a, Attendance b) {
    final cmp = _dateKey(b.date).compareTo(_dateKey(a.date));
    return cmp != 0 ? cmp : b.checkIn.compareTo(a.checkIn);
  }

  String _dateKey(String date) {
    final p = date.split('/');
    if (p.length != 3) return date;
    return '${p[2]}${p[1].padLeft(2, '0')}${p[0].padLeft(2, '0')}';
  }

  Future<String> _computeStatus(BioUser user, DateTime now) async {
    final minutes = now.hour * 60 + now.minute;

    int? start;
    int tolerance = 0;

    try {
      if ((user.shiftId ?? '').isNotEmpty && user.companyId.isNotEmpty) {
        final shift = await _db
            .collection('companies')
            .doc(user.companyId)
            .collection('shifts')
            .doc(user.shiftId)
            .get();
        if (shift.exists) {
          start = _hhmm(shift.data()?['startTime']);
          tolerance = ((shift.data()?['toleranceMin'] as num?) ?? 0).toInt();
        }
      }
    } catch (_) {}

    if (start == null && user.companyId.isNotEmpty) {
      try {
        final company = await _db.collection('companies').doc(user.companyId).get();
        if (company.exists) {
          start = _hhmm(company.data()?['horaEntrada']);
          tolerance = ((company.data()?['toleranciaMin'] as num?) ?? 0).toInt();
        }
      } catch (_) {}
    }

    if (start == null) return 'PUNTUAL';
    return minutes <= start + tolerance ? 'PUNTUAL' : 'TARDANZA';
  }

  int? _hhmm(Object? value) {
    if (value is! String) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  Future<_SedeInfo?> _sede(String companyId, String sedeId) async {
    if (companyId.isEmpty || sedeId.isEmpty) return null;
    try {
      final doc = await _db
          .collection('companies')
          .doc(companyId)
          .collection('sedes')
          .doc(sedeId)
          .get();
      final data = doc.data();
      if (data == null) return null;
      final name = (data['nombre'] as String?)?.trim();
      return _SedeInfo(
        nombre: (name == null || name.isEmpty) ? 'Sede' : name,
        lat: (data['lat'] as num?)?.toDouble(),
        lng: (data['lng'] as num?)?.toDouble(),
        radioMetros: ((data['radioMetros'] as num?) ?? 100).toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  int _distanceMeters(double lat, double lng, double? sedeLat, double? sedeLng) {
    if (sedeLat == null || sedeLng == null) return 0;
    const earth = 6371000.0;
    final dLat = _rad(sedeLat - lat);
    final dLng = _rad(sedeLng - lng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat)) *
            math.cos(_rad(sedeLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return (earth * c).round();
  }

  double _rad(double deg) => deg * math.pi / 180.0;
}

class _SedeInfo {
  final String nombre;
  final double? lat;
  final double? lng;
  final int radioMetros;
  _SedeInfo({
    required this.nombre,
    required this.lat,
    required this.lng,
    required this.radioMetros,
  });
}
