# Resumen de avances de obra desde WhatsApp

El script `whatsapp_resumen.py` lee los chats que exportas de WhatsApp. Con ellos genera un **Excel** y un **reporte por día** con las actividades, cantidades, elementos, cadenamientos, incidencias y pendientes que se reportaron en cada grupo.

## 1. Exportar el chat del grupo

**Android**
1. Abre el grupo → toca **⋮** (arriba a la derecha) → **Más** → **Exportar chat**.
2. Elige **Sin archivos** (más rápido) o **Incluir archivos** (si quieres conservar las fotos).
3. Mándatelo por correo o guárdalo en Drive y pásalo a tu computadora.

**iPhone**
1. Abre el grupo → toca el **nombre del grupo** → baja hasta **Exportar chat**.
2. Elige **Sin archivos** o **Adjuntar archivos**.
3. Guárdalo en *Archivos* o mándatelo por correo.

Se genera un archivo `.txt` o `.zip`, por ejemplo `Chat de WhatsApp con Puente Barrio 5.zip`. **No necesitas descomprimirlo.**

## 2. Copiar los archivos a la carpeta `whatsapp/`

```
sistema-estimaciones/
├── whatsapp/
│   ├── Chat de WhatsApp con Puente Barrio 5.zip
│   └── Chat de WhatsApp con Frente Norte.txt
└── whatsapp_resumen.py
```

> 🔒 La carpeta `whatsapp/` y los reportes están en `.gitignore`, así que **nunca se suben a GitHub**.

## 3. Ejecutar el script

Instala las dependencias una sola vez:
```bash
pip install -r requirements.txt
```

Luego ejecuta:
```bash
# Todos los grupos, todo el historial
python whatsapp_resumen.py whatsapp/

# Solo una semana (formato AAAA-MM-DD)
python whatsapp_resumen.py whatsapp/ --desde 2026-11-16 --hasta 2026-11-22

# Un solo grupo y otra carpeta de salida
python whatsapp_resumen.py "whatsapp/Chat de WhatsApp con Frente Norte.txt" --salida reportes/semana47
```

### Varios grupos de la misma obra

Si en la carpeta hay **más de un chat**, además del reporte de cada grupo se genera uno **consolidado** que une todos en una sola línea de tiempo:
- Cada mensaje indica de qué grupo viene, por ejemplo `[Supervisión]`.
- Un mensaje o reporte reenviado a varios grupos (mismo día y mismo texto) aparece una sola vez, con los grupos donde se publicó.

```bash
python whatsapp_resumen.py whatsapp/ --nombre "Barrio V"        # genera también resumen_Barrio V.xlsx / .md
python whatsapp_resumen.py whatsapp/ --sin-consolidado          # solo un reporte por grupo
```

## 4. Resultados (carpeta `reportes_whatsapp/`)

Por cada grupo se generan dos archivos.

**`resumen_<grupo>.xlsx`**, con estas hojas:

| Hoja | Contenido |
|---|---|
| Resumen diario | Por día: n.º de mensajes, quién reportó, categorías, elementos (Pila 3, Zapata 4…), cadenamientos, incidencias, pendientes y fotos |
| Avance por frente | Se llena desde los mensajes **"Reporte de actividades …"**. Hay una fila por frente y por día, con obra, actividad, estado (en proceso / concluido), volúmenes y profundidades, elementos (Pila, Eje, Zapata, Caballete), personal y equipo |
| Personal y equipo | Por reporte diario: total de personal, maquinaria y equipo inactivo |
| Mensajes | Todos los mensajes ya clasificados, con filtros |
| Incidencias | Problemas, fallas, retrasos, paros, material que no llegó… |
| Pendientes | Lo programado, lo que falta y las solicitudes |
| Cantidades | Mensajes con volúmenes o avances (m3, m2, ml, ton, %, viajes…), útiles para soportar estimaciones |
| Por autor | Quién reporta y cuánto |
| Adjuntos | Fotos y archivos enviados (fecha y autor) |

**`resumen_<grupo>.md`**: reporte legible día por día, agrupado por categoría (Colado, Acero, Pilas, Terracerías…), con secciones de ⚠️ Incidencias y 📌 Pendientes.

## 5. Ajustar las palabras clave

Al inicio de `whatsapp_resumen.py` están los diccionarios `CATEGORIAS`, `INCIDENCIAS` y `PENDIENTES`. Puedes agregar los términos que usa tu gente en obra.
- Se escriben **sin acentos y en minúsculas**.
- Un `*` al final funciona como prefijo: `colad*` encuentra *colado*, *colada* y *colados*.

## Notas

- Los reportes diarios se reconocen cuando el mensaje empieza con **"Reporte de actividades"** y tiene bloques **"Frente N"**, cada uno con sus secciones *Personal* o *Mano de obra* y *Equipo y maquinaria*. Si se reenvía un reporte del mismo día y la misma obra, se toma el último.

- Funciona con exportaciones de Android y iPhone, en español o inglés, con formato de 12 h o de 24 h.
- Las fechas se interpretan como **día/mes/año**.
- La clasificación es por palabras clave, así que conviene revisar las hojas *Incidencias* y *Pendientes*.
- Si quieres un resumen redactado (narrativo), pásale a Claude el `.md` o el `.txt` exportado y pídele el resumen.
