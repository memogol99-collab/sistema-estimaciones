;;; MemoPRO 3.1.0 - archivo generado por construir_bundle.py
;;; Origen: @fuente/MEMO_Areas.lsp

;;; =====================================================================
;;;  MEMO_Areas.lsp - Herramientas de áreas de MemoPRO
;;;
;;;   MAREA  Cuadro de diálogo: qué hacer y cómo escribir el área
;;;   HA     Hatch o área cerrada -> su texto, uno tras otro
;;;   AC     Tocar dentro de contornos y sumar por tipo (AC=, ACA=, AB=...)
;;;   AS     Área entre la línea de terreno y la de corte (cualquier N)
;;;   CAS    Figuras con fórmula para generadores (triángulo, trapecio...)
;;;   (AH, EA y HAEA-EXPORT están en EA_ExportarEstArea.lsp)
;;;
;;;  Reemplaza a: HA2 HAPREF HARESET HAINFO AM2 AH2 AHINFO QA EA-HA HAEA
;;;  y corrige:
;;;   - AC encendía TODAS las capas al terminar; ahora deja cada capa como
;;;     estaba (también si se cancela) y descuenta las islas.
;;;   - CAS en triángulos mostraba como "base x altura" los dos lados más
;;;     cortos; en cuadriláteros suponía qué lados eran paralelos; los
;;;     círculos salían como "RECTANGULO".
;;;   - AS sólo servía con 3 vértices y creaba el estilo con un comando
;;;     que abre cuadro de diálogo.
;;; =====================================================================
(vl-load-com)

;;; ---------------------------------------------------------------------
;;; Utilidades
;;; ---------------------------------------------------------------------
(defun ar:num (clave defecto / v)
  (setq v (distof (memo:cfg-txt clave "") 2))
  (if v v defecto))

(defun ar:valor (area) (memo:fmt-dec area (memo:decimales-area)))

(defun ar:es-area-p (ent / d tipo)
  (setq d (entget ent) tipo (cdr (assoc 0 d)))
  (or (member tipo '("HATCH" "CIRCLE" "ELLIPSE" "REGION"))
      (and (member tipo '("LWPOLYLINE" "POLYLINE"))
           (= 1 (logand 1 (cdr (assoc 70 d)))))))

(defun ar:area (ent / r)
  (setq r (vl-catch-all-apply 'vla-get-Area (list (vlax-ename->vla-object ent))))
  (if (and (not (vl-catch-all-error-p r)) (numberp r)) r))

;; entsel que repite si se hace clic en el vacío y devuelve nil con Enter
(defun ar:pedir (msg prueba aviso / r fin)
  (while (not fin)
    (setvar "ERRNO" 0)
    (setq r (entsel msg))
    (cond
      ((and (null r) (= (getvar "ERRNO") 7)))                 ; clic en el vacío
      ((null r) (setq fin T))                                 ; Enter
      ((apply prueba (list (car r))) (setq fin T))
      (T (princ aviso))))
  (if r (car r)))

(defun ar:es-texto-p (ent) (wcmatch (cdr (assoc 0 (entget ent))) "TEXT,MTEXT"))

;; Escribe el área en el texto y, si se pide, lo pasa a la capa del hatch
(defun ar:escribir (tent valor tipo capa / d nuevo)
  (setq d (entget tent)
        nuevo (memo:texto-area (cdr (assoc 1 d)) valor tipo))
  (entmod (subst (cons 1 nuevo) (assoc 1 d) d))
  (if (and capa (memo:si-p "AREA_MOVER_CAPA" "NO") (tblsearch "LAYER" capa))
    (progn (setq d (entget tent)) (entmod (subst (cons 8 capa) (assoc 8 d) d))))
  (entupd tent)
  nuevo)

(defun ar:capa (nombre color)
  (if (not (tblsearch "LAYER" nombre))
    (entmake (list '(0 . "LAYER") '(100 . "AcDbSymbolTableRecord") '(100 . "AcDbLayerTableRecord")
                   (cons 2 nombre) '(70 . 0) (cons 62 color) '(6 . "Continuous")))))

(defun ar:texto (pt txt alt capa estilo color / l)
  (setq l (list '(0 . "TEXT") (cons 8 capa) (cons 10 pt) (cons 40 alt) (cons 1 txt)))
  (if estilo (setq l (append l (list (cons 7 estilo)))))
  (if color (setq l (append l (list (cons 62 color)))))
  (entmake l))

(defun ar:mtexto (pt txt alt capa color)
  (entmake (list '(0 . "MTEXT") '(100 . "AcDbEntity") '(100 . "AcDbMText")
                 (cons 10 pt) (cons 1 txt) (cons 40 alt) (cons 7 (getvar "TEXTSTYLE"))
                 (cons 62 color) (cons 8 capa) '(71 . 5) '(50 . 0.0))))

;;; ---------------------------------------------------------------------
;;; HA - un hatch (o área cerrada) a su texto, uno tras otro
;;; ---------------------------------------------------------------------
(defun c:HA (/ e tx a capa n)
  (princ (strcat "\n=== HA - Área a texto  (escritura: " (memo:cfg-txt "AREA_ESCRITURA" "NUMERO")
                 ", decimales: " (itoa (memo:decimales-area)) "; se cambia en MAREA) ==="))
  (memo:cargar-patrones)
  (setq n 0)
  (while (setq e (ar:pedir "\nSelecciona HATCH o área cerrada <Enter = terminar>: "
                           'ar:es-area-p "\n  No es un hatch ni un área cerrada."))
    (if (setq a (ar:area e))
      (progn
        (setq capa (cdr (assoc 8 (entget e))))
        (princ (strcat "  Área = " (ar:valor a)))
        (if (setq tx (ar:pedir "\nSelecciona el TEXTO a actualizar: " 'ar:es-texto-p "\n  No es un texto."))
          (progn
            (princ (strcat "\n  -> " (ar:escribir tx (ar:valor a) (memo:tipo-de capa) capa)))
            (setq n (1+ n)))))
      (princ "\n  No se pudo obtener el área de ese objeto.")))
  (princ (strcat "\n" (itoa n) " texto(s) actualizado(s)."))
  (princ))

;;; ---------------------------------------------------------------------
;;; AC - tocar dentro de contornos y sumar por tipo
;;; Pasos: (TIPO "PATRON=" ((capa encender?) ...) antes del paso)
;;; ---------------------------------------------------------------------
(setq ar:*ac-capas-iniciales* '("XGRID" "APV-Cotas" "XGRIDT" "APV-Textosdatos" "XFG"))
(setq ar:*ac-pasos*
  '(("CORTE"      "AC="  nil)
    ("CARPETA"    "ACA=" (("XFG" T) ("AC" nil) ("XEG" nil)))
    ("BASE"       "AB="  nil)
    ("SUBRASANTE" "ASR=" nil)
    ("TERRAPLEN"  "AT="  (("XEG" T) ("AC" T)))))

(defun ar:capa-obj (nombre / r)
  (setq r (vl-catch-all-apply 'vla-Item (list (vla-get-Layers (memo:doc)) nombre)))
  (if (not (vl-catch-all-error-p r)) r))

(defun ar:poner-capa (nombre encendida / o)
  (if (setq o (ar:capa-obj nombre))
    (vl-catch-all-apply 'vla-put-LayerOn (list o (if encendida :vlax-true :vlax-false)))))

;; Área tocando un punto interior: contorno exterior menos islas
(defun ar:area-punto (pt / ultima e nuevas areas total)
  (setq ultima (entlast))
  (command "_.-BOUNDARY" "_non" pt "")
  (setq e (if ultima (entnext ultima) (entnext)))
  (while e (setq nuevas (cons e nuevas) e (entnext e)))
  (foreach x nuevas (if (setq total (ar:area x)) (setq areas (cons total areas))))
  (foreach x nuevas (entdel x))
  (if areas
    (- (* 2 (apply 'max areas)) (apply '+ areas))))    ; mayor - suma de islas

;; Número que sigue al patrón: "AC=12.50" -> reemplaza 12.50
(defun ar:reemplazar-tras-patron (txt patron valor / pos r)
  (if (setq pos (vl-string-search (strcase patron) (strcase txt)))
    (if (setq r (memo:numero-tras txt (+ pos (strlen patron) 1)))
      (strcat (substr txt 1 (1- (car r))) valor (substr txt (1+ (cadr r))))
      (strcat (substr txt 1 (+ pos (strlen patron))) valor (substr txt (+ pos (strlen patron) 1))))
    txt))

(defun ar:texto-con-patron (pt patron / ss i e d txt dist mejor dmin)
  (setq ss (ssget "_X" '((0 . "TEXT,MTEXT"))) i 0 dmin 1e99)
  (if ss
    (repeat (sslength ss)
      (setq e (ssname ss i) d (entget e) txt (cdr (assoc 1 d)) i (1+ i))
      (if (and txt (vl-string-search (strcase patron) (strcase (memo:limpiar-mtext txt))))
        (if (< (setq dist (distance (list (car pt) (cadr pt)) (list (cadr (assoc 10 d)) (caddr (assoc 10 d))))) dmin)
          (setq dmin dist mejor e)))))
  mejor)

(defun c:AC (/ *error* cad pcad estado paso total pt a tx d nuevo resumen nombre)
  (setq estado (mapcar '(lambda (n / o) (if (setq o (ar:capa-obj n)) (list n (vla-get-LayerOn o))))
                       (append ar:*ac-capas-iniciales* '("AC" "XEG"))))
  (defun *error* (msg)
    (foreach s estado (if s (vl-catch-all-apply 'vla-put-LayerOn (list (ar:capa-obj (car s)) (cadr s)))))
    (if (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*EXIT*,*BREAK*"))
      (princ (strcat "\nError en AC: " msg)))
    (princ "\nCapas restauradas como estaban.")
    (princ))
  (princ "\n=== AC - Áreas por contorno ===")
  (if (setq cad (ar:pedir "\nSelecciona el texto del CADENAMIENTO: " 'ar:es-texto-p "\n  No es un texto."))
    (progn
      (setq d (entget cad) pcad (cdr (assoc 10 d)))
      (princ (strcat "\nCadenamiento: " (memo:limpiar-mtext (cdr (assoc 1 d)))))
      (foreach n ar:*ac-capas-iniciales* (ar:poner-capa n nil))
      (foreach paso ar:*ac-pasos*
        (foreach c (caddr paso) (ar:poner-capa (car c) (cadr c)))
        (setq nombre (car paso) total 0.0)
        (princ (strcat "\n--- " nombre " (" (cadr paso) ") ---"))
        (while (setq pt (getpoint (strcat "\nToca DENTRO de un área de " nombre " <Enter = terminar " nombre ">: ")))
          (if (setq a (ar:area-punto pt))
            (progn (setq total (+ total a))
                   (princ (strcat "  área " (ar:valor a) "   acumulado " (ar:valor total))))
            (princ "  No se pudo formar el contorno; toca otra vez.")))
        (setq resumen (cons (list nombre total) resumen))
        (if (> total 0.0)
          (if (setq tx (ar:texto-con-patron pcad (cadr paso)))
            (progn
              (setq d (entget tx)
                    nuevo (ar:reemplazar-tras-patron (cdr (assoc 1 d)) (cadr paso) (ar:valor total)))
              (entmod (subst (cons 1 nuevo) (assoc 1 d) d))
              (entupd tx)
              (princ (strcat "\n  Texto actualizado: " nuevo)))
            (princ (strcat "\n  No hay texto con '" (cadr paso) "' en el dibujo.")))))
      ;; capas como estaban al empezar
      (foreach s estado (if s (vla-put-LayerOn (ar:capa-obj (car s)) (cadr s))))
      (princ "\n--- RESUMEN ---")
      (foreach r (reverse resumen) (princ (strcat "\n  " (car r) ": " (ar:valor (cadr r)) " m2")))))
  (princ))

;;; ---------------------------------------------------------------------
;;; AS - área entre la línea de terreno y la de corte
;;; ---------------------------------------------------------------------
(defun ar:verts (ent / d l)
  (setq d (entget ent))
  (foreach g d (if (= (car g) 10) (setq l (cons (list (cadr g) (caddr g)) l))))
  (vl-sort l '(lambda (a b) (< (car a) (car b)))))

;; y de la polilínea (ordenada por x) en x, interpolando
(defun ar:y-en (verts x / a b res)
  (setq a (car verts))
  (foreach b (cdr verts)
    (if (and (null res) (<= (car a) x (car b)))
      (setq res (if (equal (car a) (car b) 1e-9)
                  (cadr a)
                  (+ (cadr a) (* (- (cadr b) (cadr a)) (/ (- x (car a)) (- (car b) (car a))))))))
    (setq a b))
  res)

;; Trapecios entre dos polilíneas: ((x1 x2 h1 h2 area) ...)
(defun ar:trapecios (vt vc / x0 x1 xs res i h1 h2)
  (setq x0 (max (car (car vt)) (car (car vc)))
        x1 (min (car (last vt)) (car (last vc))))
  (foreach v (append vt vc)
    (if (and (>= (car v) (- x0 1e-9)) (<= (car v) (+ x1 1e-9)) (not (vl-member-if '(lambda (q) (equal q (car v) 1e-6)) xs)))
      (setq xs (cons (car v) xs))))
  (setq xs (vl-sort xs '<))
  (setq i 0)
  (while (< i (1- (length xs)))
    (setq h1 (- (ar:y-en vt (nth i xs)) (ar:y-en vc (nth i xs)))
          h2 (- (ar:y-en vt (nth (1+ i) xs)) (ar:y-en vc (nth (1+ i) xs))))
    (setq res (cons (list (nth i xs) (nth (1+ i) xs) h1 h2
                          (* (- (nth (1+ i) xs) (nth i xs)) (/ (+ h1 h2) 2.0))) res)
          i (1+ i)))
  (reverse res))

(defun c:AS (/ et ec vt vc trs org ini k total f)
  (princ "\n=== AS - Área entre terreno y corte ===")
  (if (and (setq et (ar:pedir "\nSelecciona la línea de TERRENO: " '(lambda (e) (wcmatch (cdr (assoc 0 (entget e))) "LWPOLYLINE,POLYLINE")) "\n  Debe ser una polilínea."))
           (setq ec (ar:pedir "\nSelecciona la línea de CORTE: " '(lambda (e) (wcmatch (cdr (assoc 0 (entget e))) "LWPOLYLINE,POLYLINE")) "\n  Debe ser una polilínea.")))
    (progn
      (setq vt (ar:verts et) vc (ar:verts ec) trs (ar:trapecios vt vc))
      (if (not trs)
        (princ "\nLas dos líneas no se traslapan en X.")
        (progn
          (ar:capa "Area de Secciones" 7)
          (if (not (tblsearch "STYLE" "text-Secc"))
            (entmake '((0 . "STYLE") (100 . "AcDbSymbolTableRecord") (100 . "AcDbTextStyleTableRecord")
                       (2 . "text-Secc") (70 . 0) (40 . 0.15) (41 . 0.85) (50 . 0.0) (71 . 0) (42 . 0.15)
                       (3 . "romans.shx") (4 . ""))))
          (setq org (car vc) ini (polar (list (car org) (cadr org)) (- (/ pi 6)) 1.2) k 1 total 0.0
                f (lambda (v) (memo:fmt-dec v 2)))
          (foreach tr trs
            (ar:texto ini (strcat "A" (itoa k) "=(" (f (caddr tr)) "+" (f (cadddr tr)) ")/2x" (f (- (cadr tr) (car tr))))
                      0.15 "Area de Secciones" "text-Secc" nil)
            (ar:texto (polar ini (- (/ pi 2)) 0.22)
                      (strcat "A" (itoa k) "=" (f (/ (+ (caddr tr) (cadddr tr)) 2.0)) "x" (f (- (cadr tr) (car tr))))
                      0.15 "Area de Secciones" "text-Secc" nil)
            (ar:texto (polar ini (- (/ pi 2)) 0.44) (strcat "A" (itoa k) "=" (f (nth 4 tr)))
                      0.15 "Area de Secciones" "text-Secc" nil)
            (setq total (+ total (nth 4 tr)) ini (polar ini 0 3.5) k (1+ k)))
          (setq ini (polar (polar ini pi 3.5) (- (/ pi 2)) 0.8))
          (ar:texto ini (strcat "At=A1+...+A" (itoa (1- k))) 0.15 "Area de Secciones" "text-Secc" nil)
          (ar:texto (polar ini (- (/ pi 2)) 0.22) (strcat "At=" (f total) " m2") 0.15 "Area de Secciones" "text-Secc" nil)
          (princ (strcat "\n" (itoa (1- k)) " trapecio(s), área total = " (f total) " m2"))))))
  (princ))

;;; ---------------------------------------------------------------------
;;; CAS - figuras con fórmula para generadores
;;; ---------------------------------------------------------------------
(defun ar:cross (a b c d)   ; producto cruz de (b-a) x (d-c)
  (- (* (- (car b) (car a)) (- (cadr d) (cadr c))) (* (- (cadr b) (cadr a)) (- (car d) (car c)))))

(defun ar:paralelos-p (a b c d)
  (< (abs (ar:cross a b c d)) (* 0.005 (distance a b) (distance c d))))

;; Pie de la perpendicular de p sobre la recta a-b
(defun ar:pie (p a b / dx dy t2)
  (setq dx (- (car b) (car a)) dy (- (cadr b) (cadr a))
        t2 (/ (+ (* (- (car p) (car a)) dx) (* (- (cadr p) (cadr a)) dy)) (+ (* dx dx) (* dy dy))))
  (list (+ (car a) (* t2 dx)) (+ (cadr a) (* t2 dy))))

(defun ar:medio (a b) (list (/ (+ (car a) (car b)) 2.0) (/ (+ (cadr a) (cadr b)) 2.0)))

;; Analiza una figura. pts = vértices (x y); area = área real.
;; Devuelve (tipo texto capa color linea-altura) ; linea = (p1 p2 h) o nil
(defun ar:analizar (pts area dec / f n l1 l2 l3 b h p1 p2 p3 p4 mayor menor mb pie)
  (setq f (lambda (v) (memo:fmt-dec v dec)) n (length pts))
  (cond
    ((= n 3)
     (setq l1 (distance (nth 0 pts) (nth 1 pts)) l2 (distance (nth 1 pts) (nth 2 pts))
           l3 (distance (nth 2 pts) (nth 0 pts)) b (max l1 l2 l3) h (/ (* 2.0 area) b))
     (list "TRIANGULO" (strcat "TRIANGULO\\P=(b*h)/2\\P=(" (f b) "*" (f h) ")/2\\P=" (f area) " m2")
           "TRIANGULOS" 1 nil))
    ((= n 4)
     (setq p1 (nth 0 pts) p2 (nth 1 pts) p3 (nth 2 pts) p4 (nth 3 pts))
     (cond
       ;; RECTÁNGULO: lados paralelos dos a dos y ángulo recto
       ((and (ar:paralelos-p p1 p2 p4 p3) (ar:paralelos-p p2 p3 p1 p4)
             (< (abs (+ (* (- (car p2) (car p1)) (- (car p3) (car p2))) (* (- (cadr p2) (cadr p1)) (- (cadr p3) (cadr p2)))))
                (* 0.005 (distance p1 p2) (distance p2 p3))))
        (setq l1 (distance p1 p2) l2 (distance p2 p3))
        (list "RECTANGULO" (strcat "RECTANGULO\\P=b*h\\P=" (f (max l1 l2)) "*" (f (min l1 l2)) "\\P=" (f area) " m2")
              "RECTANGULOS" 5 nil))
       ;; TRAPECIO: un par de lados paralelos (cualquiera de los dos pares)
       ((or (ar:paralelos-p p1 p2 p4 p3) (ar:paralelos-p p2 p3 p1 p4))
        (if (not (ar:paralelos-p p1 p2 p4 p3))
          (setq pts (list p2 p3 p4 p1) p1 (nth 0 pts) p2 (nth 1 pts) p3 (nth 2 pts) p4 (nth 3 pts)))
        ;; ahora p1-p2 y p3-p4 son paralelos.
        ;; OJO: AutoLISP no distingue mayúsculas: "B" y "b" son la MISMA variable
        ;; (ese error tenía el CAS original), por eso "mayor" y "menor".
        (setq l1 (distance p1 p2) l3 (distance p3 p4) mayor (max l1 l3) menor (min l1 l3)
              h (/ (* 2.0 area) (+ mayor menor)))
        ;; línea de altura: del medio del lado menor, perpendicular al mayor
        (if (>= l1 l3)
          (setq mb (ar:medio p3 p4) pie (ar:pie mb p1 p2))
          (setq mb (ar:medio p1 p2) pie (ar:pie mb p3 p4)))
        (list "TRAPECIO" (strcat "TRAPECIO\\P=(B+b)*h/2\\P=(" (f mayor) "+" (f menor) ")*" (f h) "/2\\P=" (f area) " m2")
              "TRAPECIOS" 3 (list mb pie h)))
       (T (list "CUADRILATERO" (strcat "CUADRILATERO\\P=" (f area) " m2") "OTRAS-FIGURAS" 7 nil))))
    ((= n 5) (list "PENTAGONO" (strcat "PENTAGONO\\P=" (f area) " m2") "PENTAGONOS" 5 nil))
    ((= n 6) (list "HEXAGONO" (strcat "HEXAGONO\\P=" (f area) " m2") "HEXAGONOS" 6 nil))
    (T (list (strcat "POLIGONO-" (itoa n)) (strcat "POLIGONO DE " (itoa n) " LADOS\\P=" (f area) " m2") "OTRAS-FIGURAS" 7 nil))))

(defun ar:cas-figura (ent dec / d tipo pts area r a b info)
  (setq d (entget ent) tipo (cdr (assoc 0 d)) area (ar:area ent))
  (cond
    ((null area) nil)
    ((= tipo "CIRCLE")
     (setq r (cdr (assoc 40 d)))
     (list "CIRCULO" (strcat "CIRCULO\\P=PI*r²\\P=PI*" (memo:fmt-dec r dec) "²\\P=" (memo:fmt-dec area dec) " m2")
           "CIRCULOS" 2 nil (cdr (assoc 10 d))))
    ((= tipo "ELLIPSE")
     (setq a (distance '(0 0) (cdr (assoc 11 d))) b (* a (cdr (assoc 40 d))))
     (list "ELIPSE" (strcat "ELIPSE\\P=PI*a*b\\P=PI*" (memo:fmt-dec a dec) "*" (memo:fmt-dec b dec) "\\P=" (memo:fmt-dec area dec) " m2")
           "OTRAS-FIGURAS" 7 nil (cdr (assoc 10 d))))
    ((and (= tipo "LWPOLYLINE") (vl-some '(lambda (g) (and (= (car g) 42) (/= (cdr g) 0.0))) d))
     (setq pts (mapcar '(lambda (g) (list (cadr g) (caddr g))) (vl-remove-if-not '(lambda (g) (= (car g) 10)) d)))
     (list "CON ARCOS" (strcat "FIGURA CON ARCOS\\P=" (memo:fmt-dec area dec) " m2") "OTRAS-FIGURAS" 7 nil (ar:centro pts)))
    (T
     (setq pts (ar:verts-orden ent))
     ;; quitar vértice final repetido
     (if (and (> (length pts) 2) (equal (car pts) (last pts) 1e-6)) (setq pts (reverse (cdr (reverse pts)))))
     (setq info (ar:analizar pts area dec))
     (append info (list (ar:centro pts))))))

(defun ar:verts-orden (ent / d e l)
  (setq d (entget ent))
  (if (= (cdr (assoc 0 d)) "POLYLINE")
    (progn
      (setq e (entnext ent))
      (while (and e (= (cdr (assoc 0 (entget e))) "VERTEX"))
        (setq l (cons (list (cadr (assoc 10 (entget e))) (caddr (assoc 10 (entget e)))) l) e (entnext e))))
    (foreach g d (if (= (car g) 10) (setq l (cons (list (cadr g) (caddr g)) l)))))
  (reverse l))

(defun ar:centro (pts / x y)
  (setq x 0.0 y 0.0)
  (foreach p pts (setq x (+ x (car p)) y (+ y (cadr p))))
  (list (/ x (length pts)) (/ y (length pts)) 0.0))

(defun c:CAS (/ alt dec e info total pt n lin)
  (princ "\n=== CAS - Figuras con fórmula ===")
  (setq alt (ar:num "AREA_ALTURA_TEXTO" 0.15) dec (memo:decimales-area))
  (initget 6)
  (if (setq pt (getreal (strcat "\nAltura del texto <" (memo:fmt-dec alt 2) ">: ")))
    (progn (setq alt pt) (memo:cfg-set "AREA_ALTURA_TEXTO" (rtos alt 2 3))))
  (foreach c '(("TRIANGULOS" 1) ("TRAPECIOS" 3) ("RECTANGULOS" 5) ("PENTAGONOS" 5) ("HEXAGONOS" 6)
               ("CIRCULOS" 2) ("OTRAS-FIGURAS" 7) ("TEXTOS-AREAS" 4) ("LINEAS-ALTURA" 2))
    (ar:capa (car c) (cadr c)))
  (setq total 0.0 n 0)
  (while (setq e (ar:pedir "\nSelecciona un área cerrada <Enter = terminar>: " 'ar:es-area-p "\n  No es un área cerrada."))
    (if (setq info (ar:cas-figura e dec))
      (progn
        (ar:mtexto (nth 5 info) (nth 1 info) alt (nth 2 info) (nth 3 info))
        (if (setq lin (nth 4 info))
          (progn
            (if (not (tblsearch "LTYPE" "DASHED")) (vl-catch-all-apply 'vla-Load (list (vla-get-Linetypes (memo:doc)) "DASHED" "acad.lin")))
            (entmake (list '(0 . "LINE") '(8 . "LINEAS-ALTURA") '(62 . 2)
                           (if (tblsearch "LTYPE" "DASHED") '(6 . "DASHED") '(6 . "BYLAYER"))
                           (cons 10 (car lin)) (cons 11 (cadr lin))))
            (ar:texto (ar:medio (car lin) (cadr lin)) (strcat "h=" (memo:fmt-dec (caddr lin) dec)) alt "LINEAS-ALTURA" nil 2)))
        (setq total (+ total (ar:area e)) n (1+ n))
        (princ (strcat "  " (car info) ": " (memo:fmt-dec (ar:area e) dec) " m2")))
      (princ "  No se pudo obtener el área.")))
  (if (and (> n 0) (setq pt (getpoint "\nPunto para el ÁREA TOTAL <Enter = no poner>: ")))
    (ar:mtexto pt (strcat "AREA TOTAL = " (memo:fmt-dec total dec) " m2") (* alt 1.5) "TEXTOS-AREAS" 2))
  (princ (strcat "\n" (itoa n) " figura(s), total " (memo:fmt-dec total dec) " m2"))
  (princ))

;;; ---------------------------------------------------------------------
;;; MAREA - cuadro de diálogo de áreas
;;; ---------------------------------------------------------------------
(setq ar:*acciones*
  '(("HA"  "Un hatch o área cerrada -> su texto (HA)")
    ("AH"  "Varios hatches -> su texto, automático (AH)")
    ("AC"  "Tocar dentro de contornos y sumar por tipo (AC)")
    ("AS"  "Área entre terreno y corte, 2 polilíneas (AS)")
    ("CAS" "Figuras con fórmula para generadores (CAS)")
    ("EA"  "Secciones: etiquetar y exportar a Excel (EA)")))

(defun ar:dcl (/ ruta f)
  (setq ruta (vl-filename-mktemp "memo_areas" nil ".dcl") f (open ruta "w"))
  (foreach l
    (append
      (list "memo_areas : dialog {" "  label = \"Áreas - MemoPRO\";"
            "  : boxed_radio_column { label = \"¿Qué quieres hacer?\"; key = \"accion\";")
      (mapcar '(lambda (a) (strcat "    : radio_button { key = \"" (car a) "\"; label = \"" (cadr a) "\"; }")) ar:*acciones*)
      (list "  }"
            "  : boxed_column { label = \"Cómo escribir el área en el texto\";"
            "    : radio_row { key = \"escritura\";"
            "      : radio_button { key = \"NUMERO\"; label = \"Cambiar sólo el número\"; }"
            "      : radio_button { key = \"COMPLETO\"; label = \"Escribir el texto completo\"; } }"
            "    : row {"
            "      : edit_box { key = \"prefijo\"; label = \"Prefijo:\"; edit_width = 12; }"
            "      : edit_box { key = \"sufijo\"; label = \"Sufijo:\"; edit_width = 6; } }"
            "    : toggle { key = \"preftipo\"; label = \"Prefijo según el tipo de la capa (AREA DE CORTE=)\"; }"
            "    : toggle { key = \"mayus\"; label = \"Texto en MAYÚSCULAS\"; }"
            "    : row {"
            "      : edit_box { key = \"decimales\"; label = \"Decimales:\"; edit_width = 3; }"
            "      : edit_box { key = \"altura\"; label = \"Altura de texto CAS:\"; edit_width = 6; } }"
            "    : toggle { key = \"movercapa\"; label = \"Pasar el texto a la capa del hatch\"; }"
            "  }"
            "  : text { key = \"ejemplo\"; width = 55; }"
            "  ok_cancel;"
            "}"))
    (write-line l f))
  (close f)
  ruta)

;; Valores actuales del cuadro -> configuración temporal para el ejemplo
(defun ar:dcl-ejemplo (/ pref suf txt)
  (if (= (get_tile "escritura") "NUMERO")
    (setq txt "AREA DE CORTE=12.50 M2  ->  AREA DE CORTE=13.10 M2")
    (progn
      (setq pref (if (= (get_tile "preftipo") "1") "AREA DE CORTE=" (get_tile "prefijo"))
            suf (get_tile "sufijo")
            txt (strcat pref "13.10" suf))
      (if (= (get_tile "mayus") "1") (setq txt (strcase txt)))))
  (set_tile "ejemplo" (strcat "Ejemplo:  " txt))
  (foreach k '("prefijo" "sufijo" "preftipo" "mayus")
    (mode_tile k (if (= (get_tile "escritura") "COMPLETO") 0 1))))

(defun c:MAREA (/ ruta id res acc datos)
  (setq ruta (ar:dcl) id (load_dialog ruta))
  (if (not (new_dialog "memo_areas" id))
    (princ "\nNo se pudo abrir el cuadro de diálogo.")
    (progn
      (setq acc (memo:cfg-txt "AREA_ULTIMO" "HA"))
      (if (not (assoc acc ar:*acciones*)) (setq acc "HA"))
      (set_tile acc "1")
      (set_tile (strcase (memo:cfg-txt "AREA_ESCRITURA" "NUMERO")) "1")
      (set_tile "prefijo" (memo:cfg-txt "AREA_PREFIJO" "A="))
      (set_tile "sufijo" (memo:sufijo-area))
      (set_tile "preftipo" (if (memo:si-p "AREA_PREF_TIPO" "SI") "1" "0"))
      (set_tile "mayus" (if (memo:si-p "AREA_MAYUSCULAS" "NO") "1" "0"))
      (set_tile "decimales" (itoa (memo:decimales-area)))
      (set_tile "altura" (memo:fmt-dec (ar:num "AREA_ALTURA_TEXTO" 0.15) 2))
      (set_tile "movercapa" (if (memo:si-p "AREA_MOVER_CAPA" "NO") "1" "0"))
      (ar:dcl-ejemplo)
      (foreach k '("escritura" "prefijo" "sufijo" "preftipo" "mayus")
        (action_tile k "(ar:dcl-ejemplo)"))
      (action_tile "accept"
        "(setq datos (list (get_tile \"accion\") (get_tile \"escritura\") (get_tile \"prefijo\")
                           (get_tile \"sufijo\") (get_tile \"preftipo\") (get_tile \"mayus\")
                           (get_tile \"decimales\") (get_tile \"altura\") (get_tile \"movercapa\")))
         (done_dialog 1)")
      (setq res (start_dialog))))
  (unload_dialog id)
  (vl-file-delete ruta)
  (if (and (= res 1) datos)
    (progn
      (memo:cfg-set "AREA_ULTIMO" (nth 0 datos))
      (memo:cfg-set "AREA_ESCRITURA" (nth 1 datos))
      (memo:cfg-set "AREA_PREFIJO" (nth 2 datos))
      (memo:cfg-set "AREA_SUFIJO" (if (= (nth 3 datos) "") "NINGUNO" (nth 3 datos)))
      (memo:cfg-set "AREA_PREF_TIPO" (if (= (nth 4 datos) "1") "SI" "NO"))
      (memo:cfg-set "AREA_MAYUSCULAS" (if (= (nth 5 datos) "1") "SI" "NO"))
      (if (distof (nth 6 datos) 2) (memo:cfg-set "AREA_DECIMALES" (itoa (fix (distof (nth 6 datos) 2)))))
      (if (distof (nth 7 datos) 2) (memo:cfg-set "AREA_ALTURA_TEXTO" (nth 7 datos)))
      (memo:cfg-set "AREA_MOVER_CAPA" (if (= (nth 8 datos) "1") "SI" "NO"))
      (memo:llamar (nth 0 datos))))
  (princ))

(princ)
