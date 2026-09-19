# Tawyers (Musify Modular)

Documento vivo de arquitectura, cambios realizados y planificación para futuras iteraciones del proyecto.

---

## 🟢 Fase 1: Cambios e Implementaciones Realizadas (Completado)

### 1.1 Entorno de Compilación, Seguridad y SDKs
- [x] **Actualización de Flutter y Dart**: Subida a **Flutter 3.47.5** y **Dart 3.13.4**.
- [x] **Ajustes de Gradle y JVM**: Configuración de target dinámico Java 17 / Kotlin JVM 17 y optimización de memoria RAM (`-Xmx2048m`) en `android/gradle.properties` para evitar bloqueos del SO.
- [x] **Protección de Firma y Git**: Reglas en `.gitignore` para proteger certificados `*.jks` y `key.properties`. Soporte para rutas externas de firmas.
- [x] **Verificación y Versión**: Versión actualizada a `10.5.0` en `pubspec.yaml`, `flutter analyze` en 0 errores y compilación exitosa del APK Release (`app-fdroid-release.apk` de 33.9 MB).

### 1.2 Arquitectura Modular de Plugins en JavaScript (QuickJS Engine)
- [x] **Inclusión de `flutter_js`**: Integración del motor nativo C de QuickJS en `pubspec.yaml`.
- [x] **`PluginEngine` (`lib/services/plugin_engine.dart`)**:
  - Puente nativo HTTP `fetch()` asíncrono sin *deadlocks* en QuickJS.
  - User-Agent nativo `okhttp/4.12.0` para evitar bloqueos HTTP 403 (Cloudflare/TuneIn/iHeart).
  - Evaluador rápido y sincrónico en QuickJS con logs limpios etiquetados como `🔌 [PLUGIN]`.
- [x] **`PluginManager` (`lib/services/plugin_manager.dart`)**:
  - Carga de plugins embebidos desde `assets/plugins/`.
  - Persistencia de estados en Hive (`plugin_settings`).
  - Resolvedor nativo de URLs intermedias (`Tune.ashx`, `.pls`, `.m3u`).
- [x] **Interfaz de Gestión (`lib/screens/plugins_page.dart`)**:
  - Ubicada en **Ajustes > Gestor de Plugins** (Oculta la sección remota en V1).
  - Opción para ingresar/editar una **URL de Lista M3U / M3U8 Personalizada**.

### 1.3 Plugins Integrados en V1 (`assets/plugins/*.js`)
- [x] **`iheartradio.js`**: Traducido de `TestExtensionIHR.kt` (Búsqueda, catálogo por géneros, selección HLS > Shoutcast > PLS, y parser `.pls`).
- [x] **`tunein.js`**: Traducido de `TestExtensionTUNE.kt` (OPML API `opml.radiotime.com`, estaciones locales y resolvedor de enlaces `Tune.ashx`).
- [x] **`iptv_audio.js`**: Traducido de Echo IPTV (Parser `#EXTINF`, logos, géneros, cabeceras custom VLCOPT/EXTHTTP e índice `index.m3u`).
- [x] **`radio_browser.js`**: Integración con el directorio abierto de RadioBrowser (Top 30 por países).

### 1.4 Arranque Instantáneo, Música Local y UI Adaptativa
- [x] **Arranque ultra-rápido (<0.2s)**: La app abre en la Librería/Modo Local sin esperar respuestas de red.
- [x] **`LocalMusicService` (`lib/services/local_music_service.dart`)**:
  - Guardado de carpeta local en **Ajustes > Carpeta de Música Local** y escaneo recursivo de audio (`.mp3`, `.m4a`, `.flac`, `.wav`, `.aac`, `.ogg`).
- [x] **Home con Píldoras / Tabs**:
  - Píldoras en la parte superior (`Offline`, `YouTube`, e íconos de plugins activos) con renderizado de contenido según la pestaña seleccionada.
- [x] **Buscador Inteligente Multi-Fuente (`SearchPage`)**:
  - Modal de **Fuentes de Búsqueda** con selección múltiple (Música Local, YouTube, Plugins).
  - Ocultamiento inmediato de sugerencias al presionar *Enter* y timer de seguridad de 7s para el spinner.
- [x] **Reproductor Inmersivo Adaptativo (`NowPlayingPage`)**:
  - Distinción visual para **`TRANSMISIÓN EN VIVO`** (desactiva skip/repeat/lyrics/descargas pero permite guardar en biblioteca y agregar a favoritos).
- [x] **MiniPlayer Flotante**:
  - Botón de **Corazón / Favorito** directo en la barra flotante.
- [x] **Librería y Modal "Guardar en..."**:
  - Modal emergente con la opción por defecto **`Raíz de la Librería (Liked Items)`** y botón **Aceptar**.
  - Lista de **`Liked Items`** (Elementos Favoritos) que reúne canciones y emisoras.
  - Historiales separados: **`History Song`** y **`History Streaming`** (con opción de deslizar para eliminar `Dismissible`).
- [x] **Navegación Adaptativa para Tablets (`BottomNavigationPage`)**:
  - Modo Retrato: Menú de navegación abajo (`NavigationBar`).
  - Modo Panorámica/Horizontal: Menú lateral izquierdo (`NavigationRail`) con padding superior.
- [x] **Internacionalización Completa (i18n)**:
  - Todas las cadenas traducidas en `app_en.arb` y `app_es.arb` para evitar mezcla de idiomas.

---

## 🔥 Fase 2: PRIORIDAD #1 INMEDIATA — Limpieza, Refactorización y Arquitectura Limpia

> **Objetivo de la Fase 2**: Limpiar la deuda técnica, desacoplar dependencias globales y convertir los archivos monolíticos en módulos limpios, testeables e independientes. Esto es lo que marcará la diferencia en rendimiento, fluidez y mantenibilidad de la aplicación.

### 2.1 Inyección de Dependencias (DI)
- [ ] **Introducción de contenedor DI (`GetIt`)**:
  - Registrar todos los servicios (`AudioService`, `PluginManager`, `LocalMusicService`, `SettingsManager`) centralizadamente.
  - Eliminar instancias globales sueltas como `audioHandler` o variables top-level globales.

### 2.2 Descomposición de Archivos Monolíticos
- [ ] **Dividir `lib/services/audio_service.dart` (~3,100 líneas)**:
  - `AudioQueueManager`: Exclusivo para gestión de colas, orden, shuffle e historial de reproducción.
  - `AudioPreloader`: Precarga de streams de audio de YouTube/servicios en segundo plano.
  - `EqualizerController`: Control y configuración del ecualizador.
  - `MusifyAudioHandler`: Exclusivamente para callbacks del servicio de audio nativo de Android y notificaciones.
- [ ] **Dividir `lib/services/playlists_manager.dart` (~1,500 líneas)**:
  - Desacoplar funciones de manejo de listas locales de los widgets y vistas.
- [ ] **Dividir `lib/services/common_services.dart` (~1,200 líneas)**:
  - Separar en `YouTubeSearchService`, `SponsorBlockService` y `StreamResolverService`.

### 2.3 Capa de Repositorios (Data Abstraction Layer)
- [ ] **Abstraer acceso a datos (Hive)**:
  - Crear `SongRepository`, `PlaylistRepository`, `RadioRepository` y `SettingsRepository`.
  - Evitar que la UI y los servicios hagan llamadas directas a `getData(...)` o `Hive.box(...)`.

---

## 🟡 Fase 3: Futuras Mejoras de Branding, Nube y Metadatos en Vivo (Backlog)

### 3.1 Branding & Identidad Visual
- [ ] **Rediseño del Ícono Principal ("T" de Tawyers)**:
  - Diseñar el nuevo logo basado en la nota musical donde la varilla y el corchete formen la letra **"T"**.
  - Actualizar assets nativos (`ic_launcher` e `ic_launcher_adaptive_fore`).

### 3.2 Extensión del Sistema de Plugins (V2 Remota)
- [ ] **Sincronización de Plugins desde Repositorio GitHub**:
  - Descarga y actualización remota de plugins `.js`.
- [ ] **Estandarización de Íconos por Nombre (`iconName`)**:
  - Mapear nombres vectoriales (`'radio'`, `'tv'`, `'music'`, `'podcast'`) a íconos compilados de Flutter.
- [ ] **Módulo de YouTube como Plugin JS**:
  - Convertir la lógica de extracción de YouTube a un plugin `youtube.js` desacoplado.

### 3.3 Metadatos ICY/Shoutcast en Vivo para Streaming
- [ ] **Parsing de Metadatos ICY/ID3 en Vivo**:
  - Integrar parsing de metadatos de transmisiones de audio en vivo (cabecera ICY `StreamTitle` / ID3v2 tags en streams Icecast/Shoutcast/HLS) usando librerías como `music-metadata`.
  - Actualizar en tiempo real el título de la canción que está sonando en vivo en la radio dentro de la pantalla **Now Playing** y **MiniPlayer**.

### 3.4 Respaldo y Persistencia
- [ ] **Respaldo Automático en Nube (Google Drive)**:
  - Sincronización transparente de `user.hive` en Google Drive.
