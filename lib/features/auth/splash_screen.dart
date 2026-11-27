import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/firebase_errors.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _routed = false;
  String? _error;
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    if (_routed) return;
    // Mantener el splash al menos el tiempo de la animación, como la app original.
    final started = DateTime.now();
    try {
      final user = await ref.read(authStateProvider.future);
      final elapsed = DateTime.now().difference(started);
      const minSplash = Duration(milliseconds: 1600);
      if (elapsed < minSplash) {
        await Future<void>.delayed(minSplash - elapsed);
      }
      if (user == null) {
        _routed = true;
        if (mounted) context.go('/login');
        return;
      }
      final profile = await ref.read(userRepositoryProvider).getUser(user.uid);
      _routed = true;
      if (!mounted) return;
      if (profile == null) {
        context.go('/login');
        return;
      }
      context.go(profile.isAdmin ? '/admin' : '/employee');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = FirebaseErrors.message(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BioColors.greenDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scale,
                child: Image.asset(
                  'assets/images/penguin_splash.png',
                  height: 160,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'BioSecure',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sistema de Asistencia Biométrica',
                style: TextStyle(fontSize: 14, color: BioColors.tealLight),
              ),
              if (_error == null) ...[
                const SizedBox(height: 28),
                const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: BioColors.tealLight,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 24),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _routed = false;
                    });
                    _resolve();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
