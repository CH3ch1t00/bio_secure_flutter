import 'package:firebase_auth/firebase_auth.dart';

/// Traduce errores técnicos de Firebase a mensajes claros en español.
class FirebaseErrors {
  const FirebaseErrors._();

  static String message(Object error) {
    if (error is FirebaseAuthException) {
      return _auth(error.code, error.message);
    }
    if (error is FirebaseException) {
      return _firestore(error.code, error.message ?? '');
    }

    final raw = error.toString();
    final lower = raw.toLowerCase();

    if (lower.contains('permission-denied') || lower.contains('permission denied')) {
      return 'Firestore rechazó la operación (permisos). Revisa las reglas de seguridad del proyecto.';
    }
    if (lower.contains('unavailable') ||
        lower.contains('network') ||
        lower.contains('failed host lookup') ||
        lower.contains('socketexception')) {
      return 'Sin conexión con Firebase. Verifica tu internet e inténtalo de nuevo.';
    }
    if (lower.contains('not-found') || lower.contains('not found')) {
      return 'No se encontró la base de datos Firestore del proyecto.';
    }
    if (lower.contains('firebaseoptions cannot be null')) {
      return 'Falta la configuración de Firebase (FirebaseOptions).';
    }
    if (lower.contains('perfil no encontrado')) {
      return 'Tu cuenta existe en Firebase Auth pero no tiene perfil en Firestore. '
          'Pide a un administrador que te registre.';
    }
    return raw.replaceFirst('Exception: ', '');
  }

  static String _auth(String code, String? fallback) {
    switch (code) {
      case 'invalid-email':
        return 'El correo no es válido. Verifica que no tenga espacios ni caracteres especiales.';
      case 'user-disabled':
        return 'Esta cuenta fue deshabilitada.';
      case 'user-not-found':
        return 'No existe una cuenta con ese correo.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
      case 'network-request-failed':
        return 'Sin conexión. Revisa tu internet.';
      case 'operation-not-allowed':
        return 'El método de inicio de sesión no está habilitado en Firebase Console.';
      case 'weak-password':
        return 'La contraseña es demasiado débil (mínimo 6 caracteres).';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo.';
      default:
        return fallback?.replaceFirst('Exception: ', '') ?? 'Error de autenticación ($code).';
    }
  }

  static String _firestore(String code, String fallback) {
    switch (code) {
      case 'permission-denied':
        return 'Firestore rechazó la operación (permisos). Revisa las reglas de seguridad.';
      case 'unavailable':
        return 'Sin conexión con Firestore. Revisa tu internet.';
      case 'not-found':
        return 'No se encontró la base de datos Firestore del proyecto.';
      case 'failed-precondition':
        return 'Firestore no está listo. Puede faltar un índice o la base de datos.';
      case 'already-exists':
        return 'El registro ya existe.';
      case 'invalid-argument':
        return 'Datos inválidos para Firestore.';
      case 'deadline-exceeded':
        return 'Firestore tardó demasiado en responder.';
      case 'unauthenticated':
        return 'Tu sesión expiró. Vuelve a iniciar sesión.';
      default:
        return fallback.replaceFirst('Exception: ', '');
    }
  }
}
