;;; MemoPRO 3.0.0 - archivo generado por construir_bundle.py
;;; Origen: @fuente/EA_ExportarEstArea.lsp

;===============================================================
; EA - EXPORTADOR + ETIQUETADO + EXCEL
; Versión 7.2 MEMO - Compatible con CivilCAD (restaura *error*)
;
; Nuevo en 7.2 (MemoPRO):
;  - Asignación por RECUADRO de sección: cada texto de área va al CAD
;    que está dentro del mismo recuadro (polilínea cerrada); al
;    etiquetar, sólo se buscan hatches dentro de ese recuadro.
;  - Hoja RESUMEN en Excel: corte, corte x coeficiente de
;    abundamiento, relleno, diferencia y CURVA MASA acumulada, más
;    volumen total por tipo.
;  - Tipos nuevos SUBBASE, TERRAPLEN y DESMONTE; patrones de texto y
;    capa configurables (EA_TIPO_<TIPO>); SUBBASE ya no cuenta como BASE.
;
; Correcciones 7.1 (MemoPRO):
;  - El valor de área que va a Excel se toma DESPUÉS del "=" o ":".
;    Antes "SUB-BASE=3.25" daba -3.25, "(M2)=12.50" daba 2,
;    "1,234.56" daba 1 y "15,5" daba 15.
;  - Se ignoran los códigos de formato de MTEXT (\H0.25x; etc.) al
;    leer y al reemplazar el área.
;  - Cadenamiento: sólo se leen los dígitos junto al "+"
;    ("SECCION 3 KM 1+020" daba 31020).
;  - Un CAD repetido en el dibujo ya no duplica sus áreas en Excel.
;  - Fórmulas de Excel en inglés (IF, AVERAGE, ROUND, SUM): con las
;    fórmulas en español Excel mostraba #¿NOMBRE?.
;  - Las casillas "Tipo de Áreas a Procesar" ahora sí filtran.
;  - Se ignoran textos en capas de membrete/títulos/notas.
;  - "Exportar" en modo "Seleccionar secciones" pide la selección
;    (antes usaba una selección vieja o todo el dibujo).
;  - Áreas con decimales fijos (sin depender de DIMZIN).
;  - Distancia máxima y decimales configurables con MEMO_CONFIG
;    (EA_DISTANCIA_MAX, EA_DECIMALES).
;===============================================================

(vl-load-com)

;===============================================================
; GUARDAR ENTORNO DE CIVILCAD
;===============================================================
(if (not *haea_error_original*) 
  (setq *haea_error_original* *error*))

;===============================================================
; VARIABLES GLOBALES
;===============================================================
(if (not *haea_capas_ignorar*)
  (setq *haea_capas_ignorar* 
    '("MEMBRETE" "MEMBRETES" "TITULOS" "TÍTULOS" 
      "ESCALAS" "ESCALA" "NOTAS" "NOTA" 
      "SIMBOLOGIA" "SIMBOLOGÍA" "LEYENDA" 
      "DEFPOINTS")))

(if (not *haea_textos_ignorar*)
  (setq *haea_textos_ignorar*
    '("*ESCALA*" "* : *" "*1:*" "*:1*"
      "*LAMINA*" "*LÁMINA*" "*PLANO*" "*PLANTA*" "*PERFIL*" "*ALZADO*"
      "*SECCION*" "*SECCIÓN*" "*DETALLE*"
      "*PROYECTO*" "*TITULO*" "*TÍTULO*"
      "*FECHA*" "*DIBUJO*" "*DIBUJANTE*" "*REVISO*" "*REVISÓ*"
      "*DISEÑO*" "*ING.*" "*ARQ.*"
      "*NORTE*" "*CROQUIS*"
      "*SIMBOLOGIA*" "*SIMBOLOGÍA*" "*LEYENDA*"
      "*NOTA:*" "*NOTA :*"
      "*NOMENCLATURA*" "*ABREVIATURA*")))

(if (not *haea_prefijo*) (setq *haea_prefijo* "A="))
(if (not *haea_ultimo_modo*) (setq *haea_ultimo_modo* "Manual"))
(if (not *haea_ultima_accion*) (setq *haea_ultima_accion* "HA"))
(if (not *haea_usar_filtro_capas*) (setq *haea_usar_filtro_capas* T))
(if (not *haea_usar_filtro_textos*) (setq *haea_usar_filtro_textos* T))
(if (not *haea_limite_dist*) (setq *haea_limite_dist* 50.0))
(if (not *haea_cambiar_capa*) (setq *haea_cambiar_capa* T))
(if (not *haea_textos_seleccionados*) (setq *haea_textos_seleccionados* nil))
(if (not *haea_tipos_activos*)
  (setq *haea_tipos_activos* '("SUBBASE" "SUBRASANTE" "CARPETA" "EXCAVACION" "DESMONTE" "TERRAPLEN"
                               "RELLENO" "CORAZA" "NUCLEO" "ARENA" "CORTE" "AFINE" "BASE")))

(setq *haea_tipos_areas* '(
  ("CARPETA" ("*CARPETA*" "*ACA*" "*ASF*" "*ASFALTO*" "*CARP*"))
  ("CORTE" ("*CORTE*" "*CEPA*" "*ACO*"))
  ("EXCAVACION" ("*EXCAVACION*" "*EXCAV*" "*EXC*"))
  ("BASE" ("*BASE*" "*BAS*" "*AB*"))
  ("SUBRASANTE" ("*SUBRASANTE*" "*ASR*" "*SUBR*"))
  ("ARENA" ("*ARENA*" "*AREN*"))
  ("NUCLEO" ("*NUCLEO*" "*NUC*" "*NUCLE*"))
  ("CORAZA" ("*CORAZA*" "*CORAZ*" "*COR*"))
  ("RELLENO" ("*RELLENO*" "*RELL*" "*TERRAPLEN*"))
  ("AFINE" ("*AFINE*" "*TALUD*" "*ACOMODO*"))
))

;===============================================================
; HELPERS EXCEL
;===============================================================

(defun numero-a-letra (num / n resto resultado letras)
  (setq letras "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        resultado ""
        n (fix num))
  (while (> n 0)
    (setq resto (rem (1- n) 26)
          resultado (strcat (substr letras (1+ resto) 1) resultado)
          n (/ (- n (1+ resto)) 26))
  )
  resultado
)

(defun excel-set (hoja fila col valor / celda_str celda)
  (setq celda_str (strcat (numero-a-letra col) (itoa fila)))
  (setq celda (vlax-get-property hoja 'Range celda_str))
  (vlax-put celda 'Value valor)
)

(defun excel-formato (hoja fila1 col1 fila2 col2 opciones / 
                       rango_str rango font interior bordes)
  (setq rango_str (strcat (numero-a-letra col1) (itoa fila1) ":" 
                          (numero-a-letra col2) (itoa fila2)))
  
  (setq rango (vlax-get-property hoja 'Range rango_str))
  
  (foreach opcion opciones
    (cond
      ((= (car opcion) 'bold)
       (setq font (vlax-get-property rango 'Font))
       (vlax-put-property font 'Bold 
         (if (= (cadr opcion) 1) :vlax-true :vlax-false)))
      ((= (car opcion) 'size)
       (setq font (vlax-get-property rango 'Font))
       (vlax-put-property font 'Size (cadr opcion)))
      ((= (car opcion) 'color)
       (setq font (vlax-get-property rango 'Font))
       (vlax-put-property font 'Color (cadr opcion)))
      ((= (car opcion) 'bg)
       (setq interior (vlax-get-property rango 'Interior))
       (vlax-put-property interior 'Color (cadr opcion)))
      ((= (car opcion) 'halign)
       (vlax-put-property rango 'HorizontalAlignment (cadr opcion)))
      ((= (car opcion) 'valign)
       (vlax-put-property rango 'VerticalAlignment (cadr opcion)))
      ((= (car opcion) 'merge)
       (vlax-put-property rango 'MergeCells 
         (if (cadr opcion) :vlax-true :vlax-false)))
      ((= (car opcion) 'borders)
       (setq bordes (vlax-get-property rango 'Borders))
       (vlax-put-property bordes 'LineStyle 1)
       (vlax-put-property bordes 'Weight (cadr opcion)))
    )
  )
  rango
)

(defun excel-ancho-col (hoja col ancho / col_str col_rango)
  (setq col_str (if (numberp col)
                    (numero-a-letra col)
                    col))
  (setq col_rango (vlax-get-property hoja 'Range 
                    (strcat col_str ":" col_str)))
  (vlax-put col_rango 'ColumnWidth ancho)
)

;===============================================================
; HOJA RESUMEN: CORTE / RELLENO / CURVA MASA (7.2)
;   Lee la hoja VOLUMEN con fórmulas (si se corrige VOLUMEN, el
;   resumen se recalcula). Clases configurables con MEMO_CONFIG:
;   EA_TIPOS_CORTE, EA_TIPOS_RELLENO; coeficiente en la celda D2.
;===============================================================

;; "=SUM(VOLUMEN!X7,VOLUMEN!Y7)" o 0 si no hay columnas
(defun ea:suma-cols (cols fila / f)
  (if cols
    (progn
      (setq f (strcat "=SUM(VOLUMEN!" (car cols) (itoa fila)))
      (foreach c (cdr cols) (setq f (strcat f ",VOLUMEN!" c (itoa fila))))
      (strcat f ")"))
    0))

(defun ea:hoja-resumen (excel_wb tipos num_tipos fini ffin ftotal
                        / ws cortes rellenos cols_c cols_r k col f r ultima fila_t)
  (setq ws (vlax-invoke-method (vlax-get-property excel_wb 'Worksheets) 'Add))
  (vlax-put-property ws 'Name "RESUMEN")
  (setq cortes (ea:split (strcase (ea:cfg-txt "EA_TIPOS_CORTE" "CORTE,EXCAVACION,DESMONTE")) ",")
        rellenos (ea:split (strcase (ea:cfg-txt "EA_TIPOS_RELLENO" "RELLENO,TERRAPLEN,NUCLEO,CORAZA,SUBRASANTE")) ",")
        k 0)
  ;; columnas de VOLUMEN de cada clase
  (foreach tp tipos
    (setq col (numero-a-letra (+ 3 (* 2 num_tipos) k)) k (1+ k))
    (if (member tp cortes) (setq cols_c (append cols_c (list col))))
    (if (member tp rellenos) (setq cols_r (append cols_r (list col)))))
  (excel-set ws 1 1 "RESUMEN DE VOLÚMENES Y CURVA MASA")
  (excel-set ws 2 1 "Coeficiente de abundamiento del corte:")
  (excel-set ws 2 4 (ea:cfg-num "EA_COEF_ABUND" 1.0))
  (excel-set ws 4 1 "CAD")
  (excel-set ws 4 2 "VOL. CORTE")
  (excel-set ws 4 3 "CORTE x COEF.")
  (excel-set ws 4 4 "VOL. RELLENO")
  (excel-set ws 4 5 "DIFERENCIA")
  (excel-set ws 4 6 "CURVA MASA (acumulado)")
  ;; una fila por CAD
  (setq r fini f 5)
  (while (<= r ffin)
    (excel-set ws f 1 (strcat "=VOLUMEN!A" (itoa r)))
    (excel-set ws f 2 (ea:suma-cols cols_c r))
    (excel-set ws f 3 (strcat "=B" (itoa f) "*$D$2"))
    (excel-set ws f 4 (ea:suma-cols cols_r r))
    (excel-set ws f 5 (strcat "=C" (itoa f) "-D" (itoa f)))
    (excel-set ws f 6 (if (= f 5) "=E5" (strcat "=F" (itoa (1- f)) "+E" (itoa f))))
    (setq r (1+ r) f (1+ f)))
  (setq ultima (1- f))
  (excel-set ws f 1 "TOTAL")
  (foreach c '("B" "C" "D" "E")
    (excel-set ws f (1+ (- (ascii c) (ascii "A"))) (strcat "=SUM(" c "5:" c (itoa ultima) ")")))
  (excel-formato ws 1 1 1 6 (list (list 'bold 1) (list 'size 14) (list 'color 16777215)
                                  (list 'bg 12238897) (list 'halign -4108) (list 'merge T)))
  (excel-formato ws 4 1 4 6 (list (list 'bold 1) (list 'color 16777215) (list 'bg 12238897) (list 'halign -4108)))
  (excel-formato ws 4 1 f 6 (list (list 'borders 2)))
  (excel-formato ws f 1 f 6 (list (list 'bold 1) (list 'bg 16248831)))
  (excel-formato ws 2 4 2 4 (list (list 'bold 1) (list 'bg 10092543)))
  ;; volumen total por tipo y su clase
  (setq fila_t (+ f 3) k 0)
  (excel-set ws (1- fila_t) 1 "VOLUMEN POR TIPO")
  (excel-set ws fila_t 1 "TIPO")
  (excel-set ws fila_t 2 "VOLUMEN")
  (excel-set ws fila_t 3 "CLASE")
  (foreach tp tipos
    (setq fila_t (1+ fila_t))
    (excel-set ws fila_t 1 tp)
    (excel-set ws fila_t 2 (strcat "=VOLUMEN!" (numero-a-letra (+ 3 (* 2 num_tipos) k)) (itoa ftotal)))
    (excel-set ws fila_t 3 (cond ((member tp cortes) "CORTE") ((member tp rellenos) "RELLENO") (T "-")))
    (setq k (1+ k)))
  (excel-formato ws (- fila_t (length tipos)) 1 (- fila_t (length tipos)) 3
                 (list (list 'bold 1) (list 'color 16777215) (list 'bg 12238897)))
  (excel-formato ws (- fila_t (length tipos)) 1 fila_t 3 (list (list 'borders 2)))
  (vl-catch-all-apply
    '(lambda ()
       (vlax-put-property (vlax-get-property ws 'Range (strcat "B5:F" (itoa f))) 'NumberFormat "0.00")
       (vlax-put-property (vlax-get-property ws 'Range (strcat "B" (itoa (- fila_t (length tipos))) ":B" (itoa fila_t))) 'NumberFormat "0.00")
       (vlax-put-property (vlax-get-property ws 'Range "D2") 'NumberFormat "0.00")))
  (excel-ancho-col ws 1 14)
  (foreach c '(2 3 4 5) (excel-ancho-col ws c 15))
  (excel-ancho-col ws 6 22)
  ws)

;===============================================================
; DCL EMBEBIDO
;===============================================================
(defun escribir-dcl-embebido (/ f ruta lst)
  (setq ruta (strcat (getenv "TEMP") "\\haea_temp.dcl"))
  (setq f (open ruta "w"))
  (write-line "haea_dialog : dialog {" f)
  (write-line "  label = \"EA v7.2 MEMO\";" f)
  (write-line "  : boxed_radio_column {" f)
  (write-line "    label = \"Accion\";" f)
  (write-line "    key = \"accion\";" f)
  (write-line "    : radio_button { label = \"Exportar a Excel (con formato)\"; key = \"accion_xlsx\"; value = \"1\"; }" f)
  (write-line "    : radio_button { label = \"Etiquetar HATCHs\"; key = \"accion_ha\"; }" f)
  (write-line "    : radio_button { label = \"Etiquetar Y Exportar a Excel\"; key = \"accion_ambos\"; }" f)
  (write-line "  }" f)
  (write-line "  : boxed_radio_column {" f)
  (write-line "    label = \"Alcance del proceso\";" f)
  (write-line "    key = \"modo\";" f)
  (write-line "    : radio_button { label = \"Seleccionar secciones (por ventana)\"; key = \"modo_manual\"; value = \"1\"; }" f)
  (write-line "    : radio_button { label = \"Procesar todo el dibujo\"; key = \"modo_auto\"; }" f)
  (write-line "  }" f)
  (write-line "  : boxed_column {" f)
  (write-line "    label = \"Tipo de Areas a Procesar\";" f)
  (setq lst ea:*tipos*)
  (while lst
    (write-line "    : row {" f)
    (foreach tp (list (car lst) (cadr lst))
      (if tp
        (write-line (strcat "      : toggle { label = \"" (ea:nombre-tipo tp)
                            "\"; key = \"tipo_" tp "\"; value = \"1\"; width = 18; }") f)))
    (write-line "    }" f)
    (setq lst (cddr lst)))
  (write-line "  }" f)
  (write-line "  : boxed_column {" f)
  (write-line "    label = \"Opciones de Etiquetado\";" f)
  (write-line "    : toggle {" f)
  (write-line "      label = \"Mover etiquetas a la capa del HATCH\";" f)
  (write-line "      key = \"mover_capa\";" f)
  (write-line "      value = \"1\";" f)
  (write-line "    }" f)
  (write-line "  }" f)
  (write-line "  : boxed_column {" f)
  (write-line "    label = \"Estado\";" f)
  (write-line "    : text { key = \"estado\"; label = \"Listo...\"; width = 55; }" f)
  (write-line "  }" f)
  (write-line "  : row {" f)
  (write-line "    alignment = centered;" f)
  (write-line "    : button { label = \"Procesar\"; key = \"aceptar\"; is_default = true; width = 15; }" f)
  (write-line "    : button { label = \"Cancelar\"; key = \"cancelar\"; is_cancel = true; width = 15; }" f)
  (write-line "  }" f)
  (write-line "}" f)
  (close f)
  ruta
)

;===============================================================
; COMANDO PRINCIPAL: EA
;===============================================================
(defun c:EA (/ *error* dcl_file dcl_id resultado datos old_err)
  (setq old_err *error*)
  
  (defun *error* (msg)
    (if old_err (setq *error* old_err))
    (if (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*EXIT*,*BREAK*"))
      (princ (strcat "\n[Error] " msg))
    )
    (princ)
  )
  
  (ea:cargar-patrones)
  (setq dcl_file (escribir-dcl-embebido))
  (setq dcl_id (load_dialog dcl_file))
  
  (if (not (new_dialog "haea_dialog" dcl_id))
    (progn (unload_dialog dcl_id) (setq *error* old_err) (exit))
  )
  
  (set_tile "estado" "Configura...")
  
  (cond
    ((= *haea_ultima_accion* "XLSX") (set_tile "accion_xlsx" "1"))
    ((= *haea_ultima_accion* "HA") (set_tile "accion_ha" "1"))
    ((= *haea_ultima_accion* "AMBOS") (set_tile "accion_ambos" "1"))
  )
  
  (if (= *haea_ultimo_modo* "Auto")
    (set_tile "modo_auto" "1")
    (set_tile "modo_manual" "1")
  )
  
  (foreach tipo *haea_tipos_activos*
    (set_tile (strcat "tipo_" tipo) "1")
  )
  
  (set_tile "mover_capa" (if *haea_cambiar_capa* "1" "0"))
  
  (action_tile "aceptar" 
    "(setq datos (recoger-datos-dcl))
     (if datos (done_dialog 1)
       (set_tile \"estado\" \"ERROR\"))")
  (action_tile "cancelar" "(done_dialog 0)")
  
  (setq resultado (start_dialog))
  (unload_dialog dcl_id)
  (vl-file-delete dcl_file)
  
  (if (= resultado 1)
    (progn
      (setq *haea_tipos_activos* (car datos))
      (setq *haea_ultima_accion* (cadr datos))
      (setq *haea_cambiar_capa* (caddr datos))
      (setq *haea_ultimo_modo* (cadddr datos))
      (setq *haea_limite_dist* (ea:cfg-num "AREA_DIST_MAX" 50.0))
      ;; "Sólo exportar" no debe usar una selección de una corrida anterior
      (if (= *haea_ultima_accion* "XLSX") (setq *haea_textos_seleccionados* nil))
      
      (princ "\n\n========================================")
      (princ (strcat "\n  Accion: " *haea_ultima_accion*))
      (princ (strcat "\n  Alcance: " *haea_ultimo_modo*))
      (princ "\n========================================")
      
      (cond
        ((= *haea_ultima_accion* "XLSX") (c:HAEA-EXPORT))
        ((= *haea_ultima_accion* "HA") 
          (ejecutar-etiquetado-ha *haea_prefijo* *haea_ultimo_modo*))
        ((= *haea_ultima_accion* "AMBOS") 
          (progn
            (ejecutar-etiquetado-ha *haea_prefijo* *haea_ultimo_modo*)
            (c:HAEA-EXPORT)))
      )
    )
  )
  
  ; RESTAURAR *error* de CivilCAD
  (setq *error* old_err)
  (princ)
)

(defun recoger-datos-dcl (/ tipos accion resp mover_capa modo)
  (setq accion "XLSX")
  (if (= (get_tile "accion_xlsx") "1") (setq accion "XLSX"))
  (if (= (get_tile "accion_ha") "1") (setq accion "HA"))
  (if (= (get_tile "accion_ambos") "1") (setq accion "AMBOS"))
  
  (if (= (get_tile "modo_auto") "1")
    (setq modo "Auto")
    (setq modo "Manual"))
  
  (setq tipos '())
  (foreach tipo ea:*tipos*
    (if (= (get_tile (strcat "tipo_" tipo)) "1")
      (setq tipos (cons tipo tipos))
    )
  )
  (setq tipos (reverse tipos))
  
  (setq mover_capa (= (get_tile "mover_capa") "1"))
  
  (if tipos (list tipos accion mover_capa modo) nil)
)

;===============================================================
; AUXILIARES 7.1
;===============================================================

;; Valor numérico de MEMO_CONFIG (o el valor por defecto si no hay MEMO)
(defun ea:cfg-num (clave defecto / v)
  (if (and memo:cfg-num (setq v (memo:cfg-num clave)) (> v 0.0)) v defecto))

;; Área con decimales fijos, sin depender de DIMZIN
(defun ea:fmt-area (v / dz txt)
  (setq dz (getvar "DIMZIN"))
  (setvar "DIMZIN" 0)
  (setq txt (rtos v 2 (memo:decimales-area)))
  (setvar "DIMZIN" dz)
  txt)







;; T si el texto está en una capa de membrete/títulos/notas
(defun ea:capa-ignorada-p (capa)
  (and *haea_usar_filtro_capas* capa
       (member (strcase capa) (mapcar 'strcase *haea_capas_ignorar*))))











;; ---------------------------------------------------------------
;; RECUADROS DE SECCIÓN (7.2)
;; Cada texto de área se asigna al CAD que está dentro del MISMO
;; recuadro (polilínea cerrada) que el texto: el más pequeño que
;; contenga al texto y a algún CAD. Si el texto no está dentro de
;; ningún recuadro, se usa el CAD más cercano (como antes).
;; MEMO_CONFIG: EA_ASIGNACION (RECUADRO/CERCANO), EA_CAPA_RECUADRO.
;; ---------------------------------------------------------------

;; T si (x y) está dentro del polígono verts ((x y) ...)
(defun ea:pt-en-pol (x y verts / dentro j xi yi xj yj)
  (setq j (last verts))
  (foreach v verts
    (setq xi (car v) yi (cadr v) xj (car j) yj (cadr j))
    (if (and (/= (> yi y) (> yj y))
             (< x (+ xi (/ (* (- xj xi) (- y yi)) (float (- yj yi))))))
      (setq dentro (not dentro)))
    (setq j v))
  dentro)

;; Área de un polígono (fórmula del área de Gauss)
(defun ea:area-pol (verts / s j)
  (setq s 0.0 j (last verts))
  (foreach v verts
    (setq s (+ s (- (* (car j) (cadr v)) (* (car v) (cadr j)))) j v))
  (abs (/ s 2.0)))

;; T si pt está dentro del recuadro rec
(defun ea:en-rec (pt rec)
  (and pt rec
       (>= (car pt) (nth 1 rec)) (<= (car pt) (nth 3 rec))
       (>= (cadr pt) (nth 2 rec)) (<= (cadr pt) (nth 4 rec))
       (ea:pt-en-pol (car pt) (cadr pt) (car rec))))

;; Recuadros que contienen al menos un CAD:
;;   polis = ((x y) ...) por polilínea;  cads = lista_cads ((nombre num pos) ...)
;;   -> ((verts xmin ymin xmax ymax area (cads dentro)) ...)
(defun ea:recuadros-de (polis cads / res xs ys rec dentro)
  (foreach v polis
    (if (>= (length v) 3)
      (progn
        (setq xs (mapcar 'car v) ys (mapcar 'cadr v)
              rec (list v (apply 'min xs) (apply 'min ys) (apply 'max xs) (apply 'max ys) (ea:area-pol v))
              dentro nil)
        (foreach c cads
          (if (ea:en-rec (caddr c) rec) (setq dentro (cons c dentro))))
        (if dentro (setq res (cons (append rec (list (reverse dentro))) res))))))
  res)

;; Recuadro más pequeño que contiene a pt, o nil
(defun ea:recuadro-de (pt recs / mejor)
  (foreach r recs
    (if (and (ea:en-rec pt r) (or (null mejor) (< (nth 5 r) (nth 5 mejor))))
      (setq mejor r)))
  mejor)

;; Polilíneas cerradas del dibujo (capa según EA_CAPA_RECUADRO)
(defun ea:leer-polis (/ ss i e d capa pat v res)
  (setq pat (strcase (ea:cfg-txt "EA_CAPA_RECUADRO" "*"))
        ss (ssget "_X" '((0 . "LWPOLYLINE") (-4 . "&=") (70 . 1))) i 0)
  (if ss
    (repeat (sslength ss)
      (setq e (ssname ss i) d (entget e) capa (strcase (cdr (assoc 8 d))) i (1+ i) v nil)
      (if (wcmatch capa pat)
        (progn
          (foreach g d (if (= (car g) 10) (setq v (cons (list (cadr g) (caddr g)) v))))
          (setq res (cons (reverse v) res))))))
  res)

;; CADs de un conjunto de textos: ((cad_limpia cad_num pos) ...) ordenados
(defun ea:cads-de-ss (ss / i ent datos contenido pos cad_limpia cad_num res)
  (setq i 0)
  (if ss
    (repeat (sslength ss)
      (setq ent (ssname ss i) datos (entget ent)
            contenido (cdr (assoc 1 datos)) pos (cdr (assoc 10 datos)) i (1+ i))
      (if (and contenido
               (not (wcmatch (strcase contenido) "*ESCALA*"))
               (not (wcmatch (strcase contenido) "*AREA*"))
               (wcmatch contenido "*+*")
               (not (ea:capa-ignorada-p (cdr (assoc 8 datos)))))
        (progn
          (setq cad_limpia (extraer-cad-limpia (ea:limpiar-mtext contenido))
                cad_num (if cad_limpia (cad-a-numero cad_limpia)))
          (if (and cad_limpia cad_num pos)
            (setq res (cons (list cad_limpia cad_num pos) res)))))))
  (vl-sort res '(lambda (a b) (< (cadr a) (cadr b)))))

;; Prepara ea:*recuadros* para el comando actual
(defun ea:preparar-recuadros (cads)
  (setq ea:*recuadros*
    (if (/= (strcase (ea:cfg-txt "EA_ASIGNACION" "RECUADRO")) "CERCANO")
      (ea:recuadros-de (ea:leer-polis) cads)))
  (princ (strcat "\n[OK] Recuadros de sección con CAD: " (itoa (length ea:*recuadros*))
                 (if ea:*recuadros* "" " (se usa el CAD más cercano)"))))



;; Funciones compartidas: viven en MEMO_Lib (memo:*); estos alias mantienen
;; los nombres que usa EA.
(defun ea:limpiar-mtext (txt) (memo:limpiar-mtext txt))
(defun ea:pos-igual (txt) (memo:pos-igual txt))
(defun ea:buscar-numero (txt ini) (memo:buscar-numero txt ini))
(defun ea:cfg-txt (clave defecto) (memo:cfg-txt clave defecto))
(defun ea:split (txt sep) (memo:split txt sep))
(defun ea:cargar-patrones () (memo:cargar-patrones))
(defun ea:tipo-de (cadena) (memo:tipo-de cadena))
(defun ea:nombre-tipo (tipo) (memo:nombre-tipo tipo))
(setq ea:*tipos* memo:*tipos*)

;; T si el tipo está desmarcado en el cuadro de diálogo de EA
(defun ea:tipo-excluido-p (tipo)
  (and tipo
       (member tipo ea:*tipos*)
       (not (member tipo *haea_tipos_activos*))))

;===============================================================
; AUXILIARES
;===============================================================

(defun extraer-cad-limpia (texto / resultado i char pos_inicio j)
  (setq resultado "" pos_inicio nil i 1)
  (while (and (<= i (strlen texto)) (not pos_inicio))
    (setq char (substr texto i 1))
    (if (wcmatch char "[0-9]")
      (progn
        (setq j i)
        (while (and (<= j (strlen texto)) (wcmatch (substr texto j 1) "[0-9]"))
          (setq j (1+ j)))
        (if (and (<= j (strlen texto)) (= (substr texto j 1) "+"))
          (setq pos_inicio i))))
    (setq i (1+ i)))
  (if pos_inicio
    (progn
      (setq i pos_inicio)
      ;; sólo "km+metros": termina en el primer carácter que no sea 0-9 . +
      (while (and (<= i (strlen texto)) (wcmatch (substr texto i 1) "[0-9.+]"))
        (setq resultado (strcat resultado (substr texto i 1)))
        (setq i (1+ i)))
      (vl-string-right-trim "." resultado))
    nil))

(defun cad-a-numero (cad_texto / i char antes despues encontrado_plus)
  (setq antes "" despues "" encontrado_plus nil i 1)
  (if (not (wcmatch cad_texto "*+*"))
    nil
    (progn
      (while (<= i (strlen cad_texto))
        (setq char (substr cad_texto i 1))
        (cond
          ((= char "+") (setq encontrado_plus T))
          ((and (not encontrado_plus) (wcmatch char "[0-9]"))
           (setq antes (strcat antes char)))
          ((and encontrado_plus (wcmatch char "[0-9.]"))
           (setq despues (strcat despues char))))
        (setq i (1+ i)))
      (if (and (/= antes "") (/= despues ""))
        (+ (* (atof antes) 1000.0) (atof despues))
        nil))))

(defun obtener-centro-hatch (ent / obj minpt maxpt coord resultado pos)
  (setq obj (vlax-ename->vla-object ent))
  (setq resultado nil)
  (setq coord (vl-catch-all-apply 'vla-getboundingbox (list obj 'minpt 'maxpt)))
  (if (not (vl-catch-all-error-p coord))
    (progn
      (setq minpt (vlax-safearray->list minpt))
      (setq maxpt (vlax-safearray->list maxpt))
      (setq resultado (list 
        (/ (+ (car minpt) (car maxpt)) 2.0)
        (/ (+ (cadr minpt) (cadr maxpt)) 2.0)
        0.0))))
  (if (not resultado)
    (progn
      (setq pos (cdr (assoc 10 (entget ent))))
      (if (and pos (not (equal pos '(0.0 0.0 0.0) 0.01)))
        (setq resultado pos))))
  resultado)

(defun obtener-area-hatch (ent / obj area area_vla area_cmd resultado)
  (setq resultado nil)
  (setq obj (vlax-ename->vla-object ent))
  (setq area_vla (vl-catch-all-apply 'vla-get-area (list obj)))
  (if (not (vl-catch-all-error-p area_vla))
    (if (> area_vla 0)
      (setq resultado area_vla)))
  (if (or (not resultado) (<= resultado 0))
    (progn
      (setq area_cmd (obtener-area-con-comando ent))
      (if (and area_cmd (> area_cmd 0))
        (setq resultado area_cmd))))
  (if (or (not resultado) (<= resultado 0))
    (setq resultado (obtener-area-por-contorno ent)))
  (if resultado resultado 0.0))

(defun obtener-area-con-comando (ent / old_cmdecho old_osmode area_val)
  (setq old_cmdecho (getvar "CMDECHO"))
  (setq old_osmode (getvar "OSMODE"))
  (setvar "CMDECHO" 0)
  (setvar "OSMODE" 0)
  (setq area_val nil)
  (vl-catch-all-apply
    '(lambda ()
       (command "_.AREA" "_O" ent)
       (setq area_val (getvar "AREA"))))
  (setvar "CMDECHO" old_cmdecho)
  (setvar "OSMODE" old_osmode)
  (if (and area_val (> area_val 0)) area_val nil))

(defun obtener-area-por-contorno (ent / obj coords pts area i n
                                        x1 y1 x2 y2 suma p1 p2)
  (setq obj (vlax-ename->vla-object ent))
  (setq area 0.0)
  (setq coords (vl-catch-all-apply
                 '(lambda ()
                    (vlax-safearray->list
                      (vlax-variant-value (vla-get-coordinates obj))))))
  (if (not (vl-catch-all-error-p coords))
    (if coords
      (progn
        (setq pts '() i 0)
        (while (< i (length coords))
          (setq pts (cons (list (nth i coords) (nth (1+ i) coords)) pts))
          (setq i (+ i 2)))
        (setq pts (reverse pts))
        (setq n (length pts) suma 0.0 i 0)
        (while (< i n)
          (setq p1 (nth i pts) p2 (nth (if (= i (1- n)) 0 (1+ i)) pts))
          (setq x1 (car p1) y1 (cadr p1) x2 (car p2) y2 (cadr p2))
          (setq suma (+ suma (- (* x1 y2) (* x2 y1))))
          (setq i (1+ i)))
        (setq area (abs (/ suma 2.0))))))
  area)

(defun extraer-tipo-de-texto (texto)
  (ea:tipo-de texto))

;; Reemplaza el número del área (después del último "=" o ":") por nuevo_valor,
;; sin tocar los códigos de formato del MTEXT.
(defun reemplazar-solo-numero (texto_original nuevo_valor / pos r)
  (setq pos (ea:pos-igual texto_original))
  (setq r (ea:buscar-numero texto_original (if pos (1+ pos) 1)))
  (if r
    (strcat (substr texto_original 1 (1- (car r)))
            nuevo_valor
            (substr texto_original (1+ (cadr r))))
    texto_original))

(defun extraer-numero (str / txt txt_upper pos r)
  (setq txt (ea:limpiar-mtext str) txt_upper (strcase txt))
  (if (or (wcmatch txt_upper "*ESCALA*") (wcmatch txt_upper "* : *")
          (wcmatch txt_upper "*1:*") (wcmatch txt_upper "*:1*"))
    nil
    (progn
      (setq pos (ea:pos-igual txt))
      (setq r (ea:buscar-numero txt (if pos (1+ pos) 1)))
      (if r (abs (caddr r))))))

(defun reemplazar-en-lista (lista indice nuevo_elemento / resultado i)
  (setq resultado '() i 0)
  (foreach elemento lista
    (if (= i indice)
      (setq resultado (cons nuevo_elemento resultado))
      (setq resultado (cons elemento resultado)))
    (setq i (1+ i)))
  (reverse resultado))

;===============================================================
; ETIQUETADO v7.0
;===============================================================
(defun ejecutar-etiquetado-ha (prefijo modo / ss_textos i j 
                                hatch_ent hatch_obj area_val 
                                texto_datos nuevo_texto texto_original
                                texto_capa capa_hatch hatch_capa hatch_capa_upper
                                contador pos_texto 
                                mejor_dist dist
                                ss_hatch pos_hatch coord ent datos pos
                                ignorados ok capa_texto
                                ent_texto contenido_texto
                                sin_match limite_dist
                                tipo_texto area_hatch
                                ss_todo tipo_ent contador_hatchs
                                lista_textos_actualizada datos_actualizados
                                contenido_actualizado lista_textos contenido capa rec)
  
  (princ "\n\n=== ETIQUETADO v7.2 ===")
  (princ (strcat "\nAlcance: " modo))
  (princ (strcat "\nMover etiquetas a capa HATCH: " 
                 (if *haea_cambiar_capa* "SI" "NO")))
  (setq ok T)
  (if (not *haea_limite_dist*) (setq *haea_limite_dist* 50.0))
  (setq limite_dist *haea_limite_dist*)
  
  (setq *haea_textos_seleccionados* nil)
  
  (if (= modo "Auto")
    (progn
      (princ "\nSeleccionando TODO el dibujo...")
      (setq ss_todo (ssget "_X" '((0 . "TEXT,MTEXT,HATCH")))))
    (progn
      (princ "\nSeleccione la zona (textos + HATCHs): ")
      (setq ss_todo (ssget '((0 . "TEXT,MTEXT,HATCH"))))))
  
  (if (not ss_todo) (setq ok nil))
  
  (if ok
    (progn
      (setq lista_textos '() 
            ss_hatch (ssadd)
            i 0
            ignorados 0
            contador_hatchs 0)
      
      (repeat (sslength ss_todo)
        (setq ent (ssname ss_todo i)
              tipo_ent (cdr (assoc 0 (entget ent))))
        
        (cond
          ((= tipo_ent "HATCH")
           (ssadd ent ss_hatch)
           (setq contador_hatchs (1+ contador_hatchs)))
          
          ((or (= tipo_ent "TEXT") (= tipo_ent "MTEXT"))
           (setq datos (entget ent)
                 pos (cdr (assoc 10 datos))
                 contenido (cdr (assoc 1 datos))
                 capa (cdr (assoc 8 datos)))
           
           (if (and pos contenido (not (ea:capa-ignorada-p capa))
                    (not (ea:tipo-excluido-p (extraer-tipo-de-texto contenido))))
             (if (wcmatch (strcase (ea:limpiar-mtext contenido)) "*AREA*")
               (setq lista_textos (cons (list ent pos contenido capa) lista_textos))
               (setq ignorados (1+ ignorados)))))
        )
        (setq i (1+ i)))
      
      (princ (strcat "\n[OK] Textos de area: " (itoa (length lista_textos))))
      (if (> ignorados 0)
        (princ (strcat "\n[--] Textos ignorados: " (itoa ignorados))))
      (princ (strcat "\n[OK] HATCHs: " (itoa contador_hatchs)))
      
      (if (or (not lista_textos) (= contador_hatchs 0)) 
        (setq ok nil)
        (ea:preparar-recuadros (ea:cads-de-ss (ssget "_X" '((0 . "TEXT,MTEXT"))))))
    )
  )
  
  (if ok
    (progn
      (setq contador 0 sin_match 0)
      (foreach texto_item lista_textos
        (setq ent_texto (car texto_item)
              pos_texto (cadr texto_item)
              contenido_texto (caddr texto_item)
              texto_capa (nth 3 texto_item))
        
        (setq tipo_texto (extraer-tipo-de-texto contenido_texto))
        (setq rec (ea:recuadro-de pos_texto ea:*recuadros*))   ; recuadro de la sección
        (setq mejor_dist 1e308 capa_hatch nil area_hatch nil)
        
        (setq j 0)
        (repeat (sslength ss_hatch)
          (setq hatch_ent (ssname ss_hatch j))
          (setq hatch_capa (cdr (assoc 8 (entget hatch_ent))))
          (setq hatch_capa_upper (strcase hatch_capa))
          (if (and tipo_texto (= (ea:tipo-de hatch_capa) tipo_texto))
            (progn
              (setq hatch_obj (vlax-ename->vla-object hatch_ent))
              (setq pos_hatch (obtener-centro-hatch hatch_ent))
              (if (and pos_hatch pos_texto (or (null rec) (ea:en-rec pos_hatch rec)))
                (progn
                  (setq dist (distance pos_texto pos_hatch))
                  (if (< dist mejor_dist)
                    (setq mejor_dist dist
                          capa_hatch hatch_capa
                          area_hatch (obtener-area-hatch hatch_ent)))))))
          (setq j (1+ j)))
        
        (if (and area_hatch (or rec (<= mejor_dist limite_dist)))
          (progn
            (setq texto_datos (entget ent_texto))
            (setq texto_original (cdr (assoc 1 texto_datos)))
            (setq area_val (ea:fmt-area area_hatch))
            (setq nuevo_texto (memo:texto-area texto_original area_val tipo_texto))
            (entmod (subst (cons 1 nuevo_texto) (assoc 1 texto_datos) texto_datos))
            
            (if (and *haea_cambiar_capa*
                     (not (equal (strcase texto_capa) (strcase capa_hatch)))
                     (tblsearch "LAYER" capa_hatch))
              (progn
                (setq texto_datos (entget ent_texto))
                (entmod (subst (cons 8 capa_hatch) (assoc 8 texto_datos) texto_datos))
                (princ (strcat "\n   [" (itoa (1+ contador)) "] OK | " tipo_texto 
                               " | Area:" area_val 
                               " | Capa: " texto_capa " -> " capa_hatch)))
              (princ (strcat "\n   [" (itoa (1+ contador)) "] OK | " tipo_texto 
                             " | Area:" area_val 
                             " | Capa: " texto_capa " (sin cambio)")))
            
            (entupd ent_texto)
            (setq contador (1+ contador)))
          (progn
            (setq sin_match (1+ sin_match))
            (princ (strcat "\n   [!] SIN HATCH | " (if tipo_texto tipo_texto "?"))))))
      (princ (strcat "\n[OK] Etiquetados: " (itoa contador)))
      (if (> sin_match 0) (princ (strcat "\n[!] Sin HATCH: " (itoa sin_match))))
      
      (princ "\n\n[INFO] Actualizando valores para la exportación...")
      (setq lista_textos_actualizada '())
      (foreach texto_item lista_textos
        (setq ent_texto (car texto_item)
              pos_texto (cadr texto_item)
              capa_texto (nth 3 texto_item))
        (setq datos_actualizados (entget ent_texto))
        (setq contenido_actualizado (cdr (assoc 1 datos_actualizados)))
        (setq lista_textos_actualizada 
              (cons (list ent_texto pos_texto contenido_actualizado capa_texto) 
                    lista_textos_actualizada)))
      (setq *haea_textos_seleccionados* (reverse lista_textos_actualizada))
      (princ (strcat "\n[OK] Valores actualizados: " 
                     (itoa (length *haea_textos_seleccionados*)) " textos"))
    )
  )
  
  (princ))



(defun c:HAEA-EXPORT (/ *error* ss_cads ss_textos i j
                        ent datos contenido capa pos
                        lista_cads cad_limpia cad_num
                        lista_textos_area areas_por_cad areas_por_cad_filtrado
                        mejor_cad mejor_dist dist
                        texto_info cad_actual
                        tipos_detectados tipo_actual
                        archivo excel_app excel_wb excel_ws
                        fila col fila_inicio fila_fin
                        num_cads num_tipos valor_area
                        cad_anterior num_actual num_anterior dist_actual
                        usar_seleccion old_err pos_texto nueva_lista col_total rec)
  
  (setq old_err *error*)
  (defun *error* (msg)
    (if old_err (setq *error* old_err))
    (if (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*EXIT*,*BREAK*"))
      (princ (strcat "\n[Error] " msg))
    )
    (princ)
  )
  
  (ea:cargar-patrones)
  (princ "\n\n=== EXPORTACION A EXCEL v7.2 ===")
  
  (setq usar_seleccion 
        (and (= *haea_ultimo_modo* "Manual")
             *haea_textos_seleccionados*))
  
  (cond
    (usar_seleccion
     (princ "\n[INFO] Modo Manual - usando los textos recién etiquetados")
     (setq ss_cads (ssget "_X" '((0 . "TEXT,MTEXT")))))
    ((= *haea_ultimo_modo* "Manual")
     (princ "\n[INFO] Modo Manual - seleccione las secciones (textos de CAD y de área):")
     (setq ss_cads (ssget '((0 . "TEXT,MTEXT")))))
    (T
     (princ "\n[INFO] Modo Auto - usando todo el dibujo")
     (setq ss_cads (ssget "_X" '((0 . "TEXT,MTEXT"))))))
  (if (not ss_cads)
    (progn (princ "\n[!] No hay textos.") (setq *error* old_err) (exit)))
  
  (setq lista_cads '() i 0)
  (repeat (sslength ss_cads)
    (setq ent (ssname ss_cads i)
          datos (entget ent)
          contenido (cdr (assoc 1 datos))
          pos (cdr (assoc 10 datos)))
    (if (and (not (wcmatch (strcase contenido) "*ESCALA*"))
             (not (wcmatch (strcase contenido) "*AREA*"))
             (wcmatch contenido "*+*")
             (not (ea:capa-ignorada-p (cdr (assoc 8 datos)))))
      (progn
        (setq cad_limpia (extraer-cad-limpia (ea:limpiar-mtext contenido))
              cad_num (if cad_limpia (cad-a-numero cad_limpia)))
        (if (and cad_limpia cad_num pos)
          (setq lista_cads (cons (list cad_limpia cad_num pos) lista_cads)))))
    (setq i (1+ i)))
  
  (setq lista_cads (vl-sort lista_cads '(lambda (a b) (< (cadr a) (cadr b)))))
  (princ (strcat "\n[OK] CADs detectadas: " (itoa (length lista_cads))))
  
  (if (= lista_cads nil)
    (progn (princ "\n[!] No se encontraron CADs.") (setq *error* old_err) (exit)))
  (ea:preparar-recuadros lista_cads)
  
  (if usar_seleccion
    (progn
      (setq lista_textos_area *haea_textos_seleccionados*)
      (princ (strcat "\n[OK] Textos (selección): " (itoa (length lista_textos_area)))))
    (progn
      (setq lista_textos_area '() i 0)
      (repeat (sslength ss_cads)
        (setq ent (ssname ss_cads i)
              datos (entget ent)
              contenido (cdr (assoc 1 datos))
              capa (cdr (assoc 8 datos))
              pos (cdr (assoc 10 datos)))
        (if (and pos (wcmatch (strcase (ea:limpiar-mtext contenido)) "*AREA*")
                 (not (ea:capa-ignorada-p capa))
                 (not (ea:tipo-excluido-p (extraer-tipo-de-texto contenido))))
          (setq lista_textos_area (cons (list ent pos contenido capa) lista_textos_area)))
        (setq i (1+ i)))
      (princ (strcat "\n[OK] Textos (todo el dibujo): " (itoa (length lista_textos_area))))))
  
  (setq areas_por_cad '())
  (foreach cad lista_cads
    (if (not (assoc (car cad) areas_por_cad))   ; un CAD repetido = una sola fila
      (setq areas_por_cad (cons (list (car cad) (cadr cad) '()) areas_por_cad))))
  (setq areas_por_cad (reverse areas_por_cad))
  
  (foreach texto_item lista_textos_area
    (setq pos_texto (cadr texto_item) contenido (caddr texto_item))
    (setq mejor_cad nil mejor_dist 1e308)
    ;; dentro del recuadro de la sección, sólo sus CADs; si no, todos
    (foreach cad (if (setq rec (ea:recuadro-de pos_texto ea:*recuadros*)) (nth 6 rec) lista_cads)
      (setq dist (distance (caddr cad) pos_texto))
      (if (< dist mejor_dist)
        (setq mejor_dist dist mejor_cad cad)))
    (if mejor_cad
      (progn
        (setq i 0)
        (foreach cad_item areas_por_cad
          (if (equal (car cad_item) (car mejor_cad))
            (progn
              (setq texto_info (list contenido (extraer-numero contenido) mejor_dist))
              (setq nueva_lista (cons texto_info (caddr cad_item)))
              (setq areas_por_cad (reemplazar-en-lista areas_por_cad i 
                (list (car cad_item) (cadr cad_item) nueva_lista)))))
          (setq i (1+ i))))))
  
  (setq tipos_detectados '())
  (foreach cad areas_por_cad
    (foreach texto (caddr cad)
      (setq tipo_actual (extraer-tipo-de-texto (car texto)))
      (if (and tipo_actual (not (member tipo_actual tipos_detectados))
               (not (ea:tipo-excluido-p tipo_actual)))
        (setq tipos_detectados (cons tipo_actual tipos_detectados)))))
  (setq tipos_detectados (reverse tipos_detectados))
  (princ (strcat "\n[OK] Tipos: " (itoa (length tipos_detectados))))
  
  (setq areas_por_cad_filtrado '())
  (foreach cad areas_por_cad
    (if (caddr cad)
      (setq areas_por_cad_filtrado (cons cad areas_por_cad_filtrado))))
  (setq areas_por_cad (reverse areas_por_cad_filtrado))
  (princ (strcat "\n[OK] CADs con areas: " (itoa (length areas_por_cad))))
  
  (setq archivo (getfiled "Guardar Excel" "Volumen_Areas" "xlsx" 1))
  (if (not archivo) 
    (progn (princ "\n[!] Cancelado.") (setq *error* old_err) (exit)))
  
  (princ "\nAbriendo Excel...")
  
  (setq excel_app (vl-catch-all-apply 'vlax-get-or-create-object (list "Excel.Application")))
  (if (vl-catch-all-error-p excel_app)
    (progn (alert "No se pudo abrir Excel.") (setq *error* old_err) (exit)))
  
  (vlax-put-property excel_app 'Visible 1)
  (vlax-put-property excel_app 'DisplayAlerts 0)
  
  (setq excel_wb (vlax-get-property excel_app 'Workbooks))
  (setq excel_wb (vlax-invoke-method excel_wb 'Add))
  (setq excel_ws (vlax-get-property excel_app 'ActiveSheet))
  (vlax-put-property excel_ws 'Name "VOLUMEN")
  
  (setq num_cads (length areas_por_cad)
        num_tipos (length tipos_detectados)
        col_total (+ 2 (* num_tipos 3)))
  
  (princ "\nEscribiendo datos...")
  
  (excel-set excel_ws 1 1 "VOLUMEN")
  (excel-set excel_ws 4 1 "CAD")
  (excel-set excel_ws 4 2 "DIST")
  (excel-set excel_ws 4 3 "AREA")
  (excel-set excel_ws 4 (+ 3 num_tipos) "PROMEDIO")
  (excel-set excel_ws 4 (+ 3 (* num_tipos 2)) "VOLUMEN")
  
  (setq col 3)
  (foreach tipo tipos_detectados
    (excel-set excel_ws 5 col (strcase tipo))
    (setq col (1+ col)))
  (setq col (+ 3 num_tipos))
  (foreach tipo tipos_detectados
    (excel-set excel_ws 5 col (strcase tipo))
    (setq col (1+ col)))
  (setq col (+ 3 (* num_tipos 2)))
  (foreach tipo tipos_detectados
    (excel-set excel_ws 5 col (strcase tipo))
    (setq col (1+ col)))
  
  (setq fila 6 cad_anterior nil num_anterior nil)
  (foreach cad areas_por_cad
    (setq cad_actual (car cad) num_actual (cadr cad))
    (excel-set excel_ws fila 1 cad_actual)
    (if cad_anterior
      (progn
        (setq dist_actual (- num_actual num_anterior))
        (excel-set excel_ws fila 2 dist_actual))
      (excel-set excel_ws fila 2 0))
    
    (setq col 3)
    (foreach tipo tipos_detectados
      (setq valor_area 0.0)
      (foreach texto (caddr cad)
        (if (equal (extraer-tipo-de-texto (car texto)) tipo)
          (setq valor_area (+ valor_area (cadr texto)))))
      (excel-set excel_ws fila col valor_area)
      (setq col (1+ col)))
    
    (setq col (+ 3 num_tipos) i 0)
    (foreach tipo tipos_detectados
      (if (> fila 6)
        (excel-set excel_ws fila col
          (strcat "=IF(" (numero-a-letra (+ 3 i)) (itoa fila) "=\"\",\"\","
                  "AVERAGE(" (numero-a-letra (+ 3 i)) (itoa (- fila 1)) ":"
                  (numero-a-letra (+ 3 i)) (itoa fila) "))"))
        (excel-set excel_ws fila col 0))
      (setq col (1+ col) i (1+ i)))
    
    (setq col (+ 3 (* num_tipos 2)) i 0)
    (foreach tipo tipos_detectados
      (if (> fila 6)
        (excel-set excel_ws fila col
          (strcat "=IF(B" (itoa fila) "=\"\",\"\","
                  "ROUND(B" (itoa fila) "*" 
                  (numero-a-letra (+ 3 num_tipos i)) (itoa fila) ",2))"))
        (excel-set excel_ws fila col 0))
      (setq col (1+ col) i (1+ i)))
    
    (setq cad_anterior cad_actual num_anterior num_actual)
    (setq fila (1+ fila)))
  
  (setq fila_inicio 6 fila_fin (1- fila))
  (excel-set excel_ws fila (+ 3 num_tipos) "TOTAL")
  
  (setq col (+ 3 (* num_tipos 2)) i 0)
  (foreach tipo tipos_detectados
    (excel-set excel_ws fila (+ col i)
      (strcat "=SUM(" (numero-a-letra (+ col i)) (itoa fila_inicio) ":"
              (numero-a-letra (+ col i)) (itoa fila_fin) ")"))
    (setq i (1+ i)))
  
  (princ "\nAplicando formato...")
  
  (excel-formato excel_ws 1 1 1 col_total
                 (list (list 'bold 1) (list 'size 16) (list 'color 16777215)
                       (list 'bg 12238897) (list 'halign -4108) (list 'valign -4108)
                       (list 'merge T)))
  
  (excel-formato excel_ws 4 1 4 col_total
                 (list (list 'bold 1) (list 'size 12) (list 'color 16777215)
                       (list 'bg 12238897) (list 'halign -4108) (list 'valign -4108)))
  
  (excel-formato excel_ws 5 1 5 col_total
                 (list (list 'bold 1) (list 'size 10) (list 'color 12238897)
                       (list 'bg 16248831) (list 'halign -4108) (list 'valign -4108)))
  
  (excel-formato excel_ws 4 1 fila col_total (list (list 'borders 2)))
  (excel-formato excel_ws 6 2 fila col_total (list (list 'halign -4152)))
  (excel-formato excel_ws fila 1 fila col_total
                 (list (list 'bold 1) (list 'size 12) (list 'color 16777215)
                       (list 'bg 2631720) (list 'halign -4152)))
  
  ;; números con 2 decimales en distancias, áreas, promedios y volúmenes
  (vl-catch-all-apply
    '(lambda ()
       (vlax-put-property
         (vlax-get-property excel_ws 'Range
           (strcat "B6:" (numero-a-letra col_total) (itoa fila)))
         'NumberFormat "0.00")))
  (excel-ancho-col excel_ws 1 12)
  (excel-ancho-col excel_ws 2 10)
  
  (princ "\nCreando hoja RESUMEN (corte, relleno, curva masa)...")
  (if (vl-catch-all-error-p
        (vl-catch-all-apply 'ea:hoja-resumen
          (list excel_wb tipos_detectados num_tipos fila_inicio fila_fin fila)))
    (princ "\n[!] No se pudo crear la hoja RESUMEN (la hoja VOLUMEN sí está completa)."))
  (vl-catch-all-apply 'vlax-invoke-method (list excel_wb 'SaveAs archivo))
  
  (princ (strcat "\n\n[OK] Archivo: " archivo))
  (princ (strcat "\n[OK] " (itoa num_cads) " CADs, " (itoa num_tipos) " tipos."))
  
  ;(vlax-release-object excel_ws)
  ;(vlax-release-object excel_wb)
  ;(vlax-release-object excel_app)
  
  ; RESTAURAR *error*
  (setq *error* old_err)
  
  (princ "\n=== FIN ===")
  (princ))



;===============================================================
; AH - etiquetar los hatches y textos seleccionados (sin cuadro)
; Usa el mismo motor que EA > Etiquetar (recuadros de sección, tipos,
; filtros) y la forma de escribir el área elegida en MAREA.
;===============================================================
(defun c:AH (/ *haea_tipos_activos* *haea_cambiar_capa* *haea_limite_dist*)
  (ea:cargar-patrones)
  (setq *haea_tipos_activos* memo:*tipos*
        *haea_cambiar_capa* (memo:si-p "AREA_MOVER_CAPA" "NO")
        *haea_limite_dist* (ea:cfg-num "AREA_DIST_MAX" 50.0))
  (princ "\n=== AH - Etiquetar hatches (mismo motor que EA) ===")
  (ejecutar-etiquetado-ha *haea_prefijo* "Manual")
  (princ))

;===============================================================
; MENSAJE DE CARGA
;===============================================================
(princ "\n==========================================")
(princ "\n  EA v7.2 MEMO - Compatible con CivilCAD")
(princ "\n==========================================")
(princ "\n  EA          -> Interfaz completa (etiquetar + Excel)")
(princ "\n  HAEA-EXPORT -> Solo exportar Excel")
(princ "\n  AH          -> Etiquetar hatches seleccionados (sin cuadro)")
(princ "\n==========================================")
(princ)