import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/firebase_errors.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bio_app_bar.dart';
import '../../data/models/attendance.dart';
import '../../data/models/sede_shift.dart';
import '../shared/history_list.dart';

class AdminHistoryScreen extends ConsumerStatefulWidget {
  const AdminHistoryScreen({super.key});
  @override
  ConsumerState<AdminHistoryScreen> createState() => _AdminHistoryScreenState();
}

class _AdminHistoryScreenState extends ConsumerState<AdminHistoryScreen> {
  bool _onlyToday = false;
  String _query = '';
  String _statusFilter = 'TODOS';
  String? _sedeId;

  static const _statuses = ['TODOS', 'PUNTUAL', 'TARDANZA', 'SALIDA'];

  List<Attendance> _applyFilters(List<Attendance> items) {
    final q = _query.trim().toLowerCase();
    return items.where((a) {
      if (q.isNotEmpty &&
          !a.userName.toLowerCase().contains(q) &&
          !a.date.contains(q) &&
          !a.location.toLowerCase().contains(q)) {
        return false;
      }
      if (_sedeId != null && a.sedeId != _sedeId) return false;
      switch (_statusFilter) {
        case 'PUNTUAL':
          return a.status == 'PUNTUAL' || a.status == 'EXITOSO';
        case 'TARDANZA':
          return a.status == 'TARDANZA';
        case 'SALIDA':
          return a.hasCheckedOut;
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _exportCsv(List<Attendance> items) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros para exportar.')),
      );
      return;
    }
    final buffer = StringBuffer(
      'Empleado,Fecha,Entrada,Salida,Estado,Tipo,Sede,Latitud,Longitud\n',
    );
    for (final a in items) {
      String esc(String v) => '"${v.replaceAll('"', '""')}"';
      buffer.writeln([
        esc(a.userName),
        esc(a.date),
        esc(a.checkIn),
        esc(a.checkOut),
        esc(a.status),
        esc(a.type),
        esc(a.location),
        a.latitude?.toString() ?? '',
        a.longitude?.toString() ?? '',
      ].join(','));
    }
    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final file = File('${dir.path}/biosecure_historial_$stamp.csv');
      await file.writeAsString(buffer.toString());
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'Historial de asistencia BioSecure',
          text: 'Historial de asistencia (${items.length} registros).',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo exportar: ${FirebaseErrors.message(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (profile.companyId.isEmpty) {
      return const Scaffold(
        appBar: BioAppBar(title: 'Historial', fallbackRoute: '/admin'),
        body: Center(child: Text('Tu perfil no tiene companyId.')),
      );
    }
    final repo = ref.watch(attendanceRepositoryProvider);
    final stream = _onlyToday
        ? repo.watchToday(profile.companyId)
        : repo.watchAll(profile.companyId);
    final sedes = ref.watch(sedesProvider).value ?? const <Sede>[];
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: BioAppBar(
        title: 'Historial',
        fallbackRoute: '/admin',
        actions: [
          IconButton(
            tooltip: _onlyToday ? 'Ver todo' : 'Ver solo hoy',
            icon: Icon(_onlyToday ? Icons.today : Icons.calendar_view_month),
            onPressed: () => setState(() => _onlyToday = !_onlyToday),
          ),
          IconButton(
            tooltip: 'Exportar CSV',
            icon: const Icon(Icons.ios_share),
            onPressed: () async {
              final snap = await stream.first;
              if (mounted) await _exportCsv(_applyFilters(snap));
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Attendance>>(
        stream: stream,
        builder: (_, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(FirebaseErrors.message(snap.error!)),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!;
          final items = _applyFilters(all);
          final late = items.where((a) => a.status == 'TARDANZA').length;
          final onTime = items
              .where((a) => a.status == 'PUNTUAL' || a.status == 'EXITOSO')
              .length;
          final finished = items.where((a) => a.hasCheckedOut).length;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
              await Future<void>.delayed(
                const Duration(milliseconds: 400),
              );
            },
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar empleado, fecha o sede…',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() => _query = ''),
                            ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          _Summary(
                            value: '${items.length}',
                            label: 'Registros',
                            color: colors.primary,
                          ),
                          _Summary(
                            value: '$onTime',
                            label: 'Puntuales',
                            color: BioColors.successGreen,
                          ),
                          _Summary(
                            value: '$late',
                            label: 'Tardanzas',
                            color: BioColors.warnOrange,
                          ),
                          _Summary(
                            value: '$finished',
                            label: 'Salidas',
                            color: colors.secondary,
                          ),
                        ],
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
                      ChoiceChip(
                        label: const Text('Hoy'),
                        selected: _onlyToday,
                        onSelected: (_) => setState(() => _onlyToday = true),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Todo'),
                        selected: !_onlyToday,
                        onSelected: (_) => setState(() => _onlyToday = false),
                      ),
                      const SizedBox(width: 16),
                      for (final s in _statuses) ...[
                        ChoiceChip(
                          label: Text(_statusLabel(s)),
                          selected: _statusFilter == s,
                          onSelected: (_) => setState(() => _statusFilter = s),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                if (sedes.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        ChoiceChip(
                          label: const Text('Todas las sedes'),
                          selected: _sedeId == null,
                          onSelected: (_) => setState(() => _sedeId = null),
                        ),
                        const SizedBox(width: 8),
                        for (final s in sedes) ...[
                          ChoiceChip(
                            label: Text(s.nombre),
                            selected: _sedeId == s.id,
                            onSelected: (_) => setState(() => _sedeId = s.id),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Expanded(child: HistoryList(items: items)),
              ],
            ),
          );
        },
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'PUNTUAL':
        return 'Puntual';
      case 'TARDANZA':
        return 'Tardanza';
      case 'SALIDA':
        return 'Con salida';
      default:
        return 'Todos';
    }
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value;
  final String label;
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
