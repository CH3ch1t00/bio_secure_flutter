import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BioBottomBar extends StatelessWidget {
  const BioBottomBar({
    super.key,
    required this.isAdmin,
    required this.currentRoute,
  });

  final bool isAdmin;
  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = isAdmin
        ? const <_BarItem>[
            _BarItem('/admin', 'PANEL', Icons.dashboard_outlined),
            _BarItem('/admin/sedes', 'SEDES', Icons.location_on_outlined),
            _BarItem('/admin/history', 'HISTORIAL', Icons.history_outlined),
            _BarItem('/employee/settings', 'AJUSTES', Icons.settings_outlined),
          ]
        : const <_BarItem>[
            _BarItem('/employee', 'INICIO', Icons.home_outlined),
            _BarItem('/employee/scan', 'ESCANEO', Icons.fingerprint),
            _BarItem('/employee/history', 'HISTORIAL', Icons.history_outlined),
            _BarItem('/employee/settings', 'AJUSTES', Icons.settings_outlined),
          ];

    return NavigationBar(
      backgroundColor: colors.surface,
      indicatorColor: colors.primaryContainer,
      destinations: items
          .map((it) => NavigationDestination(
                icon: Icon(it.icon),
                label: it.label,
              ))
          .toList(),
      selectedIndex: _indexFor(items),
      onDestinationSelected: (i) {
        final route = items[i].route;
        if (route != currentRoute) {
          // ignore: use_build_context_synchronously
          context.go(route);
        }
      },
    );
  }

  int _indexFor(List<_BarItem> items) {
    for (var i = 0; i < items.length; i++) {
      if (currentRoute == items[i].route) {
        return i;
      }
    }
    return 0;
  }
}

class _BarItem {
  const _BarItem(this.route, this.label, this.icon);
  final String route;
  final String label;
  final IconData icon;
}
