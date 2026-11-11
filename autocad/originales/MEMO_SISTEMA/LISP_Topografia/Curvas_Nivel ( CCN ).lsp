;;; ============================================================================
;;; CCN 3.1.1 | 2026-11-05 | MEJORA DE COMANDOS - Guillermo Michel
;;; Base: Curvas_Nivel (CCN). Un solo LSP, DCL integrado, AutoCAD/ZWCAD Windows.
;;; COMANDOS CCN / CCNT / CCNAYUDA / CCNTEST.
;;; Colorea geometria EXISTENTE; no genera curvas ni modifica coordenadas.
;;; Misma paleta e intervalos de XYZ-Tools 2.6.1; extremos estrictos << y >>.
;;; 3.1.1: referencia separada del destino; escala XYZ persistida; texto Standard.
;;; Correcciones: Z WCS de polilineas 2D/3D; texto numerico estricto; colores de
;;; leyenda iguales a objetos; cancelar seguro; rollback y grupo DESHACER.
;;; Pruebas nativas en CAD pendientes; conservar registro de versiones interno.
;;; ============================================================================
(vl-load-com)
(setq *ccn:version* "3.1.1")

(defun ccn:defaults (/ cfg key value)
  (setq cfg '(("palette" . "0") ("classmode" . "0") ("classes" . "15") ("step" . "0.50")
    ("base" . "0") ("top" . "10") ("height" . "1") ("legend" . "1")
    ("textmode" . "0") ("tol" . "0.001") ("csv" . "0") ("zoom" . "1") ("prefix" . "CCN")))
  ;; Si XYZ-Tools esta cargado, reutilizar sus ultimos ajustes comunes al iniciar.
  (foreach key '("palette" "classmode" "classes" "step" "base" "top" "height" "legend")
    (if (setq value (cdr (assoc key *xyzt:lastcfg*))) (setq cfg (ccn:put key value cfg)))) cfg)
(setq ccn:keys '("palette" "classmode" "classes" "step" "base" "top" "height" "legend" "textmode" "tol" "csv" "zoom"))
(defun ccn:locked (en / layer flags)
  (setq layer (tblsearch "LAYER" (cdr (assoc 8 (entget en)))) flags (cdr (assoc 70 layer)))
  (and flags (/= 0 (logand 4 flags))))
(defun ccn:plain-mtext (text / i n ch next out stop invalid)
  (setq i 1 n (strlen text) out "" invalid nil)
  (while (<= i n)
    (setq ch (substr text i 1))
    (cond
      ((member ch '("{" "}")) nil)
      ((= ch "\\")
        (setq i (1+ i) next (if (<= i n) (substr text i 1) ""))
        (cond
          ((member next '("P" "~")) (setq out (strcat out " ")))
          ((member next '("L" "l" "O" "o" "K" "k")) nil)
          ((member next '("H" "h" "W" "w" "C" "c" "F" "f" "T" "t" "Q" "q" "A" "a"))
            (while (and (<= i n) (/= (substr text i 1) ";")) (setq i (1+ i)))
            (if (> i n) (setq invalid T)))
          (T (setq invalid T))))
      (T (setq out (strcat out ch))))
    (setq i (1+ i)))
  (if invalid nil out))
(defun ccn:text-number (text / clean upper prefix suffix)
  (setq clean (ccn:plain-mtext text))
  (if clean
    (progn
      (setq clean (ccn:trim clean) upper (strcase clean))
      (foreach prefix '("ELEVACION" "ELEVATION" "COTA" "NIVEL" "ELEV" "Z")
        (if (= (substr upper 1 (strlen prefix)) prefix)
          (setq clean (vl-string-left-trim " :=\t" (substr clean (1+ (strlen prefix)))) upper (strcase clean))))
      (foreach suffix '("M.S.N.M." "MSNM" "METROS" "M")
        (if (and (>= (strlen upper) (strlen suffix))
                 (= (substr upper (1+ (- (strlen upper) (strlen suffix)))) suffix))
          (setq clean (ccn:trim (substr clean 1 (- (strlen clean) (strlen suffix)))) upper (strcase clean))))
      (ccn:setting-number clean))))
(defun ccn:full-text (data / text part)
  (setq text "")
  ;; MTEXT: codigos 3 contienen fragmentos previos; 1 contiene el ultimo.
  (foreach part data (if (= (car part) 3) (setq text (strcat text (cdr part)))))
  (strcat text (cond ((cdr (assoc 1 data))) (T ""))))
(defun ccn:point-z (point)
  (if (and point (= (length point) 3) (numberp (caddr point))) (caddr point) nil))
(defun ccn:horizontal-normal (data / normal)
  (setq normal (cdr (assoc 210 data)))
  (or (null normal) (and (equal (car normal) 0.0 1e-10) (equal (cadr normal) 0.0 1e-10))))
(defun ccn:elevation (en cfg / data kind point elev lo hi part vertex vd flags tol value stop)
  (setq data (entget en) kind (cdr (assoc 0 data)) tol (ccn:get 'v-tol cfg) lo nil hi nil)
  (cond
    ((= kind "POINT") (ccn:point-z (cdr (assoc 10 data))))
    ((member kind '("TEXT" "MTEXT"))
      (if (= (ccn:get "textmode" cfg) "0") (ccn:text-number (ccn:full-text data))
        (ccn:point-z (if (= kind "TEXT") (trans (cdr (assoc 10 data)) en 0) (cdr (assoc 10 data))))))
    ((= kind "LWPOLYLINE")
      (if (ccn:horizontal-normal data)
        (progn
      (setq elev (cond ((cdr (assoc 38 data))) (T 0.0)))
      (foreach part data
        (if (= (car part) 10)
          (progn
            (setq point (trans (list (cadr part) (caddr part) elev) en 0) value (caddr point))
            (setq lo (if lo (min lo value) value) hi (if hi (max hi value) value)))))
      (if (and lo (<= (- hi lo) tol)) (/ (+ lo hi) 2.0) nil))))
    ((= kind "POLYLINE")
      (setq flags (cond ((cdr (assoc 70 data))) (T 0)))
      (if (and (= 0 (logand flags 80))
               (or (/= 0 (logand flags 8)) (ccn:horizontal-normal data)))
        (progn
          (setq point (cdr (assoc 10 data)) elev (cond ((ccn:point-z point)) (T 0.0)) vertex (entnext en) stop nil)
          (while (and vertex (not stop))
            (setq vd (entget vertex))
            (if (= (cdr (assoc 0 vd)) "SEQEND") (setq stop T)
              (if (= (cdr (assoc 0 vd)) "VERTEX")
                (progn
                  (setq point (cdr (assoc 10 vd)))
                  (setq point (if (/= 0 (logand 8 flags)) point (trans (list (car point) (cadr point) elev) en 0)))
                  (setq value (ccn:point-z point))
                  (if value (setq lo (if lo (min lo value) value) hi (if hi (max hi value) value))))))
            (if (not stop) (setq vertex (entnext vertex))))
          (if (and lo (<= (- hi lo) tol)) (/ (+ lo hi) 2.0) nil))))
    (T nil)))
(defun ccn:validate (cfg / key value count)
  (foreach key '("step" "base" "top" "height" "tol" "classes")
    (setq value (ccn:setting-number (ccn:get key cfg)))
    (if (or (null value) (> (abs value) 1e9)) (ccn:fail (strcat "Numero invalido: " key)))
    (setq cfg (ccn:put (read (strcat "v-" key)) value cfg)))
  (foreach key '(step height tol)
    (if (<= (ccn:get (read (strcat "v-" (vl-symbol-name key))) cfg) 0.0)
      (ccn:fail "Intervalo, altura y tolerancia deben ser positivos.")))
  (setq count (ccn:get 'v-classes cfg))
  (if (or (/= count (fix count)) (< count 1) (> count 100)) (ccn:fail "Numero de clases: entero de 1 a 100."))
  (if (and (= (ccn:get "classmode" cfg) "2") (>= (ccn:get 'v-base cfg) (ccn:get 'v-top cfg)))
    (ccn:fail "El limite inferior debe ser menor que el superior.")) cfg)
(defun ccn:analyze (selection cfg / i en z stat invalid locked)
  (setq i 0 stat (ccn:empty-stat) invalid 0 locked 0)
  (repeat (sslength selection)
    (setq en (ssname selection (float i)))
    (cond
      ((ccn:locked en) (setq locked (1+ locked)))
      ((setq z (ccn:elevation en cfg)) (setq stat (ccn:stat-add stat (list 0.0 0.0 z))))
      (T (setq invalid (1+ invalid))))
    (setq i (1+ i)))
  (list (cons 'eligible stat) (cons 'invalid invalid) (cons 'locked locked)))
(defun ccn:fill (key items / item)
  (start_list key) (foreach item items (add_list item)) (end_list))
(defun ccn:save-ui (/ key)
  (foreach key ccn:keys (setq *ccn:ui* (ccn:put key (get_tile key) *ccn:ui*))))
(defun ccn:dialog (stats / key)
  (if (not (new_dialog "CCN_MAIN" *ccn:dclid*)) (ccn:fail "No se pudo abrir la interfaz CCN."))
  (ccn:fill "palette" '("CCN topografica" "CCN batimetrica"))
  (ccn:fill "classmode" '("Automatico redondeado" "Intervalo fijo @ (m)" "Limites comunes + intervalo"))
  (ccn:fill "textmode" '("Contenido numerico de textos" "Z geometrica de textos"))
  (foreach key ccn:keys (set_tile key (ccn:get key *ccn:ui*)))
  (if *ccn:shared*
    (foreach key '("palette" "classmode" "classes" "step" "base" "top") (mode_tile key 1)))
  (set_tile "reference" *ccn:refname*)
  (set_tile "stats"
    (if *ccn:shared*
      (strcat "Escala registrada: " (itoa (length *ccn:shared*)) " clases; limites y RGB identicos a XYZ-Tools.")
      (strcat "Referencia: " (itoa (car (car (ccn:get 'eligible stats)))) " validos; "
        (itoa (ccn:get 'invalid stats)) " ambiguos/variables.")))
  (action_tile "accept" "(ccn:save-ui)(done_dialog 1)")
  (action_tile "preview" "(ccn:save-ui)(done_dialog 2)")
  (action_tile "help" "(ccn:save-ui)(done_dialog 3)")
  (action_tile "cancel" "(done_dialog 0)")
  (start_dialog))
(defun ccn:preview (classes / text info)
  (setq text "Intervalos de color (extremos estrictos):\n")
  (foreach info classes
    (princ (strcat "\n" (ccn:class-label info) " | " (ccn:hex (nth 3 info)))))
  (alert (strcat "Se generaron " (itoa (length classes)) " clases, incluyendo << y >>.\n"
    "Limite inferior: " (rtos (nth 2 (car classes)) 2 2)
    "\nLimite superior: " (rtos (nth 1 (last classes)) 2 2)
    "\nIntervalos y colores completos en la linea de comandos.")))
(defun ccn:color-data (data rgb / out part)
  (setq out nil)
  (foreach part data (if (not (member (car part) '(62 420 430))) (setq out (cons part out))))
  (append (reverse out) (list '(62 . 256) (cons 420 (ccn:tc rgb)))))
(defun ccn:bump (key counts) (ccn:put key (1+ (cond ((ccn:get key counts)) (T 0))) counts))
(defun ccn:make (data / en)
  (if (entmake data)
    (progn (setq en (entlast) *ccn:created* (cons en *ccn:created*)) en)
    (ccn:fail "No se pudo crear la simbologia.")))
(defun ccn:legend-text (point height text layer)
  (ccn:make (list '(0 . "TEXT") '(100 . "AcDbEntity") (cons 8 layer) '(62 . 7)
    '(100 . "AcDbText") (cons 10 point) (cons 40 height) (cons 1 text)
    '(7 . "Standard"))))
(defun ccn:legend (classes cfg base counts total lot / layer h x y info rgb n)
  (setq layer (strcat "CCN_SIMBOLOGIA_" lot) h (ccn:get 'v-height cfg) x (car base) y (cadr base))
  (if (not (entmake (list '(0 . "LAYER") '(100 . "AcDbSymbolTableRecord") '(100 . "AcDbLayerTableRecord")
        (cons 2 layer) '(70 . 0) '(62 . 7) '(6 . "Continuous")))) (ccn:fail "No se pudo crear la capa de simbologia."))
  (setq *ccn:newlayer* layer)
  (ccn:legend-text (list x y 0.0) (* h 1.25) "SIMBOLOGIA DE COTAS (m)" layer)
  (setq y (- y (* h 2.2)))
  (ccn:legend-text (list x y 0.0) h
    (strcat "CCN " *ccn:version* " | " (if (= (ccn:get "palette" cfg) "1") "BATIMETRICO" "TOPOGRAFICO")) layer)
  (setq y (- y (* h 2.0)))
  (if (and *ccn:refname* (/= *ccn:refname* ""))
    (progn (ccn:legend-text (list x y 0.0) h *ccn:refname* layer) (setq y (- y (* h 2.0)))))
  (foreach info (reverse classes)
    (setq rgb (nth 3 info) n (cond ((ccn:get (car info) counts)) (T 0)))
    (ccn:make (list '(0 . "SOLID") '(100 . "AcDbEntity") (cons 8 layer) (cons 420 (ccn:tc rgb))
      '(100 . "AcDbTrace") (cons 10 (list x y 0.0)) (cons 11 (list (+ x (* h 2)) y 0.0))
      (cons 12 (list x (+ y h) 0.0)) (cons 13 (list (+ x (* h 2)) (+ y h) 0.0))))
    (ccn:legend-text (list (+ x (* h 3)) y 0.0) h
      (strcat (ccn:class-label info) " | " (itoa n) " obj | " (rtos (ccn:percent n total) 2 2) "%") layer)
    (setq y (- y (* h 1.8)))) layer)
(defun ccn:report (path classes counts total cfg / f info n)
  (setq *ccn:out* (open path "w"))
  (if (not *ccn:out*) (ccn:fail "No se pudo escribir el CSV."))
  (setq f *ccn:out*)
  (write-line "Clase;Rango;Z_min;Z_max;Color_RGB;Objetos;Porcentaje" f)
  (foreach info classes
    (setq n (cond ((ccn:get (car info) counts)) (T 0)))
    (write-line (strcat (ccn:csv-quote (car info)) ";" (ccn:csv-quote (ccn:class-label info)) ";"
      (ccn:class-bound info 1) ";" (ccn:class-bound info 2) ";" (ccn:hex (nth 3 info)) ";"
      (itoa n) ";" (ccn:nstr (ccn:percent n total))) f))
  (close f) (setq *ccn:out* nil))
(defun ccn:unique-file (path / out i)
  (setq out path i 1)
  (while (findfile out)
    (setq out (strcat (vl-filename-directory path) "\\" (vl-filename-base path) "_" (itoa i) ".csv") i (1+ i))) out)
(defun ccn:cleanup ()
  (if *ccn:out* (progn (close *ccn:out*) (setq *ccn:out* nil)))
  (if (and *ccn:dclid* (>= *ccn:dclid* 0)) (unload_dialog *ccn:dclid*))
  (setq *ccn:dclid* nil)
  (if *ccn:dclfile* (vl-file-delete *ccn:dclfile*)) (setq *ccn:dclfile* nil)
  (if *ccn:temp* (vl-file-delete *ccn:temp*)) (setq *ccn:temp* nil))
(defun ccn:restore (/ data en failures)
  (setq failures 0)
  (foreach data *ccn:journal*
    (setq en (vl-catch-all-apply 'entmod (list data)))
    (if (or (vl-catch-all-error-p en) (not en)) (setq failures (1+ failures))))
  (foreach en *ccn:created* (vl-catch-all-apply 'entdel (list en))) failures)
(defun c:CCN (/ *error* doc oldcm olddim ss cfg stats classes result code i en z data index counts
                 total invalid locked point lot path temp start elapsed restored)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)) oldcm (getvar "CMDECHO") olddim (getvar "DIMZIN")
        *ccn:journal* nil *ccn:created* nil *ccn:newlayer* nil *ccn:out* nil *ccn:temp* nil
        *ccn:dclid* nil *ccn:dclfile* nil *ccn:failure* nil *ccn:undo* nil)
  (defun *error* (msg)
    (setq msg (if *ccn:failure* *ccn:failure* msg) *ccn:failure* nil)
    (ccn:cleanup) (setq restored (ccn:restore))
    (if *ccn:undo* (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
    (setvar "CMDECHO" oldcm) (setvar "DIMZIN" olddim)
    (princ (strcat "\nCCN detenido: " (if msg msg "sin mensaje")))
    (if (> restored 0) (princ (strcat "\nRevisar " (itoa restored) " objetos no restaurados; use U.")))
    (princ))
  (setvar "CMDECHO" 0) (setvar "DIMZIN" 0)
  (princ "\nCCN: primero defina la referencia; despues seleccione los objetos a colorear. ")
  (if (not *ccn:lastcfg*) (setq *ccn:lastcfg* (ccn:defaults)))
  (setq *ccn:ui* *ccn:lastcfg* cfg (ccn:validate *ccn:ui*))
  (setq ss (if (ccn:choose-reference cfg) (ccn:choose-target) nil))
  (if ss
    (progn
      (if (not *ccn:lastcfg*) (setq *ccn:lastcfg* (ccn:defaults)))
      (setq *ccn:ui* *ccn:lastcfg*)
      (if (and *ccn:shared* *ccn:sharedpalette*) (setq *ccn:ui* (ccn:put "palette" *ccn:sharedpalette* *ccn:ui*)))
      (setq cfg (ccn:validate *ccn:ui*) stats (ccn:reference-stats cfg))
      (ccn:make-dcl) (setq *ccn:dclid* (load_dialog *ccn:dclfile*))
      (if (< *ccn:dclid* 0) (ccn:fail "No se pudo cargar el dialogo integrado."))
      (setq code -1)
      (while (and (/= code 0) (/= code 1))
        (setq code (ccn:dialog stats))
        (cond
          ((= code 3) (c:CCNAYUDA))
          ((member code '(1 2))
            (setq result (ccn:try 'ccn:validate (list *ccn:ui*)))
            (if (vl-catch-all-error-p result)
              (progn (alert (ccn:errmsg result)) (setq code -1))
              (progn
                (setq cfg result stats (ccn:reference-stats cfg))
                (if (= 0 (car (car (ccn:get 'eligible stats))))
                  (progn (alert "No hay elevaciones validas en objetos desbloqueados. Revise textos/geometria.") (setq code -1))
                  (progn
                    (setq lot (strcat (vl-string-translate "." "_" (rtos (getvar "CDATE") 2 6)) "_" (itoa (getvar "MILLISECS"))))
                    (setq result (if *ccn:shared* *ccn:shared* (ccn:try 'ccn:classes (list cfg stats lot))))
                    (if (vl-catch-all-error-p result) (progn (alert (ccn:errmsg result)) (setq code -1))
                      (progn (setq classes result) (if (= code 2) (ccn:preview classes)))))))))))
      (setq *ccn:lastcfg* *ccn:ui*)
      (if (= code 1)
        (progn
          (if (= 0 (logand 1 (getvar "UNDOCTL"))) (ccn:fail "Active DESHACER antes de colorear."))
          (setq path nil)
          (if (= (ccn:get "csv" cfg) "1")
            (progn
              (setq path (getfiled "Guardar resumen de colores CSV" "CCN_COLORES.csv" "csv" 33))
              (if path
                (progn
                  (setq path (ccn:unique-file path))
                  (setq *ccn:temp* (vl-filename-mktemp "ccn_csv_" (vl-filename-directory path) ".tmp"))))))
          (vla-StartUndoMark doc) (setq *ccn:undo* T)
          (setq i 0 total 0 invalid 0 locked 0 counts nil start (getvar "MILLISECS"))
          (repeat (sslength ss)
            (setq en (ssname ss (float i)))
            (cond
              ((ccn:locked en) (setq locked (1+ locked)))
              ((not (setq z (ccn:elevation en cfg))) (setq invalid (1+ invalid)))
              (T
                (setq index (ccn:class-index z classes "1") data (entget en))
                (if (not (entmod (ccn:color-data data (nth 3 (nth index classes)))))
                  (ccn:fail "No se pudo colorear un objeto. Se restauran los cambios previos."))
                (setq *ccn:journal* (cons data *ccn:journal*) total (1+ total)
                      counts (ccn:bump (car (nth index classes)) counts))))
            (setq i (1+ i))
            (if (= 0 (rem i 1000)) (princ (strcat "\rCCN: " (itoa i) " objetos revisados..."))))
          (if (= total 0) (ccn:fail "No se colorearon objetos."))
          (vla-Regen doc 1)
          (if (= (ccn:get "zoom" cfg) "1") (vl-catch-all-apply 'command-s (list "_.ZOOM" "_Object" ss "")))
          (if (= (ccn:get "legend" cfg) "1")
            (progn
              (redraw)
              (setq result (ccn:try 'getpoint (list "\nObjetos coloreados. Insercion de simbologia (Enter/Esc: omitir): ")))
              (if (not (vl-catch-all-error-p result))
                (if result (ccn:legend classes cfg (trans result 1 0) counts total lot))
                (setq *ccn:failure* nil))))
          (if (and path *ccn:temp*)
            (progn
              (ccn:report *ccn:temp* classes counts total cfg)
              (if (not (vl-file-rename *ccn:temp* path)) (ccn:fail "No se pudo publicar el CSV."))
              (setq *ccn:temp* nil)))
          (vla-EndUndoMark doc) (setq *ccn:undo* nil *ccn:journal* nil *ccn:created* nil)
          (setq elapsed (/ (- (getvar "MILLISECS") start) 1000.0))
          (princ (strcat "\nCCN terminado: " (itoa total) " coloreados; " (itoa invalid)
            " ambiguos/variables omitidos; " (itoa locked) " bloqueados. Tiempo: " (rtos elapsed 2 2) " s."))
          (if path (princ (strcat "\nCSV: " path)))
          (alert (strcat "CCN " *ccn:version* " terminado\nColoreados: " (itoa total)
            "\nOmitidos por elevacion ambigua/variable: " (itoa invalid)
            "\nEn capas bloqueadas: " (itoa locked) "\nU deshace la operacion."))))))
  (ccn:cleanup) (setvar "CMDECHO" oldcm) (setvar "DIMZIN" olddim) (princ))
(defun c:CCNT () (c:CCN))
(defun c:CCNAYUDA ()
  (alert (strcat "CCN - colorear objetos existentes por elevacion\n\n"
    "1. Elija referencia: Puntos, Curvas o escala XYZ registrada.\n"
    "2. Seleccione aparte los objetos que desea colorear.\n"
    "Todo incluye puntos, curvas, TEXT y MTEXT; puede elegir solo curvas.\n"
    "Puntos del mismo lote XYZ reutilizan sus limites y RGB exactos.\n"
    "Por eso una seleccion parcial de puntos conserva la escala original.\n"
    "La simbologia usa el estilo Standard, igual que XYZ-Tools.\n"
    "2. Automatico redondeado o intervalo fijo @0.50, @1.00, etc.\n"
    "3. Limites comunes: mismos colores/rangos entre levantamientos.\n"
    "4. Topografico/batimetrico cambia SOLO colores, nunca signo de Z.\n"
    "5. Simbologia despues de colorear; Enter/Esc omite sin perder colores.\n\n"
    "POINT: Z mundial. Polilineas: Z mundial constante dentro de tolerancia.\n"
    "Polilineas 3D inclinadas, mallas y textos ambiguos se omiten.\n"
    "Textos: contenido numerico estricto o Z de insercion (elegible).\n"
    "Ejemplos validos: -8.50, Z=-8,50 m, COTA: 12.50 msnm.\n"
    "P12 Z=-8.5 se omite: contiene mas informacion que una cota.\n"
    "Extremos << minimo y >> maximo son estrictos; igualdad va al rango normal.\n"
    "Dibujo en metros; no modifica INSUNITS.\n"
    "No modifica geometria ni capa; aplica TrueColor directo a cada objeto.\n"
    "Colores y porcentajes de tabla salen de la misma clasificacion.\n"
    "CSV opcional con ; y punto decimal. Salida de coordenadas en metros.\n"
    "CCNTEST: pruebas puras. Validacion nativa AutoCAD/ZWCAD pendiente.")) (princ))

;;; Escala de referencia independiente de los objetos a colorear.
(defun ccn:split (text delimiter / pos result)
  (setq result nil)
  (while (setq pos (vl-string-search delimiter text))
    (setq result (cons (substr text 1 pos) result) text (substr text (+ pos 2))))
  (reverse (cons text result)))
(defun ccn:hex-rgb (text / i value bytes a b digits)
  (setq digits "0123456789ABCDEF" text (strcase text) bytes nil i 2)
  (if (and (= (strlen text) 7) (= (substr text 1 1) "#"))
    (progn
      (repeat 3
        (setq a (vl-string-search (substr text i 1) digits) b (vl-string-search (substr text (1+ i) 1) digits))
        (if (or (null a) (null b)) (ccn:fail "Color RGB invalido en el registro XYZ."))
        (setq bytes (cons (+ (* a 16) b) bytes) i (+ i 2)))
      (reverse bytes))
    (ccn:fail "No se pudo leer un color de la escala XYZ.")))
(defun ccn:entity-lot (en / app)
  (setq app (cadr (assoc -3 (entget en '("IXYZ7")))))
  (if (equal (car app) "IXYZ7") (cdr (assoc 1000 (cdr app))) nil))
(defun ccn:xyz-scale (lot / root record part line fields lo hi rgb classes cfgkey value)
  (setq root (dictsearch (namedobjdict) "IXYZ7_LOTES") classes nil)
  (if (and root (setq record (dictsearch (cdr (assoc -1 root)) lot)))
    (progn
      (foreach part record
        (if (= (car part) 1)
          (progn
            (setq line (cdr part))
            (if (and (= (substr line 1 8) "palette=") (member (substr line 9) '("0" "1")))
              (setq *ccn:sharedpalette* (substr line 9)))
            (if (= (substr line 1 6) "CLASE=")
              (progn
                (setq fields (ccn:split (substr line 7) ";"))
                (if (/= (length fields) 4) (ccn:fail "Registro de clase XYZ incompleto."))
                (setq lo (if (= (nth 1 fields) "") nil (ccn:setting-number (nth 1 fields)))
                      hi (if (= (nth 2 fields) "") nil (ccn:setting-number (nth 2 fields)))
                      rgb (ccn:hex-rgb (nth 3 fields)))
                (cond
                  ((and (null lo) hi) (setq value (list (car fields) -1e99 hi rgb 'UNDER)))
                  ((and lo (null hi)) (setq value (list (car fields) lo 1e99 rgb 'OVER)))
                  ((and lo hi (< lo hi)) (setq value (list (car fields) lo hi rgb)))
                  (T (ccn:fail "Limites de escala XYZ invalidos.")))
                (setq classes (cons value classes)))))))
      (reverse classes))))
(defun ccn:selection-lot (selection / i lot current same)
  (setq i 0 lot nil same T)
  (repeat (sslength selection)
    (setq current (ccn:entity-lot (ssname selection (float i))))
    (if (not current) (setq same nil)
      (if (not lot) (setq lot current) (if (/= lot current) (setq same nil))))
    (setq i (1+ i)))
  (if same lot nil))
(defun ccn:reference-analyze (selection cfg / i en z stat invalid)
  ;; Una capa bloqueada puede definir el rango, aunque no se modifique su color.
  (setq i 0 stat (ccn:empty-stat) invalid 0)
  (repeat (sslength selection)
    (setq en (ssname selection (float i)) z (ccn:elevation en cfg))
    (if z (setq stat (ccn:stat-add stat (list 0.0 0.0 z))) (setq invalid (1+ invalid)))
    (setq i (1+ i)))
  (list (cons 'eligible stat) (cons 'invalid invalid) '(locked . 0)))
(defun ccn:scale-stats (classes / stat info)
  (setq stat (ccn:empty-stat))
  (foreach info classes
    (if (not (ccn:tail-kind info))
      (setq stat (ccn:stat-add stat (list 0.0 0.0 (nth 1 info)))
            stat (ccn:stat-add stat (list 0.0 0.0 (nth 2 info))))))
  (list (cons 'eligible stat) '(invalid . 0) '(locked . 0)))
(defun ccn:choose-reference (cfg / option chosen lot en result)
  (setq *ccn:refss* nil *ccn:shared* nil *ccn:sharedpalette* nil *ccn:refname* "" *ccn:refkind* nil)
  (initget "Puntos Curvas XYZ")
  (setq option (getkword "\nBase para la escala de colores [Puntos/Curvas/XYZ] <Puntos>: "))
  (if (null option) (setq option "Puntos"))
  (setq *ccn:refkind* option)
  (if (= option "XYZ")
    (progn
      (setq chosen (entsel "\nSeleccione un punto o una simbologia del lote XYZ-Tools: "))
      (if chosen
        (progn
          (setq lot (ccn:entity-lot (car chosen)))
          (if (not lot) (ccn:fail "El objeto no pertenece a un lote XYZ-Tools."))
          (setq *ccn:shared* (ccn:xyz-scale lot))
          (if (not *ccn:shared*) (ccn:fail "El lote no tiene escala registrada. Use Puntos o Curvas."))
          (setq *ccn:refname* (strcat "Escala XYZ exacta: " lot) result T))))
    (progn
      (princ (if (= option "Puntos") "\nSeleccione puntos para DEFINIR el rango: " "\nSeleccione curvas para DEFINIR el rango: "))
      (setq *ccn:refss* (ssget (if (= option "Puntos") '((0 . "POINT")) '((0 . "LWPOLYLINE,POLYLINE")))))
      (if *ccn:refss*
        (progn
          (if (and (= option "Puntos") (setq lot (ccn:selection-lot *ccn:refss*)))
            (setq *ccn:shared* (ccn:xyz-scale lot)))
          (setq *ccn:refname* (if *ccn:shared* (strcat "Escala XYZ exacta: " lot) (strcat "Rango definido por " option)))
          (setq result T)))))
  result)
(defun ccn:choose-target (/ option)
  (initget "Todo Curvas CurvasEtiquetas Etiquetas")
  (setq option (getkword "\nObjetos a colorear [Todo/Curvas/CurvasEtiquetas/Etiquetas] <Todo>: "))
  (if (null option) (setq option "Todo"))
  (princ "\nSeleccione AHORA los objetos a colorear (pueden ser distintos de la referencia): ")
  (ssget (cond ((= option "Curvas") '((0 . "LWPOLYLINE,POLYLINE")))
               ((= option "Etiquetas") '((0 . "TEXT,MTEXT")))
               ((= option "CurvasEtiquetas") '((0 . "LWPOLYLINE,POLYLINE,TEXT,MTEXT")))
               (T '((0 . "LWPOLYLINE,POLYLINE,POINT,TEXT,MTEXT"))))))
(defun ccn:reference-stats (cfg)
  (if *ccn:shared* (ccn:scale-stats *ccn:shared*) (ccn:reference-analyze *ccn:refss* cfg)))

(defun ccn:get (key cfg) (cdr (assoc key cfg)))

(defun ccn:put (key val cfg / a)
  (if (setq a (assoc key cfg)) (subst (cons key val) a cfg)
    (cons (cons key val) cfg)))

(defun ccn:trim (s) (vl-string-trim (strcat " " (chr 9) (chr 13) (chr 10)) s))

(defun ccn:fail (s) (setq *ccn:failure* (strcat "IXYZ: " s)) (exit))

(defun ccn:try (fn args) (setq *ccn:failure* nil) (vl-catch-all-apply fn args))

(defun ccn:errmsg (err) (if *ccn:failure* *ccn:failure* (vl-catch-all-error-message err)))

(defun ccn:nstr (v / old out)
  (setq old (getvar "DIMZIN"))
  (setvar "DIMZIN" 0)
  (setq out (rtos v 2 8))
  (setvar "DIMZIN" old)
  out)

(defun ccn:floor (v / n)
  (if (> (abs v) 2147483000.0)
    (setq n (atof (rtos (- v (rem v 1.0)) 2 0)))
    (setq n (fix v)))
  (if (< v n) (- n 1) n))

(defun ccn:hex (rgb / out digits n)
  (setq digits "0123456789ABCDEF" out "#")
  (foreach n rgb
    (setq out (strcat out (substr digits (1+ (/ n 16)) 1)
      (substr digits (1+ (rem n 16)) 1)))) out)

(defun ccn:percent (part total)
  (if (> total 0) (* 100.0 (/ (float part) total)) 0.0))

(defun ccn:tc (rgb) (+ (* (car rgb) 65536) (* (cadr rgb) 256) (caddr rgb)))

(defun ccn:number (s decimal / i n ch digits dot expo expdigits expstart ok norm)
  (setq s (ccn:trim s) i 1 n (strlen s) digits 0 dot nil expo nil
        expdigits 0 expstart nil ok T norm "")
  (if (and (> n 0) (member (substr s 1 1) '("+" "-")))
    (setq norm (substr s 1 1) i 2))
  (while (and ok (<= i n))
    (setq ch (strcase (substr s i 1)))
    (cond
      ((and (>= (ascii ch) 48) (<= (ascii ch) 57))
        (if expo (setq expdigits (1+ expdigits)) (setq digits (1+ digits)))
        (setq norm (strcat norm ch) expstart nil))
      ((and (= ch decimal) (not dot) (not expo))
        (setq dot T norm (strcat norm ".")))
      ((and (member ch '("E" "D")) (not expo) (> digits 0))
        (setq expo T expstart T norm (strcat norm "E")))
      ((and expstart (member ch '("+" "-")))
        (setq norm (strcat norm ch) expstart nil))
      (T (setq ok nil)))
    (setq i (1+ i)))
  (if (and ok (> digits 0) (or (not expo) (> expdigits 0)))
    (distof norm (if expo 1 2)) nil))

(defun ccn:setting-number (s / value)
  ;; OR en AutoLISP devuelve T/nil, nunca el numero encontrado.
  (setq value (ccn:number s "."))
  (if (null value) (setq value (ccn:number s ",")))
  value)

(defun ccn:nice-step (raw / scale choice candidate)
  (if (<= raw 0.0) 0.5
    (progn
      (setq scale 1.0 choice nil)
      (while (> raw (* 5.0 scale)) (setq scale (* scale 10.0)))
      (while (< raw (* 0.5 scale)) (setq scale (/ scale 10.0)))
      (foreach candidate '(0.5 1.0 2.0 2.5 5.0)
        (if (and (null choice) (<= raw (* candidate scale))) (setq choice (* candidate scale))))
      choice)))

(defun ccn:classes (cfg stats lot / s lo hi step count mode i out upper)
  (setq s (ccn:get 'eligible stats) lo (cadr s) hi (caddr s) mode (atoi (ccn:get "classmode" cfg)))
  (setq step
    (if (= mode 0)
      (if (equal lo hi 1e-12) (ccn:get 'v-step cfg)
        (ccn:nice-step (/ (- hi lo) (atoi (ccn:get "classes" cfg)))))
      (ccn:get 'v-step cfg)))
  (if (= mode 2) (setq lo (ccn:get 'v-base cfg) hi (ccn:get 'v-top cfg)))
  ;; Limites completos y multiplos del intervalo, tambien para cotas negativas.
  (setq lo (* step (ccn:floor (+ (/ lo step) 1e-10)))
        hi (* step (ccn:ceil (/ hi step)))
        count (max 1 (ccn:ceil (/ (- hi lo) step))) hi (+ lo (* count step)))
  (if (> count 100) (ccn:fail "Mas de 100 intervalos. Aumente el intervalo o use Automatico redondeado."))
  (setq i 0 out nil)
  (repeat count
    (setq upper (+ lo (* (1+ i) step)))
    (setq out (cons (list (strcat (ccn:get "prefix" cfg) "_" lot "_" (if (< i 9) "0" "") (itoa (1+ i)))
      (+ lo (* i step)) upper (ccn:rgb-ccn (1+ i) count (= (ccn:get "palette" cfg) "1"))) out))
    (setq i (1+ i)))
  (ccn:add-tails (reverse out) cfg lot))

(defun ccn:ceil (v / n) (setq n (fix v)) (if (> v (+ n 1e-10)) (1+ n) n))

(defun ccn:tail-kind (info) (nth 4 info))

(defun ccn:class-label (info)
  (cond
    ((eq (ccn:tail-kind info) 'UNDER) (strcat "<< " (rtos (nth 2 info) 2 2)))
    ((eq (ccn:tail-kind info) 'OVER) (strcat ">> " (rtos (nth 1 info) 2 2)))
    (T (strcat (rtos (nth 1 info) 2 2) " a " (rtos (nth 2 info) 2 2)))))

(defun ccn:class-bound (info index)
  (if (or (and (= index 1) (eq (ccn:tail-kind info) 'UNDER))
          (and (= index 2) (eq (ccn:tail-kind info) 'OVER))) ""
    (ccn:nstr (nth index info))))

(defun ccn:add-tails (classes cfg lot / count index out info low high)
  (setq low (nth 1 (car classes)) high (nth 2 (last classes))
        count (+ (length classes) 2) index 2 out nil)
  (foreach info classes
    (setq out (cons (list (car info) (nth 1 info) (nth 2 info)
      (ccn:rgb-ccn index count (= (ccn:get "palette" cfg) "1"))) out) index (1+ index)))
  (append
    (list (list (strcat (ccn:get "prefix" cfg) "_" lot "_BAJO") -1e99 low
      (ccn:rgb-ccn 1 count (= (ccn:get "palette" cfg) "1")) 'UNDER))
    (reverse out)
    (list (list (strcat (ccn:get "prefix" cfg) "_" lot "_ALTO") high 1e99
      (ccn:rgb-ccn count count (= (ccn:get "palette" cfg) "1")) 'OVER))))

(defun ccn:class-index (z classes outside / i found info kind next)
  (setq i 0 found nil)
  (foreach info classes
    (setq kind (ccn:tail-kind info) next (nth (1+ i) classes))
    (if (null found)
      (cond
        ((eq kind 'UNDER) (if (and (= outside "1") (< z (nth 2 info))) (setq found i)))
        ((eq kind 'OVER) (if (and (= outside "1") (> z (nth 1 info))) (setq found i)))
        ((and (>= z (nth 1 info))
              (or (< z (nth 2 info))
                  (and (or (not next) (eq (ccn:tail-kind next) 'OVER)) (<= z (nth 2 info)))))
          (setq found i))))
    (setq i (1+ i)))
  ;; Compatibilidad para listas antiguas sin clases abiertas.
  (if (and (null found) (= outside "1") (not (eq (ccn:tail-kind (car classes)) 'UNDER)))
    (setq found (if (< z (nth 1 (car classes))) 0 (1- (length classes))))) found)

(defun ccn:rgb-ccn (indice total batimetria / escala ratio pos-frac pos-entera c1 c2 r g b)
  (setq escala '(
      (36 18 0) (100 50 0) (150 0 0) (255 0 0) (255 71 26)
      (255 100 0) (255 150 0) (255 255 0) (10 208 6) (6 147 44)
      (10 214 156) (0 200 255) (0 100 255) (0 0 255) (26 21 157)
      (16 13 99) (11 9 68)))
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
      (setq c1 (nth pos-entera escala)
            c2 (nth (1+ pos-entera) escala)
            pos-frac (- pos-frac pos-entera))
      (setq r (fix (+ (car c1) (* pos-frac (- (car c2) (car c1))))))
      (setq g (fix (+ (cadr c1) (* pos-frac (- (cadr c2) (cadr c1))))))
      (setq b (fix (+ (caddr c1) (* pos-frac (- (caddr c2) (caddr c1))))))
      (list (max 0 (min 255 r)) (max 0 (min 255 g)) (max 0 (min 255 b)))
    )
  )
)

(defun ccn:welford (state z / n mean m2 delta)
  (setq n (1+ (car state)) delta (- z (cadr state)) mean (+ (cadr state) (/ delta n))
        m2 (+ (caddr state) (* delta (- z mean))))
  (list n mean m2))

(defun ccn:stat-add (s p / z)
  (setq z (caddr p))
  (list (ccn:welford (car s) z)
    (if (cadr s) (min (cadr s) z) z) (if (caddr s) (max (caddr s) z) z)
    (if (nth 3 s) (mapcar 'min (nth 3 s) p) p)
    (if (nth 4 s) (mapcar 'max (nth 4 s) p) p)))

(defun ccn:empty-stat () (list '(0 0.0 0.0) nil nil nil nil))

(defun ccn:std (s / w) (setq w (car s))
  (if (> (car w) 1) (sqrt (max 0.0 (/ (caddr w) (1- (car w))))) 0.0))

(defun ccn:csv-quote (s / i out ch)
  (setq i 1 out "\"")
  (while (<= i (strlen s))
    (setq ch (substr s i 1) out (strcat out (if (= ch "\"") "\"\"" ch)) i (1+ i)))
  (strcat out "\""))
(defun ccn:make-dcl (/ f)
  (setq *ccn:dclfile* (vl-filename-mktemp "ccn_" nil ".dcl"))
  (setq *ccn:out* (open *ccn:dclfile* "w"))
  (if (not *ccn:out*) (ccn:fail "No se pudo escribir DCL temporal."))
  (setq f *ccn:out*)
  (write-line "CCN_MAIN : dialog {label=\"CCN 3.1 - Curvas, puntos y textos por elevacion\";:row {:column {:boxed_column {label=\"Colores e intervalos\";:popup_list {key=\"palette\";label=\"Paleta\";width=35;}:popup_list {key=\"classmode\";label=\"Metodo\";width=35;}:row {:edit_box {key=\"classes\";label=\"Clases aprox.\";edit_width=5;}:edit_box {key=\"step\";label=\"Intervalo @ (m)\";edit_width=8;}}:row {:edit_box {key=\"base\";label=\"Desde\";edit_width=10;}:edit_box {key=\"top\";label=\"Hasta\";edit_width=10;}}}}:column {:boxed_column {label=\"Lectura y salida\";:popup_list {key=\"textmode\";label=\"Textos\";width=35;}:edit_box {key=\"tol\";label=\"Tolerancia Z polilinea (m)\";edit_width=8;}:toggle {key=\"legend\";label=\"Crear simbologia despues de colorear\";}:edit_box {key=\"height\";label=\"Altura de texto de simbologia\";edit_width=8;}:toggle {key=\"zoom\";label=\"Zoom a extension antes de simbologia\";}:toggle {key=\"csv\";label=\"Exportar resumen CSV\";}}}}:text {key=\"reference\";width=85;}:text {key=\"stats\";width=85;}:row {:button {key=\"preview\";label=\"Ver intervalos\";}:button {key=\"help\";label=\"Ayuda\";}:button {key=\"accept\";label=\"Colorear\";is_default=true;}:button {key=\"cancel\";label=\"Cancelar\";is_cancel=true;}}}" f)
  (close f) (setq *ccn:out* nil))
(defun ccn:test (name actual expected fuzz)
  (if (if fuzz (equal actual expected fuzz) (equal actual expected))
    (setq *ccn:pass* (1+ *ccn:pass*))
    (progn (setq *ccn:failed* (1+ *ccn:failed*)) (princ (strcat "\nFALLO: " name)))))
(defun c:CCNTEST (/ cfg stat classes data result)
  (setq *ccn:pass* 0 *ccn:failed* 0)
  (ccn:test "Cota cero" (ccn:text-number "0") 0.0 1e-10)
  (ccn:test "Decimal coma" (ccn:text-number "-8,50") -8.5 1e-10)
  (ccn:test "Cota con unidades" (ccn:text-number "COTA: 12.50 msnm") 12.5 1e-10)
  (ccn:test "Prefijo Z" (ccn:text-number "Z = -8,50 m") -8.5 1e-10)
  (ccn:test "Rechazar ID y cota" (ccn:text-number "P12 Z=-8.5") nil nil)
  (ccn:test "Rechazar fecha" (ccn:text-number "05/11/2026") nil nil)
  (ccn:test "MTEXT formato altura" (ccn:text-number "{\\H0.7x;-8.50}") -8.5 1e-10)
  (ccn:test "MTEXT formato color" (ccn:text-number "{\\C3;-8.50}") -8.5 1e-10)
  (ccn:test "Dos cotas ambiguas" (ccn:text-number "-8.5 / -9.0") nil nil)
  (ccn:test "No unir numeros por formato" (ccn:text-number "8\\P5") nil nil)
  (ccn:test "Desviacion segura" (ccn:std (ccn:stat-add (ccn:empty-stat) '(1 2 3))) 0.0 1e-10)
  (ccn:test "Porcentaje" (ccn:percent 1 4) 25.0 1e-10)
  (ccn:test "Intervalo redondeado" (ccn:nice-step 2.123) 2.5 1e-10)
  (setq cfg '(("prefix" . "CCN") ("palette" . "0") ("classmode" . "1") ("classes" . "10") (v-step . 0.5))
        stat (ccn:empty-stat))
  (setq stat (ccn:stat-add stat '(0 0 -25)) stat (ccn:stat-add stat '(0 0 0))
        classes (ccn:classes cfg (list (cons 'eligible stat)) "TEST"))
  (ccn:test "Intervalo normal sin recursion" (ccn:class-label (cadr classes)) "-25.00 a -24.50" nil)
  (ccn:test "Extremo inferior" (ccn:class-label (car classes)) "<< -25.00" nil)
  (ccn:test "Extremo superior" (ccn:class-label (last classes)) ">> 0.00" nil)
  (ccn:test "Inferior estricto" (ccn:class-index -25.01 classes "1") 0 nil)
  (ccn:test "Igual al inferior" (ccn:class-index -25 classes "1") 1 nil)
  (ccn:test "Igual al superior" (ccn:class-index 0 classes "1") (- (length classes) 2) nil)
  (ccn:test "Superior estricto" (ccn:class-index 0.01 classes "1") (1- (length classes)) nil)
  (setq data '((0 . "POINT") (8 . "ORIGINAL") (10 100.0 200.0 -8.5) (62 . 3) (420 . 1234) (430 . "LIBRO") (440 . 77))
        result (ccn:color-data data '(255 0 0)))
  (ccn:test "Conserva geometria" (cdr (assoc 10 result)) '(100.0 200.0 -8.5) 1e-10)
  (ccn:test "Conserva capa" (cdr (assoc 8 result)) "ORIGINAL" nil)
  (ccn:test "Conserva transparencia" (cdr (assoc 440 result)) 77 nil)
  (ccn:test "Elimina color book" (assoc 430 result) nil nil)
  (ccn:test "TrueColor correcto" (cdr (assoc 420 result)) 16711680 nil)
  (ccn:test "LAST devuelve ultimo elemento" (last '(("A" 1) ("B" 2))) '("B" 2) nil)
  (princ (strcat "\nCCNTEST: " (itoa *ccn:pass*) " correctas; " (itoa *ccn:failed*) " fallidas. Sin cambios en dibujo.")) (princ))

(princ "\nCCN 3.1.1 cargado. CCN / CCNT | Ayuda CCNAYUDA | Pruebas CCNTEST")
(princ)
