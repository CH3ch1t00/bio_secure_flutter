import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/firebase_errors.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bio_app_bar.dart';
import '../../data/models/sede_shift.dart';
import '../../data/models/user.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});
  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  String _query = '';
  String _filter = 'TODOS'; // TODOS | ACTIVOS | INACTIVOS
  String? _sedeId;

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(employeesProvider);
    final sedes = ref.watch(sedesProvider).value ?? const <Sede>[];
    final shifts = ref.watch(shiftsProvider).value ?? const <Shift>[];
    final colors = Theme.of(context).colorScheme;

    String shiftName(String? id) {
      if (id == null || id.isEmpty) return 'Sin turno';
      for (final s in shifts) {
        if (s.id == id) return s.name;
      }
      return 'Turno';
    }

    String sedeName(String? id) {
      if (id == null || id.isEmpty) return 'Sin sede';
      for (final s in sedes) {
        if (s.id == id) return s.nombre;
      }
      return 'Sede';
    }

    return Scaffold(
      appBar: const BioAppBar(title: 'Empleados', fallbackRoute: '/admin'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/register'),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Registrar'),
      ),
      body: employees.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(FirebaseErrors.message(e), textAlign: TextAlign.center),
          ),
        ),
        data: (all) {
          if (all.isEmpty) {
            return _EmptyEmployees(
              onRegister: () => context.push('/admin/register'),
            );
          }
          final q = _query.trim().toLowerCase();
          final list = all.where((u) {
            if (q.isNotEmpty &&
                !u.fullName.toLowerCase().contains(q) &&
                !u.email.toLowerCase().contains(q) &&
                !u.cargo.toLowerCase().contains(q)) {
              return false;
            }
            if (_filter == 'ACTIVOS' && !u.isActive) return false;
            if (_filter == 'INACTIVOS' && u.isActive) return false;
            if (_sedeId != null && u.sedeId != _sedeId) return false;
            return true;
          }).toList();
          final active = all.where((e) => e.isActive).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, correo o cargo…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _query = ''),
                          ),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _FilterChip(
                      label: 'Todos (${all.length})',
                      value: 'TODOS',
                      current: _filter,
                      onTap: (v) => setState(() => _filter = v),
                    ),
                    _FilterChip(
                      label: 'Activos ($active)',
                      value: 'ACTIVOS',
                      current: _filter,
                      onTap: (v) => setState(() => _filter = v),
                    ),
                    _FilterChip(
                      label: 'Inactivos (${all.length - active})',
                      value: 'INACTIVOS',
                      current: _filter,
                      onTap: (v) => setState(() => _filter = v),
                    ),
                    if (sedes.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        initialValue: _sedeId ?? '',
                        tooltip: 'Filtrar por sede',
                        onSelected: (v) =>
                            setState(() => _sedeId = v.isEmpty ? null : v),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: '',
                            child: Text('Todas las sedes'),
                          ),
                          for (final s in sedes)
                            PopupMenuItem(value: s.id, child: Text(s.nombre)),
                        ],
                        child: Chip(
                          avatar: const Icon(Icons.location_on_outlined, size: 16),
                          label: Text(
                            _sedeId == null ? 'Sede' : sedeName(_sedeId),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${list.length} empleado${list.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      '$active activos',
                      style: const TextStyle(
                        fontSize: 12,
                        color: BioColors.successGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const _EmptyFilter()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final u = list[i];
                          return _EmployeeCard(
                            user: u,
                            sedeName: sedeName(u.sedeId),
                            shiftName: shiftName(u.shiftId),
                            onEdit: () => _edit(context, u),
                            onToggle: () => _toggle(context, u),
                            onShift: () => _pickShift(context, u),
                            onSede: () => _pickSede(context, u),
                            onDelete: () => _delete(context, u),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, BioUser user) async {
    final first = TextEditingController(text: user.firstName);
    final last = TextEditingController(text: user.lastName);
    final phone = TextEditingController(text: user.phone);
    final cargo = TextEditingController(text: user.cargo);
    final department = TextEditingController(text: user.department);
    String? error;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Editar empleado'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: first,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: last,
                  decoration: const InputDecoration(labelText: 'Apellido'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: cargo,
                  decoration: const InputDecoration(labelText: 'Cargo'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: department,
                  decoration: const InputDecoration(labelText: 'Departamento'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (first.text.trim().isEmpty) {
                  setState(() => error = 'El nombre no puede quedar vacío.');
                  return;
                }
                try {
                  final name = '${first.text.trim()} ${last.text.trim()}'.trim();
                  await ref.read(userRepositoryProvider).updateUser(user.uid, {
                    'firstName': first.text.trim(),
                    'lastName': last.text.trim(),
                    'name': name,
                    'phone': phone.text.trim(),
                    'cargo': cargo.text.trim(),
                    'department': department.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  setState(() => error = FirebaseErrors.message(e));
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    first.dispose();
    last.dispose();
    phone.dispose();
    cargo.dispose();
    department.dispose();
    if (ok == true && context.mounted) {
      _snack(context, 'Empleado actualizado.');
    }
  }

  Future<void> _toggle(BuildContext context, BioUser user) async {
    try {
      await ref.read(userRepositoryProvider).setActive(user.uid, !user.isActive);
      if (context.mounted) {
        _snack(
          context,
          user.isActive
              ? '${user.fullName} desactivado.'
              : '${user.fullName} activado.',
        );
      }
    } catch (e) {
      if (context.mounted) _snack(context, FirebaseErrors.message(e));
    }
  }

  Future<void> _pickShift(BuildContext context, BioUser user) async {
    final shifts = ref.read(shiftsProvider).value ?? const <Shift>[];
    if (shifts.isEmpty) {
      _snack(context, 'Primero crea turnos en la sección Turnos.');
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(
            title: Text(
              'Asignar turno',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Sin turno'),
            onTap: () => Navigator.pop(context, ''),
          ),
          for (final s in shifts)
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(s.name),
              subtitle: Text(
                '${s.startTime} - ${s.endTime} · tolerancia ${s.toleranceMin} min',
              ),
              trailing: user.shiftId == s.id
                  ? const Icon(Icons.check, color: BioColors.successGreen)
                  : null,
              onTap: () => Navigator.pop(context, s.id),
            ),
        ],
      ),
    );
    if (selected == null) return;
    try {
      await ref.read(userRepositoryProvider).assignShift(user.uid, selected);
      if (context.mounted) _snack(context, 'Turno actualizado.');
    } catch (e) {
      if (context.mounted) _snack(context, FirebaseErrors.message(e));
    }
  }

  Future<void> _pickSede(BuildContext context, BioUser user) async {
    final sedes = ref.read(sedesProvider).value ?? const <Sede>[];
    if (sedes.isEmpty) {
      _snack(context, 'Primero crea sedes en la sección Sedes.');
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(
            title: Text(
              'Asignar sede',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Sin sede'),
            onTap: () => Navigator.pop(context, ''),
          ),
          for (final s in sedes)
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(s.nombre),
              subtitle: Text('Radio ${s.radioMetros} m'),
              trailing: user.sedeId == s.id
                  ? const Icon(Icons.check, color: BioColors.successGreen)
                  : null,
              onTap: () => Navigator.pop(context, s.id),
            ),
        ],
      ),
    );
    if (selected == null) return;
    try {
      await ref.read(userRepositoryProvider).assignSede(user.uid, selected);
      if (context.mounted) _snack(context, 'Sede actualizada.');
    } catch (e) {
      if (context.mounted) _snack(context, FirebaseErrors.message(e));
    }
  }

  Future<void> _delete(BuildContext context, BioUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar perfil'),
        content: Text(
          '¿Eliminar el perfil de ${user.fullName}? '
          'La cuenta de Firebase Auth no se borra.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(userRepositoryProvider).deleteUser(user.uid);
      if (context.mounted) _snack(context, 'Perfil eliminado.');
    } catch (e) {
      if (context.mounted) _snack(context, FirebaseErrors.message(e));
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.user,
    required this.sedeName,
    required this.shiftName,
    required this.onEdit,
    required this.onToggle,
    required this.onShift,
    required this.onSede,
    required this.onDelete,
  });

  final BioUser user;
  final String sedeName;
  final String shiftName;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onShift;
  final VoidCallback onSede;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final activeColor =
        user.isActive ? BioColors.successGreen : colors.onSurfaceVariant;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: activeColor.withValues(alpha: 0.14),
                    child: Text(
                      user.initials,
                      style: TextStyle(
                        color: activeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (user.email.isNotEmpty)
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (user.cargo.isNotEmpty)
                          _Tag(
                            icon: Icons.work_outline,
                            text: user.cargo,
                            color: colors.secondary,
                          ),
                        _Tag(
                          icon: Icons.schedule,
                          text: shiftName,
                          color: user.shiftId == null
                              ? colors.onSurfaceVariant
                              : colors.primary,
                        ),
                        _Tag(
                          icon: Icons.location_on_outlined,
                          text: sedeName,
                          color: user.sedeId == null
                              ? colors.onSurfaceVariant
                              : colors.primary,
                        ),
                        if (!user.isActive)
                          const _Tag(
                            icon: Icons.pause_circle_outline,
                            text: 'Inactivo',
                            color: BioColors.errorRed,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  switch (v) {
                    case 'edit':
                      onEdit();
                    case 'toggle':
                      onToggle();
                    case 'shift':
                      onShift();
                    case 'sede':
                      onSede();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(user.isActive ? 'Desactivar' : 'Activar'),
                  ),
                  const PopupMenuItem(value: 'shift', child: Text('Asignar turno')),
                  const PopupMenuItem(value: 'sede', child: Text('Asignar sede')),
                  const PopupMenuItem(value: 'delete', child: Text('Eliminar perfil')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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

class _EmptyEmployees extends StatelessWidget {
  const _EmptyEmployees({required this.onRegister});
  final VoidCallback onRegister;

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
                Icons.groups_2_outlined,
                size: 40,
                color: colors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sin empleados todavía',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Registra a tu primer empleado para que pueda marcar asistencia '
              'con huella o rostro.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRegister,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Registrar empleado'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFilter extends StatelessWidget {
  const _EmptyFilter();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: colors.onSurfaceVariant),
            const SizedBox(height: 8),
            const Text('No hay empleados que coincidan con la búsqueda.'),
          ],
        ),
      ),
    );
  }
}
