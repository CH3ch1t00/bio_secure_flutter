"""Genera la presentacion en PowerPoint (PPTX) para exponer BioSecure Flutter."""
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.enum.shapes import MSO_SHAPE

GREEN_DARK = RGBColor(0x0D, 0x3B, 0x35)
TEAL = RGBColor(0x00, 0xB4, 0xA6)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
GRAY = RGBColor(0x59, 0x59, 0x59)

prs = Presentation()
# 16:9
prs.slide_width = Inches(13.333)
prs.slide_height = Inches(7.5)

BLANK = prs.slide_layouts[6]  # blank
TITLE_CONTENT = prs.slide_layouts[1]  # title + content

def style_title(tf):
    for p in tf.paragraphs:
        for r in p.runs:
            r.font.color.rgb = GREEN_DARK
            r.font.size = Pt(32)
            r.font.bold = True
            r.font.name = 'Calibri'

def add_title_slide(title, subtitle):
    slide = prs.slides.add_slide(BLANK)
    # fondo
    bg = slide.background.fill
    bg.solid()
    bg.fore_color.rgb = GREEN_DARK
    # banda teal inferior
    band = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0), Inches(6.2), Inches(13.333), Inches(1.3))
    band.fill.solid()
    band.fill.fore_color.rgb = TEAL
    band.line.fill.background()
    # titulo
    tb = slide.shapes.add_textbox(Inches(0.8), Inches(2.0), Inches(11.7), Inches(1.6))
    tf = tb.text_frame
    p = tf.paragraphs[0]
    r = p.add_run()
    r.text = title
    r.font.size = Pt(44)
    r.font.bold = True
    r.font.color.rgb = WHITE
    r.font.name = 'Calibri'
    p.alignment = PP_ALIGN.LEFT
    # subtitulo
    tb2 = slide.shapes.add_textbox(Inches(0.8), Inches(3.7), Inches(11.7), Inches(1.2))
    tf2 = tb2.text_frame
    p2 = tf2.paragraphs[0]
    r2 = p2.add_run()
    r2.text = subtitle
    r2.font.size = Pt(20)
    r2.font.color.rgb = WHITE
    r2.font.name = 'Calibri'
    # linea decorativa
    line = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0.8), Inches(3.55), Inches(4.0), Inches(0.06))
    line.fill.solid()
    line.fill.fore_color.rgb = TEAL
    line.line.fill.background()
    return slide

def add_content_slide(title, bullets, subtitle=None):
    slide = prs.slides.add_slide(TITLE_CONTENT)
    # titulo
    title_shape = slide.shapes.title
    title_shape.text = title
    style_title(title_shape.text_frame)
    # contenido
    body = slide.placeholders[1]
    tf = body.text_frame
    tf.word_wrap = True
    first = True
    for b in bullets:
        if first:
            p = tf.paragraphs[0]
            first = False
        else:
            p = tf.add_paragraph()
        p.text = b
        p.level = 0
        for r in p.runs:
            r.font.size = Pt(18)
            r.font.name = 'Calibri'
            r.font.color.rgb = RGBColor(0x26, 0x26, 0x26)
        p.space_after = Pt(6)
    if subtitle:
        note = slide.notes_slide.notes_text_frame
        note.text = subtitle
    return slide

def add_section_slide(title, subtitle):
    slide = prs.slides.add_slide(BLANK)
    bg = slide.background.fill
    bg.solid()
    bg.fore_color.rgb = TEAL
    tb = slide.shapes.add_textbox(Inches(0.8), Inches(2.6), Inches(11.7), Inches(1.6))
    tf = tb.text_frame
    p = tf.paragraphs[0]
    r = p.add_run()
    r.text = title
    r.font.size = Pt(40)
    r.font.bold = True
    r.font.color.rgb = WHITE
    r.font.name = 'Calibri'
    tb2 = slide.shapes.add_textbox(Inches(0.8), Inches(4.3), Inches(11.7), Inches(1.0))
    tf2 = tb2.text_frame
    p2 = tf2.paragraphs[0]
    r2 = p2.add_run()
    r2.text = subtitle
    r2.font.size = Pt(18)
    r2.font.color.rgb = WHITE
    r2.font.name = 'Calibri'
    return slide

# ---------- Slides ----------
add_title_slide(
    'BioSecure Flutter',
    'Control de asistencia biométrica · Migración multiplataforma Android → Flutter\n'
    'Repositorio: github.com/CH3ch1t00/bio_secure_flutter'
)

add_content_slide('Resumen ejecutivo', [
    'App móvil para registro de asistencia con huella digital y reconocimiento facial.',
    'Valida la ubicación GPS del empleado dentro del radio de su sede.',
    'Migrada desde la app Android original (Kotlin + Jetpack Compose + Firebase) a Flutter.',
    'Mismo backend (Firebase/Firestore) y mismo esquema de datos.',
    'Instalable junto a la app original (applicationId distinto) como "Biosecure Flutter".',
])

add_content_slide('Problema / Motivación', [
    'La app original solo funcionaba en Android.',
    'Se buscaba una versión multiplataforma (Android + iOS + Web/Desktop).',
    'Necesidad de mantener coexistencia con la app original durante la transición.',
    'Dependencia de una sola plataforma limitaba el alcance y la adopción.',
])

add_content_slide('Solución propuesta', [
    'Flutter 3.47 + Riverpod + GoRouter + Firebase.',
    'Mismo esquema Firestore: users, attendances, companies, sedes, shifts, notifications.',
    'Autenticación Firebase (email/contraseña + Google).',
    'Roles admin/empleado con navegación por pestañas.',
    'applicationId distinto: com.biosecure.bio_secure_flutter.',
])

add_section_slide('Arquitectura', 'Capas y tecnologías principales')

add_content_slide('Arquitectura por capas', [
    'Presentación: pantallas organizadas por rol (auth, admin, employee, settings).',
    'Estado: Providers con Riverpod (reactivo, inyectado).',
    'Datos: Repositories para Firestore, Auth y preferencias locales.',
    'Backend: Firebase Authentication y Cloud Firestore (proyecto biosecure2).',
    'Modelos: BioUser, Attendance, Sede, Shift, Company.',
    'Navegación: GoRouter + PopScope global para el botón físico "Atrás".',
    'Tema: paleta original BioSecure (GreenDark/Teal) en claro y oscuro (Material 3).',
])

add_section_slide('Funcionalidades', 'Módulos de empleado y administrador')

add_content_slide('Módulo de empleado', [
    'Marcar asistencia con huella digital (biometría del dispositivo).',
    'Marcar asistencia con rostro (cámara + ML Kit) tras enrolamiento.',
    'Validación GPS (≤ 50 m y dentro del radio de la sede).',
    'Código QR personal (visualización y compartición en PNG).',
    'Historial propio con filtros y resumen.',
    'Enrolamiento facial guiado (3 capturas: frente, izquierda, derecha).',
    'Ajustes: tema claro/oscuro, notificaciones, contraseña.',
])

add_content_slide('Módulo de administrador', [
    'Panel con métricas, filtro por sede y gráfico semanal de asistencia.',
    'Auditoría de puntualidad (puntuales, tardanzas, sin registro).',
    'Gestión de empleados: alta, edición, activar/desactivar, asignar sede y turno.',
    'Gestión de sedes: CRUD con geocerca (radio 20–500 m) y editor visual con mapa.',
    'Gestión de turnos: CRUD con horario y tolerancia, asignación de empleados.',
    'Escaneo QR de empleados con verificación.',
    'Historial completo con filtros y exportación CSV.',
    'Configuración de empresa.',
])

add_content_slide('Seguridad', [
    'Reglas de Firestore: empleados solo actualizan fcmToken, phone e image.',
    'Los administradores gestionan su empresa.',
    'Asistencia validada en cliente y en reglas (GPS, sede, duplicados, check-out).',
    'Biometría delegada al sistema del dispositivo; no se almacenan plantillas en el servidor.',
    'Enrolamiento facial guardado localmente en el teléfono.',
    'Repositorio público en GitHub sin secretos sensibles (.gitignore).',
])

add_section_slide('Migración', 'Android (Kotlin) → Flutter')

add_content_slide('Migración técnica', [
    'ViewModels (Kotlin) → Providers (Riverpod). [Estado]',
    'Jetpack Compose → Widgets de Flutter. [UI]',
    'CameraX + ML Kit → camera + google_mlkit_face_detection. [Cámara]',
    'BiometricPrompt/Keystore → local_auth. [Biometría]',
    'ZXing → mobile_scanner / qr_flutter. [QR]',
    'DataStore → shared_preferences. [Preferencias]',
    'Push (FCM) y widget de escritorio: pendiente.',
])

add_content_slide('Bugs resueltos durante la migración', [
    'no_fragment_activity → MainActivity extiende FlutterFragmentActivity.',
    'Firebase: nueva app "Biosecure Flutter" en proyecto biosecure2.',
    'Cámara bloqueada al pasar de enrolamiento a marcado → dispose + reintento.',
    'Botón físico "Atrás" minimizaba la app → PopScope global con fallback por rol.',
    'Enrolamiento facial no persistía → flags locales + fotos en documentos.',
    'Correo "no válido" al iniciar sesión → normalización (minúsculas, sin espacios).',
    'Lag del reloj/cámara → reloj aislado + detección facial rápida con throttle.',
])

add_content_slide('Resultados', [
    'flutter analyze: 0 errores.',
    'APK debug construido e instalado (Huawei CLK-LX3).',
    'APK release construido (100.8 MB) y optimizado.',
    'Aplicación lanzada y verificada.',
    'Repositorio público: github.com/CH3ch1t00/bio_secure_flutter',
])

add_content_slide('Roadmap y pendientes', [
    'Mapa visual de sedes (OpenStreetMap) — implementado.',
    'Notificaciones push (FCM) y widget de escritorio.',
    'Sincronización offline.',
    'Renombrar proyecto Atlas y crear colecciones (acción del usuario).',
    'Tests automatizados y CI/CD.',
])

add_content_slide('Demo sugerida (5 minutos)', [
    '1. Inicio de sesión.',
    '2. Panel del empleado.',
    '3. Marcar asistencia con huella.',
    '4. Enrolar rostro.',
    '5. Marcar asistencia con rostro.',
    '6. Panel del administrador (métricas, sedes, turnos).',
    '7. Historial y exportación CSV.',
])

add_title_slide(
    'Conclusión',
    'BioSecure Flutter permite el control de asistencia biométrica de forma multiplataforma,\n'
    'manteniendo paridad funcional con la app Android original.\n'
    'Código abierto · github.com/CH3ch1t00/bio_secure_flutter\n\n¡Gracias!'
)

out = r'D:\bio_secure_flutter\docs\PRESENTACION_BIOSECURE.pptx'
prs.save(out)
print('Guardado:', out)
print('Slides:', len(prs.slides))
