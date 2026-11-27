import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/bio_bottom_bar.dart';

/// Pantalla de confirmación de asistencia (admin) estilo original.
class ConfirmationScreen extends ConsumerWidget {
  const ConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmación')),
      bottomNavigationBar:
          const BioBottomBar(isAdmin: true, currentRoute: '/admin'),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: BioColors.successGreen.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 60,
                  color: BioColors.successGreen,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Asistencia confirmada',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'El registro del empleado fue verificado correctamente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _Line(
                        icon: Icons.verified_user_outlined,
                        label: 'Validación',
                        value: 'QR verificado',
                      ),
                      Divider(height: 18),
                      _Line(
                        icon: Icons.cloud_done_outlined,
                        label: 'Registro',
                        value: 'Sincronizado',
                      ),
                      Divider(height: 18),
                      _Line(
                        icon: Icons.lock_outline,
                        label: 'Seguridad',
                        value: 'Datos protegidos',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/admin/qr-scan'),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear otro empleado'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/admin'),
                child: const Text('Volver al panel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: colors.onSurfaceVariant)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
