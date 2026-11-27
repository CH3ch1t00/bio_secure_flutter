import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/attendance.dart';
import '../data/models/sede_shift.dart';
import '../data/models/user.dart';
import '../data/repositories/attendance_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/company_repository.dart';
import '../data/repositories/sede_shift_repository.dart';
import '../data/repositories/user_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());
final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepository());
final attendanceRepositoryProvider =
    Provider<AttendanceRepository>((ref) => AttendanceRepository());
final sedeRepositoryProvider = Provider<SedeRepository>((ref) => SedeRepository());
final shiftRepositoryProvider = Provider<ShiftRepository>((ref) => ShiftRepository());
final companyRepositoryProvider = Provider<CompanyRepository>((ref) => CompanyRepository());

final authStateProvider = StreamProvider((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentProfileProvider = FutureProvider<BioUser?>((ref) async {
  final auth = await ref.watch(authStateProvider.future);
  if (auth == null) return null;
  return ref.watch(userRepositoryProvider).getUser(auth.uid);
});

final companyProvider = FutureProvider<Company?>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null || profile.companyId.isEmpty) return null;
  return ref.watch(companyRepositoryProvider).getCompany(profile.companyId);
});

final employeesProvider = StreamProvider<List<BioUser>>((ref) {
  final profile = ref.watch(currentProfileProvider).value;
  if (profile == null) return Stream.value(const []);
  return ref.watch(userRepositoryProvider).watchEmployees(profile.companyId);
});

final todayAttendanceProvider = StreamProvider<Attendance?>((ref) {
  final profile = ref.watch(currentProfileProvider).value;
  if (profile == null) return Stream.value(null);
  return ref.watch(attendanceRepositoryProvider).watchTodayForUser(profile.uid);
});

/// Registros de hoy de toda la empresa (para el panel del administrador).
final companyTodayAttendanceProvider = StreamProvider<List<Attendance>>((ref) {
  final profile = ref.watch(currentProfileProvider).value;
  if (profile == null || profile.companyId.isEmpty) {
    return Stream.value(const <Attendance>[]);
  }
  return ref.watch(attendanceRepositoryProvider).watchToday(profile.companyId);
});

/// Historial completo del empleado actual (para rendimiento semanal).
final employeeHistoryProvider = StreamProvider<List<Attendance>>((ref) {
  final profile = ref.watch(currentProfileProvider).value;
  if (profile == null) return Stream.value(const <Attendance>[]);
  return ref.watch(attendanceRepositoryProvider).watchByUser(profile.uid);
});

/// Historial completo de la empresa (para gráfico semanal del admin).
final companyHistoryProvider = StreamProvider<List<Attendance>>((ref) {
  final profile = ref.watch(currentProfileProvider).value;
  if (profile == null || profile.companyId.isEmpty) {
    return Stream.value(const <Attendance>[]);
  }
  return ref.watch(attendanceRepositoryProvider).watchAll(profile.companyId);
});

final sedesProvider = StreamProvider<List<Sede>>((ref) {
  final profile = ref.watch(currentProfileProvider).value;
  if (profile == null || profile.companyId.isEmpty) return Stream.value(const []);
  return ref.watch(sedeRepositoryProvider).watchSedes(profile.companyId);
});

final shiftsProvider = StreamProvider<List<Shift>>((ref) {
  final profile = ref.watch(currentProfileProvider).value;
  if (profile == null || profile.companyId.isEmpty) return Stream.value(const []);
  return ref.watch(shiftRepositoryProvider).watchShifts(profile.companyId);
});

/// Modo de tema (claro/oscuro/sistema) con persistencia simple.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString('theme_mode') ?? 'system';
    state = _fromString(v);
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', _toString(mode));
  }

  static ThemeMode _fromString(String v) {
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ThemeModeNotifier());
