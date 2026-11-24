# -*- coding: utf-8 -*-
"""
Catálogo único del MemoPRO.

Es la "fuente de verdad": de aquí se generan el cargador (autoload), el menú
CUIX con fichas, los iconos y la tabla de comandos de la documentación.
Para agregar un LISP nuevo basta con:
  1. Agregarlo a ARCHIVOS (origen -> destino).
  2. Describir sus comandos en COMANDOS.
  3. Colocar los comandos en FICHAS (Ribbon).
  4. Ejecutar:  python construir_bundle.py
"""

# ---------------------------------------------------------------------------
# Archivos que se incluyen en el sistema
#   origen  : ruta relativa dentro de autocad/originales/MEMO_SISTEMA
#   destino : ruta relativa dentro de Contents/LISP del bundle
#   parches : lista de correcciones a aplicar (ver construir_bundle.py)
# ---------------------------------------------------------------------------
ARCHIVOS = [
    # --- Estimaciones / Conceptos -----------------------------------------
    ("LISP_Estimaciones/Conceptos Obras Publicas ( COP ).lsp", "Estimaciones/COP_ConceptosObrasPublicas.lsp", ["prefijo:cop", "portapapeles:5", "cfg-cop"]),
    ("LISP_Estimaciones/Conceptos Asipona ( ASI ).lsp",        "Estimaciones/ASI_ConceptosAsipona.lsp",      ["prefijo:asi", "portapapeles:7", "cfg-asi"]),
    ("LISP_Estimaciones/Conceptos SSA ( CSSA ).lsp",           "Estimaciones/CSSA_ConceptosSSA.lsp",         ["prefijo:cssa", "portapapeles:4", "cfg-cssa"]),
    ("LISP_Estimaciones/Limpiar Conceptos ( LC ).lsp",         "Estimaciones/LC_LimpiarConceptos.lsp",       ["renombrar:LC=LCO"]),
    ("LISP_Estimaciones/CAD a JPG  ( IJPG ).LSP",              "Estimaciones/IJPG_CadAJpg.lsp",              []),
    # --- Bacheo ------------------------------------------------------------
    ("LISP_Estimaciones/RectanguloSnap ( RS ).lsp",            "Bacheo/RS_RectanguloSnap.lsp",               ["renombrar:CC=RSC"]),
    ("LISP_Estimaciones/RenumerarRectangulos ( RV ).lsp",      "Bacheo/RV_RenumerarRectangulos.lsp",         ["renombrar:RV=RNB"]),
    ("LISP_Estimaciones/COTAR_BACHES  (COTB ).lsp",            "Bacheo/COTB_CotarBaches.lsp",                []),
    ("LISP_Estimaciones/ExportaRectangulos ( EXR ).lsp",       "Bacheo/EXR_ExportaRectangulos.lsp",          ["cfg-espesor"]),
    ("LISP_Estimaciones/HatchRectangulos.lsp",                 "Bacheo/HR_HatchRectangulos.lsp",             ["msg-hr"]),
    ("LISP_Estimaciones/BorrarTextoEnRect.lsp",                "Bacheo/BTR_BorrarTextoEnRect.lsp",           []),
    # --- Secciones / Áreas -------------------------------------------------
    ("LISP_Secciones/Elevacion ( EL ).lsp",                    "Secciones/EL_Elevacion.lsp",                 ["renombrar:EL=ELTN"]),
    ("LISP_Secciones/Cambia Numeros x 00.00 ( R00 ).LSP",      "Secciones/R00_CambiaNumeros.lsp",            []),
    ("@fuente/MEMO_Areas.lsp",                                "Secciones/MEMO_Areas.lsp",                   []),   # MAREA HA AC AS CAS (nuevo)
    ("@fuente/EA_ExportarEstArea.lsp",                         "Secciones/EA_ExportarEstArea.lsp",           []),   # v7.1 corregida (original en originales/)
    # --- Textos ------------------------------------------------------------
    ("LISP_Textos/CT-Toolbox.lsp",                             "Textos/CT_Toolbox.lsp",                      ["renombrar:CT=CTB"]),
    ("LISP_Textos/Cambia Texto ( CTT ).lsp",                   "Textos/CTT_CambiaTexto.lsp",                 ["renombrar:CTT=CTX", "ctx-portapapeles"]),
    ("LISP_Textos/Alinear Texto ( ALIT ).lsp",                 "Textos/ALIT_AlinearTexto.lsp",               []),
    ("LISP_Textos/Pendiente ( PTE ).lsp",                      "Textos/PTE_Pendiente.lsp",                   []),
    ("LISP_Textos/MayMin ( UL ).lsp",                          "Textos/UL_MayMin.lsp",                       []),
    ("LISP_Textos/PrefijoSufijo ( PS ).lsp",                   "Textos/PS_PrefijoSufijo.lsp",                []),
    ("LISP_Textos/Rot-Text ( RTT ).lsp",                       "Textos/RTT_RotarTexto.lsp",                  []),
    ("LISP_Textos/Suma Valores Textos ( ST ).lsp",             "Textos/ST_SumaTextos.lsp",                   []),
    ("LISP_Textos/Texto_Alto_Ancho.lsp",                       "Textos/CTAF_TextoAltoAncho.lsp",             []),
    ("LISP_Textos/Coordenadas_a_texto ( CORM ).lsp",           "Textos/CORM_CoordenadasATexto.lsp",          ["corm-princ"]),
    # --- Hatch -------------------------------------------------------------
    ("LISP_Hatch/SeparaHatch ( SPH ).lsp",                     "Hatch/SPH_SeparaFusionaHatch.lsp",           []),
    ("LISP_Hatch/Crear Hatch Similar ( CHS ).lsp",             "Hatch/CHS_HatchSimilar.lsp",                 []),
    # --- Vistas / Layouts --------------------------------------------------
    ("LISP_VistasLayout/Crear Vistas ( CV ).lsp",              "VistasLayout/CV_CrearVistas.lsp",            []),
    ("LISP_VistasLayout/Restaurar Vistas ( AV ).lsp",          "VistasLayout/AV_GuardarRestaurarVistas.lsp", []),
    ("LISP_VistasLayout/Borrar Vistas ( BV ).lsp",             "VistasLayout/BV_BorrarVistas.lsp",           ["prefijo:bv"]),
    ("LISP_VistasLayout/ClonLayout ( CL ).lsp",                "VistasLayout/CL_ClonarLayout.lsp",           ["renombrar:CL=CLO"]),
    ("LISP_VistasLayout/Configurar Layouts  ( CFTL ).lsp",     "VistasLayout/CFTL_ConfigurarLayouts.lsp",    []),
    ("LISP_VistasLayout/SuprimirLayouts ( SL ).lsp",           "VistasLayout/SL_SuprimirLayouts.lsp",        ["prefijo:sl"]),
    # --- Topografía --------------------------------------------------------
    ("LISP_Topografia/Importar PUNTOS ( ICE ).lsp",            "Topografia/ICE_ImportarPuntos.lsp",          []),
    ("LISP_Topografia/Ptos Civil a Capas ( PCC ).lsp",         "Topografia/PCC_PuntosCivilACapas.lsp",       []),
    ("LISP_Topografia/UnirPuntosPol ( UPP ).lsp",              "Topografia/UPP_UnirPuntosPol.lsp",           []),
    ("LISP_Topografia/Malla_PUNTOS  ( MALLA ).lsp",            "Topografia/MP_MallaPuntos.lsp",              ["quitar-mp", "malla-entrecurvas"]),
    ("LISP_Topografia/Exportar_Coord_POL ( X-Y ).lsp",         "Topografia/XY_ExportarCoordPol.lsp",         ["getfiled-c"]),
    ("LISP_Topografia/ColorearPorElevacion.lsp",               "Topografia/CPEC_ColorearPorElevacion.lsp",   []),
    ("LISP_Topografia/Curvas_Nivel ( CCN ).lsp",               "Topografia/CCN_CurvasNivel.lsp",             []),
    ("LISP_Topografia/Elevación_Curvas_Nivel  ( ECN ).lsp",    "Topografia/ECN_ElevacionCurvas.lsp",         []),
    ("LISP_Topografia/Borra_pol ( BPOL ).lsp",                 "Topografia/BPOL_BorraPol.lsp",               ["bpol-error"]),
    ("LISP_Topografia/CLIPIT.LSP",                             "Topografia/CLIPIT.lsp",                      []),
    # --- Batimetría / Nube de puntos --------------------------------------
    ("LISP_Batimetria/XYZ-Tools  ( IXYZ ).lsp",                "Batimetria/XYZ_Tools.lsp",                   []),
    ("LISP_NubePuntos/PTO-INS-TEXTO  ( PIT ).lsp",             "Batimetria/PIT_PuntoInsTexto.lsp",           []),
    ("LISP_NubePuntos/perfil_transversal.lsp",                 "Batimetria/PERFIL_Transversal.lsp",          ["getfiled-c"]),
    # --- Bloques -----------------------------------------------------------
    ("LISP_Bloques/Insertar Bloques en Capa ( IBC ).lsp",      "Bloques/IBC_BloquesEnCapa.lsp",              []),
    ("LISP_Bloques/Insertar Bloques en Capa ( IBCZ ).lsp",     "Bloques/IBCZ_BloquesEnCapaEscala.lsp",       ["renombrar:PV=IBPV", "renombrar:TM=IBTM"]),
    ("LISP_Bloques/Insetar Bloques Multiples ( IBM ).lsp",     "Bloques/IBM_BloquesMultiples.lsp",           []),
    # --- Comandos unificados (código nuevo, en autocad/fuente) -----------
    ("@fuente/MEMO_Unificados.lsp",                            "Sistema/MEMO_Unificados.lsp",                []),
]

# Biblioteca común: se carga al abrir cada dibujo (no bajo demanda).
BIBLIOTECA = ("@fuente/MEMO_Lib.lsp", "Sistema/MEMO_Lib.lsp")

# Comandos renombrados por chocar con alias del acad.pgp del usuario.
RENOMBRADOS = {
    "EL": ("ELTN", "ELIPSE"), "RV": ("RNB", "REVOLUCION"), "CC": ("RSC", "CERRARCINTA"),
    "PV": ("IBPV", "PTOVISTA"), "TM": ("IBTM", "TILEMODE"), "CL": ("CLO", "LINEACENTRO"),
    "LC": ("LCO", "LINEACENTRO"), "CT": ("CTB", "TXTC / CTABLESTYLE"), "CTT": ("CTX", "ADMATRB"),
    "MP": ("(eliminado; use MLL)", "EMPALME"),
}

# Mensajes de carga que mencionan el nombre viejo (texto exacto -> nuevo).
MENSAJES = {
    "Bacheo/RS_RectanguloSnap.lsp": [("|  CC       - Crear cotas", "|  RSC      - Crear cotas")],
    "Bacheo/RV_RenumerarRectangulos.lsp": [("RENUMERARVECINO (o RV) - Renumerar", "RENUMERARVECINO (o RNB)- Renumerar")],
    "Secciones/EL_Elevacion.lsp": [("Comando EL cargado", "Comando ELTN cargado")],
    "Estimaciones/LC_LimpiarConceptos.lsp": [('"\\n  LC - Eliminar', '"\\n  LCO - Eliminar')],
    "Textos/CT_Toolbox.lsp": [("Comando: CT (di", "Comando: CTB (di")],
    "Bloques/IBCZ_BloquesEnCapaEscala.lsp": [('"\\n  PV            - Inserta', '"\\n  IBPV          - Inserta'),
                                            ('"\\n  TM            - Inserta', '"\\n  IBTM          - Inserta')],
    "Estimaciones/COP_ConceptosObrasPublicas.lsp": [("COP5 - Crear tabla completa", "COP  - Crear tabla completa")],
    "Topografia/XY_ExportarCoordPol.lsp": [("Ejecute EXPORCOOR para comenzar", "Ejecute X-Y para comenzar")],
    "VistasLayout/BV_BorrarVistas.lsp": [("Rutina LVA cargada. Escribe LVA para", "Comando BV cargado. Escribe BV para")],
    "VistasLayout/CL_ClonarLayout.lsp": [("Comando ClonLayout cargado. Ejecute ClonLayout para", "Comando CLO cargado. Ejecute CLO para")],
    "VistasLayout/AV_GuardarRestaurarVistas.lsp": [('"\\nAG - Guardar vista', '"\\nGV - Guardar vista')],
    "VistasLayout/SL_SuprimirLayouts.lsp": [("EliminarLayouts - Escribe ELIMINARLAYOUTS o EL para", "SL - Escribe SL para")],
    "Topografia/CLIPIT.lsp": [("Comando CLIPIMAGE_RECT cargado. Escribe CLIPIMAGE_RECT para", "Comando CLIPIT cargado. Escribe CLIPIT para")],
    "Textos/CTT_CambiaTexto.lsp": [("Comandos cargados: CTE", "Comando CTX cargado (Enter = usar el texto copiado)")],
    "Topografia/MP_MallaPuntos.lsp": [("- MP / MLL         : Alias", "- MLL              : Alias"),
                                     ("Use MALLA-PUNTOS, MP o MLL", "Use MALLA-PUNTOS o MLL")],
}

# ---------------------------------------------------------------------------
# Configuración (MEMO_CONFIG).  CLAVE: (defecto, descripción, tipo, opciones)
# ---------------------------------------------------------------------------
CONFIG = [
    ("TABLA_PORTAPAPELES", "SI",      "Tablas: tomar datos del portapapeles (SI/NO/PREGUNTAR)", "TXT", "SI,NO,PREGUNTAR"),
    ("DESHACER_AGRUPADO",  "SI",      "Un solo Deshacer por comando y restaurar variables con ESC", "TXT", "SI,NO"),
    ("COP_ANCHO_NO",       "0.5",     "COP: ancho columna No.", "NUM", ""),
    ("COP_ANCHO_CODIGO",   "4.6641",  "COP: ancho No.+Código", "NUM", ""),
    ("COP_ANCHO_CONCEPTO", "21.1083", "COP: ancho Concepto", "NUM", ""),
    ("COP_ANCHO_UNIDAD",   "2.0596",  "COP: ancho Unidad", "NUM", ""),
    ("COP_ANCHO_PRECIO",   "2.0596",  "COP: ancho Precio", "NUM", ""),
    ("ASI_ANCHO_NO",       "0.9841",  "ASI: ancho No.", "NUM", ""),
    ("ASI_ANCHO_CODIGO",   "1.7887",  "ASI: ancho Código", "NUM", ""),
    ("ASI_ANCHO_DESCRIPCION", "14.8620", "ASI: ancho Descripción", "NUM", ""),
    ("ASI_ANCHO_UNIDAD",   "1.1700",  "ASI: ancho Unidad", "NUM", ""),
    ("ASI_ANCHO_PU",       "1.7250",  "ASI: ancho P.U.", "NUM", ""),
    ("ASI_ANCHO_CANTIDAD", "1.6997",  "ASI: ancho Cantidad", "NUM", ""),
    ("ASI_ANCHO_IMPORTE",  "1.9849",  "ASI: ancho Importe", "NUM", ""),
    ("CSSA_ANCHO_TOTAL",   "24.0964", "CSSA: ancho total de la tabla", "NUM", ""),
    ("BACHEO_ESPESOR",     "0.10",    "Bacheo: espesor para volumen en EXR (m)", "NUM", ""),
    ("MALLA_METODO",       "ENTRECURVAS", "Malla de puntos: ENTRECURVAS (nuevo) o IDW (anterior)", "TXT", "ENTRECURVAS,IDW"),
    ("MALLA_RADIO",        "0",       "Malla: distancia máx. de búsqueda (0 = automática)", "NUM", ""),
    ("MALLA_CURVA_CERO",   "NO",      "Malla: usar curvas con elevación 0 (SI para batimetría)", "TXT", "SI,NO"),
    ("EA_ASIGNACION",      "RECUADRO", "EA: asignar áreas por RECUADRO de sección o CERCANO", "TXT", "RECUADRO,CERCANO"),
    ("EA_CAPA_RECUADRO",   "*",       "EA: capa(s) de los recuadros de sección (* = todas)", "TXT", ""),
    ("EA_TIPOS_CORTE",     "CORTE,EXCAVACION,DESMONTE", "EA resumen: tipos que son CORTE", "TXT", ""),
    ("EA_TIPOS_RELLENO",   "RELLENO,TERRAPLEN,NUCLEO,CORAZA,SUBRASANTE", "EA resumen: tipos que son RELLENO", "TXT", ""),
    ("EA_COEF_ABUND",      "1.00",    "EA resumen: coeficiente de abundamiento del corte", "NUM", ""),
    ("EA_TIPO_SUBBASE", '*SUBBASE*,*SUB-BASE*,*SUB BASE*', "EA: patrón de texto/capa del tipo SUBBASE", "TXT", ""),
    ("EA_TIPO_SUBRASANTE", '*SUBRASANTE*,*SUB-RASANTE*', "EA: patrón de texto/capa del tipo SUBRASANTE", "TXT", ""),
    ("EA_TIPO_CARPETA", '*CARPETA*', "EA: patrón de texto/capa del tipo CARPETA", "TXT", ""),
    ("EA_TIPO_EXCAVACION", '*EXCAVACION*,*EXCAVACIÓN*', "EA: patrón de texto/capa del tipo EXCAVACION", "TXT", ""),
    ("EA_TIPO_DESMONTE", '*DESMONTE*', "EA: patrón de texto/capa del tipo DESMONTE", "TXT", ""),
    ("EA_TIPO_TERRAPLEN", '*TERRAPLEN*,*TERRAPLÉN*', "EA: patrón de texto/capa del tipo TERRAPLEN", "TXT", ""),
    ("EA_TIPO_RELLENO", '*RELLENO*', "EA: patrón de texto/capa del tipo RELLENO", "TXT", ""),
    ("EA_TIPO_CORAZA", '*CORAZA*', "EA: patrón de texto/capa del tipo CORAZA", "TXT", ""),
    ("EA_TIPO_NUCLEO", '*NUCLEO*,*NÚCLEO*', "EA: patrón de texto/capa del tipo NUCLEO", "TXT", ""),
    ("EA_TIPO_ARENA", '*ARENA*', "EA: patrón de texto/capa del tipo ARENA", "TXT", ""),
    ("EA_TIPO_CORTE", '*CORTE*', "EA: patrón de texto/capa del tipo CORTE", "TXT", ""),
    ("EA_TIPO_AFINE", '*AFINE*', "EA: patrón de texto/capa del tipo AFINE", "TXT", ""),
    ("EA_TIPO_BASE", '*BASE*', "EA: patrón de texto/capa del tipo BASE", "TXT", ""),
    ("AREA_ULTIMO",        "HA",      "MAREA: última herramienta usada", "TXT", "HA,AH,AC,AS,CAS,EA"),
    ("AREA_ESCRITURA",     "NUMERO",  "Áreas: NUMERO (cambia sólo el número) o COMPLETO", "TXT", "NUMERO,COMPLETO"),
    ("AREA_PREFIJO",       "A=",      "Áreas: prefijo del texto completo", "TXT", ""),
    ("AREA_SUFIJO",        "m2",      "Áreas: sufijo (NINGUNO = sin sufijo)", "TXT", ""),
    ("AREA_PREF_TIPO",     "SI",      "Áreas: prefijo AREA DE <TIPO>= si se conoce el tipo", "TXT", "SI,NO"),
    ("AREA_MAYUSCULAS",    "NO",      "Áreas: texto completo en mayúsculas", "TXT", "SI,NO"),
    ("AREA_DECIMALES",     "2",       "Áreas y EA: decimales del área", "NUM", ""),
    ("AREA_MOVER_CAPA",    "NO",      "Áreas: pasar el texto a la capa del hatch", "TXT", "SI,NO"),
    ("AREA_DIST_MAX",      "50",      "Áreas y EA: distancia máx. texto-hatch (sin recuadro)", "NUM", ""),
    ("AREA_ALTURA_TEXTO",  "0.15",    "CAS: altura de texto", "NUM", ""),
    ("TABLA_ULTIMO",       "Obras",   "MTABLA: último formato usado", "TXT", ""),
]

# Archivos que se dejan FUERA a propósito (quedan en /originales) y por qué.
EXCLUIDOS = {
    "LISP_Secciones/Area Pref Guard ( HA ).lsp": "Reemplazado por MEMO_Areas.lsp (HA y MAREA). HA2/HAPREF/HARESET/HAINFO quedan como opciones de MAREA.",
    "LISP_Secciones/Area_m2 ( AM2 ).lsp": "AM2 hacía lo mismo que HA con otro formato: ahora es una opción de MAREA (sufijo ' m²').",
    "LISP_Secciones/Extraer Area de Hatch ( AH ).lsp": "AH/AH2 ahora usan el motor de etiquetado de EA (recuadros, tipos, sin escribir CORTE por defecto).",
    "LISP_Secciones/Extraer Area de Cont ( AC ).LSP": "Reescrito en MEMO_Areas.lsp: ya no enciende todas las capas y descuenta islas.",
    "LISP_Secciones/Area_Secc 3P( AS ).lsp": "Reescrito en MEMO_Areas.lsp: cualquier número de vértices.",
    "LISP_Estimaciones/Comp_Area_Secc ( CAS ).lsp": "Reescrito en MEMO_Areas.lsp: geometría corregida; QA era idéntico a CAS.",
    "LISP_Secciones/Area Pref Nuevo ( HA2 ).lsp": "Copia idéntica byte a byte de 'Area Pref Guard ( HA )'.",
    "LISP_Secciones/HAEA.lsp": "Versión 5.2 superada por EA v7.0 (mismos comandos EA/HA/HAEA). Además cambiaba el *error* global de AutoCAD al cargar.",
    "LISP_Hatch/Fusionar Hatch ( FH ).lsp": "FUSIONHATCH/FH ya vienen incluidos dentro de SeparaHatch ( SPH ).",
    "LISP_VistasLayout/Guardar Vistas ( GV ).lsp": "GV ya viene incluido dentro de Restaurar Vistas ( AV ).",
    "LISP_Textos/Coordenadas_a_texto ( COR ).lsp": "Versión anterior; CORM (versión mejorada 2024) define COR, COR2 y CORM. Sólo se pierde CORA.",
    "LISP_NubePuntos/Procesa-XYZ  ( PZ ).lsp": "Superado por XYZ-Tools 2.6.2 (incluye PZ y P-Z). Buscaba un Procesa-XYZ.dcl que no existe y armaba mal la ruta (sin '\\').",
    "LISP_NubePuntos/perfil_dialog.dcl": "No se usa: PERFIL genera su propio DCL temporal.",
}

# Comandos que existen idénticos en más de un archivo (permitido).
DUPLICADOS_PERMITIDOS = {
    # LIMPIARTABLA es idéntico en COP y ASI; se carga desde COP.
    "LIMPIARTABLA": "Estimaciones/COP_ConceptosObrasPublicas.lsp",
}

# Comandos de prueba/depuración: se cargan pero no aparecen en el menú.
OCULTOS = {"XYZTEST", "CCNTEST", "ST-TEST", "HARESET"}

# ---------------------------------------------------------------------------
# Categorías -> color del icono
# ---------------------------------------------------------------------------
CATEGORIAS = {
    "conceptos":  ("Conceptos",   "#1F6FB2"),
    "bacheo":     ("Bacheo",      "#D9730D"),
    "secciones":  ("Secciones",   "#2E8B57"),
    "areas":      ("Áreas",       "#3C9D5D"),
    "imagen":     ("Imagen",      "#6A4C93"),
    "textos":     ("Textos",      "#C0392B"),
    "coord":      ("Coordenadas", "#A93226"),
    "hatch":      ("Hatch",       "#8E6E3B"),
    "vistas":     ("Vistas",      "#34495E"),
    "layouts":    ("Layouts",     "#4A6076"),
    "puntos":     ("Puntos",      "#138D75"),
    "curvas":     ("Curvas",      "#117864"),
    "xyz":        ("Batimetría",  "#1F618D"),
    "perfil":     ("Perfiles",    "#2874A6"),
    "edicion":    ("Edición",     "#5D6D7E"),
    "bloques":    ("Bloques",     "#7D3C98"),
    "memo":       ("MEMO",        "#212F3D"),
}

# ---------------------------------------------------------------------------
# Comandos:  COMANDO -> (etiqueta corta, descripción/tooltip, glifo, categoría)
# ---------------------------------------------------------------------------
COMANDOS = {
    # Conceptos
    "COP":          ("Obras Públicas",   "Tabla de conceptos de 5 columnas (No. | Código | Concepto | Unidad | Precio). Lee lo copiado en Excel (portapapeles).", "tabla", "conceptos"),
    "ASI":          ("Asipona",          "Tabla de conceptos de 7 columnas (No. | Código | Descripción | Unidad | P.U. | Cantidad | Importe) con total. Lee el portapapeles.", "tabla", "conceptos"),
    "CSSA":         ("SSA",              "Tabla de conceptos formato SSA (No. | Concepto | Unidad | Cantidad) con recuadros. Lee el portapapeles.", "tabla", "conceptos"),
    "LCO":          ("Limpiar conceptos","Borra TEXT y MTEXT de la capa CONCEPTOS.", "limpiar", "conceptos"),
    "LIMPIARTABLA": ("Limpiar tabla",    "Borra textos de las capas CONCEPTOS y ENCABEZADOS (tablas COP/ASI).", "limpiar", "conceptos"),
    "LIMPIARCSSA":  ("Limpiar SSA",      "Borra los elementos creados por CSSA.", "limpiar", "conceptos"),
    # Bacheo
    "RS":           ("Rectángulo",       "Dibuja rectángulos (baches) con cotas por fuera y hatch individual en capa Hatch_Bache.", "rect", "bacheo"),
    "RNB":          ("Renumerar",        "Renumera los rectángulos seleccionados por vecino más cercano.", "renum", "bacheo"),
    "RENUMERARVECINO": ("Renumerar vecino", "Igual que RNB.", "renum", "bacheo"),
    "COTB":         ("Cotar baches",     "Anota largo y ancho de cada rectángulo en la capa GEOMETRIA_RECTANGULOS.", "cota", "bacheo"),
    "EXR":          ("Exportar CSV",     "Exporta los baches a CSV: número, largo, ancho, área, volumen y acumulado.", "export", "bacheo"),
    "HR":           ("Hatch baches",     "Aplica hatch a los rectángulos seleccionados.", "hatch", "bacheo"),
    "BTR":          ("Borrar textos",    "Borra los textos que quedan dentro de los rectángulos seleccionados.", "borrar", "bacheo"),
    "RSHATCH":      ("Re-hatch",         "Vuelve a aplicar el hatch a polilíneas existentes.", "hatch", "bacheo"),
    "RS-CONFIG":    ("Config. RS",       "Configura patrón, escala, ángulo, color y capa del hatch de RS.", "engrane", "bacheo"),
    "RSC":          ("Cotas 2 dec.",     "Crea cotas con 2 decimales (estilo de RS).", "cota", "bacheo"),
    "AEC":          ("Estilo cota",      "Actualiza el estilo de cota usado por RS.", "cota", "bacheo"),
    "RC2":          ("Redondear cotas",  "Redondea cotas existentes a 2 decimales.", "cota", "bacheo"),
    "VERLISTA":     ("Ver lista",        "Muestra la lista de rectángulos en memoria.", "lista", "bacheo"),
    "VERXDATA":     ("Ver XDATA",        "Muestra el XDATA de los rectángulos.", "lista", "bacheo"),
    "AXD":          ("Asignar XDATA",    "Asigna XDATA (número, largo, ancho) a rectángulos existentes.", "lista", "bacheo"),
    # Secciones
    "ELTN":         ("Elevación T.N.",   "Coloca elevaciones de terreno natural en secciones (escala vertical 1:1000 o 1:100).", "elev", "secciones"),
    "CAS": ('Figuras con fórmula', 'Generador: triángulos, trapecios, rectángulos, círculos con su fórmula y el área total.', 'area', 'secciones'),
    "AS": ('Área terreno-corte', 'Área entre la línea de terreno y la de corte, con su fórmula por trapecios.', 'area', 'secciones'),
    "R00":          ("Números 00.00",    "Cambia números de los textos por 00.00 (conserva 'M2').", "renum", "secciones"),
    # Áreas
    "EA": ('Exportar áreas', 'Secciones: etiquetar por capa y exportar a Excel con hoja RESUMEN (cuadro de diálogo).', 'export', 'areas'),
    "HAEA-EXPORT":  ("Sólo exportar",    "Sólo exporta las áreas a Excel/CSV.", "export", "areas"),
    "HA": ('Área a texto', 'Hatch o área cerrada -> su texto, uno tras otro (Enter = terminar). Formato según MAREA.', 'area', 'areas'),
    "AC": ('Áreas contorno', 'Tocar dentro de los contornos y sumar por tipo (AC=, ACA=, AB=, ASR=, AT=); respeta tus capas.', 'area', 'areas'),
    "AH": ('Hatches a texto', 'Hatches seleccionados -> su texto del mismo tipo (motor de EA, por recuadro de sección).', 'hatch', 'areas'),
    # Imagen
    "IJPG":         ("CAD a JPG",        "Exporta el área seleccionada a imagen JPG/PNG con recorte exacto.", "imagen", "imagen"),
    "IJPG-EMF":     ("CAD a EMF",        "Exporta el área seleccionada a EMF vectorial sin bordes.", "imagen", "imagen"),
    "IJPG-PC3":     ("Trazador JPG",     "Configura el trazador PC3 para JPG/PNG.", "engrane", "imagen"),
    # Textos
    "CTB":          ("Copiar texto",     "Caja de herramientas de texto (diálogo con 6 herramientas).", "copiar", "textos"),
    "CTE":          ("Copia + estilo",   "Copia texto con opción de estilo.", "copiar", "textos"),
    "CTP":          ("Copia + prop.",    "Copia texto con propiedades (texto / todo / sólo rotación).", "copiar", "textos"),
    "IPT":          ("Igualar prop.",    "Iguala propiedades de texto.", "copiar", "textos"),
    "CTN":          ("Copia numerada",   "Copia texto con numeración automática (V-1, V-2, V-3...).", "renum", "textos"),
    "STV":          ("Sumar valor",      "Suma o resta un valor a textos numéricos.", "suma", "textos"),
    "CTX":          ("Cambiar texto",    "Cambia los textos seleccionados por un texto tecleado (Enter = usar el texto copiado).", "texto", "textos"),
    "ALIT":         ("Alinear",          "Alinea textos (TEXT/MTEXT) en vertical u horizontal.", "alinear", "textos"),
    "RTT":          ("Rotar texto",      "Rota textos sobre su punto medio.", "rotar", "textos"),
    "UL":           ("May/Min",          "Cambia entre mayúsculas y minúsculas.", "mayus", "textos"),
    "PS":           ("Prefijo/Sufijo",   "Agrega prefijo y/o sufijo a varios textos.", "prefijo", "textos"),
    "PREFSUFIND":   ("Pref/Suf indiv.",  "Agrega prefijo/sufijo texto por texto.", "prefijo", "textos"),
    "SETPREFSUF":   ("Config. Pref/Suf", "Establece los valores por defecto de PS.", "engrane", "textos"),
    "VERPREFSUF":   ("Ver Pref/Suf",     "Muestra los valores guardados de PS.", "info", "textos"),
    "LIMPIARPREFSUF": ("Limpiar Pref/Suf", "Limpia los valores guardados de PS.", "limpiar", "textos"),
    "ST":           ("Sumar textos",     "Suma los valores numéricos de los textos seleccionados.", "suma", "textos"),
    "PTE":          ("Pendiente",        "Rotula la pendiente entre dos puntos.", "pendiente", "textos"),
    "CTAF":         ("Alto/Ancho",       "Cambia altura y factor de ancho de textos.", "texto", "textos"),
    "CTAF2":        ("Alto/Ancho +",     "Cambia altura y factor de ancho con opciones.", "texto", "textos"),
    "CTF":          ("Factor ancho",     "Cambia sólo el factor de ancho de textos.", "texto", "textos"),
    # Coordenadas
    "CORM":         ("Coordenadas",      "Actualiza textos E/N/Z con las coordenadas de varios puntos.", "coord", "coord"),
    "COR":          ("Coord. punto",     "Actualiza textos con coordenadas (decimales y prefijo).", "coord", "coord"),
    "COR2":         ("Coord. rápida",    "Coordenadas rápido (3 decimales, con prefijo).", "coord", "coord"),
    # Hatch
    "FH":           ("Fusionar",         "Fusiona varios hatches en uno solo con el patrón de referencia.", "fusion", "hatch"),
    "FUSIONHATCH":  ("Fusionar hatch",   "Igual que FH.", "fusion", "hatch"),
    "SPH":          ("Separar",          "Separa un hatch compuesto en un hatch por frontera.", "separa", "hatch"),
    "SEPARAHATCH":  ("Separar hatch",    "Igual que SPH.", "separa", "hatch"),
    "CHS":          ("Hatch similar",    "Crea un hatch con las propiedades de otro.", "hatch", "hatch"),
    # Vistas
    "CV":           ("Crear vistas",     "Crea vistas en capa VISTAS a partir de puntos.", "vista", "vistas"),
    "GV":           ("Guardar vista",    "Guarda la vista actual con número o nombre.", "vista", "vistas"),
    "AV":           ("Activar vista",    "Restaura una vista guardada.", "vista", "vistas"),
    "BV":           ("Borrar vistas",    "Lista y borra vistas guardadas.", "borrar", "vistas"),
    # Layouts
    "CLO":          ("Clonar layout",    "Copia el layout activo N veces con prefijo.", "layout", "layouts"),
    "CFTL":         ("Config. layouts",  "Configura página de varios layouts a la vez (copiar de uno existente).", "engrane", "layouts"),
    "SL":           ("Suprimir layouts", "Elimina layouts seleccionados de una lista.", "borrar", "layouts"),
    # Puntos
    "ICE":          ("Importar puntos",  "Importa puntos desde TXT/CSV/XYZ con capas y etiquetas.", "import", "puntos"),
    "PCC":          ("Puntos a capas",   "Clasifica puntos y textos de CivilCAD en capas.", "capas", "puntos"),
    "UPP":          ("Unir puntos",      "Une puntos con una polilínea.", "poli", "puntos"),
    "UPPA":         ("Unir puntos (osnap)", "UPP con referencia a objetos automática (nodo, punto medio, intersección).", "poli", "puntos"),
    "PIT":          ("Punto en texto",   "Convierte '-18 36' en '-18.36' y crea puntos en el punto de inserción.", "puntos", "puntos"),
    "MALLA-PUNTOS": ("Malla de puntos",  "Genera malla de puntos interpolando entre curvas de nivel, con coloreo y etiquetas.", "puntos", "puntos"),
    "MLL":          ("Malla (MLL)",      "Alias de MALLA-PUNTOS.", "puntos", "puntos"),
    "EXPORTAR-PUNTOS": ("Exportar puntos", "Exporta puntos a CSV.", "export", "puntos"),
    "EXP":          ("Exportar (EXP)",   "Alias de EXPORTAR-PUNTOS.", "export", "puntos"),
    "X-Y":          ("Coord. polígono",  "Exporta las coordenadas X Y de una polilínea a TXT.", "export", "puntos"),
    "CPEC":         ("Color por Z",      "Colorea puntos AutoCAD según su elevación.", "color", "puntos"),
    # Curvas
    "CCN":          ("Color curvas",     "Colorea curvas de nivel existentes por intervalos (no modifica geometría).", "curvas", "curvas"),
    "CCNT":         ("Color curvas (T)", "Alias de CCN.", "curvas", "curvas"),
    "CCNAYUDA":     ("Ayuda CCN",        "Ayuda de CCN.", "ayuda", "curvas"),
    "ECN":          ("Elevar curvas",    "Asigna elevación a curvas de nivel y las etiqueta (menú principal).", "elev", "curvas"),
    "ECN-P":        ("Propagar",         "ECN: propagación de elevación por clic.", "curvas", "curvas"),
    "ECN-M":        ("Manual",           "ECN: método manual.", "curvas", "curvas"),
    "ECN-ETIQ":     ("Etiquetas auto",   "ECN: etiquetas automáticas con intervalo.", "texto", "curvas"),
    "ECN-ETIQM":    ("Etiqueta manual",  "ECN: etiqueta manual con intervalo.", "texto", "curvas"),
    "ETM":          ("ETM",              "Atajo de ECN-ETIQM.", "texto", "curvas"),
    "ECN-RECOLOR":  ("Recolorear",       "ECN: colorear por elevación.", "color", "curvas"),
    "ECN-DUPLICADOS": ("Duplicados",     "ECN: limpia etiquetas duplicadas.", "limpiar", "curvas"),
    "ECN-CONFIG":   ("Config. ECN",      "ECN: configurar parámetros.", "engrane", "curvas"),
    "ECN-QUITAR":   ("Quitar",           "ECN: quitar elevación/etiquetas de lo seleccionado.", "borrar", "curvas"),
    "ECN-LIMPIA":   ("Limpiar color",    "ECN: restaura colores originales.", "limpiar", "curvas"),
    "ECN-DESHACER": ("Deshacer ECN",     "ECN: deshace el último coloreo.", "rotar", "curvas"),
    "ECN-LISTA":    ("Listar",           "ECN: lista curvas por capa/elevación.", "lista", "curvas"),
    # XYZ
    "XYZ":          ("XYZ-Tools",        "Menú principal de XYZ-Tools (importar, procesar, unir, exportar).", "agua", "xyz"),
    "IXYZ":         ("Importar XYZ",     "Importa archivos XYZ con simbología por profundidad.", "import", "xyz"),
    "PZ":           ("Procesar XYZ",     "Procesa archivos XYZ (5 modos de procesamiento).", "agua", "xyz"),
    "P-Z":          ("Puntos Z",         "Herramientas de puntos (Procesa_Puntos).", "puntos", "xyz"),
    "XYZU":         ("Unir XYZ",         "Une varios archivos XYZ.", "fusion", "xyz"),
    "XYZUNIR":      ("Unir XYZ",         "Igual que XYZU.", "fusion", "xyz"),
    "EXYZ":         ("Exportar XYZ",     "Exporta puntos seleccionados a XYZ.", "export", "xyz"),
    "XYZEXPORTAR":  ("Exportar XYZ",     "Igual que EXYZ.", "export", "xyz"),
    "IZ":           ("Invertir Z",       "Invierte el signo de Z de los puntos seleccionados.", "elev", "xyz"),
    "OZ":           ("Offset Z",         "Suma una distancia a la Z de los puntos seleccionados.", "elev", "xyz"),
    "ZM":           ("Z mín/máx",        "Muestra Z mínima y máxima de la selección.", "info", "xyz"),
    "XYZLOTES":     ("Lotes",            "Lista los lotes importados.", "lista", "xyz"),
    "XYZBORRAR":    ("Borrar lote",      "Borra un lote importado.", "borrar", "xyz"),
    "XYZRESTAURAR": ("Restaurar capas",  "Restaura la visibilidad de capas.", "vista", "xyz"),
    "XYZAYUDA":     ("Ayuda XYZ",        "Ayuda de XYZ-Tools.", "ayuda", "xyz"),
    "XYZTEST":      ("Prueba XYZ",       "Pruebas internas de XYZ-Tools.", "info", "xyz"),
    # Perfil
    "PERFIL":       ("Perfil transv.",   "Genera secciones transversales batimétricas con retícula y área.", "perfil", "perfil"),
    # Edición
    "BPOL":         ("Borra por pol.",   "Borra/recorta objetos por un objeto cerrado.", "clip", "edicion"),
    "CLIPIT":       ("CLIPIT",           "Recorta imágenes con un rectángulo (polilínea cerrada).", "clip", "edicion"),
    # Bloques
    "IBC":          ("Bloques en capa",  "Inserta bloques en los puntos de capas *-Punto detectando la escala.", "bloque", "bloques"),
    "IBCZ":         ("Bloques escala",   "Inserta bloques en capa con escalas definidas.", "bloque", "bloques"),
    "IBM":          ("Bloques múltiples","Copia un bloque de referencia a múltiples puntos.", "bloque", "bloques"),
    "ARBOLES":      ("Árboles",          "Inserta 'Arbol' (escala 760.32).", "bloque", "bloques"),
    "RAP":          ("RAP",              "Inserta 'RAP'.", "bloque", "bloques"),
    "DES":          ("Descarga",         "Inserta 'Descarga'.", "bloque", "bloques"),
    "IBPV":         ("PV existente",     "Inserta 'PV Existente'.", "bloque", "bloques"),
    "IBTM":         ("Poste TM",         "Inserta 'Poste de TM'.", "bloque", "bloques"),
    "CFE":          ("Poste CFE",        "Inserta 'Poste de CFE'.", "bloque", "bloques"),
    "VERBLOQUES":   ("Ver bloques",      "Muestra los bloques existentes en el dibujo.", "lista", "bloques"),
    "VERCAPAS":     ("Ver capas",        "Muestra las capas finales requeridas.", "capas", "bloques"),
    "CONFIGESCALAS":("Ver escalas",      "Muestra las escalas configuradas.", "info", "bloques"),
    # Unificados
    "MTABLA":       ("Tabla Excel",      "Tabla de conceptos desde el portapapeles: detecta el formato (5 col. Obras Públicas, 7 Asipona, 4 SSA) y llama a COP/ASI/CSSA.", "tabla", "conceptos"),
    "MAREA": ('Áreas (MAREA)', 'Cuadro de diálogo de áreas: elige la herramienta y cómo escribir el área.', 'area', 'areas'),
    "MBACHEO":      ("Flujo bacheo",     "Bacheo paso a paso: Dibujar > Numerar > Cotar > Hatch > Exportar.", "rect", "bacheo"),
    # MEMO (definidos en el cargador)
    "MEMO_AYUDA":   ("Ayuda",            "Lista todos los comandos del MemoPRO por categoría.", "ayuda", "memo"),
    "MEMO_MENU":    ("Mostrar menú",     "Carga el menú MEMO si no está cargado y explica cómo mostrar las fichas.", "ayuda", "memo"),
    "MEMO_INFO":    ("Info",             "Muestra versión, carpeta y archivos cargados del MemoPRO.", "info", "memo"),
    "MEMO_QUITAR_ANTERIOR": ("Quitar menú viejo", "Descarga el menú anterior 'MEMO' (Memo.cuix) para que no se duplique.", "limpiar", "memo"),
    "MEMO_CONFIG":  ("Configurar",       "Anchos de tablas, espesor de bacheo, uso del portapapeles, etc.", "engrane", "memo"),
    "MEMO_VERIFICAR": ("Verificar",      "Carga todos los archivos y comprueba que cada comando exista (usar en un dibujo nuevo).", "lista", "memo"),
    "MEMO_COMPILAR": ("Compilar",        "Compila los LISP a FAS en %APPDATA%\\MEMO_SISTEMA\\FAS para cargar más rápido.", "engrane", "memo"),
    "ST-TEST":      ("Prueba ST",        "Prueba interna de ST.", "info", "textos"),
    "CCNTEST":      ("Prueba CCN",       "Prueba interna de CCN.", "info", "curvas"),
}

# Comandos que define el propio cargador (no vienen de un archivo).
COMANDOS_CARGADOR = ["MEMO_AYUDA", "MEMO_MENU", "MEMO_INFO", "MEMO_QUITAR_ANTERIOR", "MEMO_VERIFICAR", "MEMO_COMPILAR"]

# ---------------------------------------------------------------------------
# Fichas (Ribbon).  Cada panel es una lista de elementos:
#   "CMD"            -> botón grande con texto
#   ["A", "B", "C"]  -> columna de hasta 3 botones pequeños con texto
# ---------------------------------------------------------------------------
FICHAS = [
    ("MemoPRO Estimaciones", "ME", [
        ("Conceptos", ["MTABLA", "COP", "ASI", "CSSA", ["LCO", "LIMPIARTABLA", "LIMPIARCSSA"]]),
        ("Bacheo", ["MBACHEO", "RS", "RNB", "COTB", "EXR",
                    ["HR", "BTR", "RSHATCH"], ["RSC", "AEC", "RC2"], ["RS-CONFIG", "VERLISTA", "AXD"]]),
        ("Secciones", ["ELTN", "CAS", ["AS", "R00"]]),
        ("Áreas", ["MAREA", "HA", "AH", "AC", "EA", ["HAEA-EXPORT"]]),
        ("Imagen", ["IJPG", ["IJPG-EMF", "IJPG-PC3"]]),
    ]),
    ("MemoPRO Topografía", "MT", [
        ("Puntos", ["ICE", "PCC", "MALLA-PUNTOS", ["UPP", "UPPA", "PIT"], ["EXPORTAR-PUNTOS", "X-Y", "CPEC"]]),
        ("Curvas de nivel", ["CCN", "ECN", ["ECN-P", "ECN-M", "ECN-ETIQ"], ["ECN-ETIQM", "ECN-RECOLOR", "ECN-DUPLICADOS"],
                             ["ECN-CONFIG", "ECN-DESHACER", "ECN-LISTA"]]),
        ("Batimetría XYZ", ["XYZ", "IXYZ", "PZ", ["P-Z", "XYZU", "EXYZ"], ["IZ", "OZ", "ZM"],
                            ["XYZLOTES", "XYZBORRAR", "XYZAYUDA"]]),
        ("Perfiles", ["PERFIL"]),
        ("Edición", ["BPOL", "CLIPIT"]),
        ("Bloques", ["IBC", "IBCZ", "IBM", ["ARBOLES", "RAP", "DES"], ["IBPV", "IBTM", "CFE"],
                     ["VERBLOQUES", "VERCAPAS", "CONFIGESCALAS"]]),
    ]),
    ("MemoPRO Dibujo", "MD", [
        ("Textos", ["CTB", ["CTE", "CTP", "IPT"], ["CTN", "STV", "CTX"], ["ALIT", "RTT", "UL"],
                    ["PS", "PREFSUFIND", "SETPREFSUF"], ["ST", "PTE", "CTAF"]]),
        ("Coordenadas", ["CORM", ["COR", "COR2"]]),
        ("Hatch", ["FH", "SPH", "CHS"]),
        ("Vistas", ["CV", "GV", "AV", "BV"]),
        ("Layouts", ["CLO", "CFTL", "SL"]),
        ("MEMO", ["MEMO_AYUDA", "MEMO_CONFIG", ["MEMO_INFO", "MEMO_VERIFICAR", "MEMO_COMPILAR"], ["MEMO_QUITAR_ANTERIOR", "MEMO_MENU"]]),
    ]),
]
