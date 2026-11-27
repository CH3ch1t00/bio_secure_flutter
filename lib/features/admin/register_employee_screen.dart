import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/firebase_errors.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bio_app_bar.dart';
import '../../data/models/sede_shift.dart';
import '../../data/models/user.dart';
import '../../firebase_options.dart';

class RegisterEmployeeScreen extends ConsumerStatefulWidget {
  const RegisterEmployeeScreen({super.key});
  @override
  ConsumerState<RegisterEmployeeScreen> createState() =>
      _RegisterEmployeeScreenState();
}

class _RegisterEmployeeScreenState extends ConsumerState<RegisterEmployeeScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _cargo = TextEditingController();
  final _department = TextEditingController();
  String? _shiftId;
  String? _sedeId;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _firstName,
      _lastName,
      _email,
      _password,
      _cargo,
      _department,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    _error = null;
    final profile = await ref
        .read(currentProfileProvider.future)
        .timeout(const Duration(seconds: 15), onTimeout: () => null);
    if (profile == null) {
      setState(() => _error = 'No se pudo cargar tu perfil. Revisa tu conexión.');
      return;
    }
    if (profile.companyId.isEmpty) {
      setState(() => _error = 'Tu perfil no tiene companyId.');
      return;
    }
    if (!profile.isAdmin) {
      setState(() => _error = 'Solo un administrador puede registrar empleados.');
      return;
    }
    if (_firstName.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el nombre del empleado.');
      return;
    }
    final email = _email.text.trim().toLowerCase().replaceAll(RegExp(r'\\s+'), '');
    if (!email.contains('@') || _password.text.length < 6) {
      setState(
        () => _error =
            'Correo válido y contraseña de al menos 6 caracteres.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    FirebaseApp? secondary;
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Creando cuenta en Firebase Auth…'),
          duration: Duration(seconds: 2),
        ),
      );

      const name = 'employeeCreator';
      try {
        final existing = Firebase.app(name);
        await existing.delete().timeout(const Duration(seconds: 5));
      } catch (_) {}
      secondary = await Firebase.initializeApp(
        name: name,
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 15));
      final auth = FirebaseAuth.instanceFor(app: secondary);

      final cred = await auth
          .createUserWithEmailAndPassword(
            email: email,
            password: _password.text,
          )
          .timeout(const Duration(seconds: 30));
      final uid = cred.user!.uid;

      // Cerrar sesión en la app secundaria (no bloquear si falla).
      try {
        await auth.signOut().timeout(const Duration(seconds: 10));
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guardando perfil en Firestore…'),
          duration: Duration(seconds: 2),
        ),
      );

      final user = BioUser(
        uid: uid,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: email,
        role: 'employee',
        cargo: _cargo.text.trim(),
        department: _department.text.trim(),
        companyId: profile.companyId,
        shiftId: _shiftId,
        sedeId: _sedeId,
      );
      await ref
          .read(userRepositoryProvider)
          .createUser(user)
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;
      await _showQrDialog(user);
      if (!mounted) return;
      _firstName.clear();
      _lastName.clear();
      _email.clear();
      _password.clear();
      _cargo.clear();
      _department.clear();
      setState(() {
        _shiftId = null;
        _sedeId = null;
      });
    } on TimeoutException {
      setState(
        () => _error =
            'La operación tardó demasiado. Revisa tu conexión a internet y '
            'los permisos de Firestore (¿el admin tiene companyId?).',
      );
    } catch (e) {
      setState(() => _error = FirebaseErrors.message(e));
    } finally {
      try {
        await secondary?.delete().timeout(const Duration(seconds: 5));
      } catch (_) {}
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showQrDialog(BioUser user) async {
    final colors = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: BioColors.successGreen.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_add_alt_1,
            size: 34,
            color: BioColors.successGreen,
          ),
        ),
        title: const Text('Empleado registrado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              user.fullName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              user.email,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: user.uid,
                version: QrVersions.auto,
                size: 190,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Este es el QR personal del empleado. Puede mostrarlo al '
              'administrador para verificar su asistencia.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shifts = ref.watch(shiftsProvider).value ?? const <Shift>[];
    final sedes = ref.watch(sedesProvider).value ?? const <Sede>[];
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const BioAppBar(
        title: 'Registrar empleado',
        fallbackRoute: '/admin',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: colors.onSecondaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Se crea la cuenta de Firebase y el perfil en Firestore. '
                    'El empleado podrá iniciar sesión con ese correo.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _Section('Datos personales'),
          TextField(
            controller: _firstName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lastName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Apellido',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cargo,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Cargo',
              prefixIcon: Icon(Icons.work_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _department,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Departamento',
              prefixIcon: Icon(Icons.apartment_outlined),
            ),
          ),
          const SizedBox(height: 18),
          const _Section('Acceso'),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Contraseña temporal (mín. 6)',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const _Section('Asignación'),
          DropdownButtonFormField<String>(
            initialValue: _shiftId,
            decoration: const InputDecoration(
              labelText: 'Turno',
              prefixIcon: Icon(Icons.schedule),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('Sin turno'),
              ),
              for (final s in shifts)
                DropdownMenuItem(
                  value: s.id,
                  child: Text('${s.name} (${s.startTime}-${s.endTime})'),
                ),
            ],
            onChanged: (v) => setState(() => _shiftId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _sedeId,
            decoration: const InputDecoration(
              labelText: 'Sede',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('Sin sede'),
              ),
              for (final s in sedes)
                DropdownMenuItem(value: s.id, child: Text(s.nombre)),
            ],
            onChanged: (v) => setState(() => _sedeId = v),
          ),
          if (shifts.isEmpty || sedes.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Consejo: crea turnos y sedes para asignarlos al empleado. '
              'También puedes hacerlo después desde la lista de empleados.',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: colors.onErrorContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add),
            label: Text(_busy ? 'Creando cuenta…' : 'Crear empleado'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        title.toUpperCase(),
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
