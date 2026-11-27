import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/firebase_errors.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bio_app_bar.dart';

/// Verificación de asistencia por QR.
///
/// Las reglas de Firestore solo permiten al empleado actualizar su propio
/// documento y únicamente el campo `checkOut`, por lo que el administrador
/// aquí no escribe nada: valida el QR y muestra el estado del día.
class AdminQrScanScreen extends ConsumerStatefulWidget {
  const AdminQrScanScreen({super.key});
  @override
  ConsumerState<AdminQrScanScreen> createState() => _AdminQrScanScreenState();
}

class _AdminQrScanScreenState extends ConsumerState<AdminQrScanScreen> {
  bool _busy = false;
  String? _message;
  bool _success = false;
  String? _lastCode;

  Future<void> _handle(String? raw) async {
    final code = raw?.trim();
    if (_busy || code == null || code.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
      _lastCode = code;
    });
    try {
      final admin = await ref.read(currentProfileProvider.future);
      if (admin == null) throw Exception('Sin perfil de administrador.');

      final employee = await ref.read(userRepositoryProvider).getUser(code);
      if (employee == null) {
        throw Exception('El QR no corresponde a un empleado registrado.');
      }
      if (!employee.isActive) {
        throw Exception('${employee.fullName} está desactivado.');
      }
      if (admin.companyId.isNotEmpty &&
          employee.companyId.isNotEmpty &&
          employee.companyId != admin.companyId) {
        throw Exception('Ese empleado pertenece a otra empresa.');
      }

      final attendance = await ref
          .read(attendanceRepositoryProvider)
          .todayForUser(employee.uid);
      if (attendance == null) {
        throw Exception('${employee.fullName} aún no ha marcado su entrada hoy.');
      }

      setState(() {
        _success = true;
        _message = '${employee.fullName} · Entrada ${attendance.checkIn} · '
            '${attendance.status} · ${attendance.location}'
            '${attendance.hasCheckedOut ? ' · Salida ${attendance.checkOut}' : ''}';
      });
      if (mounted) {
        await _showResult(
          employee.fullName,
          employee.initials,
          attendance.checkIn,
          attendance.status,
          attendance.location,
        );
      }
    } catch (e) {
      setState(() {
        _success = false;
        _message = FirebaseErrors.message(e);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showResult(
    String name,
    String initials,
    String checkIn,
    String status,
    String location,
  ) async {
    final colors = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: BioColors.successGreen.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 40,
            color: BioColors.successGreen,
          ),
        ),
        title: const Text('Asistencia verificada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colors.primaryContainer,
              child: Text(
                initials,
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _ResultLine(label: 'Entrada', value: checkIn),
            _ResultLine(label: 'Estado', value: status),
            _ResultLine(label: 'Sede', value: location),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _message = null;
                _success = false;
                _lastCode = null;
              });
            },
            child: const Text('Escanear otro'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const BioAppBar(title: 'Escanear QR', fallbackRoute: '/admin'),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;
                    final value = barcodes.first.rawValue;
                    if (value != null && value != _lastCode) _handle(value);
                  },
                ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.primary, width: 3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                if (_busy)
                  const Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          if (_message != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: _success ? Colors.green.shade50 : colors.errorContainer,
              child: Row(
                children: [
                  Icon(
                    _success ? Icons.check_circle : Icons.error_outline,
                    color: _success ? Colors.green : colors.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _success ? Colors.green.shade900 : colors.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _message = null;
                          _success = false;
                          _lastCode = null;
                        }),
                icon: const Icon(Icons.refresh),
                label: const Text('Escanear de nuevo'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            '$label:',
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
