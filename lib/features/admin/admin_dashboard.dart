import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/firebase_errors.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bio_bottom_bar.dart';
import '../../data/models/attendance.dart';
import '../../data/models/sede_shift.dart';
import '../../data/models/user.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  String? _sedeId; // null = todas las sedes
  String _audit = 'ALL'; // ALL | PUNTUAL | TARDANZA | SIN

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      bottomNavigationBar:
          const BioBottomBar(isAdmin: true, currentRoute: '/admin'),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(message: FirebaseErrors.message(e)),
        data: (u) {
          if (u == null) {
            return const _ErrorView(message: 'Sin perfil de administrador.');
          }
          if (u.companyId.isEmpty) {
            return const _ErrorView(
              message: 'Tu perfil no tiene companyId. Configúralo en Firestore.',
            );
          }

          final employees = ref.watch(employeesProvider);
          final today = ref.watch(companyTodayAttendanceProvider);
          final history = ref.watch(companyHistoryProvider);
          final companyName = ref.watch(companyProvider).value?.name;
          final sedes = ref.watch(sedesProvider).value ?? const <Sede>[];

          final all = today.value ?? const <Attendance>[];
          final list = _sedeId == null
              ? all
              : all.where((a) => a.sedeId == _sedeId).toList();
          final staff = employees.value ?? const <BioUser>[];
          final staffFiltered = _sedeId == null
              ? staff
              : staff.where((e) => e.sedeId == _sedeId).toList();

          final employeesCount = staffFiltered.length;
          final present = list.length;
          final late = list.where((a) => a.status == 'TARDANZA').length;
          final onTime = list
              .where((a) => a.status == 'PUNTUAL' || a.status == 'EXITOSO')
              .length;
          final finished = list.where((a) => a.hasCheckedOut).length;
          final markedIds = list.map((a) => a.userId).toSet();
          final absent = staffFiltered
              .where((e) => e.isActive && !markedIds.contains(e.uid))
              .toList();
          final dateText = _capitalize(
            DateFormat("EEEE, d 'de' MMMM", 'es').format(DateTime.now()),
          );

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentProfileProvider);
              ref.invalidate(employeesProvider);
              ref.invalidate(companyTodayAttendanceProvider);
              ref.invalidate(companyHistoryProvider);
              ref.invalidate(companyProvider);
              ref.invalidate(sedesProvider);
            },
            child: SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // Encabezado verde con saludo, empresa y fecha.
                  _Header(
                    name: u.fullName,
                    initials: u.initials,
                    company: (companyName == null || companyName.isEmpty)
                        ? u.companyId
                        : companyName,
                    date: dateText,
                    alerts: late + absent.length,
                    onAlerts: () => _showAlerts(
                      context,
                      late: late,
                      absent: absent,
                    ),
                    onLogout: () async {
                      await ref.read(authRepositoryProvider).signOut();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                  const SizedBox(height: 18),

                  // Filtro por sede (como "Todas las Sedes" del original).
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Resumen de hoy',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      _SedeSelector(
                        sedes: sedes,
                        value: _sedeId,
                        onChanged: (v) => setState(() => _sedeId = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Empleados',
                          value: '$employeesCount',
                          icon: Icons.groups_rounded,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          label: 'Asistieron',
                          value: '$present',
                          icon: Icons.how_to_reg_rounded,
                          color: BioColors.successGreen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          label: 'Tardanzas',
                          value: '$late',
                          icon: Icons.warning_amber_rounded,
                          color: BioColors.warnOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _MiniMetric(
                            label: 'Puntuales',
                            value: '$onTime',
                            color: BioColors.successGreen,
                          ),
                          _MiniDivider(),
                          _MiniMetric(
                            label: 'Sin registro',
                            value: '${absent.length}',
                            color: BioColors.errorRed,
                          ),
                          _MiniDivider(),
                          _MiniMetric(
                            label: 'Con salida',
                            value: '$finished',
                            color: colors.secondary,
                          ),
                          _MiniDivider(),
                          _MiniMetric(
                            label: 'Total',
                            value: '${list.length}',
                            color: colors.onSurface,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (late + absent.length > 0) ...[
                    _AlertBanner(
                      late: late,
                      absent: absent.length,
                      onTap: () => _showAlerts(
                        context,
                        late: late,
                        absent: absent,
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  _WeeklyChartCard(
                    records: history.value ?? const <Attendance>[],
                    sedeId: _sedeId,
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'ACCIONES RÁPIDAS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.92,
                    children: const [
                      _QuickAction(
                        label: 'Empleados',
                        icon: Icons.people_alt_outlined,
                        route: '/admin/employees',
                      ),
                      _QuickAction(
                        label: 'Registrar',
                        icon: Icons.person_add_alt_1,
                        route: '/admin/register',
                      ),
                      _QuickAction(
                        label: 'Escanear QR',
                        icon: Icons.qr_code_scanner,
                        route: '/admin/qr-scan',
                      ),
                      _QuickAction(
                        label: 'Historial',
                        icon: Icons.history,
                        route: '/admin/history',
                      ),
                      _QuickAction(
                        label: 'Sedes',
                        icon: Icons.location_on_outlined,
                        route: '/admin/sedes',
                      ),
                      _QuickAction(
                        label: 'Turnos',
                        icon: Icons.schedule,
                        route: '/admin/shifts',
                      ),
                      _QuickAction(
                        label: 'Empresa',
                        icon: Icons.business_outlined,
                        route: '/admin/company',
                      ),
                      _QuickAction(
                        label: 'Ajustes',
                        icon: Icons.settings_outlined,
                        route: '/employee/settings',
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Auditoría de puntualidad.
                  Text(
                    'AUDITORÍA DE PUNTUALIDAD',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _AuditChip(
                          label: 'Todos',
                          value: 'ALL',
                          current: _audit,
                          onTap: (v) => setState(() => _audit = v),
                        ),
                        _AuditChip(
                          label: 'Puntuales',
                          value: 'PUNTUAL',
                          current: _audit,
                          onTap: (v) => setState(() => _audit = v),
                        ),
                        _AuditChip(
                          label: 'Tardanzas',
                          value: 'TARDANZA',
                          current: _audit,
                          onTap: (v) => setState(() => _audit = v),
                        ),
                        _AuditChip(
                          label: 'Sin registro',
                          value: 'SIN',
                          current: _audit,
                          onTap: (v) => setState(() => _audit = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _AuditList(
                    records: list,
                    absent: absent,
                    filter: _audit,
                    sedeName: _sedeName(sedes, _sedeId),
                  ),
                  const SizedBox(height: 22),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Registros de hoy',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        '${list.length}',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (today.hasError)
                    _InlineError(FirebaseErrors.message(today.error!))
                  else if (!today.hasValue)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (list.isEmpty)
                    const _EmptyCard(
                      icon: Icons.event_busy,
                      title: 'Aún no hay registros hoy',
                      subtitle:
                          'Los empleados aparecerán aquí cuando marquen asistencia.',
                    )
                  else
                    Card(
                      child: Column(
                        children: [
                          for (var i = 0; i < list.length && i < 12; i++) ...[
                            _AttendanceTile(a: list[i]),
                            if (i < list.length - 1 && i < 11)
                              const Divider(height: 1),
                          ],
                          if (list.length > 12)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: TextButton(
                                onPressed: () =>
                                    context.push('/admin/history'),
                                child: Text(
                                  'Ver los ${list.length} registros',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.invalidate(companyTodayAttendanceProvider);
                      ref.invalidate(companyHistoryProvider);
                      ref.invalidate(employeesProvider);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar panel'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String? _sedeName(List<Sede> sedes, String? id) {
    if (id == null) return null;
    for (final s in sedes) {
      if (s.id == id) return s.nombre;
    }
    return null;
  }

  void _showAlerts(
    BuildContext context, {
    required int late,
    required List<BioUser> absent,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(
              'Alertas del día',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Revisa las tardanzas y los empleados sin registro.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _AlertRow(
              icon: Icons.warning_amber_rounded,
              color: BioColors.warnOrange,
              title: '$late tardanza${late == 1 ? '' : 's'}',
              subtitle: 'Empleados que marcaron después de la tolerancia.',
            ),
            const SizedBox(height: 8),
            _AlertRow(
              icon: Icons.person_off_outlined,
              color: BioColors.errorRed,
              title: '${absent.length} sin registro',
              subtitle: absent.isEmpty
                  ? 'Todos los empleados activos ya marcaron.'
                  : absent.map((e) => e.fullName).take(12).join(', '),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check),
              label: const Text('Entendido'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.initials,
    required this.company,
    required this.date,
    required this.alerts,
    required this.onAlerts,
    required this.onLogout,
  });

  final String name;
  final String initials;
  final String company;
  final String date;
  final int alerts;
  final VoidCallback onAlerts;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [BioColors.greenDark, BioColors.greenMedium, BioColors.tealDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hola, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: onAlerts,
                    tooltip: 'Alertas',
                    icon: const Icon(Icons.notifications_none,
                        color: Colors.white),
                  ),
                  if (alerts > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: BioColors.errorRed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          alerts > 9 ? '9+' : '$alerts',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              PopupMenuButton<String>(
                tooltip: 'Cuenta',
                onSelected: (v) {
                  if (v == 'logout') onLogout();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
                ],
                child: CircleAvatar(
                  radius: 19,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            company,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 14, color: Colors.white.withValues(alpha: 0.75)),
              const SizedBox(width: 6),
              Text(
                date,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SedeSelector extends StatelessWidget {
  const _SedeSelector({
    required this.sedes,
    required this.value,
    required this.onChanged,
  });

  final List<Sede> sedes;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      initialValue: value ?? '',
      tooltip: 'Filtrar por sede',
      onSelected: (v) => onChanged(v.isEmpty ? null : v),
      itemBuilder: (_) => [
        const PopupMenuItem(value: '', child: Text('Todas las sedes')),
        for (final s in sedes)
          PopupMenuItem(value: s.id, child: Text(s.nombre)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on_outlined,
                size: 15, color: colors.onSecondaryContainer),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                value == null ? 'Todas' : _label(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.onSecondaryContainer,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: colors.onSecondaryContainer),
          ],
        ),
      ),
    );
  }

  String _label() {
    for (final s in sedes) {
      if (s.id == value) return s.nombre;
    }
    return 'Todas';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MiniDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({
    required this.late,
    required this.absent,
    required this.onTap,
  });
  final int late;
  final int absent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (late > 0) '$late tardanza${late == 1 ? '' : 's'}',
      if (absent > 0) '$absent sin registro',
    ];
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BioColors.warnOrange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: BioColors.warnOrange.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_active_outlined,
                color: BioColors.warnOrange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Atención: ${parts.join(' · ')}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.route,
  });
  final String label;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: colors.onSecondaryContainer, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuditChip extends StatelessWidget {
  const _AuditChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: current == value,
        onSelected: (_) => onTap(value),
      ),
    );
  }
}

class _AuditList extends StatelessWidget {
  const _AuditList({
    required this.records,
    required this.absent,
    required this.filter,
    required this.sedeName,
  });

  final List<Attendance> records;
  final List<BioUser> absent;
  final String filter;
  final String? sedeName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (filter == 'SIN') {
      if (absent.isEmpty) {
        return const _EmptyCard(
          icon: Icons.task_alt,
          title: 'Todos marcaron',
          subtitle: 'No hay empleados pendientes por registrar hoy.',
        );
      }
      return Card(
        child: Column(
          children: [
            for (var i = 0; i < absent.length && i < 8; i++) ...[
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: BioColors.errorRed.withValues(alpha: 0.12),
                  child: Text(
                    absent[i].initials,
                    style: const TextStyle(
                      color: BioColors.errorRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(absent[i].fullName),
                subtitle: Text(
                  absent[i].cargo.isEmpty ? 'Sin registro hoy' : absent[i].cargo,
                ),
                trailing: const Chip(
                  label: Text('PENDIENTE'),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                ),
              ),
              if (i < absent.length - 1 && i < 7) const Divider(height: 1),
            ],
          ],
        ),
      );
    }

    final filtered = switch (filter) {
      'PUNTUAL' => records
          .where((a) => a.status == 'PUNTUAL' || a.status == 'EXITOSO')
          .toList(),
      'TARDANZA' => records.where((a) => a.status == 'TARDANZA').toList(),
      _ => records,
    };

    if (filtered.isEmpty) {
      return const _EmptyCard(
        icon: Icons.search_off,
        title: 'Sin resultados',
        subtitle: 'No hay registros que coincidan con el filtro.',
      );
    }

    return Card(
      child: Column(
        children: [
          for (var i = 0; i < filtered.length && i < 8; i++) ...[
            ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: _statusColor(filtered[i]).withValues(
                  alpha: 0.14,
                ),
                child: Text(
                  filtered[i].userName.isEmpty
                      ? '?'
                      : filtered[i].userName[0].toUpperCase(),
                  style: TextStyle(
                    color: _statusColor(filtered[i]),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(filtered[i].userName),
              subtitle: Text(
                '${filtered[i].checkIn}'
                '${filtered[i].hasCheckedOut ? ' - ${filtered[i].checkOut}' : ''}'
                '${filtered[i].location.isEmpty ? '' : ' · ${filtered[i].location}'}',
              ),
              trailing: Chip(
                label: Text(
                  filtered[i].hasCheckedOut ? 'SALIDA' : filtered[i].status,
                ),
                visualDensity: VisualDensity.compact,
                backgroundColor: _statusColor(filtered[i]).withValues(
                  alpha: 0.14,
                ),
                side: BorderSide.none,
              ),
            ),
            if (i < filtered.length - 1 && i < 7) const Divider(height: 1),
          ],
          if (sedeName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Sede: $sedeName',
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  Color _statusColor(Attendance a) {
    if (a.hasCheckedOut) return BioColors.tealDark;
    if (a.status == 'TARDANZA') return BioColors.warnOrange;
    if (a.status == 'INASISTENCIA' || a.status == 'FALLIDO') {
      return BioColors.errorRed;
    }
    return BioColors.successGreen;
  }
}

class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile({required this.a});
  final Attendance a;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = a.hasCheckedOut
        ? colors.secondary
        : (a.status == 'TARDANZA' ? BioColors.warnOrange : BioColors.successGreen);
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.14),
        child: Text(
          a.userName.isEmpty ? '?' : a.userName[0].toUpperCase(),
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(a.userName),
      subtitle: Text(
        '${a.checkIn}${a.hasCheckedOut ? ' - ${a.checkOut}' : ''}'
        '${a.location.isEmpty ? '' : ' · ${a.location}'}',
      ),
      trailing: Chip(
        label: Text(a.hasCheckedOut ? 'SALIDA' : a.status),
        visualDensity: VisualDensity.compact,
        backgroundColor: color.withValues(alpha: 0.14),
        side: BorderSide.none,
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(icon, size: 38, color: colors.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyChartCard extends StatelessWidget {
  const _WeeklyChartCard({required this.records, this.sedeId});
  final List<Attendance> records;
  final String? sedeId;

  static const _labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final fmt = DateFormat('dd/MM/yyyy');

    final scoped = sedeId == null
        ? records
        : records.where((r) => r.sedeId == sedeId).toList();
    final counts = List<int>.generate(7, (i) {
      final ds = fmt.format(monday.add(Duration(days: i)));
      return scoped.where((r) => r.date == ds).length;
    });
    final total = counts.fold<int>(0, (a, b) => a + b);
    final maxCount = counts.fold<int>(0, (a, b) => b > a ? b : a);
    final maxY = (maxCount < 4 ? 4 : maxCount + 1).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: colors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Asistencia semanal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  '$total registros',
                  style: TextStyle(
                      fontSize: 12, color: colors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
                  barTouchData: BarTouchData(enabled: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: colors.outlineVariant,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= _labels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _labels[i],
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < 7; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: counts[i].toDouble(),
                            width: 16,
                            borderRadius: BorderRadius.circular(4),
                            color: i == now.weekday - 1
                                ? colors.primary
                                : colors.primary.withValues(alpha: 0.55),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 56, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);
  final String message;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
