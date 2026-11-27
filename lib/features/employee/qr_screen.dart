import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/firebase_errors.dart';
import '../../core/providers.dart';
import '../../core/widgets/bio_app_bar.dart';

class QrScreen extends ConsumerStatefulWidget {
  const QrScreen({super.key});
  @override
  ConsumerState<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends ConsumerState<QrScreen> {
  final _qrKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('No se pudo capturar el QR.');
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw Exception('No se pudo generar la imagen.');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/biosecure_qr.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          subject: 'Mi código QR BioSecure',
          text: 'Mi código QR personal de BioSecure.',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FirebaseErrors.message(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const BioAppBar(title: 'Mi QR', fallbackRoute: '/employee'),
      body: Center(
        child: profile.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text(FirebaseErrors.message(e), textAlign: TextAlign.center),
          ),
          data: (u) {
            if (u == null) return const Text('Sin perfil');
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: colors.primaryContainer,
                    child: Text(
                      u.initials,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    u.fullName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    u.email,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 22),
                  RepaintBoundary(
                    key: _qrKey,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          QrImageView(
                            data: u.uid,
                            version: QrVersions.auto,
                            size: 236,
                            backgroundColor: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'BioSecure',
                            style: TextStyle(
                              color: Color(0xFF0D3B35),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            u.fullName,
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Muestra este código al administrador para verificar tu '
                    'asistencia.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _sharing ? null : _share,
                    icon: _sharing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.share),
                    label: const Text('Compartir QR'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: u.uid));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('UID copiado.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar mi UID'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
