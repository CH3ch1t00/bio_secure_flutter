import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/firebase_errors.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bio_app_bar.dart';
import '../../core/widgets/bio_bottom_bar.dart';

/// Enrolamiento facial con 3 capturas guiadas y validación con ML Kit.
class EnrollScreen extends ConsumerStatefulWidget {
  const EnrollScreen({super.key});
  @override
  ConsumerState<EnrollScreen> createState() => _EnrollScreenState();
}

class _EnrollScreenState extends ConsumerState<EnrollScreen> {
  static const int _target = 3;
  static const _steps = [
    ('Mira al frente', 'Coloca tu rostro centrado y con buena luz.'),
    ('Gira levemente a la izquierda', 'Mantén el rostro dentro del círculo.'),
    ('Gira levemente a la derecha', 'Última captura para completar el perfil.'),
  ];

  int _captured = 0;
  final List<String> _capturedPaths = [];
  bool _busy = false;
  String? _error;
  bool _enrolled = false;
  int _enrolledAt = 0;

  CameraController? _controller;
  CameraDescription? _cameraDescription;
  FaceDetector? _detector;
  bool _cameraReady = false;
  bool _cameraError = false;
  String _cameraErrorMessage = '';

  @override
  void initState() {
    super.initState();
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.12,
      ),
    );
    _loadStatus();
    _initCamera();
  }

  Future<void> _loadStatus() async {
    final uid = ref.read(currentProfileProvider).value?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _enrolled = prefs.getBool('face_enrolled_$uid') ?? false;
      _enrolledAt = prefs.getInt('face_enrolled_at_$uid') ?? 0;
      final saved = prefs.getStringList('face_refs_$uid') ?? const [];
      if (_captured == 0 && saved.isNotEmpty) {
        _capturedPaths
          ..clear()
          ..addAll(saved);
        _captured = saved.length.clamp(0, _target);
      }
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraError = true;
          _cameraErrorMessage =
              'Este dispositivo no tiene una cámara disponible.';
        });
        return;
      }
      CameraDescription? front;
      for (final c in cameras) {
        if (c.lensDirection == CameraLensDirection.front) {
          front = c;
          break;
        }
      }
      _cameraDescription = front ?? cameras.first;
      final controller = CameraController(
        _cameraDescription!,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _cameraReady = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = true;
        _cameraErrorMessage = 'No se pudo iniciar la cámara: $e';
      });
    }
  }

  String _friendlyError(Object e) {
    final raw = e.toString().replaceFirst('Exception: ', '');
    // Evitar textos enormes (stack traces / platform exceptions).
    if (raw.length > 140) {
      return 'No se pudo capturar la foto. Revisa la cámara y vuelve a intentarlo.';
    }
    if (raw.toLowerCase().contains('camera')) {
      return 'La cámara tuvo un problema. Pulsa "Reiniciar cámara" e inténtalo de nuevo.';
    }
    return raw;
  }

  Future<void> _retryCamera() async {
    setState(() {
      _cameraReady = false;
      _cameraError = false;
      _cameraErrorMessage = '';
    });
    final ctrl = _controller;
    _controller = null;
    try {
      await ctrl?.dispose();
    } catch (_) {}
    await _initCamera();
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_busy || _captured >= _target) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final xfile = await _controller!.takePicture();
      // En algunos dispositivos takePicture deja la vista previa congelada.
      try {
        await _controller?.resumePreview();
      } catch (_) {}

      // Validación con ML Kit: exactamente un rostro.
      final faces = await _detector!.processImage(
        InputImage.fromFilePath(xfile.path),
      );
      if (faces.isEmpty) {
        throw Exception(
          'No se detectó tu rostro. Acércate y mejora la iluminación.',
        );
      }
      if (faces.length > 1) {
        throw Exception('Solo debe aparecer una persona en la foto.');
      }

      final profile = await ref.read(currentProfileProvider.future);
      if (profile == null) throw Exception('Sin perfil de usuario.');

      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory(
        p.join(dir.path, 'face_enrollment', profile.uid),
      );
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
      final dest = p.join(folder.path, 'ref_${_captured + 1}.jpg');
      await File(xfile.path).copy(dest);

      setState(() {
        _captured++;
        _capturedPaths.add(dest);
      });
    } catch (e) {
      final msg = _friendlyError(e);
      if (mounted) setState(() => _error = msg);
      // Si la cámara se quedó congelada, la reiniciamos.
      if (_controller != null && !_cameraError) {
        try {
          await _controller?.dispose();
        } catch (_) {}
        _controller = null;
        _cameraReady = false;
        await _initCamera();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (_captured < _target) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await ref.read(currentProfileProvider.future);
      if (profile == null) throw Exception('Sin perfil de usuario.');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('face_enrolled_${profile.uid}', true);
      await prefs.setInt(
        'face_enrolled_at_${profile.uid}',
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setStringList('face_refs_${profile.uid}', _capturedPaths);

      // Liberar la cámara y el detector antes de navegar para evitar que la
      // cámara quede bloqueada en la siguiente pantalla (bug de cámara).
      final ctrl = _controller;
      _controller = null;
      _cameraReady = false;
      await ctrl?.dispose();
      final det = _detector;
      _detector = null;
      await det?.close();

      if (!mounted) return;
      setState(() {
        _enrolled = true;
        _enrolledAt = DateTime.now().millisecondsSinceEpoch;
      });
      await _showDone();
      if (!mounted) return;
      context.go('/employee/scan');
    } catch (e) {
      if (mounted) {
        setState(() => _error = FirebaseErrors.message(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showDone() async {
    final colors = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: BioColors.successGreen.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.face_retouching_natural,
            size: 40,
            color: BioColors.successGreen,
          ),
        ),
        title: const Text('Rostro enrolado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tu rostro quedó registrado en este teléfono. '
              'Ya puedes marcar asistencia en modo facial.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Capturas: $_target / $_target',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/employee');
            },
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ir a marcar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEnrollment() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar enrolamiento'),
        content: const Text(
          'Se eliminarán las fotos de referencia y deberás enrolar tu rostro '
          'de nuevo para usar el modo facial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final profile = await ref.read(currentProfileProvider.future);
      if (profile == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('face_enrolled_${profile.uid}');
      await prefs.remove('face_enrolled_at_${profile.uid}');
      await prefs.remove('face_refs_${profile.uid}');
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory(
        p.join(dir.path, 'face_enrollment', profile.uid),
      );
      if (await folder.exists()) await folder.delete(recursive: true);
      if (!mounted) return;
      setState(() {
        _enrolled = false;
        _enrolledAt = 0;
        _captured = 0;
        _capturedPaths.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enrolamiento eliminado.')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = FirebaseErrors.message(e));
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _detector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final step = _steps[_captured.clamp(0, _target - 1)];
    final dateText = _enrolledAt > 0
        ? ' · ${_fmtDate(DateTime.fromMillisecondsSinceEpoch(_enrolledAt))}'
        : '';

    return Scaffold(
      appBar: const BioAppBar(
        title: 'Enrolar rostro',
        fallbackRoute: '/employee',
      ),
      bottomNavigationBar:
          const BioBottomBar(isAdmin: false, currentRoute: '/employee'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        children: [
          if (_enrolled)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BioColors.successGreen.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: BioColors.successGreen.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: BioColors.successGreen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Rostro enrolado$dateText. Puedes volver a capturarlo '
                      'si cambias de apariencia.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          if (_enrolled) const SizedBox(height: 14),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _cameraError ? colors.error : colors.primary,
                      width: 3,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _cameraError
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              _cameraErrorMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.error),
                            ),
                          ),
                        )
                      : (!_cameraReady || _controller == null)
                          ? const Center(child: CircularProgressIndicator())
                          : CameraPreview(_controller!),
                ),
                if (_busy)
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Paso ${(_captured + 1).clamp(1, _target)} de $_target: ${step.$1}',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            step.$2,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: _captured / _target,
            borderRadius: BorderRadius.circular(8),
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Text(
            'Capturas: $_captured / $_target',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          if (_cameraError) ...[
            OutlinedButton.icon(
              onPressed: _busy ? null : _retryCamera,
              icon: const Icon(Icons.refresh),
              label: const Text('Reiniciar cámara'),
            ),
            const SizedBox(height: 8),
          ],
          if (_captured < _target)
            FilledButton.icon(
              onPressed:
                  (_busy || !_cameraReady || _cameraError) ? null : _capture,
              icon: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt),
              label: Text(_busy ? 'Validando rostro…' : 'Capturar foto'),
            )
          else
            FilledButton.icon(
              onPressed: _busy ? null : _finish,
              icon: const Icon(Icons.check),
              label: const Text('Finalizar enrolamiento'),
            ),
          if (_captured > 0 && _captured < _target) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {
                        _captured = 0;
                        _capturedPaths.clear();
                      });
                    },
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reiniciar capturas'),
            ),
          ],
          if (_enrolled) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                side: BorderSide(color: colors.error),
              ),
              onPressed: _busy ? null : _deleteEnrollment,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Borrar enrolamiento'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: colors.onErrorContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Tus fotos de referencia se guardan solo en este teléfono y se '
            'usan para verificar tu rostro al marcar asistencia.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}
