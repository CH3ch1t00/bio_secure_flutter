import docx
from docx.shared import Pt, Inches, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.section import WD_SECTION
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

doc = docx.Document()

# --- Estilos base (APA 7) ---
normal = doc.styles['Normal']
normal.font.name = 'Times New Roman'
normal.font.size = Pt(12)
normal.paragraph_format.line_spacing = 2.0
normal.paragraph_format.space_after = Pt(0)
normal.paragraph_format.space_before = Pt(0)
normal.paragraph_format.first_line_indent = Inches(0.5)

# Márgenes 1 pulgada
for section in doc.sections:
    section.top_margin = Inches(1)
    section.bottom_margin = Inches(1)
    section.left_margin = Inches(1)
    section.right_margin = Inches(1)

# Número de página en encabezado (esquina superior derecha)
def add_page_number(paragraph):
    run = paragraph.add_run()
    fldChar1 = OxmlElement('w:fldChar')
    fldChar1.set(qn('w:fldCharType'), 'begin')
    instrText = OxmlElement('w:instrText')
    instrText.set(qn('xml:space'), 'preserve')
    instrText.text = 'PAGE'
    fldChar2 = OxmlElement('w:fldChar')
    fldChar2.set(qn('w:fldCharType'), 'end')
    run._r.append(fldChar1)
    run._r.append(instrText)
    run._r.append(fldChar2)

for section in doc.sections:
    header = section.header
    p = header.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    add_page_number(p)

def set_run(run, bold=False, italic=False, size=12, name='Times New Roman'):
    run.font.name = name
    run.font.size = Pt(size)
    run.bold = bold
    run.italic = italic

def heading1(text):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.first_line_indent = Inches(0)
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(0)
    r = p.add_run(text)
    set_run(r, bold=True)
    return p

def heading2(text):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    p.paragraph_format.first_line_indent = Inches(0)
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(0)
    r = p.add_run(text)
    set_run(r, bold=True)
    return p

def para(text, indent=True, bold_lead=None, italic=False):
    p = doc.add_paragraph()
    if not indent:
        p.paragraph_format.first_line_indent = Inches(0)
    if bold_lead:
        r = p.add_run(bold_lead)
        set_run(r, bold=True)
    r = p.add_run(text)
    set_run(r, italic=italic)
    return p

def bullet(text, lead=None):
    p = doc.add_paragraph(style='List Bullet')
    p.paragraph_format.line_spacing = 2.0
    p.paragraph_format.first_line_indent = Inches(0)
    p.paragraph_format.left_indent = Inches(0.5)
    if lead:
        r = p.add_run(lead)
        set_run(r, bold=True)
    r = p.add_run(text)
    set_run(r)
    return p

# ============================================================
# PORTADA (APA 7)
# ============================================================
# Título en el tercio superior
for _ in range(4):
    doc.add_paragraph().paragraph_format.line_spacing = 2.0

title_p = doc.add_paragraph()
title_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
title_p.paragraph_format.first_line_indent = Inches(0)
r = title_p.add_run('BioSecure Flutter: Control de asistencia biométrica')
set_run(r, bold=True)
r.font.size = Pt(12)

author_p = doc.add_paragraph()
author_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
author_p.paragraph_format.first_line_indent = Inches(0)
r = author_p.add_run('CH3ch1t00')
set_run(r)

affil_p = doc.add_paragraph()
affil_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
affil_p.paragraph_format.first_line_indent = Inches(0)
r = affil_p.add_run('Migración multiplataforma Android → Flutter')
set_run(r)

course_p = doc.add_paragraph()
course_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
course_p.paragraph_format.first_line_indent = Inches(0)
r = course_p.add_run('Proyecto de migración y presentación técnica')
set_run(r)

instr_p = doc.add_paragraph()
instr_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
instr_p.paragraph_format.first_line_indent = Inches(0)
r = instr_p.add_run('Repositorio: https://github.com/CH3ch1t00/bio_secure_flutter')
set_run(r)

date_p = doc.add_paragraph()
date_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
date_p.paragraph_format.first_line_indent = Inches(0)
r = date_p.add_run('Noviembre, 2026')
set_run(r)

doc.add_page_break()

# ============================================================
# RESUMEN (Abstract)
# ============================================================
heading1('Resumen')

para('BioSecure Flutter es la migración multiplataforma de la aplicación Android '
     'BioSecure (Kotlin + Jetpack Compose) a Flutter, manteniendo el mismo backend '
     '(Firebase Authentication y Cloud Firestore) y el esquema de datos original. '
     'La aplicación registra la asistencia de empleados mediante huella digital y '
     'reconocimiento facial, validando la ubicación GPS dentro del radio de la sede '
     'asignada. Incluye roles de administrador y empleado, gestión de sedes, turnos '
     'y empleados, historial con filtros y exportación CSV, enrolamiento facial local, '
     'código QR personal y ajustes de preferencias. El proyecto se entrega con '
     'análisis estático sin errores, APK debug instalado en dispositivo y repositorio '
     'público en GitHub.', indent=False)

para('Palabras clave: asistencia biométrica, Flutter, Firebase, reconocimiento facial, '
     'huella digital, GPS, migración multiplataforma.', indent=False, italic=True, bold_lead='Palabras clave: ')

doc.add_page_break()

# ============================================================
# CUERPO
# ============================================================
heading1('Introducción')

para('La aplicación original BioSecure funcionaba únicamente en Android y estaba '
     'construida con Kotlin, Jetpack Compose y Firebase. Se planteó la necesidad '
     'de una versión multiplataforma que mantuviera la misma experiencia de usuario '
     'y las reglas de negocio, sin sobrescribir la aplicación original durante la '
     'transición.')

heading2('Problema y motivación')

para('La dependencia de una sola plataforma limitaba el alcance de la solución y '
     'dificultaba la adopción en entornos con dispositivos iOS. Además, la '
     'coexistencia con la app original era un requisito para no interrumpir el '
     'servicio existente.')

heading2('Solución propuesta')

para('Se desarrolló BioSecure Flutter con Flutter 3.47, Riverpod para gestión de '
     'estado, GoRouter para navegación y Firebase como backend. La aplicación se '
     'instala junto a la original gracias a un applicationId distinto '
     '(com.biosecure.bio_secure_flutter) y se muestra al usuario como '
     '"Biosecure Flutter".')

heading1('Arquitectura')

para('La arquitectura sigue un patrón por capas:')

bullet('UI (features): pantallas organizadas por rol (auth, admin, employee, '
       'settings, shared).', lead='Capa de presentación. ')
bullet('Providers (Riverpod): estado reactivo y repositorios inyectados.', lead='Capa de estado. ')
bullet('Repositories: acceso a Firestore, Auth, preferencias locales.', lead='Capa de datos. ')
bullet('Firebase: Authentication y Cloud Firestore (proyecto biosecure2).', lead='Backend. ')

para('Los modelos principales son BioUser, Attendance, Sede, Shift y Company. La '
     'navegación se gestiona con GoRouter y un PopScope global intercepta el '
     'botón físico "Atrás" del dispositivo para navegar internamente en lugar de '
     'minimizar la aplicación.')

heading1('Funcionalidades principales')

heading2('Módulo de empleado')

bullet('Marcar asistencia con huella digital (biometría del dispositivo).')
bullet('Marcar asistencia con reconocimiento facial (cámara + ML Kit) tras enrolamiento.')
bullet('Validación GPS (≤50 m y dentro del radio de la sede asignada).')
bullet('Código QR personal (visualización y compartición en PNG).')
bullet('Historial propio con filtros y resumen.')
bullet('Enrolamiento facial guiado (3 capturas: frente, izquierda, derecha).')
bullet('Ajustes: tema claro/oscuro, notificaciones, contraseña.')

heading2('Módulo de administrador')

bullet('Panel con métricas, filtro por sede y gráfico semanal de asistencia.')
bullet('Auditoría de puntualidad (puntuales, tardanzas, sin registro).')
bullet('Gestión de empleados: alta, edición, activar/desactivar, asignar sede y turno.')
bullet('Gestión de sedes: CRUD con geocerca (latitud, longitud, radio 20–500 m) y editor visual con mapa.')
bullet('Gestión de turnos: CRUD con horario y tolerancia, asignación de empleados.')
bullet('Escaneo QR de empleados con verificación.')
bullet('Historial completo con filtros por estado/sede y exportación CSV.')
bullet('Configuración de empresa (nombre, hora de entrada, tolerancia).')

heading1('Seguridad')

bullet('Reglas de Firestore: los empleados solo actualizan fcmToken, phone e image; '
       'los administradores gestionan su empresa.')
bullet('La asistencia se valida en cliente y en reglas (GPS, sede, duplicados, '
       'check-out).')
bullet('La biometría se delega al sistema del dispositivo; no se almacenan '
       'plantillas en el servidor.')
bullet('El enrolamiento facial se guarda localmente en el teléfono.')
bullet('Repositorio público en GitHub sin secretos sensibles (.gitignore).')

heading1('Migración técnica (Android → Flutter)')

bullet('ViewModels (Kotlin) → Providers (Riverpod).', lead='Estado. ')
bullet('Jetpack Compose → Widgets de Flutter.', lead='UI. ')
bullet('CameraX + ML Kit → camera + google_mlkit_face_detection.', lead='Cámara. ')
bullet('BiometricPrompt/Keystore → local_auth.', lead='Biometría. ')
bullet('ZXing → mobile_scanner / qr_flutter.', lead='QR. ')
bullet('DataStore → shared_preferences.', lead='Preferencias. ')
bullet('Push (FCM) y widget de escritorio: pendiente.', lead='Pendiente. ')

heading1('Bugs resueltos durante la migración')

bullet('no_fragment_activity → MainActivity extiende FlutterFragmentActivity.')
bullet('Firebase: nueva app "Biosecure Flutter" en proyecto biosecure2 (appId y SHA-1 nuevos).')
bullet('Cámara bloqueada al pasar de enrolamiento a marcado → dispose explícito + reintento.')
bullet('Botón físico "Atrás" minimizaba la app → PopScope global con fallback por rol.')
bullet('Enrolamiento facial no persistía → flags locales + fotos en documentos de la app.')
bullet('Correo "no válido" al iniciar sesión → normalización (minúsculas, sin espacios).')
bullet('Lag del reloj/cámara en marcado → reloj aislado + detección facial rápida con throttle.')

heading1('Resultados')

bullet('flutter analyze: 0 errores.')
bullet('APK debug construido e instalado en dispositivo (Huawei CLK-LX3).')
bullet('APK release construido (100.8 MB) y optimizado.')
bullet('Aplicación lanzada y verificada (PID activo).')
bullet('Repositorio público en GitHub: https://github.com/CH3ch1t00/bio_secure_flutter')

heading1('Roadmap y pendientes')

bullet('Mapa visual de sedes con OpenStreetMap (sin API key) — implementado.')
bullet('Notificaciones push (FCM) y widget de escritorio.')
bullet('Sincronización offline.')
bullet('Renombrar proyecto Atlas y crear colecciones (acción del usuario).')
bullet('Tests automatizados y CI/CD.')

heading1('Demo sugerida (5 minutos)')

para('1. Inicio de sesión.\n'
     '2. Panel del empleado.\n'
     '3. Marcar asistencia con huella.\n'
     '4. Enrolar rostro.\n'
     '5. Marcar asistencia con rostro.\n'
     '6. Panel del administrador (métricas, sedes, turnos).\n'
     '7. Historial y exportación CSV.')

heading1('Conclusión')

para('BioSecure Flutter permite el control de asistencia biométrica de forma '
     'multiplataforma, manteniendo paridad funcional con la aplicación Android '
     'original. El código está disponible públicamente en GitHub y la aplicación '
     'está instalada y operativa en dispositivo Android.')

# Guardar
out = r'D:\bio_secure_flutter\docs\INFORME_PRESENTACION_APA.docx'
doc.save(out)
print('Guardado:', out)