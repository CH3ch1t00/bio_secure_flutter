import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/firebase_bootstrap.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'core/theme.dart';

class BioSecureApp extends ConsumerStatefulWidget {
  const BioSecureApp({super.key});

  @override
  ConsumerState<BioSecureApp> createState() => _BioSecureAppState();
}

class _BioSecureAppState extends ConsumerState<BioSecureApp> {
  @override
  Widget build(BuildContext context) {
    if (!FirebaseBootstrap.isReady) {
      return MaterialApp(
        title: 'BioSecure',
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: _FirebaseErrorScreen(
          message: FirebaseBootstrap.error ?? 'Firebase no pudo inicializarse.',
        ),
      );
    }

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return ListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) {
        final nav = router.routerDelegate.navigatorKey.currentState;
        final canPop = nav?.canPop() ?? false;
        return PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (nav != null && nav.canPop()) {
              nav.pop();
              return;
            }
            final location = router.routerDelegate.currentConfiguration.uri
                .toString();
            String fallback = '/login';
            if (location.startsWith('/admin')) {
              fallback = '/admin';
            } else if (location.startsWith('/employee')) {
              fallback = '/employee';
            }
            router.go(fallback);
          },
          child: MaterialApp.router(
            title: 'BioSecure',
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: themeMode,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
          ),
        );
      },
    );
  }
}

class _FirebaseErrorScreen extends StatelessWidget {
  const _FirebaseErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 72, color: colors.error),
              const SizedBox(height: 20),
              Text(
                'No se pudo conectar con Firebase',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              const Text(
                'Verifica internet, que el proyecto "biosecure2" tenga Firestore '
                'creado y que los permisos del manifest estén presentes.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  await FirebaseBootstrap.initialize();
                  if (context.mounted) {
                    // Rebuild de toda la app tras reintentar.
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const BioSecureApp()),
                      (_) => false,
                    );
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
