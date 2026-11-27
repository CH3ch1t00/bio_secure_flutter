# BioSecure Flutter (Migración multiplataforma)

Proyecto Flutter creado en `D:\bio_secure_flutter` a partir de la app Android
original (`D:\BioSecure-repo`), sin mover la carpeta original. La app se instala
junto a la app de Android Studio porque usa un `applicationId` distinto
(`com.biosecure.bio_secure_flutter`) y se muestra como **"Biosecure Flutter"**.

## Stack
- Flutter 3.47.x (stable), Dart 3.x
- Firebase Auth + Cloud Firestore (proyecto `biosecure2`)
- Riverpod (estado), GoRouter (navegación), Material 3
- ML Kit (detección facial), Camera, Geolocator, local_auth (huella)
- QR (qr_flutter + mobile_scanner), fl_chart, share_plus

> La app NO se conecta a MongoDB Atlas (solo pruebas externas). Los datos viven
> en Firestore (colecciones `users`, `attendances`, `companies`, `sedes`,
> `shifts`, `notifications`).

## Funcionalidades implementadas
- **Auth**: email/contraseña y Google Sign-In; splash con animación; recordar
  último correo.
- **Roles**: admin y empleado con navegación por pestañas (bottom bar).
- **Panel empleado**: saludo, fecha, avatar, empresa, estado de hoy (sin
  registro / tardanza / completado), rendimiento semanal, acciones rápidas.
- **Panel admin**: métricas (empleados/asistieron/tardanzas/puntuales/sin
  registro/salidas), filtro por sede, alertas, gráfico semanal, auditoría de
  puntualidad, registros de hoy, 8 acciones rápidas.
- **Marcar asistencia**: huella (biometría) y facial ( cámara + ML Kit), tabs
  segmentados, reloj en vivo, validación GPS (≤50 m y dentro del radio de la
  sede), confirmación previa, diálogo de éxito, marcar salida.
- **Enrolamiento facial**: 3 capturas guiadas (frente/izquierda/derecha) con
  validación ML Kit (exactamente 1 rostro), guardado local, re-enrolamiento y
  borrado.
- **Sedes**: CRUD con geocerca (lat/lng/radio 20–500 m), activar/desactivar,
  usar ubicación actual.
- **Turnos**: CRUD con horario y tolerancia, asignación de empleados por turno.
- **Empleados**: listado, búsqueda, filtros, editar perfil, activar/desactivar,
  asignar sede/turno, eliminar, registro con QR.
- **Historial**: empleado y admin, filtros por estado/sede, búsqueda, resumen,
  exportar CSV compartiendo archivo.
- **QR personal**: mostrar y compartir PNG, copiar UID.
- **Escanear QR (admin)**: verificación con diálogo de resultado.
- **Ajustes**: modo oscuro, notificaciones, enrolamiento facial con fecha,
  cambiar contraseña, info de privacidad/cómo funciona, cerrar sesión.
- **Botón físico "Atrás"**: navega internamente (pop o panel del rol) en lugar
  de minimizar la app.
- **Tema**: paleta original BioSecure (GreenDark/Teal) en claro y oscuro.
- **Icono**: huella sobre fondo teal; nombre "Biosecure Flutter".

## Build
```bash
flutter pub get
flutter analyze
flutter build apk --debug
```
APK generado en `build/app/outputs/flutter-apk/app-debug.apk`.

## Instalación (ADB)
```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.biosecure.bio_secure_flutter/com.biosecure.bio_secure_flutter.MainActivity
```

## Pendiente / próximos pasos
- Google Maps para editor visual de sedes/geocercas (coords manuales por ahora).
- Notificaciones push (FCM) y widget de escritorio.
- Reglas/sincronización offline.
- Renombrar proyecto Atlas "Project 0" → "Biosecure" y crear colecciones
  (acción del usuario en la consola de Atlas).
