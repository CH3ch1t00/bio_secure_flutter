import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// AppBar con botón de retroceso explícito.
///
/// La navegación de la app usa `context.push` (por lo que el botón automático
/// de Flutter ya aparece), pero si una pantalla se abrió con `context.go` no
/// existe pila que retroceder. En ese caso se navega a [fallbackRoute], que
/// siempre es el panel del rol correspondiente.
class BioAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BioAppBar({
    super.key,
    required this.title,
    required this.fallbackRoute,
    this.actions,
    this.bottom,
  });

  final String title;
  final String fallbackRoute;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  static void back(BuildContext context, String fallbackRoute) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(fallbackRoute);
    }
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      leading: BackButton(
        onPressed: () => back(context, fallbackRoute),
      ),
      actions: actions,
      bottom: bottom,
    );
  }
}
