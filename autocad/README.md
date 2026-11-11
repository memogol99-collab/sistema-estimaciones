# MEMO SISTEMA para AutoCAD

Rutinas LISP para estimaciones, secciones, topografía y batimetría, con **instalación en un paso** y un **menú de fichas con iconos**.

![Fichas MEMO](docs/vista_previa_fichas.png)

## Instalar (usuario)

1. Descarga [`MEMO_SISTEMA_bundle.zip`](MEMO_SISTEMA_bundle.zip) y descomprímelo.
2. Cierra AutoCAD.
3. Clic derecho en **`INSTALAR.bat`** → *Ejecutar como administrador*.
4. Abre AutoCAD: aparecen las fichas **MEMO Estimaciones**, **MEMO Topografía** y **MEMO Dibujo**.
5. **Sólo la primera vez**, si tenías el `Memo.cuix` anterior:
   - Escribe `MEMO_QUITAR_ANTERIOR`.
   - Quita los LISP viejos del *Conjunto de inicio* de `APPLOAD`.

Instalación manual: copia la carpeta `MEMO_SISTEMA.bundle` a `C:\Program Files\Autodesk\ApplicationPlugins\` y reinicia AutoCAD. Funciona con AutoCAD 2015–2026, Civil 3D y Map.

Comandos útiles: `MEMO_AYUDA` (lista de comandos) y `MEMO_INFO` (diagnóstico).

## Estructura

| Carpeta | Contenido |
|---|---|
| `originales/` | Los LISP tal como estaban (no se editan; son la fuente) |
| `herramientas/catalogo.py` | **Fuente de verdad**: archivos, comandos, descripciones, iconos y fichas |
| `herramientas/construir_bundle.py` | Genera el bundle, el CUIX, el cargador, los iconos y el ZIP |
| `herramientas/iconos.py`, `vista_previa.py` | Dibujo de iconos y vista previa de las fichas |
| `instaladores/` | `INSTALAR.bat`, `DESINSTALAR.bat` |
| `MEMO_SISTEMA.bundle/` | Resultado listo para AutoCAD (generado) |
| `ANALISIS_Y_PROPUESTAS.md` | Análisis completo, errores encontrados y propuestas |

## Modificar o agregar un LISP

```bash
pip install pillow
# 1. copia el .lsp a originales/MEMO_SISTEMA/<carpeta>/
# 2. edita herramientas/catalogo.py (ARCHIVOS, COMANDOS y FICHAS)
python herramientas/construir_bundle.py
python herramientas/vista_previa.py docs/vista_previa_fichas.png
```

El script se detiene si hay comandos duplicados, botones que apuntan a comandos inexistentes, paréntesis desbalanceados o XML inválido.
