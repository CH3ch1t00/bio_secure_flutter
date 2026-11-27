import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/attendance.dart';

class HistoryList extends StatelessWidget {
  final List<Attendance> items;
  final bool showUser;

  const HistoryList({
    super.key,
    required this.items,
    this.showUser = true,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      final colors = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy, size: 56, color: colors.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                'Sin registros todavía.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: items.length,
      itemBuilder: (context, i) => _AttendanceCard(
        attendance: items[i],
        showUser: showUser,
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.attendance, required this.showUser});
  final Attendance attendance;
  final bool showUser;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final a = attendance;
    final color = _statusColor(a);
    final typeIcon = switch (a.type) {
      'FACIAL' => Icons.face_retouching_natural,
      'QR' => Icons.qr_code_2,
      _ => Icons.fingerprint,
    };
    final statusLabel = a.hasCheckedOut
        ? 'SALIDA'
        : (a.status.isEmpty ? 'REGISTRADO' : a.status);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showUser ? a.userName : a.date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        showUser ? a.date : (a.location.isEmpty ? '—' : a.location),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _Info(
                  icon: Icons.login,
                  label: a.checkIn.isEmpty ? '—' : a.checkIn,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 14),
                _Info(
                  icon: Icons.logout,
                  label: a.checkOut.isEmpty ? 'Pendiente' : a.checkOut,
                  color: colors.onSurfaceVariant,
                ),
                if (a.location.isNotEmpty && showUser) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: _Info(
                      icon: Icons.location_on_outlined,
                      label: a.location,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(Attendance a) {
    if (a.hasCheckedOut) return BioColors.tealDark;
    switch (a.status) {
      case 'TARDANZA':
        return BioColors.warnOrange;
      case 'INASISTENCIA':
      case 'FALLIDO':
        return BioColors.errorRed;
      default:
        return BioColors.successGreen;
    }
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 110),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
