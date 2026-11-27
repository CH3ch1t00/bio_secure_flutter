import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_dashboard.dart';
import '../features/admin/admin_qr_scan_screen.dart';
import '../features/admin/confirmation_screen.dart';
import '../features/admin/company_settings_screen.dart';
import '../features/admin/employees_screen.dart';
import '../features/admin/history_screen.dart';
import '../features/admin/register_employee_screen.dart';
import '../features/admin/sedes_screen.dart';
import '../features/admin/shifts_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/employee/employee_dashboard.dart';
import '../features/employee/enroll_screen.dart';
import '../features/employee/history_screen.dart';
import '../features/employee/qr_screen.dart';
import '../features/employee/scan_screen.dart';
import '../features/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminDashboard()),
      GoRoute(path: '/admin/employees', builder: (_, __) => const EmployeesScreen()),
      GoRoute(path: '/admin/register', builder: (_, __) => const RegisterEmployeeScreen()),
      GoRoute(path: '/admin/sedes', builder: (_, __) => const SedesScreen()),
      GoRoute(path: '/admin/shifts', builder: (_, __) => const ShiftsScreen()),
      GoRoute(path: '/admin/history', builder: (_, __) => const AdminHistoryScreen()),
      GoRoute(path: '/admin/qr-scan', builder: (_, __) => const AdminQrScanScreen()),
      GoRoute(path: '/admin/confirmation', builder: (_, __) => const ConfirmationScreen()),
      GoRoute(path: '/admin/company', builder: (_, __) => const CompanySettingsScreen()),
      GoRoute(path: '/employee', builder: (_, __) => const EmployeeDashboard()),
      GoRoute(path: '/employee/scan', builder: (_, __) => const ScanScreen()),
      GoRoute(path: '/employee/qr', builder: (_, __) => const QrScreen()),
      GoRoute(path: '/employee/history', builder: (_, __) => const EmployeeHistoryScreen()),
      GoRoute(path: '/employee/enroll', builder: (_, __) => const EnrollScreen()),
      GoRoute(path: '/employee/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
});
