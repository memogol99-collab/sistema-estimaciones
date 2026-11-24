;;; =====================================================================
;;;  EXR - Exportar baches al GENERADOR DE EXCEL (MemoPRO)
;;;
;;;  Llena la plantilla Formato_Generador_Bacheo.xlsx (carpeta Plantillas
;;;  del menú) con No., LARGO y ANCHO de cada bache; el AREA, las sumas,
;;;  el volumen y los acumulados los calculan las fórmulas de la plantilla.
;;;    - 22 baches por columna, 5 columnas por bloque (110 por bloque).
;;;    - La plantilla trae 6 bloques; si sobran se borran y si faltan se
;;;      copian más al final.
;;;    - El nombre de la calle se escribe en cada bloque usado.
;;;    - Si el espesor (MEMO_CONFIG > BACHEO_ESPESOR) no es 0.10 m, se
;;;      ajustan las fórmulas y el texto "Vol Esp ..cm".
;;;  Si no hay Excel o no se encuentra la plantilla, exporta a CSV como
;;;  antes (ese formato también queda en el comando EXRCSV).
;;; =====================================================================
(setq exr:*plantilla* "Formato_Generador_Bacheo.xlsx")
(setq exr:*paso* 44 exr:*enc* 17 exr:*filas* 22 exr:*grupos* 5 exr:*bloques-plantilla* 6)

(defun exr:buscar-plantilla (/ f)
  (cond
    ((and (= (type memo:raiz) 'STR)
          (setq f (findfile (strcat memo:raiz "/Plantillas/" exr:*plantilla*)))) f)
    ((findfile exr:*plantilla*))
    ((findfile (strcat "Plantillas/" exr:*plantilla*)))))

(defun exr:valor (v)
  (if (= (type v) 'VARIANT) (vlax-variant-value v) v))

(defun exr:celda (ws fila col)
  (exr:valor (vlax-get-property (vlax-get-property ws 'Cells) 'Item fila col)))

(defun exr:poner (ws fila col val / c)
  (setq c (exr:celda ws fila col))
  (vlax-put-property c 'Value2 val)
  (vlax-release-object c))

(defun exr:formula (ws fila col txt / c)
  (setq c (exr:celda ws fila col))
  (vlax-put-property c 'Formula txt)
  (vlax-release-object c))

(defun exr:rango (ws txt) (vlax-get-property ws 'Range txt))

(defun exr:col-letra (n / s r)
  (setq s "")
  (while (> n 0)
    (setq r (rem (1- n) 26) n (/ (1- n) 26) s (strcat (chr (+ 65 r)) s)))
  s)

(defun exr:r2 (x) (/ (fix (+ (* (abs x) 100.0) 0.5)) (if (minusp x) -100.0 100.0)))

;;; Ajusta el número de bloques de la hoja a "n"
(defun exr:ajustar-bloques (ws n / ult k r)
  (setq ult (+ 13 (* exr:*paso* exr:*bloques-plantilla*)))      ; 277
  (cond
    ((< n exr:*bloques-plantilla*)
     (setq r (exr:rango ws (strcat (itoa (+ 14 (* exr:*paso* n))) ":" (itoa ult))))
     (vlax-invoke-method r 'Delete)
     (vlax-release-object r))
    ((> n exr:*bloques-plantilla*)
     (setq k exr:*bloques-plantilla*)
     (while (< k n)
       ;; copia el último bloque (renglones 234-277) al final
       (vlax-invoke-method
         (exr:rango ws (strcat (itoa (- ult (1- exr:*paso*))) ":" (itoa ult)))
         'Copy
         (exr:rango ws (strcat "A" (itoa (+ 14 (* exr:*paso* k))))))
       (setq k (1+ k)))))
  (vl-catch-all-apply 'vlax-put-property
    (list (vlax-get-property ws 'PageSetup) 'PrintArea
          (strcat "$A$1:$AC$" (itoa (+ 13 (* exr:*paso* n)))))))

;;; Llena la hoja con la lista de baches ((num largo ancho area perim) ...)
(defun exr:llenar (ws lista calle esp / n bloques idx k g i fila cn enc etq x)
  (setq n (length lista)
        bloques (max 1 (/ (+ n (1- (* exr:*filas* exr:*grupos*))) (* exr:*filas* exr:*grupos*))))
  (exr:ajustar-bloques ws bloques)
  ;; baches
  (setq idx 0)
  (foreach b lista
    (setq k (/ idx (* exr:*filas* exr:*grupos*))
          g (/ (rem idx (* exr:*filas* exr:*grupos*)) exr:*filas*)
          i (rem idx exr:*filas*)
          fila (+ exr:*enc* 2 (* exr:*paso* k) i)
          cn (+ 1 (* 6 g)))
    (exr:poner ws fila cn (car b))
    (exr:poner ws fila (+ cn 1) (exr:r2 (cadr b)))
    (exr:poner ws fila (+ cn 2) (exr:r2 (caddr b)))
    (setq idx (1+ idx)))
  ;; calle y espesor en cada bloque
  (setq k 0 x (rtos (* esp 100.0) 2 1))
  (if (vl-string-search "." x) (setq x (vl-string-right-trim "." (vl-string-right-trim "0" x))))
  (setq etq (strcat "Vol Esp " x "cm"))
  (repeat bloques
    (setq enc (+ exr:*enc* (* exr:*paso* k)))
    (if (/= calle "") (exr:poner ws (1- enc) 1 calle))
    (if (> (abs (- esp 0.1)) 1e-6)
      (progn
        (setq g 0)
        (repeat exr:*grupos*
          (setq cn (+ 1 (* 6 g)))
          (exr:formula ws (+ enc 24) (+ cn 4)
            (strcat "=ROUND(" (exr:col-letra (+ cn 3)) (itoa (+ enc 24)) "*" (rtos esp 2 4) ",2)"))
          (if (< g (1- exr:*grupos*))
            (exr:poner ws (+ enc 20) (+ cn 4) etq)
            (exr:poner ws (+ enc 23) (+ cn 4) etq))
          (setq g (1+ g)))))
    (setq k (1+ k)))
  bloques)

(defun exr:a-excel (lista ruta calle esp / xl libros wb hojas ws r bloques)
  (setq xl (vl-catch-all-apply 'vlax-get-or-create-object (list "Excel.Application")))
  (cond
    ((or (null xl) (vl-catch-all-error-p xl))
     (princ "\n> No se pudo abrir Excel.") nil)
    (T
     (setq r (vl-catch-all-apply
       '(lambda ()
          (vlax-put-property xl 'ScreenUpdating :vlax-false)
          (setq libros (vlax-get-property xl 'Workbooks)
                wb (vlax-invoke-method libros 'Open ruta)
                hojas (vlax-get-property wb 'Worksheets)
                ws (exr:valor (vlax-get-property hojas 'Item 1)))
          (vlax-invoke-method ws 'Activate)
          (setq bloques (exr:llenar ws lista calle esp))
          (vlax-invoke-method wb 'Save))))
     (vl-catch-all-apply 'vlax-put-property (list xl 'ScreenUpdating :vlax-true))
     (vl-catch-all-apply 'vlax-put-property (list xl 'Visible :vlax-true))
     (foreach o (list ws hojas wb libros xl)
       (if (= (type o) 'VLA-OBJECT) (vl-catch-all-apply 'vlax-release-object (list o))))
     (if (vl-catch-all-error-p r)
       (progn (princ (strcat "\n> Error al llenar el Excel: " (vl-catch-all-error-message r))) nil)
       bloques))))

(defun c:EXR (/ ss plantilla ruta def calle esp total bloques)
  (princ "\n=== EXR - Exportar baches al generador de Excel ===")
  (setq ss (obtener-rectangulos-seleccion))
  (if ss (reconstruir-lista-desde-seleccion ss))
  (cond
    ((not ss) (princ "\n> No se seleccionaron rectángulos."))
    ((not *rectangulos-lista*)
     (princ "\n> Los rectángulos no tienen datos (deben crearse con RS)."))
    ((not (setq plantilla (exr:buscar-plantilla)))
     (princ (strcat "\n> No se encontró la plantilla " exr:*plantilla* "; se exporta a CSV."))
     (c:EXRCSV))
    (T
     (setq total 0.0)
     (foreach b *rectangulos-lista* (setq total (+ total (* (exr:r2 (cadr b)) (exr:r2 (caddr b))))))
     (setq esp (cond ((distof (memo:cfg "BACHEO_ESPESOR"))) (0.1)))
     (princ (strcat "\n> Baches: " (itoa (length *rectangulos-lista*))
                    "   Área: " (rtos total 2 2) " m2"
                    "   Volumen (esp. " (rtos esp 2 2) " m): " (rtos (* total esp) 2 2) " m3"))
     (setq def (memo:cfg "BACHEO_CALLE"))
     (setq calle (getstring T (strcat "\nNombre de la calle"
                                      (if (/= def "") (strcat " <" def ">") "") ": ")))
     (if (= calle "") (setq calle def) (memo:cfg-set "BACHEO_CALLE" calle))
     (setq ruta (getfiled "Guardar generador de bacheo"
                          (strcat (getvar "DWGPREFIX") (vl-filename-base (getvar "DWGNAME")) "_Generador.xlsx")
                          "xlsx" 1))
     (cond
       ((not ruta) (princ "\n> Exportación cancelada."))
       ((and (findfile ruta) (not (vl-file-delete ruta)))
        (princ (strcat "\n> No se puede reemplazar " ruta " (¿está abierto en Excel? ciérralo).")))
       ((not (vl-file-copy plantilla ruta))
        (princ (strcat "\n> No se pudo copiar la plantilla a " ruta)))
       ((setq bloques (exr:a-excel *rectangulos-lista* ruta calle esp))
        (princ (strcat "\n> Generador listo: " ruta
                       "\n  " (itoa (length *rectangulos-lista*)) " baches en " (itoa bloques)
                       " bloque(s). Excel quedó abierto para revisar.")))
       (T (princ "\n> Se exporta a CSV en su lugar.") (c:EXRCSV)))))
  (princ))
