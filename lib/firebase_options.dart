// Configuración de Firebase del proyecto "biosecure2".
//
// En Android los valores también están en `android/app/google-services.json`.
// Se declaran aquí de forma explícita para que `Firebase.initializeApp()`
// funcione igual en Android, web y escritorio (en web `main.dart` sin
// `FirebaseOptions` lanzaba:
// "FirebaseOptions cannot be null when creating the default app").
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBgkKofFD__7LMHp7CbfisXumtchOZbkXg',
    appId: '1:103319710145:android:346c1703229cedfcc52740',
    messagingSenderId: '103319710145',
    projectId: 'biosecure2',
    storageBucket: 'biosecure2.firebasestorage.app',
  );

  // Configuración "best effort" para web usando el mismo proyecto. Para una
  // app web de producción hay que registrar una app Web en Firebase Console y
  // reemplazar `appId`/`authDomain` por los valores reales.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBgkKofFD__7LMHp7CbfisXumtchOZbkXg',
    appId: '1:103319710145:android:346c1703229cedfcc52740',
    messagingSenderId: '103319710145',
    projectId: 'biosecure2',
    authDomain: 'biosecure2.firebaseapp.com',
    storageBucket: 'biosecure2.firebasestorage.app',
  );
}
