import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/firebase_errors.dart';
import '../../core/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLastEmail();
  }

  Future<void> _loadLastEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString('last_email') ?? '';
    if (!mounted) return;
    if (last.isNotEmpty && _email.text.isEmpty) {
      _email.text = last;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _afterLogin(String uid) async {
    final u = await ref.read(userRepositoryProvider).getUser(uid);
    if (u == null) {
      throw Exception(
        'Tu cuenta existe en Firebase Auth pero no tiene perfil en Firestore. '
        'Pide a un administrador que te registre.',
      );
    }
    ref.invalidate(currentProfileProvider);
    if (!mounted) return;
    context.go(u.isAdmin ? '/admin' : '/employee');
  }

  Future<void> _loginEmail() async {
    if (_email.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Escribe tu correo y contraseña.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cred = await ref
          .read(authRepositoryProvider)
          .signInWithEmail(_email.text.trim(), _pass.text);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_email', _email.text.trim());
      await _afterLogin(cred.user!.uid);
    } catch (e) {
      setState(() => _error = FirebaseErrors.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Escribe tu correo para enviarte el enlace.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Te enviamos un correo a $email para restablecer la contraseña.')),
      );
    } catch (e) {
      setState(() => _error = FirebaseErrors.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cred = await ref.read(authRepositoryProvider).signInWithGoogle();
      if (cred == null) return;
      await ref
          .read(userRepositoryProvider)
          .ensureProfileFromAuth(cred.user!);
      await _afterLogin(cred.user!.uid);
    } catch (e) {
      setState(() => _error = FirebaseErrors.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Encabezado teal con el pingüino, igual que la app original.
            Container(
              width: double.infinity,
              color: colors.primary,
              padding: EdgeInsets.only(
                top: topInset + 28,
                bottom: 44,
                left: 24,
                right: 24,
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/penguin_login.png',
                    height: 110,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'BioSecure',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sistema de Asistencia Biométrica',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            // Tarjeta de login superpuesta al encabezado.
            Transform.translate(
              offset: const Offset(0, -24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Card(
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Iniciar Sesión',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _pass,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _loading ? null : _loginEmail(),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.error_outline,
                                      color: colors.onErrorContainer, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: TextStyle(
                                          color: colors.onErrorContainer),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _loading ? null : _loginEmail,
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Iniciar Sesión'),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('o',
                                    style: TextStyle(
                                        color: colors.onSurfaceVariant)),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 18),
                          OutlinedButton.icon(
                            onPressed: _loading ? null : _loginGoogle,
                            icon: const Icon(Icons.g_mobiledata, size: 28),
                            label: const Text('Iniciar sesión con Google'),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: _loading ? null : _resetPassword,
                            child: const Text('¿Olvidaste tu contraseña?'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
