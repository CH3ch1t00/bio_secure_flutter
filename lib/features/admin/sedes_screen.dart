import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/firebase_errors.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bio_app_bar.dart';
import '../../data/models/sede_shift.dart';

class SedesScreen extends ConsumerWidget {
  const SedesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sedes = ref.watch(sedesProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const BioAppBar(title: 'Sedes', fallbackRoute: '/admin'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Nueva sede'),
      ),
      body: sedes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(FirebaseErrors.message(e), textAlign: TextAlign.center),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return _EmptySedes(onCreate: () => _edit(context, ref, null));
          }
          final activas = list.where((s) => s.activa).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(
                  '$activas de ${list.length} sedes activas · '
                  'Toca el mapa al crear para elegir la ubicación.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              for (final s in list)
                _SedeCard(
                  sede: s,
                  onEdit: () => _edit(context, ref, s),
                  onToggle: () async {
                    final profile =
                        await ref.read(currentProfileProvider.future);
                    if (profile == null) return;
                    await ref.read(sedeRepositoryProvider).upsert(
                          profile.companyId,
                          Sede(
                            id: s.id,
                            nombre: s.nombre,
                            lat: s.lat,
                            lng: s.lng,
                            radioMetros: s.radioMetros,
                            activa: !s.activa,
                          ),
                        );
                  },
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
    Sede sede,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar sede'),
        content: Text(
          '¿Eliminar "${sede.nombre}"? Los empleados asignados quedarán sin sede.',
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
      await ref.read(sedeRepositoryProvider).delete(profile.companyId, sede.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sede eliminada.')),
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

  Future<void> _edit(BuildContext context, WidgetRef ref, Sede? sede) async {
    final name = TextEditingController(text: sede?.nombre ?? '');
    final lat = TextEditingController(
      text: sede != null ? sede.lat.toStringAsFixed(6) : '',
    );
    final lng = TextEditingController(
      text: sede != null ? sede.lng.toStringAsFixed(6) : '',
    );
    var radius = (sede?.radioMetros ?? 100).toDouble().clamp(20, 500).toDouble();
    var activa = sede?.activa ?? true;
    String? error;
    var locating = false;

    // Centro inicial del mapa.
    LatLng center;
    if (sede != null) {
      center = LatLng(sede.lat, sede.lng);
    } else {
      center = const LatLng(-33.4489, -70.6693); // Santiago por defecto
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final colors = Theme.of(context).colorScheme;

          double? parsedLat = double.tryParse(lat.text.trim());
          double? parsedLng = double.tryParse(lng.text.trim());
          final hasPoint = parsedLat != null && parsedLng != null;
          final point = hasPoint ? LatLng(parsedLat, parsedLng) : null;

          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  sede == null ? Icons.add_location_alt : Icons.edit_location_alt,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Text(sede == null ? 'Nueva sede' : 'Editar sede'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la sede',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Mapa OpenStreetMap (sin API key)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 230,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: center,
                            initialZoom: 15,
                            onTap: (_, tapped) {
                              setState(() {
                                lat.text = tapped.latitude.toStringAsFixed(6);
                                lng.text = tapped.longitude.toStringAsFixed(6);
                                error = null;
                              });
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName:
                                  'com.biosecure.bio_secure_flutter',
                            ),
                            if (point != null)
                              CircleLayer(
                                circles: [
                                  CircleMarker(
                                    point: point,
                                    radius: radius,
                                    useRadiusInMeter: true,
                                    color: colors.primary.withValues(alpha: 0.18),
                                    borderColor: colors.primary,
                                    borderStrokeWidth: 2,
                                  ),
                                ],
                              ),
                            if (point != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: point,
                                    width: 40,
                                    height: 40,
                                    child: Icon(
                                      Icons.location_on,
                                      color: colors.error,
                                      size: 40,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Toca el mapa para elegir la ubicación. El círculo muestra '
                      'el radio permitido.',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: lat,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Latitud',
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: lng,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Longitud',
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: locating
                          ? null
                          : () async {
                              setState(() => locating = true);
                              try {
                                final service =
                                    await Geolocator.isLocationServiceEnabled();
                                if (!service) {
                                  throw Exception('Activa el GPS del teléfono.');
                                }
                                var perm = await Geolocator.checkPermission();
                                if (perm == LocationPermission.denied) {
                                  perm = await Geolocator.requestPermission();
                                }
                                if (perm == LocationPermission.denied ||
                                    perm == LocationPermission.deniedForever) {
                                  throw Exception(
                                    'Permiso de ubicación denegado.',
                                  );
                                }
                                final pos = await Geolocator.getCurrentPosition(
                                  locationSettings: const LocationSettings(
                                    accuracy: LocationAccuracy.high,
                                    timeLimit: Duration(seconds: 20),
                                  ),
                                );
                                lat.text = pos.latitude.toStringAsFixed(6);
                                lng.text = pos.longitude.toStringAsFixed(6);
                                setState(() => error = null);
                              } catch (e) {
                                setState(
                                  () => error = FirebaseErrors.message(e),
                                );
                              } finally {
                                setState(() => locating = false);
                              }
                            },
                      icon: locating
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                      label: const Text('Usar mi ubicación actual'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Radio de la geocerca',
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
                            '${radius.round()} m',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colors.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: radius,
                      min: 20,
                      max: 500,
                      divisions: 48,
                      label: '${radius.round()} m',
                      onChanged: (v) => setState(() => radius = v),
                    ),
                    Text(
                      radius <= 60
                          ? 'Geocerca estricta: el empleado debe estar muy cerca.'
                          : radius <= 150
                              ? 'Geocerca recomendada para una sede.'
                              : 'Geocerca amplia: útil en edificios grandes.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.check_circle_outline),
                      title: const Text('Sede activa'),
                      subtitle: Text(
                        activa
                            ? 'Los empleados pueden marcar aquí.'
                            : 'No se permitirá marcar en esta sede.',
                      ),
                      value: activa,
                      onChanged: (v) => setState(() => activa = v),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!, style: TextStyle(color: colors.error)),
                    ],
                  ],
                ),
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
                  final pLat = double.tryParse(lat.text.trim());
                  final pLng = double.tryParse(lng.text.trim());
                  if (name.text.trim().isEmpty || pLat == null || pLng == null) {
                    setState(() => error =
                        'Completa el nombre y toca el mapa para elegir la ubicación.');
                    return;
                  }
                  try {
                    await ref.read(sedeRepositoryProvider).upsert(
                          profile.companyId,
                          Sede(
                            id: sede?.id ?? '',
                            nombre: name.text.trim(),
                            lat: pLat,
                            lng: pLng,
                            radioMetros: radius.round(),
                            activa: activa,
                          ),
                        );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sede guardada.')),
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
    lat.dispose();
    lng.dispose();
  }
}

class _SedeCard extends StatelessWidget {
  const _SedeCard({
    required this.sede,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final Sede sede;
  final VoidCallback onEdit;
  final Future<void> Function() onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final activeColor = sede.activa ? BioColors.successGreen : colors.outline;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.location_on, color: activeColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sede.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: activeColor.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            sede.activa ? 'ACTIVA' : 'INACTIVA',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: activeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.my_location,
                          size: 12,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${sede.lat.toStringAsFixed(5)}, '
                          '${sede.lng.toStringAsFixed(5)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.radar,
                          size: 12,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Radio permitido: ${sede.radioMetros} m',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'toggle') onToggle();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(sede.activa ? 'Desactivar' : 'Activar'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySedes extends StatelessWidget {
  const _EmptySedes({required this.onCreate});
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
                Icons.location_city,
                size: 40,
                color: colors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aún no hay sedes',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Crea la primera sede tocando el mapa para elegir la ubicación '
              'y ajusta el radio de geocerca.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Crear sede'),
            ),
          ],
        ),
      ),
    );
  }
}
