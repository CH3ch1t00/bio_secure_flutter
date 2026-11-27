# Informe de Presentación — BioSecure Flutter

> Migración multiplataforma de la app Android BioSecure a Flutter.
> Repositorio: https://github.com/CH3ch1t00/bio_secure_flutter (público)
> App instalada: "Biosecure Flutter" (`com.biosecure.bio_secure_flutter`)

---

## Página 1 — Portada
- **Título:** BioSecure Flutter — Control de asistencia biométrica
- **Subtítulo:** Migración de Android (Jetpack Compose) a Flutter (multiplataforma)
- **Autor / Fecha / Versión:** v1.0.0 (build debug)
- **Repositorio:** github.com/CH3ch1t00/bio_secure_flutter

## Página 2 — Resumen ejecutivo
- App móvil para registro de asistencia con **huella digital y reconocimiento facial**, validando la ubicación GPS del empleado dentro del radio de su sede.
- Migrada desde la app Android original (Kotlin + Jetpack Compose + Firebase) a **Flutter**, manteniendo el mismo backend (Firebase/Firestore) y esquema de datos.
- Instalable junto a la app original (applicationId distinto) y con nombre "Biosecure Flutter".

## Página 3 — Problema / Motivación
- La app original solo funcionaba en Android.
- Se buscaba una versión **multiplataforma** (Android + iOS + Web/Desktop) con la misma UX y reglas de negocio.
- Necesidad de mantener coexistencia con la app original durante la transición (no sobrescribirla).

## Página 4 — Solución propuesta
- Flutter 3.47 + Riverpod + GoRouter + Firebase.
- Mismo esquema Firestore (`users`, `attendances`, `companies`, `sedes`, `shifts`, `notifications`).
- Autenticación Firebase (email/contraseña + Google).
- Roles admin/empleado con navegación por pestañas.

## Página 5 — Arquitectura
- **Capas:** UI (features) → Providers (Riverpod) → Repositories → Firebase.
- **Modelos:** `BioUser`, `Attendance`, `Sede`, `Shift`, `Company`.
- **Navegación:** GoRouter con rutas por rol y `PopScope` global para el botón físico "Atrás".
- **Tema:** paleta original BioSecure (GreenDark/Teal) en claro y oscuro (Material 3).

## Página 6 — Funcionalidades clave (empleado)
- Marcar asistencia con huella (biometría del dispositivo).
- Marcar asistencia con rostro (cámara + ML Kit) tras enrolamiento.
- Validación GPS (≤50 m y dentro del radio de la sede).
- Mi QR personal (compartir PNG).
- Historial propio con filtros y resumen.
- Enrolamiento facial (3 capturas guiadas).
- Ajustes (tema, notificaciones, contraseña).

## Página 7 — Funcionalidades clave (administrador)
- Panel con métricas, filtro por sede y gráfico semanal.
- Auditoría de puntualidad (puntuales/tardanzas/sin registro).
- Gestión de empleados (alta, edición, activar/desactivar, asignar sede/turno).
- Gestión de sedes (CRUD + geocerca).
- Gestión de turnos (CRUD + asignación de empleados).
- Escaneo QR de empleados.
- Historial completo con filtros y exportación CSV.
- Configuración de empresa.

## Página 8 — Seguridad y reglas
- Firestore Rules: empleados solo actualizan `fcmToken/phone/image`; admins gestionan su empresa.
- Asistencia validada en cliente + reglas (GPS, sede, duplicados, check-out).
- Biometría delegada al sistema del dispositivo (no se almacenan plantillas en servidor).
- Enrolamiento facial guardado **localmente** en el teléfono.
- App privada→pública en GitHub sin secretos sensibles (`.gitignore`).

## Página 9 — Migración técnica (Android → Flutter)
- ViewModels (Kotlin) → Providers (Riverpod).
- Jetpack Compose → Widgets Flutter.
- CameraX/ML Kit → `camera` + `google_mlkit_face_detection`.
- BiometricPrompt/Keystore → `local_auth`.
- ZXing → `mobile_scanner`/`qr_flutter`.
- DataStore prefs → `shared_preferences`.
- WorkManager/FCM → (pendiente: push y widget).

## Página 10 — Bugs resueltos durante la migración
- `no_fragment_activity` → `MainActivity` extiende `FlutterFragmentActivity`.
- Firebase: nueva app "Biosecure Flutter" en proyecto `biosecure2` (appId nuevo, SHA-1 debug).
- Cámara bloqueada al pasar de enrolamiento a marcado → dispose explícito + reintento.
- Botón físico "Atrás" minimizaba la app → `PopScope` global con fallback por rol.
- Face enrollment no persistía → flags locales + fotos en documentos de la app.

## Página 11 — Resultados
- `flutter analyze`: 0 errores.
- APK debug construido e instalado en dispositivo (Huawei CLK-LX3).
- App lanzada y verificada (PID activo).
- Repositorio público en GitHub.

## Página 12 — Roadmap / pendientes
- Google Maps para editor visual de sedes.
- Notificaciones push (FCM) y widget de escritorio.
- Sincronización offline.
- Renombrar proyecto Atlas y crear colecciones (acción del usuario).
- Tests automatizados y CI/CD.

## Página 13 — Demo / capturas
- (Insertar screenshots: login, panel empleado, marcar huella/facial, panel admin, sedes, turnos, historial, QR, ajustes.)

## Página 14 — Cierre
- BioSecure Flutter permite control de asistencia biométrica multiplataforma.
- Mantiene paridad funcional con la app Android original.
- Código abierto: https://github.com/CH3ch1t00/bio_secure_flutter

---

### Notas para la presentación
- **Audiencia técnica:** enfatizar arquitectura, Riverpod, GoRouter, reglas Firestore.
- **Audiencia de negocio:** enfatizar UX, seguridad, GPS, coexistencia con app original.
- **Demo sugerida (5 min):** login → panel empleado → marcar huella → enrolar rostro → marcar facial → panel admin → métricas/sedes/turnos.
