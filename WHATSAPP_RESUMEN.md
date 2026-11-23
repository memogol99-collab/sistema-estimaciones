# Resumen de avances de obra desde WhatsApp

El script `whatsapp_resumen.py` lee los chats que exportas de WhatsApp. Con ellos genera un **Excel** y un **reporte por día** con las actividades, cantidades, elementos, cadenamientos, incidencias y pendientes que se reportaron en cada grupo.

## Actualización periódica (cada semana o cuando quieras)

1. **Exporta de nuevo los 3 grupos** (Proyeterra, Construcción Puente y Supervisión) con *Exportar chat → Sin archivos*. Cada exportación trae **todo el historial**, así que no hace falta juntar exportaciones anteriores.
2. **Copia los archivos nuevos a `whatsapp/`**, reemplazando los anteriores. Si se quedan los dos (por ejemplo `… Barrio V.zip` y `… Barrio V (1).zip`), el script usa solo el que tiene los mensajes más recientes y te avisa cuál ignoró.
3. **Ejecuta el script.** En Windows, doble clic en **`actualizar.bat`**; o desde la terminal:
   ```bash
   python whatsapp_resumen.py whatsapp/ --nombre "Barrio V"
   ```
4. Los reportes en `reportes_whatsapp/` se **sobrescriben** con la información al día. La fecha de corte es la del último mensaje de los chats.

> Conviene procesar siempre el historial completo. Con `--desde` el reporte solo cubre ese periodo, y la tabla de pilas, el avance contra el programa y los rendimientos se calcularían con esos días nada más.
> Si quieres conservar los reportes de cada semana, cambia el nombre de la carpeta de salida: `--salida reportes/semana_48`.

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
| **Tablero** | Lo mismo que el reporte HTML en una sola hoja: indicadores, contratos, pilas, datos a verificar, recursos en obra, atrasos, partidas sin abrir, posibles extraordinarios, conceptos e incidencias |
| **Bitácora por día** | Cada día, del más reciente al más antiguo, con las actividades por puente y frente, sus cantidades y su concepto, y los mensajes relevantes (incidencias en rojo, pendientes en amarillo). Cada día se abre o se cierra con los botones **+ / −** de Excel |
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

**`pilas_<grupo>.xlsx`**: tabla de pilas para soporte de estimación.

| Hoja | Contenido |
|---|---|
| Resumen por eje | Por eje: pilas coladas y pendientes, m³ de concreto colado y m³ de relleno fluido |
| Pilas | Una fila por pila (E3-P5 = Eje 3, Pila 5): estado, inicio de perforación, última profundidad, intentos, caídos, relleno fluido (m³ y fechas), fecha y volumen de colado, **observaciones a verificar** y menciones en otros grupos |
| Eventos (reportes) | Cada perforación, relleno fluido o colado tal como viene en los reportes diarios |
| Apoyos (según grupos) | Pilas por apoyo (Garzas / Gaviotas) mencionadas en los mensajes: son **programas o avisos**, no reportes de lo ejecutado |
| Menciones en grupos | Cada mensaje que menciona una pila, con el grupo y el autor |

La columna *observaciones* marca lo que conviene revisar antes de estimar:
- una pila con colado reportado dos veces;
- un texto copiado del día anterior (no se suma);
- un colado sin volumen;
- una profundidad idéntica a la de otra pila reportada el día anterior.

### Puentes: Garzas y Gaviotas

Cada mensaje, actividad y pila se asigna a un puente con las reglas de `PUENTES`, al inicio del script:
- **Garzas (2ª etapa):** "Complemento", "segunda etapa", "etapa 2" o "2ª etapa", "Retorno" y "Garzas".
- **Gaviotas (Barrio V):** "Gaviotas", "Barrio V" o "Barrio 5" (lo que no sea de la segunda etapa).

Las actividades de un reporte toman el puente del título del reporte, salvo que el frente diga otro. Por ejemplo, el *Terraplén de Retorno* que viene en los reportes de "PSV Gaviotas" se asigna a Garzas. Los nombres de calles (Av. Garzas, Av. Gaviotas, Valle de las Garzas) no cuentan para decidir el puente.

### Catálogos de los contratos (opcional, recomendado)

Copia los Excel de los contratos (con la hoja **E-7**, catálogo de conceptos) en la carpeta `contratos/`, que no se sube a GitHub. Por ejemplo:
```
contratos/CONTRATO C-029 2026 BARRIO 5 GAVIOTAS.xlsx
contratos/CONTRATO C-035 2026 BARRIO 5 GARZAS.xlsx
```
Con los catálogos, el script:
- **Asigna cada actividad de los reportes al concepto más parecido** del contrato de su puente. Agrega columnas de concepto, unidad, confianza (Alta / Media / Baja) y otras opciones. Si la actividad se parece claramente más a un concepto del otro contrato, lo avisa.
- **Agrega la hoja "Avance por concepto"**: días con actividad, periodo y cantidad reportada en la misma unidad del concepto.
- **Agrega al control de pilas la hoja "Pilas vs catálogo"**: perforación, concreto fluido, reperforación y concreto de pilas contra la cantidad del catálogo, con el % de avance y un importe preliminar (cantidad × P.U.).

La asignación es por similitud de texto: es un apoyo, no sustituye a los números generadores.

### Recursos, rendimientos y propuesta (`recursos_<nombre>.xlsx`)

De cada reporte diario se toma cada línea de personal y de equipo, del encabezado y de cada frente, y se clasifica por tipo:
- **Personal:** oficial fierrero, carpintero, ayudante general, banderero(a), residente, operador de cada máquina, etc.
- **Equipo:** perforadora, grúa de orugas, HIAB, retroexcavadora, excavadora, volteo, pipa, generador, motobomba, etc.
- **Inactivos:** se marcan los equipos reportados como inactivos.

| Hoja | Contenido |
|---|---|
| Propuesta de recursos | Conceptos atrasados contra el programa E-6. Incluye: % de avance, ritmo actual y ritmo necesario por día hábil para terminar en plazo, el recurso que manda (perforadora, fierreros, volteos…), cuántos hay y cuántos harían falta |
| Frentes sin abrir | Partidas que según el programa ya deberían llevar avance y no aparecen en los reportes, con su importe programado |
| Programa vs real | Todos los conceptos programados al corte contra lo reportado |
| Posibles extraordinarios | Actividades sin concepto claro en el catálogo. Por cada una: jornadas, cuadrilla típica, equipo típico, hombres-día y rendimiento observado, como base para la tarjeta de precio unitario |
| Rendimientos | Lo mismo para todos los conceptos y actividades |
| Personal / Maquinaria / Equipo menor por día | Recursos activos por día y tipo |
| Resumen semanal | Promedio diario y máximo por semana y tipo |
| Equipo inactivo | Equipo reportado como inactivo y por cuántos días |
| Detalle de recursos | Cada línea de personal y equipo ya clasificada |

Para la propuesta se necesitan los catálogos **con la hoja E-6** (programa de obra) en `contratos/`. El acero de pilas se estima con la cuantía del catálogo (kg de acero ÷ m³ de concreto), porque los reportes no traen kilos.

### Formatos de salida
- **`resumen_<nombre>.html`** y **`.pdf`**: reporte con formato. Incluye indicadores, contratos, pilas, datos a verificar, actividades por concepto, incidencias y bitácora por día. El PDF se genera si hay Chrome o Edge instalado; si no, abre el HTML y usa *Imprimir → Guardar como PDF*.
- **`resumen_<nombre>.xlsx`** y **`pilas_<nombre>.xlsx`**: con portada e índice, encabezados, colores por estado y por puente, totales y listos para imprimir.

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
