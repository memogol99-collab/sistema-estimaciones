;;; MEMO SISTEMA 2.0.0 - archivo generado por construir_bundle.py
;;; Origen: LISP_Topografia/Malla_PUNTOS  ( MALLA ).lsp

(vl-load-com)

;; =============================================================
;; MALLA-PUNTOS v4.7 - Malla de puntos con IDW + Coloreo + Etiquetas
;; DCL integrado (no requiere archivo externo)
;; Incluye opcion de dibujar poligono de recorte
;; Validacion por palabra completa (Si/No/Dibujar)
;; Compatible con AutoCAD en espanol e ingles
;; Puntos estilo circulo con punto central (PDMODE=35, PDSIZE=-0.3)
;; Sin conflicto con comando nativo MALLA (MESH)
;; =============================================================

;; === Variables globales configurables (valores por defecto del dialogo) ===
(setq *curv-layers* '("CVL_CURV_D" "CVL_CURV_G"))
(setq *mp-pt-layer*   "MALLA_PUNTOS")   ; Capa para puntos (modo sin color)
(setq *mp-power*      2)                  ; Exponente IDW (1=lineal, 2=estandar, 3=mas suave)
(setq *mp-decimals*   2)                  ; Decimales de redondeo en elevacion
(setq *mp-max-pts*    50000)              ; Umbral para pedir confirmacion
(setq *mp-search-radius* 10.0)            ; Radio de busqueda para curvas cercanas

;; === Variables por defecto para el dialogo DCL ===
(setq *mp-def-dx*          0.50)
(setq *mp-def-dy*          0.50)
(setq *mp-def-color-on*    nil)
(setq *mp-def-capas*       10)
(setq *mp-def-prefijo*     "MP_COTA")
(setq *mp-def-bati*        nil)
(setq *mp-def-etiq*        nil)
(setq *mp-def-etiq-alt*    0.6)
(setq *mp-def-etiq-sep*    1.2)
(setq *mp-def-etiq-dec*    2)
(setq *mp-def-etiq-anc*    0.7)
(setq *mp-def-etiq-abs*    nil)
(setq *mp-def-etiq-capa-u* nil)
(setq *mp-def-etiq-capa-n* "ETIQUETAS_Z")
(setq *mp-def-leyenda*     nil)
(setq *mp-def-csv*         nil)
(setq *mp-def-csv-nom*     "MALLA_PUNTOS")

;; ============================================================
;; DCL INTEGRADO - Escribir dialogo de configuracion a temp file
;; ============================================================
(defun mp:escribir-dcl-config (/ f)
  (setq f (open (strcat (getvar "TEMPPREFIX") "mp_config.dcl") "w"))
  (if (not f) (progn (princ "\nError: no se pudo crear DCL temporal.") (exit)))
  (write-line "mp_config : dialog {" f)
  (write-line "  label = \"MALLA-PUNTOS v4.7 - Configuracion\";" f)
  (write-line "  : column {" f)
  ;; --- SECCION MALLA ---
  (write-line "    : boxed_column {" f)
  (write-line "      label = \"Malla de Puntos\";" f)
  (write-line "      : row {" f)
  (write-line "        : text { label = \"Distancia X:\"; width = 18; fixed_width = true; }" f)
  (write-line "        : edit_box { key = \"eb_dx\"; edit_width = 10; }" f)
  (write-line "        : text { label = \"Distancia Y:\"; width = 18; fixed_width = true; }" f)
  (write-line "        : edit_box { key = \"eb_dy\"; edit_width = 10; }" f)
  (write-line "      }" f)
  (write-line "    }" f)
  (write-line "    spacer;" f)
  ;; --- SECCION COLOREO ---
  (write-line "    : boxed_column {" f)
  (write-line "      label = \"Coloreo por Cota Z\";" f)
  (write-line "      : row {" f)
  (write-line "        : text { label = \"Activar coloreo:\"; width = 18; fixed_width = true; }" f)
  (write-line "        : toggle { key = \"tgl_color\"; }" f)
  (write-line "      }" f)
  (write-line "      : row {" f)
  (write-line "        : text { label = \"  Capas de color:\"; width = 18; fixed_width = true; }" f)
  (write-line "        : radio_column { key = \"rc_capas\";" f)
  (write-line "          : radio_button { key = \"rb_5\";  label = \"5\";  }" f)
  (write-line "          : radio_button { key = \"rb_10\"; label = \"10\"; }" f)
  (write-line "          : radio_button { key = \"rb_15\"; label = \"15\"; }" f)
  (write-line "          : radio_button { key = \"rb_20\"; label = \"20\"; }" f)
  (write-line "          : radio_button { key = \"rb_custom\"; label = \"Personalizado:\"; }" f)
  (write-line "        }" f)
  (write-line "        : edit_box { key = \"eb_numcapas\"; edit_width = 6; value = \"10\"; }" f)
  (write-line "      }" f)
  (write-line "      : row {" f)
  (write-line "        : text { label = \"  Prefijo capas:\"; width = 18; fixed_width = true; }" f)
  (write-line "        : edit_box { key = \"eb_prefijo\"; edit_width = 15; }" f)
  (write-line "        : text { label = \"Batimetria:\"; width = 18; fixed_width = true; }" f)
  (write-line "        : toggle { key = \"tgl_bati\"; }" f)
  (write-line "      }" f)
  (write-line "    }" f)
  (write-line "    spacer;" f)
  ;; --- SECCION ETIQUETAS ---
  (write-line "    : boxed_column {" f)
  (write-line "      label = \"Etiquetas de Elevacion\";" f)
  (write-line "      : row {" f)
  (write-line "        : text { label = \"Activar etiquetas:\"; width = 18; fixed_width = true; }" f)
  (write-line "        : toggle { key = \"tgl_etiq\"; }" f)
  (write-line "      }" f)
  (write-line "      : row {" f)
  (write-line "        : text { label = \"  Altura texto:\"; width = 18; fixed_width = true; }" f)
  (write-line "        : edit_box { key = \"eb_altura\"; edit_width = 8; }" f)
  (write-line "        : text { label = \"Separacion:\"; width = 18; fixed_width = true; }" f)
  (write-line "        : edit_box { key = \"eb_sep\"; edit_width = 8; }" f)
  (write-line "      }" f)
  (write-line "      : row {" f)
  (write-line "        : text { label = \"  Decimales:\"; width = 18; fixed_width = true; }" f)
  (write-line "        : edit_box { key = \"eb_dec\"; edit_width = 8; }" f)
  (write-line "        : text { label = \"Ancho texto:\"; width = 18; fixed_width = true; }" f)
  (write-line "        : edit_box { key = \"eb_ancho\"; edit_width = 8; }" f)
  (write-line "      }" f)
  (write-line "      : row {" f)
  (write-line "        : text { label = \"  Valor absoluto Z:\"; width = 18; fixed_width = true; }" f)
  (write-line "        : toggle { key = \"tgl_abs\"; }" f)
  (write-line "        : text { label = \"Capa unica:\"; width = 18; fixed_width = true; }" f)
  (write-line "        : toggle { key = \"tgl_etiq_capa\"; }" f)
  (write-line "      }" f)
  (write-line "      : row {" f)
  (write-line "        : text { label = \"  Nombre capa etiq:\"; width = 18; fixed_width = true; }" f)
  (write-line "        : edit_box { key = \"eb_etiq_capa_nom\"; edit_width = 20; }" f)
  (write-line "      }" f)
  (write-line "    }" f)
  (write-line "    spacer;" f)
  ;; --- SECCION OPCIONES ---
  (write-line "    : boxed_column {" f)
  (write-line "      label = \"Opciones\";" f)
  (write-line "      : row {" f)
  (write-line "        : text { label = \"Leyenda de cotas:\"; width = 18; fixed_width = true; }" f)
  (write-line "        : toggle { key = \"tgl_leyenda\"; }" f)
  (write-line "      }" f)
  (write-line "      : row {" f)
  (write-line "        : text { label = \"Exportar CSV:\"; width = 18; fixed_width = true; }" f)
  (write-line "        : toggle { key = \"tgl_csv\"; }" f)
  (write-line "      }" f)
  (write-line "      : row {" f)
  (write-line "        : text { label = \"  Nombre archivo:\"; width = 18; fixed_width = true; }" f)
  (write-line "        : edit_box { key = \"eb_csv_nom\"; edit_width = 20; }" f)
  (write-line "      }" f)
  (write-line "    }" f)
  (write-line "    spacer;" f)
  ;; --- BOTONES ---
  (write-line "    : row {" f)
  (write-line "      : button { key = \"btn_ayuda\"; label = \"Ayuda\"; width = 12; }" f)
  (write-line "      : button { key = \"btn_cancel\"; label = \"Cancelar\"; width = 12; }" f)
  (write-line "      : button { key = \"btn_ok\"; label = \"Aceptar\"; is_default = true; width = 12; }" f)
  (write-line "    }" f)
  (write-line "  }" f)
  (write-line "}" f)
  (close f)
  (strcat (getvar "TEMPPREFIX") "mp_config.dcl")
)

;; ============================================================
;; CALLBACKS DEL DIALOGO
;; ============================================================

;; Activar/desactivar seccion de coloreo
(defun mp:dlg-toggle-color (/ val)
  (setq val (= (get_tile "tgl_color") "1"))
  (mode_tile "rb_5"           (if val 0 1))
  (mode_tile "rb_10"          (if val 0 1))
  (mode_tile "rb_15"          (if val 0 1))
  (mode_tile "rb_20"          (if val 0 1))
  (mode_tile "rb_custom"      (if val 0 1))
  (if (and val (= (get_tile "rb_custom") "1"))
    (mode_tile "eb_numcapas" 0)
    (mode_tile "eb_numcapas" 1))
  (mode_tile "eb_prefijo"     (if val 0 1))
  (mode_tile "tgl_bati"       (if val 0 1))
  (if (not val)
    (progn
      (set_tile "tgl_leyenda" "0")
      (mode_tile "tgl_leyenda" 1)
    )
  )
)

;; Activar/desactivar edit_box de capas personalizadas
(defun mp:dlg-toggle-capas-custom (/ val)
  (setq val (= (get_tile "rb_custom") "1"))
  (mode_tile "eb_numcapas" (if val 0 1))
)

;; Desmarcar otros radio buttons de capas
(defun mp:dlg-radio-capas ()
  (if (/= (get_tile "rb_custom") "1")
    (mode_tile "eb_numcapas" 1))
)

;; Activar/desactivar seccion de etiquetas
(defun mp:dlg-toggle-etiquetas (/ val)
  (setq val (= (get_tile "tgl_etiq") "1"))
  (mode_tile "eb_altura"       (if val 0 1))
  (mode_tile "eb_sep"          (if val 0 1))
  (mode_tile "eb_dec"          (if val 0 1))
  (mode_tile "eb_ancho"        (if val 0 1))
  (mode_tile "tgl_abs"         (if val 0 1))
  (mode_tile "tgl_etiq_capa"  (if val 0 1))
  (if (and val (= (get_tile "tgl_etiq_capa") "1"))
    (mode_tile "eb_etiq_capa_nom" 0)
    (mode_tile "eb_etiq_capa_nom" 1))
)

;; Activar/desactivar nombre de capa unica
(defun mp:dlg-toggle-etiq-capa (/ val-etiq val-capa)
  (setq val-etiq (= (get_tile "tgl_etiq") "1"))
  (setq val-capa (= (get_tile "tgl_etiq_capa") "1"))
  (if (and val-etiq val-capa)
    (mode_tile "eb_etiq_capa_nom" 0)
    (mode_tile "eb_etiq_capa_nom" 1))
)

;; Activar/desactivar nombre de archivo CSV
(defun mp:dlg-toggle-csv (/ val)
  (setq val (= (get_tile "tgl_csv") "1"))
  (mode_tile "eb_csv_nom" (if val 0 1))
)

;; Leer numero de capas desde dialogo
(defun mp:dlg-leer-num-capas (/ tmp)
  (if (= (get_tile "rb_custom") "1")
    (progn
      (setq tmp (atoi (get_tile "eb_numcapas")))
      (if (< tmp 2) (setq tmp 2))
      (if (> tmp 100) (setq tmp 100))
      tmp
    )
    (cond
      ((= (get_tile "rb_5") "1") 5)
      ((= (get_tile "rb_10") "1") 10)
      ((= (get_tile "rb_15") "1") 15)
      ((= (get_tile "rb_20") "1") 20)
      (T 10)
    )
  )
)

;; Leer toda la configuracion del dialogo
(defun mp:dlg-leer-config (/ tmp-h tmp-s tmp-w tmp-d tmp-cn)
  (setq tmp-h (distof (get_tile "eb_altura")))
  (if (not tmp-h) (setq tmp-h 0.6))
  (setq tmp-s (distof (get_tile "eb_sep")))
  (if (not tmp-s) (setq tmp-s 1.2))
  (setq tmp-d (atoi (get_tile "eb_dec")))
  (if (not tmp-d) (setq tmp-d 2))
  (setq tmp-w (distof (get_tile "eb_ancho")))
  (if (not tmp-w) (setq tmp-w 0.7))
  (setq tmp-cn (get_tile "eb_etiq_capa_nom"))
  (if (or (not tmp-cn) (= tmp-cn "")) (setq tmp-cn "ETIQUETAS_Z"))
  (list
    (distof (get_tile "eb_dx"))
    (distof (get_tile "eb_dy"))
    (= (get_tile "tgl_color") "1")
    (mp:dlg-leer-num-capas)
    (if (= (get_tile "eb_prefijo") "") "MP_COTA" (get_tile "eb_prefijo"))
    (= (get_tile "tgl_bati") "1")
    (= (get_tile "tgl_etiq") "1")
    tmp-h
    tmp-s
    tmp-d
    tmp-w
    (= (get_tile "tgl_abs") "1")
    (= (get_tile "tgl_etiq_capa") "1")
    tmp-cn
    (= (get_tile "tgl_leyenda") "1")
    (= (get_tile "tgl_csv") "1")
    (if (= (get_tile "eb_csv_nom") "") "MALLA_PUNTOS" (get_tile "eb_csv_nom"))
  )
)

;; Inicializar valores del dialogo con las variables globales
(defun mp:dlg-inicializar ()
  (set_tile "eb_dx" (rtos *mp-def-dx* 2 2))
  (set_tile "eb_dy" (rtos *mp-def-dy* 2 2))
  (if *mp-def-color-on*
    (set_tile "tgl_color" "1")
    (set_tile "tgl_color" "0")
  )
  (cond
    ((= *mp-def-capas* 5)  (set_tile "rb_5" "1"))
    ((= *mp-def-capas* 10) (set_tile "rb_10" "1"))
    ((= *mp-def-capas* 15) (set_tile "rb_15" "1"))
    ((= *mp-def-capas* 20) (set_tile "rb_20" "1"))
    (T
      (set_tile "rb_custom" "1")
      (set_tile "eb_numcapas" (itoa *mp-def-capas*))
    )
  )
  (set_tile "eb_prefijo" *mp-def-prefijo*)
  (if *mp-def-bati*
    (set_tile "tgl_bati" "1")
    (set_tile "tgl_bati" "0")
  )
  (if *mp-def-etiq*
    (set_tile "tgl_etiq" "1")
    (set_tile "tgl_etiq" "0")
  )
  (set_tile "eb_altura" (rtos *mp-def-etiq-alt* 2 2))
  (set_tile "eb_sep" (rtos *mp-def-etiq-sep* 2 2))
  (set_tile "eb_dec" (itoa *mp-def-etiq-dec*))
  (set_tile "eb_ancho" (rtos *mp-def-etiq-anc* 2 2))
  (if *mp-def-etiq-abs*
    (set_tile "tgl_abs" "1")
    (set_tile "tgl_abs" "0")
  )
  (if *mp-def-etiq-capa-u*
    (set_tile "tgl_etiq_capa" "1")
    (set_tile "tgl_etiq_capa" "0")
  )
  (set_tile "eb_etiq_capa_nom" *mp-def-etiq-capa-n*)
  (if *mp-def-leyenda*
    (set_tile "tgl_leyenda" "1")
    (set_tile "tgl_leyenda" "0")
  )
  (if *mp-def-csv*
    (set_tile "tgl_csv" "1")
    (set_tile "tgl_csv" "0")
  )
  (set_tile "eb_csv_nom" *mp-def-csv-nom*)
  (mp:dlg-toggle-color)
  (mp:dlg-toggle-etiquetas)
  (mp:dlg-toggle-csv)
)

;; Ayuda
(defun mp:dlg-ayuda ()
  (alert
    (strcat
      "MALLA-PUNTOS v4.7\n"
      "======================\n\n"
      "1. Configure las distancias de la malla (X/Y).\n"
      "2. Active COLOREO para puntos por rango de cota Z.\n"
      "   - Elija numero de capas (5/10/15/20/personalizado).\n"
      "   - El prefijo nombra las capas (ej: MP_COTA_1, MP_COTA_2...).\n"
      "   - BATIMETRIA invierte la escala de colores.\n"
      "3. Active ETIQUETAS para texto con la elevacion Z.\n"
      "   - Altura, separacion, decimales y ancho del texto.\n"
      "   - VALOR ABSOLUTO muestra Z positivo (para batimetria).\n"
      "   - CAPA UNICA pone todas las etiquetas en una sola capa.\n"
      "4. LEYENDA crea un cuadro visual con los colores por rango.\n"
      "5. CSV exporta los puntos a un archivo.\n\n"
      "DESPUES del dialogo:\n"
      "  - Puede seleccionar poligonos de recorte (Si).\n"
      "  - Puede DIBUJAR un poligono de recorte (Dibujar).\n"
      "  - O indicar el area de la malla (No).\n\n"
      "COMANDOS:\n"
      "  MALLA-PUNTOS   -> comando principal\n"
      "  MP / MLL       -> alias\n"
      "  EXPORTAR-PUNTOS / EXP -> exportar CSV\n\n"
      "NOTAS:\n"
      "  - Las curvas deben estar en capas: CVL_CURV_D / CVL_CURV_G\n"
      "  - Las curvas deben tener elevacion asignada (DXF 38).\n"
      "  - Los puntos se muestran como circulo con punto central\n"
      "    (PDMODE=35, PDSIZE=-0.3 en unidades absolutas)."
    )
  )
)

;; ============================================================
;; FUNCIONES AUXILIARES
;; ============================================================

;; Formatear tiempo
(defun mp-format-time (seconds / mins secs)
  (setq mins (fix (/ seconds 60)))
  (setq secs (fix (- seconds (* mins 60))))
  (if (> mins 0)
    (strcat (itoa mins) " min " (itoa secs) " seg")
    (strcat (itoa secs) " seg")
  )
)

;; Verificar punto dentro de poligono (metodo de angulos)
(defun mp-point-in-poly (pt poly-verts / x y n i angle-sum angle1 angle2)
  (setq x (car pt) y (cadr pt))
  (setq n (length poly-verts))
  (setq angle-sum 0.0) (setq i 0)
  (while (< i (1- n))
    (setq angle1 (angle (nth i poly-verts) (list x y)))
    (setq angle2 (angle (nth (1+ i) poly-verts) (list x y)))
    (setq angle-sum (+ angle-sum (mp-angle-diff angle1 angle2)))
    (setq i (1+ i))
  )
  (setq angle1 (angle (nth (1- n) poly-verts) (list x y)))
  (setq angle2 (angle (nth 0 poly-verts) (list x y)))
  (setq angle-sum (+ angle-sum (mp-angle-diff angle1 angle2)))
  (if (or
        (equal (abs angle-sum) (* 2 pi) 0.0001)
        (equal (abs angle-sum) (* 2 pi) 0.001)
        (equal (abs angle-sum) (* 2 pi) 0.01)
      )
    T nil
  )
)

;; Diferencia de angulos
(defun mp-angle-diff (a1 a2 / diff)
  (setq diff (- a2 a1))
  (while (> diff pi) (setq diff (- diff (* 2 pi))))
  (while (< diff (- pi)) (setq diff (+ diff (* 2 pi))))
  diff
)

;; Obtener vertices de poligono cerrado
(defun mp-get-poly-verts (ent / edata pts pt)
  (setq edata (entget ent)) (setq pts nil)
  (foreach item edata
    (if (and (= (car item) 10) (listp (cdr item)))
      (progn
        (setq pt (cdr item))
        (setq pts (cons (list (car pt) (cadr pt)) pts))
      )
    )
  )
  (if (not (equal (car pts) (last pts) 0.001))
    (setq pts (append pts (list (car pts))))
  )
  (reverse pts)
)

;; Obtener vertices de polilinea
(defun mp-get-verts (ent / edata pts pt)
  (setq edata (entget ent)) (setq pts nil)
  (foreach item edata
    (if (and (= (car item) 10) (listp (cdr item)))
      (progn
        (setq pt (cdr item))
        (setq pts (cons (list (car pt) (cadr pt)) pts))
      )
    )
  )
  (reverse pts)
)

;; Verificar si capa esta en lista
(defun mp-layer-match (lay layer-list / ll)
  (setq ll (mapcar 'strcase layer-list))
  (member (strcase lay) ll)
)

;; Distancia punto-segmento
(defun mp-dist-pt-seg (p a b / ax ay bx by px py sdx sdy len2 tt cx cy)
  (setq ax (car a) ay (cadr a) bx (car b) by (cadr b) px (car p) py (cadr p))
  (setq sdx (- bx ax) sdy (- by ay))
  (setq len2 (+ (* sdx sdx) (* sdy sdy)))
  (if (< len2 1e-10)
    (list (distance p a) a)
    (progn
      (setq tt (/ (+ (* (- px ax) sdx) (* (- py ay) sdy)) len2))
      (if (< tt 0.0) (setq tt 0.0))
      (if (> tt 1.0) (setq tt 1.0))
      (setq cx (+ ax (* tt sdx)) cy (+ ay (* tt sdy)))
      (list (distance p (list cx cy)) (list cx cy))
    )
  )
)

;; Distancia punto-polilinea
(defun mp-dist-to-poly (pt verts is-closed / n md d cp seg-result i)
  (setq n (length verts))
  (if (< n 2)
    (if verts (list (distance pt (car verts)) (car verts)) nil)
    (progn
      (setq md 1e99 cp nil i 0)
      (while (< i (1- n))
        (setq seg-result (mp-dist-pt-seg pt (nth i verts) (nth (1+ i) verts)))
        (setq d (car seg-result))
        (if (< d md)
          (progn (setq md d) (setq cp (cadr seg-result)))
        )
        (setq i (1+ i))
      )
      (if is-closed
        (progn
          (setq seg-result (mp-dist-pt-seg pt (nth (1- n) verts) (nth 0 verts)))
          (setq d (car seg-result))
          (if (< d md)
            (progn (setq md d) (setq cp (cadr seg-result)))
          )
        )
      )
      (if cp (list md cp) nil)
    )
  )
)

;; Pre-calcular datos de curvas (con bounding box)
(defun mp-prepare-curves (contour-data / prepared)
  (setq prepared nil)
  (foreach c contour-data
    (setq elev (car c) verts (cadr c) is-closed (caddr c))
    (setq xmin 1e99 xmax -1e99 ymin 1e99 ymax -1e99)
    (foreach pt verts
      (setq x (car pt) y (cadr pt))
      (if (< x xmin) (setq xmin x)) (if (> x xmax) (setq xmax x))
      (if (< y ymin) (setq ymin y)) (if (> y ymax) (setq ymax y))
    )
    (setq prepared (cons (list elev verts is-closed xmin xmax ymin ymax) prepared))
  )
  prepared
)

;; Verificar si punto esta cerca de curva (bounding box check)
(defun mp-is-near-curve (pt curve-data / x y xmin xmax ymin ymax radius)
  (setq x (car pt) y (cadr pt))
  (setq xmin (nth 3 curve-data) xmax (nth 4 curve-data)
        ymin (nth 5 curve-data) ymax (nth 6 curve-data))
  (setq radius *mp-search-radius*)
  (and
    (>= x (- xmin radius)) (<= x (+ xmax radius))
    (>= y (- ymin radius)) (<= y (+ ymax radius))
  )
)

;; ============================================================
;; FUNCIONES DE COLOREO Y ETIQUETADO
;; ============================================================

;; Crear capa con TrueColor
(defun mp-crear-capa (nombre color-rgb / tc)
  (if (not (tblsearch "LAYER" nombre))
    (progn
      (setq tc (+ (* (car color-rgb) 65536) (* (cadr color-rgb) 256) (caddr color-rgb)))
      (entmake (list
        (cons 0 "LAYER")
        (cons 100 "AcDbSymbolTableRecord")
        (cons 100 "AcDbLayerTableRecord")
        (cons 2 nombre)
        (cons 70 0)
        (cons 62 256)
        (cons 420 tc)
        (cons 6 "Continuous")
      ))
    )
  )
  T
)

;; Escala CCN 17 colores RGB
(defun mp-rgb-ccn (indice total batimetria
                   / escala ratio pos-frac pos-entera c1 c2 r g b)
  (setq escala
    '(
      (36 18 0) (100 50 0) (150 0 0) (255 0 0) (255 71 26)
      (255 100 0) (255 150 0) (255 255 0) (10 208 6) (6 147 44)
      (10 214 156) (0 200 255) (0 100 255) (0 0 255) (26 21 157)
      (16 13 99) (11 9 68)
    )
  )
  (if batimetria (setq escala (reverse escala)))
  (if (<= total 1)
    (setq ratio 0.0)
    (setq ratio (/ (float (1- indice)) (float (1- total))))
  )
  (setq pos-frac (* ratio (1- (length escala))))
  (setq pos-entera (fix pos-frac))
  (if (>= pos-entera (1- (length escala)))
    (setq pos-entera (1- (length escala)))
  )
  (if (= pos-entera (1- (length escala)))
    (nth pos-entera escala)
    (progn
      (setq c1 (nth pos-entera escala) c2 (nth (1+ pos-entera) escala)
            pos-frac (- pos-frac pos-entera))
      (setq r (fix (+ (car c1) (* pos-frac (- (car c2) (car c1))))))
      (setq g (fix (+ (cadr c1) (* pos-frac (- (cadr c2) (cadr c1))))))
      (setq b (fix (+ (caddr c1) (* pos-frac (- (caddr c2) (caddr c1))))))
      (list (max 0 (min 255 r)) (max 0 (min 255 g)) (max 0 (min 255 b)))
    )
  )
)

;; RGB -> hex string
(defun mp-rgb-a-hex (rgb / r g b)
  (defun mp-byte-hex (n / d)
    (setq d '("0" "1" "2" "3" "4" "5" "6" "7" "8" "9"
              "A" "B" "C" "D" "E" "F"))
    (strcat (nth (/ n 16) d) (nth (rem n 16) d))
  )
  (setq r (car rgb) g (cadr rgb) b (caddr rgb))
  (strcat "#" (mp-byte-hex r) (mp-byte-hex g) (mp-byte-hex b))
)

;; Generar lista de capas por cota
(defun mp-generar-capas (min-z max-z num-capas batimetria prefijo
                                       / intervalo i z-inicio z-fin nombre color lista-capas)
  (setq intervalo (if (> (- max-z min-z) 0.0) (/ (- max-z min-z) num-capas) 1.0))
  (setq i 1 lista-capas '())
  (repeat num-capas
    (setq z-inicio (+ min-z (* intervalo (1- i))))
    (setq z-fin    (+ min-z (* intervalo i)))
    (setq nombre   (strcat prefijo "_" (itoa i)))
    (setq color    (mp-rgb-ccn i num-capas batimetria))
    (setq lista-capas (cons (list nombre z-inicio z-fin color 0) lista-capas))
    (setq i (1+ i))
  )
  (list (reverse lista-capas) intervalo)
)

;; Crear leyenda de cotas
(defun mp-crear-leyenda (capas-info / punto-base y-pos escala-leyenda rgb-ley tc)
  (setq punto-base (getpoint "\n  Punto para la leyenda: "))
  (if punto-base
    (progn
      (if (not (tblsearch "LAYER" "LEYENDA_COTAS"))
        (mp-crear-capa "LEYENDA_COTAS" '(255 255 255))
      )
      (setq escala-leyenda (getvar "DIMSCALE"))
      (if (not escala-leyenda) (setq escala-leyenda 1.0))
      (entmake (list
        '(0 . "TEXT") (cons 8 "LEYENDA_COTAS")
        (cons 10 punto-base) (cons 40 (* 2.5 escala-leyenda))
        (cons 1 "LEYENDA DE COTAS Z")
        (cons 7 (getvar "TEXTSTYLE")) (cons 62 7)
      ))
      (setq y-pos (- (cadr punto-base) (* 4.0 escala-leyenda)))
      (foreach info (reverse capas-info)
        (setq rgb-ley (nth 3 info))
        (setq tc (+ (* (car rgb-ley) 65536) (* (cadr rgb-ley) 256) (caddr rgb-ley)))
        (entmake (list
          '(0 . "LWPOLYLINE") (cons 8 "LEYENDA_COTAS") (cons 420 tc)
          '(100 . "AcDbEntity") '(100 . "AcDbPolyline") (cons 90 4) (cons 70 1)
          (cons 10 (list (car punto-base) y-pos 0))
          (cons 10 (list (+ (car punto-base) (* 3.0 escala-leyenda)) y-pos 0))
          (cons 10 (list
            (+ (car punto-base) (* 3.0 escala-leyenda))
            (+ y-pos (* 2.0 escala-leyenda)) 0
          ))
          (cons 10 (list (car punto-base) (+ y-pos (* 2.0 escala-leyenda)) 0))
        ))
        (entmake (list
          '(0 . "TEXT") (cons 8 "LEYENDA_COTAS") (cons 420 tc)
          (cons 10 (list
            (+ (car punto-base) (* 4.0 escala-leyenda))
            (+ y-pos (* 0.5 escala-leyenda)) 0
          ))
          (cons 40 (* 2.0 escala-leyenda))
          (cons 1 (strcat
            (nth 0 info) "  Z: " (rtos (nth 1 info) 2 2) " - "
            (rtos (nth 2 info) 2 2) "  (" (itoa (nth 4 info)) " pts)"
          ))
          (cons 7 (getvar "TEXTSTYLE"))
        ))
        (setq y-pos (- y-pos (* 3.0 escala-leyenda)))
      )
      (princ "  Leyenda creada.")
    )
  )
)

;; Eliminar entidades de capas
(defun mp-eliminar-entidades-por-capa (lista-nombres / ss i)
  (foreach nom lista-nombres
    (setq ss (ssget "X" (list (cons 8 nom))))
    (if ss
      (progn
        (setq i 0)
        (repeat (sslength ss) (entdel (ssname ss i)) (setq i (1+ i)))
      )
    )
  )
)

;; Reemplazar indice en lista
(defun mp-reemplazar-indice (lista idx nuevo / i resultado)
  (setq i 0 resultado '())
  (foreach item lista
    (if (= i idx)
      (setq resultado (cons nuevo resultado))
      (setq resultado (cons item resultado))
    )
    (setq i (1+ i))
  )
  (reverse resultado)
)

;; Exportar puntos a CSV
(defun mp-export-points (pt-layer filename / ss i ent pt)
  (setq ss (ssget "X" (list (cons 0 "POINT") (cons 8 pt-layer))))
  (if ss
    (progn
      (setq file (open filename "w"))
      (write-line "X,Y,Z" file)
      (setq i 0)
      (while (< i (sslength ss))
        (setq ent (ssname ss i) pt (cdr (assoc 10 (entget ent))))
        (write-line
          (strcat
            (rtos (car pt) 2 3) ","
            (rtos (cadr pt) 2 3) ","
            (rtos (caddr pt) 2 3)
          )
          file
        )
        (setq i (1+ i))
      )
      (close file)
      (princ (strcat "\nPuntos exportados a: " filename))
    )
    (princ "\nNo hay puntos para exportar.")
  )
)

;; ============================================================
;; DIALOGO DE RESULTADOS (DCL temporal)
;; ============================================================
(defun mp-show-dialog (count total-pts contour-count use-poly poly-count elapsed
                       export-file color-on num-capas capas-info
                       / dcl_file dcl_id time-str)
  (setq time-str (mp-format-time elapsed))
  (setq dcl_file (strcat (getvar "TEMPPREFIX") "mp_result.dcl"))
  (setq file (open dcl_file "w"))
  (if file
    (progn
      (write-line "mp_result : dialog {" file)
      (write-line "  label = \"MALLA DE PUNTOS - COMPLETADO\";" file)
      (write-line "  : column {" file)
      (write-line "    : text { label = \"========================================\"; }" file)
      (write-line "    : text { label = \"     PROCESO COMPLETADO EXITOSAMENTE\"; }" file)
      (write-line "    : text { label = \"========================================\"; }" file)
      (write-line "    spacer_1;" file)
      (write-line "    : row {" file)
      (write-line "      : text { label = \"Puntos generados:\"; width = 25; }" file)
      (write-line "      : text { key = \"count\"; width = 15; }" file)
      (write-line "    }" file)
      (write-line "    : row {" file)
      (write-line "      : text { label = \"Puntos evaluados:\"; width = 25; }" file)
      (write-line "      : text { key = \"total\"; width = 15; }" file)
      (write-line "    }" file)
      (write-line "    : row {" file)
      (write-line "      : text { label = \"Curvas utilizadas:\"; width = 25; }" file)
      (write-line "      : text { key = \"curves\"; width = 15; }" file)
      (write-line "    }" file)
      (write-line "    : row {" file)
      (write-line "      : text { label = \"Poligonos recorte:\"; width = 25; }" file)
      (write-line "      : text { key = \"polys\"; width = 15; }" file)
      (write-line "    }" file)
      (write-line "    : row {" file)
      (write-line "      : text { label = \"Tiempo ejecucion:\"; width = 25; }" file)
      (write-line "      : text { key = \"time\"; width = 15; }" file)
      (write-line "    }" file)
      (if color-on
        (progn
          (write-line "    : row {" file)
          (write-line "      : text { label = \"Color por cota:\"; width = 25; }" file)
          (write-line "      : text { key = \"colorinfo\"; width = 15; }" file)
          (write-line "    }" file)
        )
      )
      (write-line "    spacer_1;" file)
      (write-line "    : text { label = \"========================================\"; }" file)
      (if export-file
        (progn
          (write-line "    : row {" file)
          (write-line "      : text { label = \"Exportado a:\"; width = 25; }" file)
          (write-line "      : text { key = \"export\"; width = 15; }" file)
          (write-line "    }" file)
          (write-line "    spacer_1;" file)
        )
      )
      (write-line "    : text { label = \"Sugerencias:\"; }" file)
      (write-line "    : text { label = \"  Los puntos ya estan configurados como\"; }" file)
      (write-line "    : text { label = \"  circulo con punto central (PDMODE=35).\"; }" file)
      (write-line
        (strcat "    : text { label = \"  Capa puntos: " *mp-pt-layer* "\"; }")
        file
      )
      (write-line "    : text { label = \"  EXPORTAR-PUNTOS para exportar a CSV\"; }" file)
      (write-line "    spacer_1;" file)
      (write-line "    : row {" file)
      (write-line "      : button { label = \"Aceptar\"; key = \"accept\"; is_default = true; width = 20; }" file)
      (write-line "    }" file)
      (write-line "  }" file)
      (write-line "}" file)
      (close file)
      (setq dcl_id (load_dialog dcl_file))
      (if (> dcl_id 0)
        (progn
          (if (new_dialog "mp_result" dcl_id)
            (progn
              (set_tile "count" (itoa count))
              (set_tile "total" (itoa total-pts))
              (set_tile "curves" (itoa contour-count))
              (if (and use-poly (not (= use-poly "N")))
                (set_tile "polys" (itoa poly-count))
                (set_tile "polys" "No usado")
              )
              (set_tile "time" time-str)
              (if color-on
                (set_tile "colorinfo" (strcat "SI (" (itoa num-capas) " capas)"))
              )
              (if export-file
                (progn
                  (if (> (strlen export-file) 35)
                    (setq export-file
                      (strcat "..." (substr export-file (- (strlen export-file) 32))))
                  )
                  (set_tile "export" export-file)
                )
              )
              (action_tile "accept" "(done_dialog 1)")
              (start_dialog)
            )
            (princ "\nNo se pudo crear el dialogo.")
          )
          (unload_dialog dcl_id)
        )
        (princ "\nError al cargar el archivo DCL.")
      )
    )
    (princ "\nError al crear el archivo DCL.")
  )
)

;; ============================================================
;; Callback: guardar config y cerrar dialogo
;; ============================================================
(defun mp:dlg-guardar-y-cerrar ()
  (setq *mp:cfg* (mp:dlg-leer-config))
  (done_dialog 1)
)

;; ============================================================
;; COMANDO PRINCIPAL: MALLA-PUNTOS (con dialogo DCL)
;; ============================================================
(defun c:MALLA-PUNTOS (/ *error* old-cmdecho old-filedia
  dlg-resultado cfg
  ss-cont n-cont ent-cont edata-cont elev-cont
  contour-data verts is-closed prepared-curves
  p1 p2 xmin xmax ymin ymax
  mp-dx mp-dy mp-nx mp-ny
  gx gy gz sum_w sum_we w d cl-result pt
  pt-layer power decimals
  count total ok ans
  i j ss-old k
  use-poly poly-ss poly-ents poly-verts-list
  point-list contour-count poly-count
  start-time end-time elapsed time-str
  color-on num-capas color-prefijo batimetria
  capas-info color-intervalo capas-resultado
  min-z max-z all-elevs tmp-z
  capa-indice capa-rgb capa-tc
  etiq-on etiq-alt etiq-sep etiq-dec etiq-anc etiq-abs
  etiq-capa-uni etiq-capa-nombre
  leyenda-on csv-on csv-nom export-file export-opt
  lista-previas idx poly-idx dcl-id ruta-dcl
  old-osmode lay-ent lay-name lay-data draw-ok ent-new
  resp-poly resp-poly-ok old-pdmode old-pdsize)

  (setq ok T)
  (setq start-time (getvar "DATE"))
  (setq old-cmdecho (getvar "CMDECHO"))
  (setq old-filedia (getvar "FILEDIA"))

  ;; --- Limpiar cualquier comando activo pendiente de sesiones previas ---
  (while (> (getvar "CMDACTIVE") 0)
    (command "")
  )

  (setvar "CMDECHO" 0)
  (setq *mp:cfg* nil)

  (defun *error* (msg)
    (if old-cmdecho (setvar "CMDECHO" old-cmdecho))
    (if old-filedia (setvar "FILEDIA" old-filedia))
    (if old-pdmode (setvar "PDMODE" old-pdmode))
    (if old-pdsize (setvar "PDSIZE" old-pdsize))
    (if (not (wcmatch (strcase msg)
              "*CANCEL*,*EXIT*,*QUIT*,*INTERRUPCION*,*BREAK*,*ABORT*"))
      (princ (strcat "\n[ERROR] " msg))
    )
    (princ)
  )

  ;; ============================================================
  ;; 1) Lanzar dialogo DCL
  ;; ============================================================
  (setq ruta-dcl (mp:escribir-dcl-config))
  (setq dcl-id (load_dialog ruta-dcl))
  (if (< dcl-id 0)
    (progn
      (princ "\nError al cargar DCL.")
      (setvar "CMDECHO" old-cmdecho)
      (setvar "FILEDIA" old-filedia)
      (princ) (exit)
    )
  )

  (if (not (new_dialog "mp_config" dcl-id))
    (progn
      (princ "\nError al crear dialogo.")
      (unload_dialog dcl-id)
      (setvar "CMDECHO" old-cmdecho)
      (setvar "FILEDIA" old-filedia)
      (princ) (exit)
    )
  )

  (action_tile "tgl_color"       "(mp:dlg-toggle-color)")
  (action_tile "rb_custom"       "(mp:dlg-toggle-capas-custom)")
  (action_tile "rb_5"            "(mp:dlg-radio-capas)")
  (action_tile "rb_10"           "(mp:dlg-radio-capas)")
  (action_tile "rb_15"           "(mp:dlg-radio-capas)")
  (action_tile "rb_20"           "(mp:dlg-radio-capas)")
  (action_tile "tgl_etiq"        "(mp:dlg-toggle-etiquetas)")
  (action_tile "tgl_etiq_capa"   "(mp:dlg-toggle-etiq-capa)")
  (action_tile "tgl_csv"         "(mp:dlg-toggle-csv)")
  (action_tile "btn_ayuda"       "(mp:dlg-ayuda)")
  (action_tile "btn_cancel"      "(done_dialog 0)")
  (action_tile "btn_ok"          "(mp:dlg-guardar-y-cerrar)")

  (mp:dlg-inicializar)

  (setq dlg-resultado (start_dialog))
  (unload_dialog dcl-id)

  (if (/= dlg-resultado 1)
    (progn
      (princ "\nOperacion cancelada.")
      (setvar "CMDECHO" old-cmdecho)
      (setvar "FILEDIA" old-filedia)
      (princ) (exit)
    )
  )

  ;; ============================================================
  ;; 2) Leer configuracion
  ;; ============================================================
  (if (not *mp:cfg*)
    (progn
      (alert "Error: no se pudo leer la configuracion.")
      (setvar "CMDECHO" old-cmdecho)
      (setvar "FILEDIA" old-filedia)
      (princ) (exit)
    )
  )

  (setq cfg *mp:cfg*)
  (setq mp-dx            (nth 0 cfg))
  (setq mp-dy            (nth 1 cfg))
  (setq color-on         (nth 2 cfg))
  (setq num-capas        (nth 3 cfg))
  (setq color-prefijo    (nth 4 cfg))
  (setq batimetria       (nth 5 cfg))
  (setq etiq-on          (nth 6 cfg))
  (setq etiq-alt         (nth 7 cfg))
  (setq etiq-sep         (nth 8 cfg))
  (setq etiq-dec         (nth 9 cfg))
  (setq etiq-anc         (nth 10 cfg))
  (setq etiq-abs         (nth 11 cfg))
  (setq etiq-capa-uni    (nth 12 cfg))
  (setq etiq-capa-nombre (nth 13 cfg))
  (setq leyenda-on       (nth 14 cfg))
  (setq csv-on           (nth 15 cfg))
  (setq csv-nom          (nth 16 cfg))

  (if (not mp-dx) (setq mp-dx 0.50))
  (if (not mp-dy) (setq mp-dy 0.50))
  (if (<= mp-dx 0.0)
    (progn (princ "\nERROR: Distancia X debe ser > 0.") (setq ok nil))
  )
  (if (<= mp-dy 0.0)
    (progn (princ "\nERROR: Distancia Y debe ser > 0.") (setq ok nil))
  )
  (if (and leyenda-on (not color-on))
    (setq leyenda-on nil)
  )
  (if (and etiq-on (not color-on))
    (progn (setq etiq-capa-uni T) (setq etiq-capa-nombre *mp-pt-layer*))
  )
  (if (and csv-on csv-nom)
    (setq export-file (strcat (getvar "DWGPREFIX") csv-nom ".csv"))
    (setq export-file nil)
  )

  ;; --- Configurar visualizacion de puntos: circulo con punto central ---
  (setq old-pdmode (getvar "PDMODE"))
  (setq old-pdsize (getvar "PDSIZE"))
  (setvar "PDMODE" 35)     ; circulo con punto en el centro
  (setvar "PDSIZE" -0.3)   ; 0.3 en unidades absolutas (negativo = absoluto)

  (princ "\n")
  (princ "============================================================\n")
  (princ "      MALLA DE PUNTOS POR INTERPOLACION IDW - v4.7\n")
  (princ "============================================================\n")
  (princ (strcat "\n  Distancia X: " (rtos mp-dx 2 2) "  Y: " (rtos mp-dy 2 2)))
  (if color-on
    (progn
      (princ (strcat "\n  Coloreo: SI (" (itoa num-capas) " capas, prefijo: " color-prefijo ")"))
      (if batimetria (princ "  [BATIMETRIA]"))
      (if etiq-on
        (princ (strcat
          "\n  Etiquetas: SI (h=" (rtos etiq-alt 2 2)
          " sep=" (rtos etiq-sep 2 2) " dec=" (itoa etiq-dec) ")"
        ))
      )
    )
    (princ "\n  Coloreo: NO (puntos en capa unica)")
  )
  (if csv-on
    (princ (strcat "\n  Exportar CSV: " export-file))
  )
  (princ "\n  Puntos: circulo con punto central, tamaño 0.3 (absoluto)")

  (setq pt-layer *mp-pt-layer* power *mp-power* decimals *mp-decimals* poly-count 0)

  ;; ============================================================
  ;; 3) Poligono de recorte (Si / No / Dibujar)
  ;; ============================================================
  (if ok
    (progn
      (setq resp-poly-ok nil)
      (while (not resp-poly-ok)
        (setq resp-poly
          (getstring
            "\nUsar poligono de recorte? [Si/No/Dibujar] <No>: "
          )
        )
        (if (or (null resp-poly) (= resp-poly ""))
          (setq resp-poly "N")
        )
        (setq resp-poly (strcase resp-poly))

        (cond
          ;; --- Si ---
          ((member resp-poly '("S" "SI" "Y" "YES"))
           (setq use-poly "S")
           (setq resp-poly-ok T)
          )
          ;; --- No ---
          ((member resp-poly '("N" "NO"))
           (setq use-poly "N")
           (setq resp-poly-ok T)
          )
          ;; --- Dibujar ---
          ((member resp-poly '("D" "DI" "DIB" "DIBU" "DIBUJ" "DIBUJA" "DIBUJAR"))
           (setq use-poly "D")
           (setq resp-poly-ok T)
          )
          ;; --- Cualquier otra cosa ---
          (T
           (princ "\nOpcion no valida. Escriba Si, No o Dibujar.")
          )
        )
      )

      (cond
        ;; --- Opcion Dibujar ---
        ((= use-poly "D")
         (setq old-osmode (getvar "OSMODE"))
         (setvar "OSMODE" 5)   ; ENDPOINT + CENTER

         ;; Crear capa POLIGONO si no existe
         (if (not (tblsearch "LAYER" "POLIGONO"))
           (entmake
             (list
               '(0 . "LAYER")
               '(100 . "AcDbSymbolTableRecord")
               '(100 . "AcDbLayerTableRecord")
               (cons 2 "POLIGONO")
               (cons 70 0)
               (cons 62 1)
               (cons 370 30)
               (cons 6 "Continuous")
             )
           )
         )

         ;; Asegurar color rojo y grosor 3.0
         (if (tblsearch "LAYER" "POLIGONO")
           (progn
             (setq lay-data (entget (tblobjname "LAYER" "POLIGONO")))
             (if (assoc 62 lay-data)
               (setq lay-data (subst (cons 62 1) (assoc 62 lay-data) lay-data))
               (setq lay-data (append lay-data (list (cons 62 1))))
             )
             (if (assoc 370 lay-data)
               (setq lay-data (subst (cons 370 30) (assoc 370 lay-data) lay-data))
               (setq lay-data (append lay-data (list (cons 370 30))))
             )
             (entmod lay-data)
           )
         )

         (princ "\nDibuje el poligono de recorte (LWPOLYLINE cerrada).")
         (setvar "CLAYER" "POLIGONO")

         (setq draw-ok nil)
         (while (not draw-ok)
           (vl-cmdf "_.PLINE")
           (while (> (getvar "CMDACTIVE") 0)
             (vl-cmdf PAUSE)
           )
           (vl-cmdf "")
           ;; Drenar cualquier comando pendiente
           (while (> (getvar "CMDACTIVE") 0)
             (vl-cmdf "")
           )

           (setq ent-new (entlast))
           (if (and ent-new
                    (= (cdr (assoc 0 (entget ent-new))) "LWPOLYLINE")
                    (> (length (mp-get-poly-verts ent-new)) 2))
             (progn
               (setq poly-ents (list ent-new))
               (setq poly-verts-list (list (mp-get-poly-verts ent-new)))
               (setq poly-count 1)
               (setq draw-ok T)
               (princ "\nPoligono de recorte dibujado correctamente.")
             )
             (progn
               (princ "\nNo se dibujo una LWPOLYLINE valida. Intente de nuevo.")
               (if ent-new (entdel ent-new))
             )
           )
         )

         (setvar "OSMODE" old-osmode)
        )

        ;; --- Opcion Si ---
        ((= use-poly "S")
         (princ "\nSelecciona uno o mas poligonos (LWPOLYLINE):")
         (setq poly-ss (ssget '((0 . "LWPOLYLINE"))))
         (if (not poly-ss)
           (progn
             (princ "\nNo se seleccionaron poligonos. Area completa.")
             (setq use-poly "N")
           )
           (progn
             (setq poly-ents nil poly-verts-list nil i 0)
             (while (< i (sslength poly-ss))
               (setq ent (ssname poly-ss i))
               (setq poly-ents (cons ent poly-ents))
               (setq verts (mp-get-poly-verts ent))
               (if (> (length verts) 2)
                 (setq poly-verts-list (cons verts poly-verts-list))
                 (princ "\nPoligono con < 3 vertices ignorado.")
               )
               (setq i (1+ i))
             )
             (if (not poly-verts-list)
               (progn
                 (princ "\nNo hay poligonos validos.")
                 (setq use-poly "N")
               )
               (progn
                 (setq poly-count (length poly-verts-list))
                 (princ (strcat "\n" (itoa poly-count) " poligonos seleccionados."))
               )
             )
           )
         )
        )

        ;; --- Opcion No ---
        (T
         (setq use-poly "N")
        )
      )
    )
  )

  ;; ============================================================
  ;; 4) Area de la malla
  ;; ============================================================
  (if (and ok (or (null use-poly) (= use-poly "N")))
    (progn
      (princ "\nIndique el area de la malla (2 esquinas).")
      (setq p1 (getpoint "\nEsquina 1: "))
      (if (not p1) (setq ok nil))
    )
  )
  (if (and ok (or (null use-poly) (= use-poly "N")))
    (progn
      (setq p2 (getcorner p1 "\nEsquina 2: "))
      (if (not p2) (setq ok nil))
    )
  )
  (if (and ok use-poly (not (= use-poly "N")))
    (progn
      (setq xmin 1e99 xmax -1e99 ymin 1e99 ymax -1e99)
      (foreach verts poly-verts-list
        (foreach pt verts
          (setq x (car pt) y (cadr pt))
          (if (< x xmin) (setq xmin x)) (if (> x xmax) (setq xmax x))
          (if (< y ymin) (setq ymin y)) (if (> y ymax) (setq ymax y))
        )
      )
      (setq p1 (list xmin ymin) p2 (list xmax ymax))
      (princ (strcat
        "\nArea: X=" (rtos xmin 2 2) " a " (rtos xmax 2 2)
        " Y=" (rtos ymin 2 2) " a " (rtos ymax 2 2)
      ))
    )
  )

  ;; ============================================================
  ;; 5) Buscar curvas y preparar capas
  ;; ============================================================
  (if ok
    (progn
      (princ "\nBuscando curvas con elevacion...")
      (setq ss-cont (ssget "X" (list (cons 0 "LWPOLYLINE"))))
      (if (not ss-cont)
        (progn
          (princ "\nERROR: No se encontraron LWPOLYLINE.")
          (setq ok nil)
        )
        (progn
          (setq contour-data nil n-cont (sslength ss-cont) i 0)
          (while (< i n-cont)
            (setq ent-cont (ssname ss-cont i))
            (setq edata-cont (entget ent-cont))
            (if (and
                  (mp-layer-match (cdr (assoc 8 edata-cont)) *curv-layers*)
                  (assoc 38 edata-cont)
                  (/= (cdr (assoc 38 edata-cont)) 0.0)
                )
              (progn
                (setq elev-cont (cdr (assoc 38 edata-cont)))
                (setq verts (mp-get-verts ent-cont))
                (setq is-closed
                  (and (assoc 70 edata-cont)
                       (= (logand (cdr (assoc 70 edata-cont)) 1) 1))
                )
                (setq contour-data (cons (list elev-cont verts is-closed) contour-data))
              )
            )
            (setq i (1+ i))
          )
          (if (not contour-data)
            (progn
              (princ (strcat "\nERROR: " (itoa n-cont) " LWPOLYLINE sin elevacion."))
              (princ "\nUse ASIGNA-M o ASIGNA-P primero.")
              (setq ok nil)
            )
            (progn
              (setq contour-count (length contour-data))
              (princ (strcat "\n" (itoa contour-count) " curvas encontradas."))
              (princ "\nPreparando datos de curvas...")
              (setq prepared-curves (mp-prepare-curves contour-data))
              (if color-on
                (progn
                  (setq all-elevs (mapcar 'car contour-data))
                  (setq min-z (apply 'min all-elevs))
                  (setq max-z (apply 'max all-elevs))
                  (if batimetria
                    (progn
                      (setq tmp-z min-z)
                      (setq min-z (- max-z))
                      (setq max-z (- tmp-z))
                    )
                  )
                  (princ (strcat "\nRango cotas: " (rtos min-z 2 2) " a " (rtos max-z 2 2)))
                  (princ (strcat "\nCalculando " (itoa num-capas) " rangos de color..."))
                  (setq capas-resultado
                    (mp-generar-capas min-z max-z num-capas batimetria color-prefijo))
                  (setq capas-info (car capas-resultado))
                  (setq color-intervalo (cadr capas-resultado))
                  (princ (strcat "  Intervalo/rango: " (rtos color-intervalo 2 3)))
                )
              )
            )
          )
        )
      )
    )
  )

  ;; ============================================================
  ;; 6) Generar puntos
  ;; ============================================================
  (if ok
    (progn
      (setq xmin (min (car p1) (car p2))
            xmax (max (car p1) (car p2)))
      (setq ymin (min (cadr p1) (cadr p2))
            ymax (max (cadr p1) (cadr p2)))
      (setq mp-nx (fix (/ (- xmax xmin) mp-dx)))
      (setq mp-ny (fix (/ (- ymax ymin) mp-dy)))
      (if (< mp-nx 1) (setq mp-nx 1))
      (if (< mp-ny 1) (setq mp-ny 1))
      (setq total (* (1+ mp-nx) (1+ mp-ny)))
      (if (and use-poly (not (= use-poly "N")))
        (princ (strcat
          "\nMalla: " (itoa (1+ mp-nx)) " x " (itoa (1+ mp-ny))
          " = " (itoa total) " pts (poligono)."
        ))
        (princ (strcat
          "\nMalla: " (itoa (1+ mp-nx)) " x " (itoa (1+ mp-ny))
          " = " (itoa total) " pts."
        ))
      )
      (if (> total *mp-max-pts*)
        (progn
          (setq ans (getstring
            (strcat "\nADVERTENCIA: " (itoa total) " pts. Continuar? [S/N]: ")))
          (if (and ans (not (member (strcase ans) '("" "S" "SI" "Y" "YES"))))
            (progn (princ "\nCancelado.") (setq ok nil))
          )
        )
      )
      (if ok
        (progn
          (setq ss-old (ssget "X" (list (cons 0 "POINT") (cons 8 pt-layer))))
          (if ss-old
            (progn
              (setq k 0)
              (while (< k (sslength ss-old))
                (entdel (ssname ss-old k))
                (setq k (1+ k))
              )
              (princ (strcat "\nEliminados " (itoa (sslength ss-old)) " puntos previos."))
            )
          )
          (if (not (tblsearch "LAYER" pt-layer))
            (progn
              (entmake (list
                (cons 0 "LAYER")
                (cons 100 "AcDbSymbolTableRecord")
                (cons 100 "AcDbLayerTableRecord")
                (cons 2 pt-layer) (cons 70 0) (cons 62 7) (cons 6 "Continuous")
              ))
              (princ (strcat "\nCapa creada: " pt-layer))
            )
          )
          (if (and etiq-on etiq-capa-uni
                   (tblsearch "LAYER" etiq-capa-nombre))
            (progn
              (mp-eliminar-entidades-por-capa (list etiq-capa-nombre))
              (princ (strcat "\nLimpiada capa: " etiq-capa-nombre))
            )
          )
          (if (tblsearch "LAYER" "LEYENDA_COTAS")
            (progn
              (mp-eliminar-entidades-por-capa (list "LEYENDA_COTAS"))
            )
          )
        )
      )

      (princ "\nGenerando puntos...")
      (setq count 0 total-pts 0 j 0 point-list nil)

      (while (<= j mp-ny)
        (setq gy (+ ymin (* j mp-dy)) i 0)
        (while (<= i mp-nx)
          (setq gx (+ xmin (* i mp-dx)))
          (setq total-pts (1+ total-pts))
          (setq inside-poly nil)
          (if (and use-poly (not (= use-poly "N")))
            (progn
              (setq poly-idx 0)
              (while (and (not inside-poly) (< poly-idx (length poly-verts-list)))
                (if (mp-point-in-poly (list gx gy) (nth poly-idx poly-verts-list))
                  (setq inside-poly T)
                )
                (setq poly-idx (1+ poly-idx))
              )
            )
            (setq inside-poly T)
          )
          (if inside-poly
            (progn
              (setq sum_w 0.0 sum_we 0.0 pt (list gx gy))
              (foreach c prepared-curves
                (if (mp-is-near-curve pt c)
                  (progn
                    (setq elev (car c) verts (cadr c) is-closed (caddr c))
                    (setq cl-result (mp-dist-to-poly pt verts is-closed))
                    (if cl-result
                      (progn
                        (setq d (car cl-result))
                        (if (< d 0.001) (setq d 0.001))
                        (setq w (/ 1.0 (expt d power)))
                        (setq sum_w (+ sum_w w))
                        (setq sum_we (+ sum_we (* w elev)))
                      )
                    )
                  )
                )
              )
              (if (> sum_w 0.0)
                (progn
                  (setq gz (/ sum_we sum_w))
                  (setq gz
                    (* (fix (+ (* gz (expt 10.0 decimals)) 0.5))
                       (/ 1.0 (expt 10.0 decimals))))
                  (if color-on
                    (progn
                      (if (> (- max-z min-z) 0.0)
                        (setq capa-indice
                          (1+ (fix (/ (- gz min-z) color-intervalo))))
                        (setq capa-indice 1)
                      )
                      (setq capa-indice
                        (max 1 (min (length capas-info) capa-indice)))
                      (setq capa-rgb (nth 3 (nth (1- capa-indice) capas-info)))
                      (setq capa-tc
                        (+ (* (car capa-rgb) 65536)
                           (* (cadr capa-rgb) 256)
                           (caddr capa-rgb)))
                      (entmake (list
                        '(0 . "POINT") (cons 8 pt-layer)
                        (cons 62 256) (cons 420 capa-tc)
                        (cons 10 (list gx gy gz))
                      ))
                      (if etiq-on
                        (entmake (list
                          '(0 . "TEXT")
                          (cons 8 (if etiq-capa-uni etiq-capa-nombre pt-layer))
                          (cons 62 256) (cons 420 capa-tc)
                          (cons 7 (getvar "TEXTSTYLE"))
                          '(72 . 1) '(73 . 0)
                          (cons 10 (list gx (- gy etiq-sep) 0.0))
                          (cons 11 (list gx (- gy etiq-sep) 0.0))
                          (cons 40 etiq-alt) (cons 41 etiq-anc)
                          (cons 1 (rtos (if etiq-abs (abs gz) gz) 2 etiq-dec))
                        ))
                      )
                      (setq idx (1- capa-indice))
                      (setq capas-info
                        (mp-reemplazar-indice capas-info idx
                          (list
                            (nth 0 (nth idx capas-info))
                            (nth 1 (nth idx capas-info))
                            (nth 2 (nth idx capas-info))
                            (nth 3 (nth idx capas-info))
                            (1+ (nth 4 (nth idx capas-info)))
                          )
                        )
                      )
                    )
                    (entmake (list
                      (cons 0 "POINT")
                      (cons 10 (list gx gy gz))
                      (cons 8 pt-layer) (cons 62 2)
                    ))
                  )
                  (setq count (1+ count))
                  (if export-file
                    (setq point-list (cons (list gx gy gz) point-list))
                  )
                )
              )
            )
          )
          (setq i (1+ i))
        )
        (if (= (rem j 10) 0)
          (princ (strcat "\r  Fila " (itoa (1+ j)) "/" (itoa (1+ mp-ny)) " ... " (itoa count) " pts"))
        )
        (setq j (1+ j))
      )

      (if (and export-file (> count 0))
        (progn
          (setq file (open export-file "w"))
          (write-line "X,Y,Z" file)
          (foreach pt point-list
            (write-line
              (strcat
                (rtos (car pt) 2 decimals) ","
                (rtos (cadr pt) 2 decimals) ","
                (rtos (caddr pt) 2 decimals)
              )
              file
            )
          )
          (close file)
          (princ (strcat "\nExportado a: " export-file))
        )
      )

      (if (and color-on leyenda-on)
        (mp-crear-leyenda capas-info)
      )

      (setq end-time (getvar "DATE"))
      (setq elapsed (* 86400.0 (- end-time start-time)))
      (setq time-str (mp-format-time elapsed))
      (princ "\n\n============================================================")
      (princ "\n              PROCESO COMPLETADO EXITOSAMENTE")
      (princ "\n============================================================")
      (princ (strcat "\n  Puntos generados: " (itoa count)))
      (princ (strcat "\n  Puntos evaluados: " (itoa total-pts)))
      (princ (strcat "\n  Curvas utilizadas: " (itoa contour-count)))
      (if color-on
        (progn
          (princ (strcat "\n  Coloreo: SI (" (itoa num-capas) " rangos, capa: " pt-layer ")"))
          (princ (strcat "\n  Intervalo/rango: " (rtos color-intervalo 2 3)))
          (if etiq-on (princ "\n  Etiquetas: SI"))
          (if leyenda-on (princ "\n  Leyenda: SI"))
        )
      )
      (if (and use-poly (not (= use-poly "N")))
        (princ (strcat "\n  Poligonos: " (itoa poly-count)))
      )
      (princ (strcat "\n  Tiempo: " time-str))
      (if export-file
        (princ (strcat "\n  CSV: " export-file))
      )
      (princ "\n============================================================")
      (princ "\n  Puntos: circulo con punto central, tamaño 0.3 (absoluto)")
      (princ (strcat "\n  Capa puntos: " pt-layer))
      (princ "\n  EXPORTAR-PUNTOS para exportar a CSV")
      (princ "\n============================================================\n")

      (mp-show-dialog
        count total-pts contour-count use-poly poly-count elapsed
        export-file color-on
        (if color-on num-capas 0)
        (if color-on capas-info nil)
      )
    )
  )

  ;; ============================================================
  ;; 7) Cierre limpio (evita comando fantasma BOX/CUADRO)
  ;; ============================================================
  (while (> (getvar "CMDACTIVE") 0)
    (command "")
  )

  ;; --- Restaurar visualizacion de puntos ---
  (if old-pdmode (setvar "PDMODE" old-pdmode))
  (if old-pdsize (setvar "PDSIZE" old-pdsize))

  (setq *mp:cfg* nil)
  (setvar "CMDECHO" old-cmdecho)
  (setvar "FILEDIA" old-filedia)
  (princ)
)

;; ============================================================
;; COMANDO: Exportar puntos a CSV
;; ============================================================
(defun c:EXPORTAR-PUNTOS (/ pt-layer filename)
  (setq pt-layer (getstring "\nNombre de la capa con puntos: "))
  (if (not pt-layer) (setq pt-layer "MALLA_PUNTOS"))
  (setq filename (getstring "\nNombre del archivo (sin extension): "))
  (if (not filename) (setq filename "PUNTOS"))
  (setq filename (strcat (getvar "DWGPREFIX") filename ".csv"))
  (mp-export-points pt-layer filename)
  (princ)
)

;; Alias seguros (evitando nombres de comandos nativos de AutoCAD)
(defun c:MP  () (c:MALLA-PUNTOS))
(defun c:MLL () (c:MALLA-PUNTOS))
(defun c:EXP () (c:EXPORTAR-PUNTOS))

;; ============================================================
;; MENSAJES DE CARGA
;; ============================================================
(princ "\n")
(princ "============================================================\n")
(princ "      MALLA-PUNTOS v4.7 (DCL integrado + Poligono recorte)\n")
(princ "      Comandos disponibles:\n")
(princ "      - MALLA-PUNTOS     : Generar malla de puntos (comando principal)\n")
(princ "      - MP / MLL         : Alias de MALLA-PUNTOS\n")
(princ "      - EXPORTAR-PUNTOS  : Exportar puntos a CSV\n")
(princ "      - EXP              : Alias de EXPORTAR-PUNTOS\n")
(princ "============================================================\n")
(princ "\n   DCL integrado: no requiere archivo externo\n")
(princ "\n   Nota: se elimino el alias MALLA porque AutoCAD lo\n")
(princ "   intercepta con el comando nativo MALLA (MESH).\n")
(princ "   Use MALLA-PUNTOS, MP o MLL en su lugar.\n")
(princ "\n   Puntos estilo circulo con punto en el centro\n")
(princ "   (PDMODE=35, PDSIZE=-0.3 en unidades absolutas).\n")
(princ "\n   Compatible con AutoCAD en espanol e ingles.\n")
(princ "\n")
(princ)