# Lista de pruebas - MEMO SISTEMA 2.1.0

> Archivo generado por `herramientas/construir_bundle.py`, a partir de `catalogo.py`.
> Imprime esta lista o cópiala a Excel y marca cada prueba.

## 0. Prueba automática (2 minutos)

1. Abre un **dibujo nuevo** (con plantilla vacía).
2. Escribe `MEMO_INFO`: debe mostrar la carpeta del bundle, *Biblioteca MEMO_Lib: cargada* y *Menú MEMO_SISTEMA: cargado*.
3. Escribe `MEMO_VERIFICAR` y presiona Enter: al final debe decir **Todo correcto**.
   Si aparece *ERROR AL CARGAR* o *NO DEFINIDO*, copia ese texto y envíamelo.

## 1. Lo nuevo en 2.1 (probar primero)

| # | Prueba | Resultado esperado | OK |
|---|---|---|---|
| 1 | En Excel copia 3 filas de 5 columnas (No., Código, Concepto, Unidad, Precio). En AutoCAD: `COP`, elige el punto | Dice *Portapapeles: 3 fila(s), 5 columna(s)*, muestra la 1a fila y pregunta *¿Usar los datos del portapapeles?*; con Enter dibuja la tabla **igual que antes** | |
| 2 | Igual que la 1, pero una celda del Concepto tiene un salto de línea (Alt+Enter en Excel) | La fila sale completa, con el concepto en una sola línea | |
| 3 | `COP` con el portapapeles vacío (o responde *No*) | Pide pegar los datos a mano, como antes | |
| 4 | Copia 7 columnas y ejecuta `MTABLA` | Propone *Asipona*; con Enter ejecuta ASI **sin volver a preguntar** por el portapapeles | |
| 5 | Copia 4 columnas y ejecuta `MTABLA` | Propone *Ssa* y ejecuta CSSA | |
| 6 | Compara una tabla ASI con una hecha con la versión anterior | Mismos anchos, estilos y encabezados (antes ASI tomaba funciones de COP y CSSA) | |
| 7 | `MEMO_CONFIG` → cambia *COP: ancho Concepto* a 25 → `COP` | La columna Concepto sale más ancha. Restablece con `R` | |
| 8 | `MEMO_CONFIG` → *Tablas: usar portapapeles* = `SI` → `COP` | Ya no pregunta, usa directamente lo copiado | |
| 9 | `MAREA` → Enter | Ejecuta la opción por defecto (*Prefijo* = HA2); la segunda vez propone la última usada | |
| 10 | `MBACHEO` | Propone *Dibujar*; después de cada paso propone el siguiente (Numerar, Cotar, Exportar, Salir) | |
| 11 | `MEMO_CONFIG` → *Bacheo: espesor* = 0.15 → `EXR` | El volumen del CSV = área × 0.15 | |
| 12 | `MP` | Ahora es **EMPALME** (tu alias). La malla es `MLL` | |
| 13 | `EL`, `RV`, `PV`, `TM`, `CL`, `LC`, `CT`, `CTT`, `CC` | Hacen lo que dice tu acad.pgp (ELIPSE, REVOLUCION, etc.) | |
| 14 | `ELTN`, `RNB`, `IBPV`, `IBTM`, `CLO`, `LCO`, `CTB`, `CTX`, `RSC` | Hacen lo que antes hacían los nombres viejos | |
| 15 | `BPOL` y presiona ESC a la mitad; después otro comando con error o ESC | AutoCAD queda normal (sin "UCS previo" raro) | |
| 16 | `MEMO_COMPILAR` → abre otro dibujo → `MEMO_INFO` | Dice *Compilados (FAS): SÍ* y los comandos funcionan igual | |
| 17 | Mensajes con acentos de `EXR` y `PERFIL` | Se ven bien (antes podían salir con caracteres raros) | |

## 2. Todos los comandos

Una prueba rápida por comando: ejecútalo en `Ejercicio COMANDOS NUEVOS.dwg` y compara con lo que hacía antes.


### MEMO Estimaciones

| Panel | Comando | Qué debe hacer | OK |
|---|---|---|---|
| Conceptos | `MTABLA` | Tabla de conceptos desde el portapapeles: detecta el formato (5 col. Obras Públicas, 7 Asipona, 4 SSA) y llama a COP/ASI/CSSA. | |
| Conceptos | `COP` | Tabla de conceptos de 5 columnas (No. \| Código \| Concepto \| Unidad \| Precio). Lee lo copiado en Excel (portapapeles). | |
| Conceptos | `ASI` | Tabla de conceptos de 7 columnas (No. \| Código \| Descripción \| Unidad \| P.U. \| Cantidad \| Importe) con total. Lee el portapapeles. | |
| Conceptos | `CSSA` | Tabla de conceptos formato SSA (No. \| Concepto \| Unidad \| Cantidad) con recuadros. Lee el portapapeles. | |
| Conceptos | `LCO` | Borra TEXT y MTEXT de la capa CONCEPTOS. | |
| Conceptos | `LIMPIARTABLA` | Borra textos de las capas CONCEPTOS y ENCABEZADOS (tablas COP/ASI). | |
| Conceptos | `LIMPIARCSSA` | Borra los elementos creados por CSSA. | |
| Bacheo | `MBACHEO` | Bacheo paso a paso: Dibujar > Numerar > Cotar > Hatch > Exportar. | |
| Bacheo | `RS` | Dibuja rectángulos (baches) con cotas por fuera y hatch individual en capa Hatch_Bache. | |
| Bacheo | `RNB` | Renumera los rectángulos seleccionados por vecino más cercano. | |
| Bacheo | `COTB` | Anota largo y ancho de cada rectángulo en la capa GEOMETRIA_RECTANGULOS. | |
| Bacheo | `EXR` | Exporta los baches a CSV: número, largo, ancho, área, volumen y acumulado. | |
| Bacheo | `HR` | Aplica hatch a los rectángulos seleccionados. | |
| Bacheo | `BTR` | Borra los textos que quedan dentro de los rectángulos seleccionados. | |
| Bacheo | `RSHATCH` | Vuelve a aplicar el hatch a polilíneas existentes. | |
| Bacheo | `RSC` | Crea cotas con 2 decimales (estilo de RS). | |
| Bacheo | `AEC` | Actualiza el estilo de cota usado por RS. | |
| Bacheo | `RC2` | Redondea cotas existentes a 2 decimales. | |
| Bacheo | `RS-CONFIG` | Configura patrón, escala, ángulo, color y capa del hatch de RS. | |
| Bacheo | `VERLISTA` | Muestra la lista de rectángulos en memoria. | |
| Bacheo | `AXD` | Asigna XDATA (número, largo, ancho) a rectángulos existentes. | |
| Secciones | `ELTN` | Coloca elevaciones de terreno natural en secciones (escala vertical 1:1000 o 1:100). | |
| Secciones | `CAS` | Cálculo de áreas con fórmulas y valores (triángulos, trapecios, rectángulos, círculos). | |
| Secciones | `QA` | Cálculo rápido de áreas con valores sustituidos. | |
| Secciones | `AS` | Área de sección por 3 puntos (estilo text-Secc). | |
| Secciones | `R00` | Cambia números de los textos por 00.00 (conserva 'M2'). | |
| Áreas | `MAREA` | Un solo comando para las áreas: Prefijo, Rápido, M2, Hatch, Contorno, 3 puntos, Detalle, Valores, Exportar. | |
| Áreas | `EA` | Etiqueta áreas por capa y exporta a CSV/Excel (interfaz completa). | |
| Áreas | `HA2` | Pone el área de un hatch en un texto, preguntando prefijo. | |
| Áreas | `HA` | Pone el área de un hatch usando el último prefijo guardado. | |
| Áreas | `HAPREF` | Cambia el prefijo usado por HA/HA2. | |
| Áreas | `HAINFO` | Muestra la configuración actual de HA. | |
| Áreas | `AM2` | Actualiza el área en m² de un hatch en su texto. | |
| Áreas | `AC` | Calcula y actualiza áreas de secciones a partir de contornos. | |
| Áreas | `AH` | Extrae el área de hatches: 'AREA DE [TIPO]=[VALOR]M2'. | |
| Áreas | `AH2` | Versión completa de AH con opciones. | |
| Áreas | `HAEA-EXPORT` | Sólo exporta las áreas a Excel/CSV. | |
| Áreas | `EA-HA` | Etiquetado manual de EA (antes se llamaba HA y chocaba con el HA de prefijos). | |
| Imagen | `IJPG` | Exporta el área seleccionada a imagen JPG/PNG con recorte exacto. | |
| Imagen | `IJPG-EMF` | Exporta el área seleccionada a EMF vectorial sin bordes. | |
| Imagen | `IJPG-PC3` | Configura el trazador PC3 para JPG/PNG. | |

### MEMO Topografía

| Panel | Comando | Qué debe hacer | OK |
|---|---|---|---|
| Puntos | `ICE` | Importa puntos desde TXT/CSV/XYZ con capas y etiquetas. | |
| Puntos | `PCC` | Clasifica puntos y textos de CivilCAD en capas. | |
| Puntos | `MALLA-PUNTOS` | Genera malla de puntos por IDW con coloreo y etiquetas. | |
| Puntos | `UPP` | Une puntos con una polilínea. | |
| Puntos | `UPPA` | UPP con referencia a objetos automática (nodo, punto medio, intersección). | |
| Puntos | `PIT` | Convierte '-18 36' en '-18.36' y crea puntos en el punto de inserción. | |
| Puntos | `EXPORTAR-PUNTOS` | Exporta puntos a CSV. | |
| Puntos | `X-Y` | Exporta las coordenadas X Y de una polilínea a TXT. | |
| Puntos | `CPEC` | Colorea puntos AutoCAD según su elevación. | |
| Curvas de nivel | `CCN` | Colorea curvas de nivel existentes por intervalos (no modifica geometría). | |
| Curvas de nivel | `ECN` | Asigna elevación a curvas de nivel y las etiqueta (menú principal). | |
| Curvas de nivel | `ECN-P` | ECN: propagación de elevación por clic. | |
| Curvas de nivel | `ECN-M` | ECN: método manual. | |
| Curvas de nivel | `ECN-ETIQ` | ECN: etiquetas automáticas con intervalo. | |
| Curvas de nivel | `ECN-ETIQM` | ECN: etiqueta manual con intervalo. | |
| Curvas de nivel | `ECN-RECOLOR` | ECN: colorear por elevación. | |
| Curvas de nivel | `ECN-DUPLICADOS` | ECN: limpia etiquetas duplicadas. | |
| Curvas de nivel | `ECN-CONFIG` | ECN: configurar parámetros. | |
| Curvas de nivel | `ECN-DESHACER` | ECN: deshace el último coloreo. | |
| Curvas de nivel | `ECN-LISTA` | ECN: lista curvas por capa/elevación. | |
| Batimetría XYZ | `XYZ` | Menú principal de XYZ-Tools (importar, procesar, unir, exportar). | |
| Batimetría XYZ | `IXYZ` | Importa archivos XYZ con simbología por profundidad. | |
| Batimetría XYZ | `PZ` | Procesa archivos XYZ (5 modos de procesamiento). | |
| Batimetría XYZ | `P-Z` | Herramientas de puntos (Procesa_Puntos). | |
| Batimetría XYZ | `XYZU` | Une varios archivos XYZ. | |
| Batimetría XYZ | `EXYZ` | Exporta puntos seleccionados a XYZ. | |
| Batimetría XYZ | `IZ` | Invierte el signo de Z de los puntos seleccionados. | |
| Batimetría XYZ | `OZ` | Suma una distancia a la Z de los puntos seleccionados. | |
| Batimetría XYZ | `ZM` | Muestra Z mínima y máxima de la selección. | |
| Batimetría XYZ | `XYZLOTES` | Lista los lotes importados. | |
| Batimetría XYZ | `XYZBORRAR` | Borra un lote importado. | |
| Batimetría XYZ | `XYZAYUDA` | Ayuda de XYZ-Tools. | |
| Perfiles | `PERFIL` | Genera secciones transversales batimétricas con retícula y área. | |
| Edición | `BPOL` | Borra/recorta objetos por un objeto cerrado. | |
| Edición | `CLIPIT` | Recorta imágenes con un rectángulo (polilínea cerrada). | |
| Bloques | `IBC` | Inserta bloques en los puntos de capas *-Punto detectando la escala. | |
| Bloques | `IBCZ` | Inserta bloques en capa con escalas definidas. | |
| Bloques | `IBM` | Copia un bloque de referencia a múltiples puntos. | |
| Bloques | `ARBOLES` | Inserta 'Arbol' (escala 760.32). | |
| Bloques | `RAP` | Inserta 'RAP'. | |
| Bloques | `DES` | Inserta 'Descarga'. | |
| Bloques | `IBPV` | Inserta 'PV Existente'. | |
| Bloques | `IBTM` | Inserta 'Poste de TM'. | |
| Bloques | `CFE` | Inserta 'Poste de CFE'. | |
| Bloques | `VERBLOQUES` | Muestra los bloques existentes en el dibujo. | |
| Bloques | `VERCAPAS` | Muestra las capas finales requeridas. | |
| Bloques | `CONFIGESCALAS` | Muestra las escalas configuradas. | |

### MEMO Dibujo

| Panel | Comando | Qué debe hacer | OK |
|---|---|---|---|
| Textos | `CTB` | Caja de herramientas de texto (diálogo con 6 herramientas). | |
| Textos | `CTE` | Copia texto con opción de estilo. | |
| Textos | `CTP` | Copia texto con propiedades (texto / todo / sólo rotación). | |
| Textos | `IPT` | Iguala propiedades de texto. | |
| Textos | `CTN` | Copia texto con numeración automática (V-1, V-2, V-3...). | |
| Textos | `STV` | Suma o resta un valor a textos numéricos. | |
| Textos | `CTX` | Cambia los textos seleccionados por un texto tecleado. | |
| Textos | `ALIT` | Alinea textos (TEXT/MTEXT) en vertical u horizontal. | |
| Textos | `RTT` | Rota textos sobre su punto medio. | |
| Textos | `UL` | Cambia entre mayúsculas y minúsculas. | |
| Textos | `PS` | Agrega prefijo y/o sufijo a varios textos. | |
| Textos | `PREFSUFIND` | Agrega prefijo/sufijo texto por texto. | |
| Textos | `SETPREFSUF` | Establece los valores por defecto de PS. | |
| Textos | `ST` | Suma los valores numéricos de los textos seleccionados. | |
| Textos | `PTE` | Rotula la pendiente entre dos puntos. | |
| Textos | `CTAF` | Cambia altura y factor de ancho de textos. | |
| Coordenadas | `CORM` | Actualiza textos E/N/Z con las coordenadas de varios puntos. | |
| Coordenadas | `COR` | Actualiza textos con coordenadas (decimales y prefijo). | |
| Coordenadas | `COR2` | Coordenadas rápido (3 decimales, con prefijo). | |
| Hatch | `FH` | Fusiona varios hatches en uno solo con el patrón de referencia. | |
| Hatch | `SPH` | Separa un hatch compuesto en un hatch por frontera. | |
| Hatch | `CHS` | Crea un hatch con las propiedades de otro. | |
| Vistas | `CV` | Crea vistas en capa VISTAS a partir de puntos. | |
| Vistas | `GV` | Guarda la vista actual con número o nombre. | |
| Vistas | `AV` | Restaura una vista guardada. | |
| Vistas | `BV` | Lista y borra vistas guardadas. | |
| Layouts | `CLO` | Copia el layout activo N veces con prefijo. | |
| Layouts | `CFTL` | Configura página de varios layouts a la vez (copiar de uno existente). | |
| Layouts | `SL` | Elimina layouts seleccionados de una lista. | |
| MEMO | `MEMO_AYUDA` | Lista todos los comandos del MEMO SISTEMA por categoría. | |
| MEMO | `MEMO_CONFIG` | Anchos de tablas, espesor de bacheo, uso del portapapeles, etc. | |
| MEMO | `MEMO_INFO` | Muestra versión, carpeta y archivos cargados del MEMO SISTEMA. | |
| MEMO | `MEMO_VERIFICAR` | Carga todos los archivos y comprueba que cada comando exista (usar en un dibujo nuevo). | |
| MEMO | `MEMO_COMPILAR` | Compila los LISP a FAS en %APPDATA%\MEMO_SISTEMA\FAS para cargar más rápido. | |
| MEMO | `MEMO_QUITAR_ANTERIOR` | Descarga el menú anterior 'MEMO' (Memo.cuix) para que no se duplique. | |
