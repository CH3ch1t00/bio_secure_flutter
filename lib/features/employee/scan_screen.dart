import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/firebase_errors.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/bio_bottom_bar.dart';
import '../../data/models/attendance.dart';
import '../../data/models/sede_shift.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});
  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  int _selectedTab = 0; // 0 = Huella, 1 = Facial

  bool _busy = false;
  String? _error;
  DateTime _now = DateTime.now();
  Timer? _clock;

  CameraController? _cameraController;
  CameraDescription? _cameraDescription;
  FaceDetector? _faceDetector;
  bool _cameraReady = false;
  bool _cameraError = false;
  String _cameraErrorMessage = '';
  bool _faceDetected = false;
  String _faceHint = '';
  bool _processingFace = false;
  bool _faceStreamStarted = false;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: false,
        minFaceSize: 0.15,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _stopFaceStream();
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  Future<Position> _position() async {
    final service = await Geolocator.isLocationServiceEnabled();
    if (!service) {
      throw Exception('Activa el GPS del teléfono para marcar.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Permiso de ubicación denegado.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicación bloqueado. Actívalo en Ajustes.');
    }

    Position? best;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            timeLimit: Duration(seconds: 12),
          ),
        );
        if (best == null || pos.accuracy < best.accuracy) best = pos;
        if (best.accuracy <= 50) return best;
      } catch (_) {}
    }

    if (best == null) {
      throw Exception(
        'No se pudo obtener tu ubicación. Sal al aire libre y vuelve a intentarlo.',
      );
    }
    throw Exception(
      'GPS con baja precisión (${best.accuracy.toStringAsFixed(0)} m). '
      'Sal al aire libre y vuelve a intentarlo.',
    );
  }

  Future<void> _biometric() async {
    final auth = LocalAuthentication();
    final supported = await auth.isDeviceSupported();
    if (!supported) {
      throw Exception(
        'Este dispositivo no tiene huella configurada. Usa el modo facial.',
      );
    }
    final ok = await auth.authenticate(
      localizedReason: 'Confirma tu identidad para marcar asistencia',
      options: const AuthenticationOptions(
        biometricOnly: false,
        stickyAuth: true,
      ),
    );
    if (!ok) throw Exception('Autenticación cancelada.');
  }

  Future<void> _confirmCheckIn({required String type}) async {
    final label = type == 'HUELLA' ? 'huella digital' : 'reconocimiento facial';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          type == 'HUELLA' ? Icons.fingerprint : Icons.face_retouching_natural,
          size: 44,
          color: Theme.of(ctx).colorScheme.primary,
        ),
        title: const Text('Confirmar entrada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Vas a registrar tu entrada con $label.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.my_location,
                    size: 18,
                    color: Theme.of(ctx).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Validaremos que estés dentro del radio de tu sede.',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            Theme.of(ctx).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok == true) await _checkIn(type: type);
  }

  Future<void> _checkIn({required String type}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await ref.read(currentProfileProvider.future);
      if (profile == null) throw Exception('Sin perfil de usuario.');
      if (profile.companyId.isEmpty) {
        throw Exception(
          'Tu perfil no está vinculado a una empresa. Contacta al administrador.',
        );
      }
      if ((profile.sedeId ?? '').isEmpty) {
        throw Exception(
          'No tienes una sede asignada. Contacta al administrador.',
        );
      }

      if (type == 'FACIAL') {
        if (!_faceDetected) {
          throw Exception(
            'Verifica tu rostro antes de confirmar la asistencia.',
          );
        }
        final prefs = await SharedPreferences.getInstance();
        final enrolled = prefs.getBool('face_enrolled_${profile.uid}') ?? false;
        if (!enrolled) {
          throw Exception(
            'Aún no enrolaste tu rostro. Ve a "Enrolar rostro" primero.',
          );
        }
      }

      final pos = await _position();
      if (pos.accuracy > 50) {
        throw Exception(
          'GPS con baja precisión (${pos.accuracy.toStringAsFixed(1)} m). '
          'Acércate a la sede e inténtalo de nuevo.',
        );
      }

      final attendance =
          await ref.read(attendanceRepositoryProvider).registerCheckIn(
                user: profile,
                latitude: pos.latitude,
                longitude: pos.longitude,
                accuracy: pos.accuracy,
                type: type,
                isMock: pos.isMocked,
                confirm: type == 'HUELLA' ? _biometric : null,
              );

      if (!mounted) return;
      await _showSuccess(attendance, isCheckOut: false);
      if (!mounted) return;
      context.go('/employee');
    } catch (e) {
      if (mounted) setState(() => _error = FirebaseErrors.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkOut(Attendance today) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.logout,
          size: 44,
          color: Theme.of(ctx).colorScheme.primary,
        ),
        title: const Text('Registrar salida'),
        content: Text(
          'Tu entrada fue a las ${today.checkIn}. '
          '¿Deseas registrar tu salida ahora?',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Registrar salida'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(attendanceRepositoryProvider).registerCheckOut(today.id);
      if (!mounted) return;
      final now = DateFormat('HH:mm').format(DateTime.now());
      await _showSuccess(
        Attendance(
          id: today.id,
          userId: today.userId,
          companyId: today.companyId,
          sedeId: today.sedeId,
          userName: today.userName,
          date: today.date,
          checkIn: today.checkIn,
          checkOut: now,
          status: today.status,
          type: today.type,
          location: today.location,
        ),
        isCheckOut: true,
      );
      if (!mounted) return;
      context.go('/employee');
    } catch (e) {
      if (mounted) setState(() => _error = FirebaseErrors.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showSuccess(
    Attendance attendance, {
    required bool isCheckOut,
  }) async {
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
            Icons.check_rounded,
            size: 44,
            color: BioColors.successGreen,
          ),
        ),
        title: Text(isCheckOut ? 'Salida registrada' : 'Entrada registrada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ResultRow(
              icon: Icons.person_outline,
              label: 'Empleado',
              value: attendance.userName,
            ),
            _ResultRow(
              icon: Icons.login,
              label: 'Entrada',
              value: attendance.checkIn,
            ),
            if (isCheckOut)
              _ResultRow(
                icon: Icons.logout,
                label: 'Salida',
                value: attendance.checkOut,
              ),
            _ResultRow(
              icon: Icons.place_outlined,
              label: 'Sede',
              value: attendance.location,
            ),
            _ResultRow(
              icon: Icons.verified_outlined,
              label: 'Estado',
              value: attendance.status,
              valueColor: attendance.status == 'TARDANZA'
                  ? BioColors.warnOrange
                  : BioColors.successGreen,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  // ---- Cámara facial ----
  void _stopFaceStream() {
    try {
      _cameraController?.stopImageStream();
    } catch (_) {}
    _faceStreamStarted = false;
    _processingFace = false;
  }

  Future<void> _initCamera() async {
    if (_cameraReady) return;
    // Disponer cualquier controlador previo antes de crear uno nuevo.
    final old = _cameraController;
    _cameraController = null;
    _cameraReady = false;
    try {
      await old?.dispose();
    } catch (_) {}
    if (_cameraError && _cameraController == null) {
      // permitir reintento
    }
    if (_cameraReady) return;
    setState(() {
      _cameraError = false;
      _cameraErrorMessage = '';
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraError = true;
          _cameraErrorMessage = 'Este dispositivo no tiene una cámara disponible.';
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
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _cameraReady = true;
      });
      _startFaceStream();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = true;
        _cameraErrorMessage = 'No se pudo iniciar la cámara: $e';
      });
    }
  }

  Future<void> _retryCamera() async {
    setState(() {
      _cameraReady = false;
      _cameraError = false;
      _cameraErrorMessage = '';
      _faceDetected = false;
      _faceHint = '';
    });
    await _initCamera();
  }


  void _startFaceStream() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }
    if (_faceStreamStarted) return;
    _faceStreamStarted = true;
    _cameraController!.startImageStream((CameraImage image) async {
      if (_processingFace) return;
      _processingFace = true;
      try {
        final inputImage = _inputImageFromCameraImage(
          image,
          _cameraDescription!,
        );
        if (inputImage != null && _faceDetector != null) {
          final faces = await _faceDetector!.processImage(inputImage);
          if (!mounted) return;
          setState(() {
            if (faces.isEmpty) {
              _faceDetected = false;
              _faceHint = 'Coloca tu rostro frente a la cámara';
            } else if (faces.length > 1) {
              _faceDetected = false;
              _faceHint = 'Solo una persona a la vez';
            } else {
              _faceDetected = true;
              _faceHint = 'Rostro detectado · listo para marcar';
            }
          });
        }
      } catch (_) {
        // ignorar errores puntuales de análisis
      } finally {
        _processingFace = false;
      }
    });
  }

  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraDescription camera,
  ) {
    try {
      final bytes = Uint8List.fromList([
        for (final Plane plane in image.planes) ...plane.bytes,
      ]);
      final Size imageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final InputImageRotation imageRotation =
          InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
              InputImageRotation.rotation0deg;
      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: InputImageFormat.yuv_420_888,
        bytesPerRow: image.planes.first.bytesPerRow,
      );
      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (_) {
      return null;
    }
  }

  void _onTabChanged(int index) {
    setState(() => _selectedTab = index);
    if (index == 1) {
      _initCamera();
    } else {
      _stopFaceStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayAttendanceProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final colors = Theme.of(context).colorScheme;
    final shifts = ref.watch(shiftsProvider).value ?? const <Shift>[];
    final sedes = ref.watch(sedesProvider).value ?? const <Sede>[];

    String shiftText = 'Sin turno asignado';
    for (final s in shifts) {
      if (s.id == profile?.shiftId) {
        shiftText = '${s.name} · ${s.startTime} - ${s.endTime}';
      }
    }
    String sedeText = 'Sin sede asignada';
    for (final s in sedes) {
      if (s.id == profile?.sedeId) {
        sedeText = '${s.nombre} · radio ${s.radioMetros} m';
      }
    }

    return Scaffold(
      bottomNavigationBar:
          const BioBottomBar(isAdmin: false, currentRoute: '/employee/scan'),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Marcar asistencia',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        DateFormat("EEEE, d 'de' MMMM", 'es')
                            .format(_now),
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    DateFormat('HH:mm:ss').format(_now),
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Selector Huella / Facial.
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.fingerprint),
                  label: Text('Huella'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.face_retouching_natural),
                  label: Text('Facial'),
                ),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (s) => _onTabChanged(s.first),
            ),
            const SizedBox(height: 20),

            if (_selectedTab == 0)
              _FingerprintPanel(busy: _busy)
            else
              _FacePanel(
                cameraError: _cameraError,
                cameraErrorMessage: _cameraErrorMessage,
                cameraReady: _cameraReady,
                controller: _cameraController,
                faceDetected: _faceDetected,
                faceHint: _faceHint,
                onRetry: _retryCamera,
              ),

            const SizedBox(height: 18),
            today.when(
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    FirebaseErrors.message(e),
                    style: TextStyle(color: colors.error),
                  ),
                ),
              ),
              data: (a) => _TodayStatus(attendance: a),
            ),
            const SizedBox(height: 12),

            // Turno y sede.
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    _InfoLine(
                      icon: Icons.schedule,
                      label: 'Turno',
                      value: shiftText,
                    ),
                    const Divider(height: 14),
                    _InfoLine(
                      icon: Icons.location_on_outlined,
                      label: 'Sede',
                      value: sedeText,
                    ),
                  ],
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
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
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),

            today.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (a) {
                if (a == null) {
                  return Column(
                    children: [
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _confirmCheckIn(
                                  type: _selectedTab == 0 ? 'HUELLA' : 'FACIAL',
                                ),
                        icon: _busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _selectedTab == 0
                                    ? Icons.fingerprint
                                    : Icons.face_retouching_natural,
                              ),
                        label: Text(
                          _selectedTab == 0
                              ? 'Marcar entrada con huella'
                              : 'Marcar entrada con rostro',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Se validará tu ubicación GPS antes de registrar.',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                }
                if (!a.hasCheckedOut) {
                  return Column(
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _checkOut(a),
                        icon: _busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.logout),
                        label: const Text('Registrar salida'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tu entrada fue a las ${a.checkIn}.',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                }
                return OutlinedButton.icon(
                  onPressed: () => context.push('/employee/history'),
                  icon: const Icon(Icons.history),
                  label: const Text('Ver mi historial'),
                );
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/employee/qr'),
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Mi QR'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/employee/enroll'),
                    icon: const Icon(Icons.face_retouching_natural),
                    label: const Text('Enrolar rostro'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FingerprintPanel extends StatelessWidget {
  const _FingerprintPanel({required this.busy});
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Column(
          children: [
            Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primaryContainer.withValues(alpha: 0.55),
              ),
              child: Icon(
                Icons.fingerprint,
                size: 68,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              busy ? 'Verificando huella…' : 'Coloca tu dedo en el sensor',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Se abrirá el sensor biométrico del teléfono.',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _FacePanel extends StatelessWidget {
  const _FacePanel({
    required this.cameraError,
    required this.cameraErrorMessage,
    required this.cameraReady,
    required this.controller,
    required this.faceDetected,
    required this.faceHint,
    this.onRetry,
  });

  final bool cameraError;
  final String cameraErrorMessage;
  final bool cameraReady;
  final CameraController? controller;
  final bool faceDetected;
  final String faceHint;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget preview;
    if (cameraError) {
      preview = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                cameraErrorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.error),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => onRetry!(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar cámara'),
                ),
              ],
            ],
          ),
        ),
      );
    } else if (!cameraReady || controller == null) {
      preview = const Center(child: CircularProgressIndicator());
    } else {
      preview = CameraPreview(controller!);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(110),
                border: Border.all(
                  color: faceDetected
                      ? BioColors.successGreen
                      : (cameraError ? colors.error : colors.outline),
                  width: 3,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: preview,
            ),
            const SizedBox(height: 14),
            Text(
              cameraError
                  ? 'Cámara no disponible'
                  : (cameraReady
                      ? (faceHint.isEmpty ? 'Iniciando cámara…' : faceHint)
                      : 'Iniciando cámara…'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cameraError
                    ? colors.error
                    : (faceDetected
                        ? BioColors.successGreen
                        : colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Mantén tu rostro dentro del círculo y con buena luz.',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayStatus extends StatelessWidget {
  const _TodayStatus({required this.attendance});
  final Attendance? attendance;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final a = attendance;
    final (IconData icon, Color color, String title, String subtitle) = switch (a) {
      null => (
          Icons.info_outline,
          colors.primary,
          'Aún no has marcado tu entrada',
          'Usa tu huella o rostro y validaremos tu ubicación.',
        ),
      Attendance(hasCheckedOut: true, :final checkIn, :final checkOut) => (
          Icons.task_alt,
          BioColors.successGreen,
          'Jornada completada',
          'Entrada $checkIn · Salida $checkOut',
        ),
      Attendance(:final status, :final checkIn)
          when status == 'TARDANZA' =>
        (
          Icons.schedule,
          BioColors.warnOrange,
          'Entrada registrada (tardanza)',
          'Marcaste a las $checkIn',
        ),
      Attendance(:final checkIn, :final status) => (
          Icons.check_circle_outline,
          BioColors.successGreen,
          'Entrada registrada',
          'A las $checkIn · $status',
        ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 17, color: colors.primary),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
