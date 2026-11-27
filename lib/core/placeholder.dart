import 'package:flutter/material.dart';

import 'widgets/bio_app_bar.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final String fallbackRoute;
  const PlaceholderScreen(this.title, {super.key, this.fallbackRoute = '/employee'});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: BioAppBar(title: title, fallbackRoute: fallbackRoute),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.construction, size: 64, color: colors.primary),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Esta función estará disponible en una próxima versión.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
