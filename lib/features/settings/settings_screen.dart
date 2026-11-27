import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/firebase_errors.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bio_app_bar.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _faceEnrolled = false;
  int _faceEnrolledAt = 0;
  bool _notifications = true;

  @override
  void initState() {
    super.initState();
    _loadFaceStatus();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notifications = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> _setNotifications(bool value) async {
    setState(() => _notifications = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
  }

  Future<void> _loadFaceStatus() async {
    final uid = ref.read(currentProfileProvider).value?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _faceEnrolled = prefs.getBool('face_enrolled_$uid') ?? false;
      _faceEnrolledAt = prefs.getInt('face_enrolled_at_$uid') ?? 0;
    });
  }

  Future<void> _changePassword() async {
    final pass = TextEditingController();
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nueva contraseña'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (pass.text.length < 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres.')),
      );
      return;
    }
    if (pass.text != confirm.text) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden.')),
      );
      return;
    }
    try {
      await ref.read(authRepositoryProvider).changePassword(pass.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FirebaseErrors.message(e))),
      );
    }
  }

  void _showInfo(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final colors = Theme.of(context).colorScheme;
    final company = ref.watch(companyProvider).value;
    final shifts = ref.watch(shiftsProvider).value ?? const [];
    final sedes = ref.watch(sedesProvider).value ?? const [];

    String shiftLabel(String? id) {
      if (id == null || id.isEmpty) return 'Sin asignar';
      for (final s in shifts) {
        if (s.id == id) return '${s.name} (${s.startTime} - ${s.endTime})';
      }
      return id;
    }

    String sedeLabel(String? id) {
      if (id == null || id.isEmpty) return 'Sin asignar';
      for (final s in sedes) {
        if (s.id == id) return s.nombre;
      }
      return id;
    }

    String faceDate() {
      if (_faceEnrolledAt <= 0) return '';
      final d = DateTime.fromMillisecondsSinceEpoch(_faceEnrolledAt);
      return ' · ${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';
    }

    return Scaffold(
      appBar: BioAppBar(
        title: 'Ajustes',
        fallbackRoute: (profile.value?.isAdmin ?? false) ? '/admin' : '/employee',
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(FirebaseErrors.message(e))),
        data: (u) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // Encabezado de perfil.
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              color: colors.surface,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: colors.primary,
                    child: Text(
                      u?.initials ?? '?',
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u?.fullName ?? 'Sin perfil',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          u?.email ?? '',
                          style: TextStyle(
                              color: colors.onSurfaceVariant, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: colors.secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            u?.isAdmin == true ? 'Administrador' : 'Empleado',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colors.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const _SectionHeader('Cuenta'),
            ListTile(
              leading: const Icon(Icons.business_outlined),
              title: const Text('Empresa'),
              subtitle: Text(
                (u?.companyId ?? '').isEmpty
                    ? 'Sin asignar'
                    : ((company?.name == null || company!.name.isEmpty)
                        ? u!.companyId
                        : company.name),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Turno'),
              subtitle: Text(shiftLabel(u?.shiftId)),
            ),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Sede'),
              subtitle: Text(sedeLabel(u?.sedeId)),
            ),
            if (u?.isAdmin != true) ...[
              ListTile(
                leading: const Icon(Icons.qr_code_2),
                title: const Text('Mi código QR'),
                subtitle: const Text('Muéstralo al administrador'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/employee/qr'),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Mi historial'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/employee/history'),
              ),
            ],
            const _SectionHeader('Preferencias'),
            Consumer(
              builder: (context, ref, _) {
                final mode = ref.watch(themeModeProvider);
                return SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Modo oscuro'),
                  subtitle: Text(mode == ThemeMode.dark
                      ? 'Activado'
                      : mode == ThemeMode.light
                          ? 'Desactivado'
                          : 'Según el sistema'),
                  value: mode == ThemeMode.dark,
                  onChanged: (v) => ref
                      .read(themeModeProvider.notifier)
                      .set(v ? ThemeMode.dark : ThemeMode.light),
                );
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Notificaciones'),
              subtitle: Text(
                _notifications
                    ? 'Avisos de turnos y recordatorios activados'
                    : 'Notificaciones desactivadas',
              ),
              value: _notifications,
              onChanged: _setNotifications,
            ),
            const _SectionHeader('Seguridad'),
            if (u?.isAdmin != true)
              ListTile(
                leading: Icon(
                  Icons.face_retouching_natural,
                  color: _faceEnrolled ? BioColors.successGreen : colors.primary,
                ),
                title: const Text('Enrolamiento facial'),
                subtitle: Text(
                  _faceEnrolled
                      ? 'Rostro enrolado${faceDate()}'
                      : 'Sin enrolar · toca para empezar',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await context.push('/employee/enroll');
                  _loadFaceStatus();
                },
              ),
            ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text('Cambiar contraseña'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _changePassword,
            ),
            const _SectionHeader('Información'),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('¿Cómo funciona?'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showInfo(
                '¿Cómo funciona BioSecure?',
                'BioSecure registra tu asistencia con huella o rostro y valida '
                'que estés dentro del radio de tu sede. '
                'El administrador configura las sedes, turnos y tolerancias. '
                'Puedes revisar tu historial y tu QR personal desde el menú.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacidad'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showInfo(
                'Privacidad',
                'Tus datos biométricos se procesan en el dispositivo. '
                'El enrolamiento facial se guarda localmente en este teléfono. '
                'Solo se envían los registros de asistencia (fecha, hora y '
                'ubicación) a la base de datos de tu empresa.',
              ),
            ),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Acerca de'),
              subtitle: Text('Biosecure Flutter 1.0.0 · Firebase: biosecure2'),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                  side: BorderSide(color: colors.error),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go('/login');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
