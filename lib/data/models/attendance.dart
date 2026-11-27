class Attendance {
  final String id;
  final String userId;
  final String companyId;
  final String sedeId;
  final String userName;
  final String? userImage;
  final String date; // dd/MM/yyyy
  final String checkIn; // HH:mm
  final String checkOut; // HH:mm | ''
  final String status; // PUNTUAL | TARDANZA | ...
  final String type; // HUELLA | FACIAL | QR
  final String location;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final int? distanceMeters;
  final String? requestId;
  final String? marcadoPor;
  final bool clientMockFlag;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Attendance({
    required this.id,
    required this.userId,
    required this.companyId,
    this.sedeId = '',
    required this.userName,
    this.userImage,
    required this.date,
    required this.checkIn,
    this.checkOut = '',
    this.status = 'PUNTUAL',
    this.type = 'HUELLA',
    this.location = '',
    this.latitude,
    this.longitude,
    this.accuracy,
    this.distanceMeters,
    this.requestId,
    this.marcadoPor,
    this.clientMockFlag = false,
    this.createdAt,
    this.updatedAt,
  });

  bool get hasCheckedOut => checkOut.trim().isNotEmpty;

  factory Attendance.fromMap(String id, Map<String, dynamic> m) => Attendance(
        id: id,
        userId: m['userId'] ?? '',
        companyId: m['companyId'] ?? '',
        sedeId: m['sedeId'] ?? '',
        userName: m['userName'] ?? 'Empleado',
        userImage: m['userImage'],
        date: m['date'] ?? '',
        checkIn: m['checkIn'] ?? '',
        checkOut: (m['checkOut'] as String?) ?? '',
        status: (m['status'] as String?) ?? 'PUNTUAL',
        type: (m['type'] as String?) ?? 'HUELLA',
        location: (m['location'] as String?) ??
            (m['locationName'] as String?) ??
            (m['sedeName'] as String?) ??
            '',
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
        accuracy: (m['accuracy'] as num?)?.toDouble(),
        distanceMeters: (m['distanceMeters'] as num?)?.toInt(),
        requestId: m['requestId'] as String?,
        marcadoPor: m['marcadoPor'] as String?,
        clientMockFlag: (m['clientMockFlag'] as bool?) ?? false,
        createdAt: _toDate(m['createdAt']),
        updatedAt: _toDate(m['updatedAt']),
      );

  /// Mapa completo que cumple el esquema validado por `firestore.rules`.
  /// Los timestamps se añaden en el repositorio con `FieldValue.serverTimestamp()`.
  Map<String, dynamic> toCreateMap() => {
        'userId': userId,
        'companyId': companyId,
        'sedeId': sedeId,
        'userName': userName.isEmpty ? 'Empleado' : userName,
        'date': date,
        'checkIn': checkIn,
        'checkOut': checkOut,
        'status': status,
        'type': type,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'distanceMeters': distanceMeters,
        'requestId': requestId,
        'marcadoPor': marcadoPor ?? userId,
        'clientMockFlag': clientMockFlag,
      };

  static DateTime? _toDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      final dynamic v = value;
      return v.toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }
}
