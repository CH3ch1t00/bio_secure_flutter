import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import 'firebase_errors.dart';

/// Inicialización central de Firebase.
///
/// Se guarda el error (si lo hay) para mostrarlo en una pantalla clara en vez
/// de que la app se quede en blanco o crashee.
class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static String? error;

  static bool get isReady => error == null && Firebase.apps.isNotEmpty;

  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      // Cache local: permite seguir leyendo datos sin conexión, con un límite
      // razonable para no consumir almacenamiento/memoria en exceso.
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 100 * 1024 * 1024,
      );
      error = null;
    } catch (e) {
      error = FirebaseErrors.message(e);
    }
  }
}
