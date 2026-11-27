import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_errors.dart';
import '../../core/providers.dart';
import '../../core/widgets/bio_app_bar.dart';

class CompanySettingsScreen extends ConsumerStatefulWidget {
  const CompanySettingsScreen({super.key});
  @override
  ConsumerState<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends ConsumerState<CompanySettingsScreen> {
  final _name = TextEditingController();
  final _tolerance = TextEditingController(text: '10');
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  bool _loaded = false;

  @override
  void dispose() {
    _name.dispose();
    _tolerance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final company = ref.watch(companyProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const BioAppBar(
        title: 'Configuración de empresa',
        fallbackRoute: '/admin',
      ),
      body: company.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(FirebaseErrors.message(e), textAlign: TextAlign.center),
          ),
        ),
        data: (c) {
          if (c == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se encontró la empresa en Firestore. '
                  'Pide a un administrador que cree el documento '
                  'companies/{tu companyId}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
            );
          }

          if (!_loaded) {
            _loaded = true;
            _name.text = c.name;
            _tolerance.text = c.toleranciaMin.toString();
            final parts = c.horaEntrada.split(':');
            if (parts.length == 2) {
              _start = TimeOfDay(
                hour: int.tryParse(parts[0]) ?? 8,
                minute: int.tryParse(parts[1]) ?? 0,
              );
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Se guarda en companies/${c.id}. Solo el administrador puede '
                'cambiar el nombre, la hora de entrada y la tolerancia.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nombre de la empresa'),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hora de entrada'),
                subtitle: Text(_start.format(context)),
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _start,
                  );
                  if (picked != null) setState(() => _start = picked);
                },
              ),
              TextField(
                controller: _tolerance,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tolerancia (minutos)',
                  helperText: 'Minutos de gracia antes de marcar TARDANZA',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _save(context),
                icon: const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final profile = await ref.read(currentProfileProvider.future);
    if (!context.mounted) return;
    if (profile == null || profile.companyId.isEmpty) {
      _snack(context, 'Tu perfil no tiene companyId.');
      return;
    }
    try {
      final tolerance =
          int.tryParse(_tolerance.text.trim().replaceAll(RegExp(r'[^0-9]'), '')) ?? 10;
      await ref.read(companyRepositoryProvider).updateCompany(
            companyId: profile.companyId,
            name: _name.text.trim().isEmpty ? profile.companyId : _name.text.trim(),
            horaEntrada:
                '${_start.hour.toString().padLeft(2, '0')}:${_start.minute.toString().padLeft(2, '0')}',
            toleranciaMin: tolerance.clamp(0, 120),
          );
      ref.invalidate(companyProvider);
      if (context.mounted) _snack(context, 'Configuración guardada.');
    } catch (e) {
      if (context.mounted) _snack(context, FirebaseErrors.message(e));
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
