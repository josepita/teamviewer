# Teamweaver

Editor visual de landings HTML inspirado en Macromedia/Adobe Dreamweaver (CS3-CS4). Pensado para retocar páginas estáticas alojadas en este mismo directorio sin tocar un IDE: abres una URL, eliges un archivo de un subdirectorio y editas en código, diseño o split simultáneo, con sincronización bidireccional.

Todo el cliente vive en un único archivo `editor.html` (~1.500 líneas, sin build step). El servidor es un Express mínimo que sirve el editor, lista archivos y lee/guarda en disco.

---

## Instalación en WSL (una sola línea)

Abre **Ubuntu** en WSL y pega esto:

```bash
curl -fsSL https://raw.githubusercontent.com/REPLACE_USER/REPLACE_REPO/main/install.sh | bash
```

El script:

1. Instala `git`, `curl` y Node.js LTS si faltan (pedirá tu contraseña de WSL una vez).
2. Clona el repo en `~/landings`.
3. Hace `npm install`.
4. Arranca el editor en `http://localhost:3333` y abre el navegador de Windows.

Para volver a arrancarlo otro día:

```bash
cd ~/landings && ./start-editor.sh
```

Para parar el servidor: **Ctrl+C** en la ventana de WSL.

---

## Cómo arrancarlo (manual / dev)

```bash
./start-editor.sh
# o, equivalentemente:
npm install
node server.js
```

Abre `http://localhost:3333`. El puerto se puede sobrescribir con `PORT=...`.

---

## Estructura del repo

```
landings/
├── editor.html              # Editor completo (HTML + CSS + JS, single-file)
├── server.js                # Express: sirve editor + API de ficheros
├── start-editor.sh          # Bootstrap (npm install + node server.js)
├── package.json             # Sólo express ^4.18
├── lasuperpapeleria/        # Landing de ejemplo (un proyecto por subdirectorio)
│   ├── productos-personalizados.html
│   ├── productos-personalizados2.html
│   └── 1.jpg ... 8.jpg
└── node_modules/
```

**Convención:** cada subdirectorio en la raíz es un "proyecto"; el editor lista automáticamente todos los `.html` que encuentre un nivel por debajo, agrupados por carpeta. Las imágenes y demás assets del proyecto se sirven bajo `/files/<proyecto>/`, y dentro del preview se inyecta un `<base href="/files/<proyecto>/">` para que los `src` relativos funcionen.

---

## Interfaz (chrome estilo Dreamweaver)

De arriba a abajo:

1. **Insert Bar** — Tres pestañas:
   - *Común*: imagen, enlace, email, tabla, div, HR, listas UL/OL, comentario.
   - *Texto*: párrafo, H1-H6, B/I/U/S, blockquote, pre, sub/superíndice.
   - *Diseño*: alineaciones, sangrías, `<section>`/`<article>`/`<aside>`/`<span>`.
2. **Document Toolbar** — Selector de archivo, botón Guardar (Ctrl+S), conmutador **Código / Dividir / Diseño** y estado a la derecha.
3. **Área principal** — Code panel (Ace) | gripper redimensionable | Preview (iframe sandbox).
4. **Tag Selector** — Breadcrumb en la status bar (`<html> › <body> › <section.hero> › <h1>`); click salta al elemento.
5. **Properties Inspector** — Panel contextual según el tag seleccionado:
   - `<img>`: thumb, src, width/height, alt, title, link.
   - `<a>`: href, target, title, class, rel.
   - `<h1>-<h6>` y genéricos: formato de bloque, B/I/U/S, alineación, color/fondo, ID, clase, link.

### Atajos

- **Ctrl/Cmd + S** — Guardar.
- **Click en el preview** — Selecciona el elemento en el código y abre sus propiedades.
- **Doble click / escribir en el preview** — Edita el texto directamente (designMode).

---

## API del servidor

| Método | Ruta                  | Función                                            |
| ------ | --------------------- | -------------------------------------------------- |
| GET    | `/`                   | Sirve `editor.html`.                               |
| GET    | `/files/*`            | Estáticos desde la raíz (imágenes, css, etc.).     |
| GET    | `/api/files`          | Lista `.html` en cada subdirectorio (no recursivo).|
| GET    | `/api/file?path=...`  | Lee `{ content }` de un archivo.                   |
| POST   | `/api/file`           | Escribe `{ path, content }` a disco.               |

Las rutas de fichero se resuelven contra `ROOT` y se rechaza cualquier `path` que escape (`..` o resolución fuera de `ROOT`).

---

## Cómo funciona por dentro

Tres piezas hacen que el "split" sea realmente bidireccional:

### 1. Inyección de marcadores de posición

Antes de meter el HTML en el iframe, `injectPositionMarkers(source)` recorre el código con un parser single-pass y añade a cada elemento dos atributos:

```html
<div data-src-start="123" data-src-end="456">…</div>
```

- `data-src-start` = índice del `<` de apertura en el código fuente.
- `data-src-end` = índice del `>` que **cierra el elemento completo** (el `>` de `</tag>` para elementos con cierre; el `>` del propio tag para void/self-close).

Esto permite que, dado cualquier nodo del iframe, se pueda calcular el rango exacto en el editor Ace y seleccionarlo (`source[srcStart..srcEnd+1]` = elemento completo).

El parser conoce los elementos void (`img`, `br`, `hr`, `input`, …), trata comentarios y DOCTYPE como opacos, y **salta el contenido raw de `<script>` y `<style>`** para no matchear `<` literales dentro de JS/CSS.

### 2. Sincronización código → preview (con debounce)

Cambios en Ace → `setTimeout(updatePreview, 350)` → `buildPreviewHTML()` reconstruye el documento con `<base>` + estilos de interacción (`#__ei__`) + marcadores → `frame.srcdoc = html` preservando `scrollX/Y`.

Si el archivo no es un documento completo (no empieza por `<!DOCTYPE>` ni `<html>`), se envuelve en un boilerplate mínimo.

### 3. Sincronización preview → código (in-place, sin recargar)

El iframe arranca con `designMode = 'on'`. Cualquier `input` dispara `onVisualInput` que, tras un debounce de 700 ms (o 250 ms para cambios desde el Properties Inspector), llama a `syncVisualToCode`:

1. Clona el `document` del iframe, borra los `data-src-*` y los estilos inyectados.
2. Si el archivo era un documento completo, sustituye sólo el contenido de `<body>` en el código original (preserva head, scripts, etc.).
3. Hace `editor.setValue(newContent)` con un flag `visualSyncing` para no retroalimentar el `change` listener.
4. **Refresca markers in-place** (`refreshMarkersInPlace`): vuelve a parsear el código nuevo y reasigna `data-src-start/end` a cada elemento del iframe **sin recargar el iframe**, así no se pierde la posición de scroll ni el caret.

### Selección unificada

`selectElement(el)` es el único punto de entrada para "seleccionar un elemento":

- Resalta el preview con `outline` y `.--sel`.
- Marca el rango en Ace usando dos markers (full-line + texto exacto).
- Repinta el breadcrumb y el Properties Inspector según el tag.
- Si llega de un click pero hay un sync pendiente en el debounce, lo fuerza primero (`syncIfPending`) para que los offsets estén al día.

---

## Limitaciones conocidas

- **HTML malformado**: el parser asume que cierra todo lo que abre. Cierres implícitos (`<p>` dentro de `<p>`, `<li>` sin cierre, etc.) pueden desalinear el stack y dejar elementos sin `data-src-end`.
- **`<script>` / `<style>` editados visualmente**: el sync sólo reemplaza el `<body>` del documento completo, por lo que cambios dentro de `<head>` desde el iframe no se persisten en el código (y tampoco al revés si se editan a mano en Ace deberían romper nada, pero no se reflejan visualmente sin recarga).
- **`document.execCommand`**: el WYSIWYG depende de la API obsoleta `execCommand`. Funciona en navegadores actuales pero está deprecada y puede generar HTML con etiquetas viejas (`<font>`, `<b>` vs `<strong>`, …).
- **Sin historial / undo cross-panel**: el undo de Ace y el del iframe son independientes.
- **Sin auth**: el servidor sirve sólo en `localhost`. No exponerlo.

---

## Por qué se llama Teamweaver

Guiño al editor original (Dreamweaver) más el equipo. El logo y el chrome (gradientes grises, bordes 1px, gripper de columna, segmented control azul) intentan reproducir el aspecto de la era Macromedia / CS3-4.
