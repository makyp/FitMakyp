# FitMakyp 💜

**Tu entrenamiento, tu progreso y tus hábitos en un solo lugar, con una mascota que crece contigo.**

App móvil hecha con Flutter (Android, con versión web de demostración). Todos los datos se guardan
**solo en el teléfono**: no hay cuentas, servidores ni publicidad.

---

## ✨ Qué incluye

**Entrenamiento**
- Bienvenida guiada: crea una rutina inicial según días por semana, lugar (mancuernas o en casa), nivel y objetivo.
- Rutina semanal editable, biblioteca de 67 ejercicios con fotos o ilustraciones animadas de inicio y final.
- Sesión guiada con series, descansos con cuenta atrás, sonidos y avisos por voz.
- Calentamiento y estiramientos automáticos según los músculos del día ("Ya calenté" / "Omitir").
- Rutina matutina de **hipopresivos** de pie, guiada respiración a respiración con ilustración animada.
- **Boxeo para principiantes** con saco y pesas: 8 golpes y defensas ilustrados, rondas de 2 minutos y dos sesiones que se agregan a la semana.
- Rutinas con IA gratis ("copiar y pegar" en ChatGPT, Gemini o Claude; sin enviar datos personales).
- Récords, fuerza estimada y reporte PDF para el entrenador (fotos opcionales y desactivadas por defecto).

**Progreso**
- Peso, medidas, estatura e IMC orientativo; silueta que cambia con tus medidas.
- Fotos de progreso con **cámara guiada** (silueta y foto anterior en transparencia) y comparador.
- Registro diario de ánimo, energía y descanso, con gráfica en el tiempo.
- Seguimiento opcional del ciclo menstrual (fases, síntomas, aviso antes de la regla).
- Tarjeta "Mi mes" para guardar o compartir.

**Hábitos**
- Agua con recordatorios (también desde el widget) y hábitos personalizados.

**Motivación**
- Mascota con nivel, tienda de ropa y accesorios, y acciones (bailar, entrenar, voltereta…).
- Rachas, 21 insignias, metas y **retos semanales** con premios exclusivos.
- Widgets de Android: "Mi día" (con botón de agua), "Mi mascota" y "Solo mi mascota".
- Modo claro/oscuro y textos personalizados según el sexo elegido.

## 🔒 Privacidad

- Todo se guarda en el dispositivo. Las fotos nunca salen del teléfono salvo que la persona las comparta.
- El ciclo, las fotos, el peso y las medidas **no** se incluyen en lo que se copia para la IA.
- Copia de seguridad manual (archivo `.json`) desde Perfil.
- IMC y ciclo son **orientativos**: la app no da diagnósticos médicos.

## 📲 Instalar (Android)

Descarga el APK desde la sección **Releases** del repositorio:

| Archivo | Para quién |
|---|---|
| `FitMakyp.apk` | Casi todos los teléfonos (arm64) |
| `FitMakyp-telefonos-antiguos.apk` | Teléfonos antiguos de 32 bits, si el primero no se instala |

Ábrelo en el teléfono y acepta "instalar apps de origen desconocido".

## 🛠️ Desarrollo

Requisitos: [Flutter](https://flutter.dev) 3.4x o superior y Android Studio (SDK de Android).

Todo se ejecuta dentro de la carpeta `app`:

| Qué | Comando |
|---|---|
| Ejecutar en un Android conectado o emulador | `flutter run` |
| Ejecutar en el navegador | `flutter run -d chrome` |
| Pruebas automáticas (95) | `flutter test` |
| Análisis del código | `flutter analyze` |
| APK ligero por tipo de teléfono | `flutter build apk --release --split-per-abi` |
| Versión web | `flutter build web --release` |

### Estructura

```
app/
  lib/
    main.dart, home_shell.dart, app_scope.dart   arranque, navegación y servicios
    core/          modelos, datos iniciales (ejercicios y rutinas), almacenamiento, notificaciones, tema
    features/      una carpeta por función:
                   workout, plans, library, history, evolution, goals, pet, habits, morning,
                   boxing, cycle, challenges, summary, report, onboarding, home_widgets…
    shared/        widgets comunes (mascota, gráficas, fotos)
  android/         incluye los widgets de inicio (Kotlin)
  assets/          fotos de ejercicios y calentamiento, sonidos
  test/            pruebas automáticas
  tool/            scripts para procesar imágenes e iconos
```

La lógica importante (máquina de estados del entrenamiento, puntos, retos, ciclo, boxeo…)
es Dart puro en las carpetas `domain/` y tiene pruebas.

## 🙏 Créditos

- Fotos de ejercicios: [Free Exercise DB](https://github.com/yuhonas/free-exercise-db) (dominio público, Unlicense).
- Mascota, ilustraciones de hipopresivos y boxeo, siluetas e iconos: dibujados en código para esta app.
