import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/firebase_errors.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bio_bottom_bar.dart';
import '../../data/models/attendance.dart';

class EmployeeDashboard extends ConsumerWidget {
  const EmployeeDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      bottomNavigationBar:
          const BioBottomBar(isAdmin: false, currentRoute: '/employee'),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(FirebaseErrors.message(e))),
        data: (u) {
          if (u == null) {
            return const Center(child: Text('Sin perfil de usuario.'));
          }
          final today = ref.watch(todayAttendanceProvider);
          final history = ref.watch(employeeHistoryProvider);
          final companyName = ref.watch(companyProvider).value?.name;
          final dateText = _capitalize(
            DateFormat("EEEE, d 'de' MMMM", 'es').format(DateTime.now()),
          );

          return SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(currentProfileProvider);
                ref.invalidate(todayAttendanceProvider);
                ref.invalidate(employeeHistoryProvider);
                ref.invalidate(companyProvider);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // Encabezado: saludo + fecha + avatar.
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hola, ${u.fullName}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateText,
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => context.push('/employee/settings'),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: colors.primary,
                          child: Text(
                            u.initials,
                            style: TextStyle(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Empresa asignada.
                  Row(
                    children: [
                      Icon(Icons.business_outlined,
                          size: 16, color: colors.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          u.companyId.isEmpty
                              ? 'Sin empresa asignada: contacta al administrador'
                              : 'Empresa: ${(companyName == null || companyName.isEmpty) ? u.companyId : companyName}',
                          style: TextStyle(
                              color: colors.onSurfaceVariant, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  if (u.companyId.isEmpty) ...[
                    const SizedBox(height: 12),
                    const _WarningCard(
                      icon: Icons.info_outline,
                      text:
                          'Tu perfil todavía no está vinculado a una empresa. '
                          'El administrador debe asignarte empresa, sede y turno.',
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Estado de hoy.
                  Text(
                    'ESTADO DE HOY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  today.when(
                    loading: () => const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (e, _) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          FirebaseErrors.message(e),
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    ),
                    data: (a) => _TodayCard(attendance: a),
                  ),
                  const SizedBox(height: 20),

                  // Rendimiento semanal.
                  history.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (list) => _WeeklyCard(records: list),
                  ),
                  const SizedBox(height: 20),

                  // Acciones rápidas.
                  Text(
                    'ACCIONES RÁPIDAS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.7,
                    children: [
                      _ActionTile(
                        label: 'Marcar asistencia',
                        icon: Icons.fingerprint,
                        onTap: () => context.push('/employee/scan'),
                      ),
                      _ActionTile(
                        label: 'Enrolar rostro',
                        icon: Icons.face_retouching_natural,
                        onTap: () => context.push('/employee/enroll'),
                      ),
                      _ActionTile(
                        label: 'Mi QR',
                        icon: Icons.qr_code_2,
                        onTap: () => context.push('/employee/qr'),
                      ),
                      _ActionTile(
                        label: 'Historial',
                        icon: Icons.history,
                        onTap: () => context.push('/employee/history'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.invalidate(todayAttendanceProvider);
                      ref.invalidate(employeeHistoryProvider);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar estado'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.attendance});
  final Attendance? attendance;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final a = attendance;

    final (String emoji, Color color, String title, String subtitle) = switch (a) {
      null => (
          '📋',
          colors.onSurfaceVariant,
          'Sin registro aún',
          'Ve a Escaneo para registrar tu asistencia',
        ),
      Attendance(hasCheckedOut: true, :final checkIn, :final checkOut) => (
          '✅',
          BioColors.successGreen,
          'Jornada completada',
          'Entrada $checkIn · Salida $checkOut',
        ),
      Attendance(:final status, :final checkIn, :final location)
          when status == 'TARDANZA' =>
        (
          '⏳',
          BioColors.warnOrange,
          'Pendiente de confirmación',
          'Registrado a las $checkIn${location.isEmpty ? '' : ' · $location'}',
        ),
      Attendance(:final status) when status == 'INASISTENCIA' || status == 'FALLIDO' => (
          '🚫',
          BioColors.errorRed,
          'Inasistencia registrada',
          'Contacta a tu administrador',
        ),
      Attendance(:final checkIn, :final status, :final location) => (
          '✅',
          BioColors.successGreen,
          'Asistencia confirmada hoy',
          'Entrada registrada: $checkIn'
              '${status.isEmpty ? '' : ' · $status'}'
              '${location.isEmpty ? '' : ' · $location'}',
        ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                        color: colors.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({required this.records});
  final List<Attendance> records;

  static const _labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: (now.weekday - 1)));
    final fmt = DateFormat('dd/MM/yyyy');

    final days = List.generate(7, (i) {
      final d = monday.add(Duration(days: i));
      final dateStr = fmt.format(d);
      Attendance? rec;
      for (final r in records) {
        if (r.date == dateStr) {
          rec = r;
          break;
        }
      }
      final isFuture = d.isAfter(DateTime(now.year, now.month, now.day));
      return (label: _labels[i], rec: rec, isFuture: isFuture);
    });

    var confirmed = 0;
    for (final d in days) {
      final s = d.rec?.status;
      if (s == 'PUNTUAL' || s == 'EXITOSO') confirmed++;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rendimiento de esta semana',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final d in days) _dayDot(context, d.rec, d.isFuture, d.label),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '$confirmed / 7 días con asistencia confirmada',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayDot(
      BuildContext context, Attendance? rec, bool isFuture, String label) {
    final colors = Theme.of(context).colorScheme;
    Color bg;
    Color fg;
    String mark;
    if (rec == null || isFuture) {
      bg = colors.onSurface.withValues(alpha: 0.10);
      fg = colors.onSurface.withValues(alpha: 0.40);
      mark = '';
    } else if (rec.status == 'PUNTUAL' || rec.status == 'EXITOSO') {
      bg = BioColors.successGreen.withValues(alpha: 0.18);
      fg = BioColors.successGreen;
      mark = '✓';
    } else if (rec.status == 'TARDANZA') {
      bg = BioColors.warnOrange.withValues(alpha: 0.18);
      fg = BioColors.warnOrange;
      mark = '!';
    } else {
      bg = BioColors.errorRed.withValues(alpha: 0.18);
      fg = BioColors.errorRed;
      mark = '✗';
    }
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            mark,
            style: TextStyle(
                color: fg, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: colors.onErrorContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colors.onSecondaryContainer, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
