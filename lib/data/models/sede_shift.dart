class Sede {
  final String id;
  final String nombre;
  final double lat;
  final double lng;
  final int radioMetros;
  final bool activa;

  Sede({
    required this.id,
    required this.nombre,
    required this.lat,
    required this.lng,
    this.radioMetros = 100,
    this.activa = true,
  });

  factory Sede.fromMap(String id, Map<String, dynamic> m) => Sede(
        id: id,
        nombre: (m['nombre'] as String?) ?? '',
        lat: (m['lat'] as num?)?.toDouble() ?? 0,
        lng: (m['lng'] as num?)?.toDouble() ?? 0,
        radioMetros: (m['radioMetros'] as num?)?.toInt() ?? 100,
        activa: (m['activa'] as bool?) ?? true,
      );

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'lat': lat,
        'lng': lng,
        'radioMetros': radioMetros,
        'activa': activa,
      };
}

class Shift {
  final String id;
  final String name;
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final int toleranceMin;

  Shift({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.toleranceMin = 5,
  });

  factory Shift.fromMap(String id, Map<String, dynamic> m) => Shift(
        id: id,
        name: (m['name'] as String?) ?? '',
        startTime: (m['startTime'] as String?) ?? (m['checkInStart'] as String?) ?? '',
        endTime: (m['endTime'] as String?) ?? (m['checkInEnd'] as String?) ?? '',
        toleranceMin: (m['toleranceMin'] as num?)?.toInt() ?? 5,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'startTime': startTime,
        'endTime': endTime,
        'toleranceMin': toleranceMin,
      };
}

class Company {
  final String id;
  final String name;
  final String horaEntrada;
  final int toleranciaMin;
  final String timezone;

  Company({
    required this.id,
    this.name = '',
    this.horaEntrada = '08:00',
    this.toleranciaMin = 10,
    this.timezone = 'UTC-5',
  });

  factory Company.fromMap(String id, Map<String, dynamic> m) => Company(
        id: id,
        name: (m['name'] as String?) ?? '',
        horaEntrada: (m['horaEntrada'] as String?) ?? '08:00',
        toleranciaMin: (m['toleranciaMin'] as num?)?.toInt() ?? 10,
        timezone: (m['timezone'] as String?) ?? 'UTC-5',
      );
}
