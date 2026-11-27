import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_errors.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bio_app_bar.dart';
import '../../data/models/attendance.dart';
import '../shared/history_list.dart';

class EmployeeHistoryScreen extends ConsumerStatefulWidget {
  const EmployeeHistoryScreen({super.key});
  @override
  ConsumerState<EmployeeHistoryScreen> createState() =>
      _EmployeeHistoryScreenState();
}

class _EmployeeHistoryScreenState extends ConsumerState<EmployeeHistoryScreen> {
  String _filter = 'TODOS';

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final stream = ref.watch(attendanceRepositoryProvider).watchByUser(
          profile.uid,
        );
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const BioAppBar(title: 'Mi Historial', fallbackRoute: '/employee'),
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
          final items = switch (_filter) {
            'PUNTUAL' => all
                .where((a) => a.status == 'PUNTUAL' || a.status == 'EXITOSO')
                .toList(),
            'TARDANZA' => all.where((a) => a.status == 'TARDANZA').toList(),
            'SALIDA' => all.where((a) => a.hasCheckedOut).toList(),
            _ => all,
          };
          final onTime = all
              .where((a) => a.status == 'PUNTUAL' || a.status == 'EXITOSO')
              .length;
          final late = all.where((a) => a.status == 'TARDANZA').length;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
              await Future<void>.delayed(const Duration(milliseconds: 400));
            },
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          _Summary(
                            value: '${all.length}',
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
                      for (final f in const [
                        ('TODOS', 'Todos'),
                        ('PUNTUAL', 'Puntuales'),
                        ('TARDANZA', 'Tardanzas'),
                        ('SALIDA', 'Con salida'),
                      ]) ...[
                        ChoiceChip(
                          label: Text(f.$2),
                          selected: _filter == f.$1,
                          onSelected: (_) =>
                              setState(() => _filter = f.$1),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: HistoryList(items: items, showUser: false),
                ),
              ],
            ),
          );
        },
      ),
    );
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
