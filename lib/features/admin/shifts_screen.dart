import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_errors.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bio_app_bar.dart';
import '../../data/models/sede_shift.dart';
import '../../data/models/user.dart';

class ShiftsScreen extends ConsumerWidget {
  const ShiftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shifts = ref.watch(shiftsProvider);
    final employees = ref.watch(employeesProvider).value ?? const <BioUser>[];
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const BioAppBar(title: 'Turnos', fallbackRoute: '/admin'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add_alarm),
        label: const Text('Nuevo turno'),
      ),
      body: shifts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(FirebaseErrors.message(e), textAlign: TextAlign.center),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return _EmptyShifts(onCreate: () => _edit(context, ref, null));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(
                  'Define horarios y tolerancias. Toca un turno para asignarle '
                  'empleados.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              for (final s in list)
                _ShiftCard(
                  shift: s,
                  assigned: employees.where((e) => e.shiftId == s.id).toList(),
                  onEdit: () => _edit(context, ref, s),
                  onAssign: () => _assignEmployees(context, ref, s),
                  onDelete: () => _confirmDelete(context, ref, s),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Shift shift,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar turno'),
        content: Text(
          '¿Eliminar "${shift.name}"? Los empleados asignados quedarán sin turno.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null) return;
    try {
      await ref.read(shiftRepositoryProvider).delete(profile.companyId, shift.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turno eliminado.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FirebaseErrors.message(e))),
        );
      }
    }
  }

  Future<void> _assignEmployees(
    BuildContext context,
    WidgetRef ref,
    Shift shift,
  ) async {
    final employees = ref.read(employeesProvider).value ?? const <BioUser>[];
    if (employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay empleados registrados.')),
      );
      return;
    }
    final selected = <String>{
      for (final e in employees)
        if (e.shiftId == shift.id) e.uid,
    };
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.92,
          builder: (_, controller) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asignar a ${shift.name}',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${shift.startTime} - ${shift.endTime} · '
                      'tolerancia ${shift.toleranceMin} min',
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: controller,
                  children: [
                    for (final e in employees)
                      CheckboxListTile(
                        value: selected.contains(e.uid),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            selected.add(e.uid);
                          } else {
                            selected.remove(e.uid);
                          }
                        }),
                        secondary: CircleAvatar(child: Text(e.initials)),
                        title: Text(e.fullName),
                        subtitle: Text(
                          e.cargo.isEmpty ? e.email : e.cargo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx, selected),
                      icon: const Icon(Icons.save),
                      label: Text('Guardar (${selected.length})'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null) return;
    try {
      final repo = ref.read(userRepositoryProvider);
      for (final e in employees) {
        final was = e.shiftId == shift.id;
        final now = result.contains(e.uid);
        if (now && !was) await repo.assignShift(e.uid, shift.id);
        if (!now && was) await repo.assignShift(e.uid, '');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Turno asignado a ${result.length} '
              'empleado${result.length == 1 ? '' : 's'}.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FirebaseErrors.message(e))),
        );
      }
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Shift? shift) async {
    final name = TextEditingController(text: shift?.name ?? '');
    var tolerance = (shift?.toleranceMin ?? 5).clamp(0, 60);
    var start = _parse(shift?.startTime) ?? const TimeOfDay(hour: 8, minute: 0);
    var end = _parse(shift?.endTime) ?? const TimeOfDay(hour: 17, minute: 0);
    String? error;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final colors = Theme.of(context).colorScheme;
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.schedule, color: colors.primary),
                const SizedBox(width: 8),
                Text(shift == null ? 'Nuevo turno' : 'Editar turno'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del turno',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeBox(
                          label: 'Entrada',
                          time: start.format(context),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: start,
                            );
                            if (picked != null) setState(() => start = picked);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TimeBox(
                          label: 'Salida',
                          time: end.format(context),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: end,
                            );
                            if (picked != null) setState(() => end = picked);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tolerancia',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.secondaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$tolerance min',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colors.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: tolerance.toDouble(),
                    min: 0,
                    max: 60,
                    divisions: 12,
                    label: '$tolerance min',
                    onChanged: (v) => setState(() => tolerance = v.round()),
                  ),
                  Text(
                    'Minutos de gracia después de la entrada antes de marcar '
                    'TARDANZA.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: TextStyle(color: colors.error)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  final profile =
                      await ref.read(currentProfileProvider.future);
                  if (profile == null) {
                    setState(() => error = 'Sin perfil de administrador.');
                    return;
                  }
                  if (name.text.trim().isEmpty) {
                    setState(() => error = 'Escribe un nombre.');
                    return;
                  }
                  try {
                    await ref.read(shiftRepositoryProvider).upsert(
                          profile.companyId,
                          Shift(
                            id: shift?.id ?? '',
                            name: name.text.trim(),
                            startTime: _format(start),
                            endTime: _format(end),
                            toleranceMin: tolerance,
                          ),
                        );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Turno guardado.')),
                      );
                    }
                  } catch (e) {
                    setState(() => error = FirebaseErrors.message(e));
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    name.dispose();
  }

  static TimeOfDay? _parse(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({
    required this.shift,
    required this.assigned,
    required this.onEdit,
    required this.onAssign,
    required this.onDelete,
  });

  final Shift shift;
  final List<BioUser> assigned;
  final VoidCallback onEdit;
  final VoidCallback onAssign;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(Icons.schedule, color: colors.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shift.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${shift.startTime} - ${shift.endTime}',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'assign') onAssign();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(
                        value: 'assign',
                        child: Text('Asignar empleados'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Pill(
                    icon: Icons.timer_outlined,
                    text: 'Tolerancia ${shift.toleranceMin} min',
                    color: BioColors.warnOrange,
                  ),
                  const SizedBox(width: 8),
                  _Pill(
                    icon: Icons.people_alt_outlined,
                    text: '${assigned.length} '
                        'asignado${assigned.length == 1 ? '' : 's'}',
                    color: colors.secondary,
                  ),
                ],
              ),
              if (assigned.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  assigned.map((e) => e.fullName).take(4).join(', ') +
                      (assigned.length > 4 ? '…' : ''),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onAssign,
                  icon: const Icon(Icons.group_add_outlined, size: 18),
                  label: const Text('Asignar empleados'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({
    required this.label,
    required this.time,
    required this.onTap,
  });
  final String label;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.access_time, size: 15, color: colors.primary),
                const SizedBox(width: 5),
                Text(
                  time,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyShifts extends StatelessWidget {
  const _EmptyShifts({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.schedule,
                size: 40,
                color: colors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aún no hay turnos',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Crea turnos con horario de entrada, salida y tolerancia para '
              'controlar la puntualidad.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_alarm),
              label: const Text('Crear turno'),
            ),
          ],
        ),
      ),
    );
  }
}
