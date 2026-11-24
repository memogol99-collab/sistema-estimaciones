;;; ===========================================================
;;; ECN v9.0 - Elevacion Curvas de Nivel
;;; ===========================================================
;;; Asigna elevacion a curvas de nivel con cobertura tipo CivilCAD
;;; VERSION: 9.0
;;; ===========================================================

(vl-load-com)

;;; ===========================================================
;;; CONFIGURACION
;;; ===========================================================
(setq *curv-layers* (list "CVL_CURV_D" "CVL_CURV_G"))
(setq *colored-ents* nil)
(setq *undo-data* nil)
(setq *label-layer* "CVL_ELEV_ETIQ")
(setq *label-offset* 0.0)
(setq *label-text-style* "STANDARD")

(setq *label-height-adaptive* T)
(setq *label-height-base* 0.75)
(setq *label-height-min* 0.15)
(setq *label-height-max* 1.0)
(setq *label-min-distance* 0.5)
(setq *label-skip-close* T)
(setq *auto-label* T)
(setq *label-decimals* 2)
(setq *label-dup-tolerance* 0.5)
(setq *label-interval* nil)

(setq *label-mask-on* T)
(setq *label-mask-margin* 1.2)

;;; ===========================================================
;;; FORMATO DE NUMEROS
;;; ===========================================================

(defun format-number (val dec / str)
  (setq str (rtos val 2 dec))
  (if (not (vl-string-search "." str))
    (setq str (strcat str ".0"))
  )
  (if (= dec 2)
    (progn
      (if (= (strlen (substr str (+ (vl-string-search "." str) 2))) 1)
        (setq str (strcat str "0"))
      )
    )
  )
  str
)

;;; ===========================================================
;;; FUNCIONES AUXILIARES BASICAS
;;; ===========================================================

(defun get-verts (ent / edata pts pt)
  (setq edata (entget ent))
  (setq pts nil)
  (foreach item edata
    (if (= (car item) 10)
      (progn
        (setq pt (cdr item))
        (setq pts (cons (list (car pt) (cadr pt)) pts))
      )
    )
  )
  (reverse pts)
)

(defun get-centroid (ent / verts n sx sy)
  (setq verts (get-verts ent))
  (if verts
    (progn
      (setq n (length verts))
      (setq sx 0.0 sy 0.0)
      (foreach v verts
        (setq sx (+ sx (car v)))
        (setq sy (+ sy (cadr v)))
      )
      (list (/ sx (float n)) (/ sy (float n)))
    )
    nil
  )
)

(defun get-point-on-curve (ent / verts n i pt)
  (setq verts (get-verts ent))
  (if (and verts (>= (length verts) 2))
    (progn
      (setq n (length verts))
      (setq i (/ n 2))
      (if (> i (1- n)) (setq i (1- n)))
      (setq pt (nth i verts))
      (if pt
        (list (car pt) (cadr pt))
        nil
      )
    )
    nil
  )
)

(defun get-elev (ent / edata)
  (setq edata (entget ent))
  (cdr (assoc 38 edata))
)

(defun set-elev (ent elev / edata new)
  (setq edata (entget ent))
  (if (assoc 38 edata)
    (setq new (subst (cons 38 elev) (assoc 38 edata) edata))
    (setq new (append edata (list (cons 38 elev))))
  )
  (entmod new)
  (entupd ent)
)

(defun dist-pt-poly (pt ent / verts md v d)
  (setq verts (get-verts ent))
  (setq md 1e99)
  (foreach v verts
    (setq d (distance pt v))
    (if (< d md) (setq md d))
  )
  md
)

(defun set-entity-color (ent color / edata new)
  (setq edata (entget ent))
  (if (not (assoc ent *colored-ents*))
    (setq *colored-ents*
      (cons (cons ent (assoc 62 edata)) *colored-ents*))
  )
  (if color
    (progn
      (if (assoc 62 edata)
        (setq new (subst (cons 62 color) (assoc 62 edata) edata))
        (setq new (append edata (list (cons 62 color))))
      )
      (if (assoc 420 new)
        (setq new (vl-remove (assoc 420 new) new))
      )
    )
    (setq new (vl-remove (assoc 62 edata) edata))
  )
  (entmod new)
  (entupd ent)
)

(defun elev-to-color (elev e-min e-max / ratio)
  (if (<= (- e-max e-min) 0.0)
    3
    (progn
      (setq ratio (/ (- elev e-min) (- e-max e-min)))
      (cond
        ((< ratio 0.25) 5)
        ((< ratio 0.50) 4)
        ((< ratio 0.75) 3)
        ((< ratio 0.90) 2)
        (T 1)
      )
    )
  )
)

(defun get-angle-between-points (p1 p2 / dx dy ang)
  (if (and p1 p2 (listp p1) (listp p2) 
           (>= (length p1) 2) (>= (length p2) 2))
    (progn
      (setq dx (- (car p2) (car p1)))
      (setq dy (- (cadr p2) (cadr p1)))
      (setq ang (atan dy dx))
      (if (and (> ang (/ pi 2)) (< ang (* 1.5 pi)))
        (setq ang (- ang pi))
      )
      (if (or (> ang (/ pi 2)) (< ang (- (/ pi 2))))
        (setq ang (- ang pi))
      )
      ang
    )
    0.0
  )
)

(defun get-curve-angle-at-point (ent pt / verts i n p1 p2 ang min-dist d)
  (setq verts (get-verts ent))
  (setq ang 0.0)
  (setq min-dist 1e99)
  (if (and verts (>= (length verts) 2) pt (listp pt))
    (progn
      (setq i 0)
      (setq n (1- (length verts)))
      (while (< i n)
        (setq p1 (nth i verts))
        (setq p2 (nth (1+ i) verts))
        (if (and p1 p2 (listp p1) (listp p2))
          (progn
            (setq d (distance pt p1))
            (if (< d min-dist)
              (progn
                (setq min-dist d)
                (setq ang (get-angle-between-points p1 p2))
              )
            )
          )
        )
        (setq i (1+ i))
      )
      (if (and (= ang 0.0) (>= (length verts) 2))
        (setq ang (get-angle-between-points (car verts) (cadr verts)))
      )
      (if (and (> ang (/ pi 2)) (< ang (* 1.5 pi)))
        (setq ang (- ang pi))
      )
      (if (or (> ang (/ pi 2)) (< ang (- (/ pi 2))))
        (setq ang (- ang pi))
      )
    )
  )
  ang
)

;;; ===========================================================
;;; COBERTURA TIPO CIVILCAD (entmod)
;;; ===========================================================

(defun apply-mask-to-last-text (aplicar / ent edata)
  (if (and *label-mask-on* aplicar)
    (progn
      (setq ent (entlast))
      (if ent
        (progn
          (setq edata (entget ent))
          (if (= (cdr (assoc 0 edata)) "TEXT")
            (progn
              (setq edata (vl-remove (assoc 90 edata) edata))
              (setq edata (vl-remove (assoc 45 edata) edata))
              (setq edata (append edata
                (list
                  (cons 90 1)
                  (cons 45 *label-mask-margin*)
                )
              ))
              (entmod edata)
              (entupd ent)
              T
            )
            nil
          )
        )
        nil
      )
    )
    T
  )
)

;;; ===========================================================
;;; PUNTOS A LO LARGO DE LA POLILINEA
;;; ===========================================================

(defun get-polyline-length (ent / verts n i len p1 p2 closed)
  (setq verts (get-verts ent))
  (setq len 0.0)
  (if (and verts (>= (length verts) 2))
    (progn
      (setq n (length verts))
      (setq i 0)
      (while (< i (1- n))
        (setq p1 (nth i verts))
        (setq p2 (nth (1+ i) verts))
        (setq len (+ len (distance p1 p2)))
        (setq i (1+ i))
      )
      (setq closed (cdr (assoc 70 (entget ent))))
      (if (and closed (= (logand closed 1) 1))
        (setq len (+ len (distance (last verts) (car verts))))
      )
    )
  )
  len
)

(defun get-point-at-distance (ent target-dist / verts n i acc p1 p2 seg-len
                                              remaining ratio px py ang closed
                                              result)
  (setq verts (get-verts ent))
  (setq result nil)
  (if (and verts (>= (length verts) 2))
    (progn
      (setq n (length verts))
      (setq acc 0.0)
      (setq i 0)
      (setq closed (cdr (assoc 70 (entget ent))))
      (setq closed (and closed (= (logand closed 1) 1)))
      (while (and (< i (1- n)) (not result))
        (setq p1 (nth i verts))
        (setq p2 (nth (1+ i) verts))
        (setq seg-len (distance p1 p2))
        (if (<= (+ acc seg-len) target-dist)
          (progn
            (setq acc (+ acc seg-len))
            (setq i (1+ i))
          )
          (progn
            (setq remaining (- target-dist acc))
            (if (> seg-len 0.0)
              (setq ratio (/ remaining seg-len))
              (setq ratio 0.0)
            )
            (setq px (+ (car p1) (* ratio (- (car p2) (car p1)))))
            (setq py (+ (cadr p1) (* ratio (- (cadr p2) (cadr p1)))))
            (setq ang (get-angle-between-points p1 p2))
            (setq result (list (list px py) ang))
          )
        )
      )
      (if (and (not result) closed)
        (progn
          (setq p1 (last verts))
          (setq p2 (car verts))
          (setq seg-len (distance p1 p2))
          (setq remaining (- target-dist acc))
          (if (and (<= remaining seg-len) (> seg-len 0.0))
            (progn
              (setq ratio (/ remaining seg-len))
              (setq px (+ (car p1) (* ratio (- (car p2) (car p1)))))
              (setq py (+ (cadr p1) (* ratio (- (cadr p2) (cadr p1)))))
              (setq ang (get-angle-between-points p1 p2))
              (setq result (list (list px py) ang))
            )
          )
        )
      )
    )
  )
  result
)

(defun get-label-positions (total-len interval / positions pos half)
  (setq positions nil)
  (if (or (not interval) (<= interval 0.0))
    (setq positions (list (/ total-len 2.0)))
    (progn
      (if (< total-len interval)
        (setq positions (list (/ total-len 2.0)))
        (progn
          (setq half (/ interval 2.0))
          (setq pos half)
          (while (< pos total-len)
            (setq positions (cons pos positions))
            (setq pos (+ pos interval))
          )
          (setq positions (reverse positions))
        )
      )
    )
  )
  positions
)

;;; ===========================================================
;;; ELIMINAR ETIQUETAS DUPLICADAS
;;; ===========================================================

(defun delete-labels-on-curve (ent / ss n label-ent label-pt d)
  (setq ss (ssget "X" (list (cons 0 "TEXT") (cons 8 *label-layer*))))
  (if ss
    (progn
      (setq n 0)
      (while (< n (sslength ss))
        (setq label-ent (ssname ss n))
        (setq label-pt (cdr (assoc 10 (entget label-ent))))
        (if label-pt
          (progn
            (setq d (dist-pt-poly label-pt ent))
            (if (< d *label-dup-tolerance*)
              (entdel label-ent)
            )
          )
        )
        (setq n (1+ n))
      )
    )
  )
)

(defun delete-all-duplicates (/ clist ss n label-ent label-pt
                               ent labels-on-curve
                               sorted-keep total-borrados total-curvas)
  (princ "\n--- Limpiando etiquetas duplicadas ---")
  (setq clist (build-contour-list *curv-layers*))
  (if (not clist)
    (progn (princ "\nNo hay curvas en las capas objetivo.") (exit))
  )
  (setq ss (ssget "X" (list (cons 0 "TEXT") (cons 8 *label-layer*))))
  (if (not ss)
    (progn (princ "\nNo hay etiquetas en la capa de etiquetas.") (exit))
  )
  (princ (strcat "\n  Curvas objetivo: " (itoa (length clist))))
  (princ (strcat "\n  Etiquetas encontradas: " (itoa (sslength ss))))
  (setq total-borrados 0)
  (setq total-curvas 0)
  (foreach c clist
    (setq ent (car c))
    (setq labels-on-curve nil)
    (setq n 0)
    (while (< n (sslength ss))
      (setq label-ent (ssname ss n))
      (setq label-pt (cdr (assoc 10 (entget label-ent))))
      (if label-pt
        (progn
          (if (< (dist-pt-poly label-pt ent) *label-dup-tolerance*)
            (setq labels-on-curve 
              (cons (cons (cdr (assoc 5 (entget label-ent))) label-ent)
                    labels-on-curve))
          )
        )
      )
      (setq n (1+ n))
    )
    (if (> (length labels-on-curve) 1)
      (progn
        (setq total-curvas (1+ total-curvas))
        (setq labels-on-curve
          (vl-sort labels-on-curve
            (function (lambda (a b) (> (car a) (car b))))))
        (setq sorted-keep (car labels-on-curve))
        (setq labels-on-curve (cdr labels-on-curve))
        (foreach item labels-on-curve
          (setq label-ent (cdr item))
          (if (and label-ent (entget label-ent))
            (progn
              (entdel label-ent)
              (setq total-borrados (1+ total-borrados))
            )
          )
        )
      )
    )
  )
  (princ "\n\n============================================")
  (princ "\n  RESULTADO LIMPIEZA DE DUPLICADOS")
  (princ "\n============================================")
  (princ (strcat "\n  Curvas afectadas: " (itoa total-curvas)))
  (princ (strcat "\n  Etiquetas eliminadas: " (itoa total-borrados)))
  (princ "\n============================================")
  (if (= total-borrados 0)
    (princ "\n  No se encontraron duplicados.")
  )
  (princ)
)

(defun c:ECN-DUPLICADOS ()
  (delete-all-duplicates)
  (princ)
)
;;; ===========================================================
;;; FUNCION DE COLOR - CURVAS Y ETIQUETAS
;;; ===========================================================

(defun color-curves-and-labels (processed / e-min e-max color-elev label-ss label-ent label-pt closest-dist closest-elev n color d)
  (setq e-min 1e99)
  (setq e-max -1e99)
  (foreach ent processed
    (setq color-elev (get-elev ent))
    (if color-elev
      (progn
        (if (< color-elev e-min) (setq e-min color-elev))
        (if (> color-elev e-max) (setq e-max color-elev))
      )
    )
  )
  (if (<= (- e-max e-min) 0.0)
    (progn
      (princ "\n  Todas las curvas tienen la misma elevacion.")
      (setq e-min 0.0)
      (setq e-max 1.0)
    )
  )
  (princ "\n  Coloreando curvas...")
  (foreach ent processed
    (setq color-elev (get-elev ent))
    (if color-elev
      (set-entity-color ent (elev-to-color color-elev e-min e-max))
      (set-entity-color ent 3)
    )
  )
  (princ "\n  Coloreando etiquetas...")
  (setq label-ss (ssget "X" (list (cons 0 "TEXT") (cons 8 *label-layer*))))
  (if label-ss
    (progn
      (setq n 0)
      (while (< n (sslength label-ss))
        (setq label-ent (ssname label-ss n))
        (setq label-pt (cdr (assoc 10 (entget label-ent))))
        (setq closest-dist 1e99)
        (setq closest-elev nil)
        (foreach ent processed
          (setq d (dist-pt-poly label-pt ent))
          (if (< d closest-dist)
            (progn
              (setq closest-dist d)
              (setq closest-elev (get-elev ent))
            )
          )
        )
        (if closest-elev
          (progn
            (setq color (elev-to-color closest-elev e-min e-max))
            (set-entity-color label-ent color)
          )
        )
        (setq n (1+ n))
      )
    )
  )
  (princ (strcat "\n  Rango colores: " (rtos e-min 2 2) " - " (rtos e-max 2 2)))
  (princ "\n  Azul(5)=baja  Cyan(4)  Verde(3)  Amarillo(2)  Rojo(1)=alta")
)

;;; ===========================================================
;;; FUNCION DE RECOLOR
;;; ===========================================================

(defun recolor-all-curves (/ clist n ent elev e-min e-max count label-ss label-ent label-pt closest-dist closest-elev color d)
  (princ "\n--- Coloreando por Elevacion ---")
  (setq clist (build-contour-list *curv-layers*))
  (if (not clist)
    (princ "\nNo hay curvas.")
    (progn
      (setq e-min 1e99) (setq e-max -1e99) (setq count 0)
      (foreach c clist
        (setq elev (get-elev (car c)))
        (if elev
          (progn
            (if (< elev e-min) (setq e-min elev))
            (if (> elev e-max) (setq e-max elev))
            (setq count (1+ count))
          )
        )
      )
      (if (<= count 0)
        (princ "\nNo hay curvas con elevacion asignada.")
        (progn
          (setq n 0)
          (while (< n (length clist))
            (setq ent (car (nth n clist)))
            (setq elev (get-elev ent))
            (if elev
              (set-entity-color ent (elev-to-color elev e-min e-max))
            )
            (setq n (1+ n))
          )
          (princ "\n  Coloreando etiquetas...")
          (setq label-ss (ssget "X" (list (cons 0 "TEXT") (cons 8 *label-layer*))))
          (if label-ss
            (progn
              (setq n 0)
              (while (< n (sslength label-ss))
                (setq label-ent (ssname label-ss n))
                (setq label-pt (cdr (assoc 10 (entget label-ent))))
                (setq closest-dist 1e99)
                (setq closest-elev nil)
                (foreach c clist
                  (setq ent (car c))
                  (setq d (dist-pt-poly label-pt ent))
                  (if (< d closest-dist)
                    (progn
                      (setq closest-dist d)
                      (setq closest-elev (get-elev ent))
                    )
                  )
                )
                (if closest-elev
                  (progn
                    (setq color (elev-to-color closest-elev e-min e-max))
                    (set-entity-color label-ent color)
                  )
                )
                (setq n (1+ n))
              )
            )
          )
          (princ (strcat "\nRecoloreadas " (itoa count) " curvas."))
          (princ (strcat "\nRango: " (format-number e-min *label-decimals*) " - " (format-number e-max *label-decimals*)))
          (princ "\nLeyenda: Azul(5)=baja  Cyan(4)  Verde(3)  Amarillo(2)  Rojo(1)=alta")
        )
      )
    )
  )
  (princ)
)

;;; ===========================================================
;;; CREAR ETIQUETA UNICA (con cobertura)
;;; ===========================================================

(defun create-single-label (ent elev pt / text height ang color use-pt)
  (if (and ent elev)
    (progn
      (if (not pt)
        (setq use-pt (get-point-on-curve ent))
        (setq use-pt pt)
      )
      (if use-pt
        (progn
          (delete-labels-on-curve ent)
          (setq text (format-number elev *label-decimals*))
          (setq height *label-height-base*)
          (if (> (getvar "DIMSCALE") 1.0)
            (setq height (* height (getvar "DIMSCALE")))
          )
          (setq ang (get-curve-angle-at-point ent use-pt))
          (if (not (numberp ang)) (setq ang 0.0))
          (setq color (cdr (assoc 62 (entget ent))))
          (if (not color) (setq color 1))
          (if (or (= color 7) (= color 255) (= color 256) (null color))
            (setq color 1)
          )
          (entmake
            (list
              (cons 0 "TEXT")
              (cons 8 *label-layer*)
              (cons 10 (list (car use-pt) (cadr use-pt) 0.0))
              (cons 11 (list (car use-pt) (cadr use-pt) 0.0))
              (cons 1 text)
              (cons 40 height)
              (cons 50 ang)
              (cons 62 color)
              (cons 7 *label-text-style*)
              (cons 72 1)
              (cons 73 2)
            )
          )
          (apply-mask-to-last-text T)
          T
        )
        nil
      )
    )
    nil
  )
)

;;; ===========================================================
;;; ETIQUETAR UNA CURVA CON MULTIPLES ETIQUETAS
;;; ===========================================================

(defun label-curve-with-interval (ent elev interval / total-len positions
                                                          count pos pos-data pt ang
                                                          text height color)
  (setq count 0)
  (setq total-len (get-polyline-length ent))
  (if (<= total-len 0.0)
    0
    (progn
      (setq positions (get-label-positions total-len interval))
      (setq text (format-number elev *label-decimals*))
      (setq height *label-height-base*)
      (if (> (getvar "DIMSCALE") 1.0)
        (setq height (* height (getvar "DIMSCALE")))
      )
      (setq color (cdr (assoc 62 (entget ent))))
      (if (not color) (setq color 1))
      (if (or (= color 7) (= color 255) (= color 256) (null color))
        (setq color 1)
      )
      (foreach pos positions
        (setq pos-data (get-point-at-distance ent pos))
        (if pos-data
          (progn
            (setq pt (car pos-data))
            (setq ang (cadr pos-data))
            (if (not (numberp ang)) (setq ang 0.0))
            (entmake
              (list
                (cons 0 "TEXT")
                (cons 8 *label-layer*)
                (cons 10 (list (car pt) (cadr pt) 0.0))
                (cons 11 (list (car pt) (cadr pt) 0.0))
                (cons 1 text)
                (cons 40 height)
                (cons 50 ang)
                (cons 62 color)
                (cons 7 *label-text-style*)
                (cons 72 1)
                (cons 73 2)
              )
            )
            (apply-mask-to-last-text T)
            (setq count (1+ count))
          )
        )
      )
      count
    )
  )
)

;;; ===========================================================
;;; ECN-P - PROPAGACION POR CLIC
;;; ===========================================================

(defun c:ECN-P (/ ent elev pt processed count continue 
                  new-elev ref-ent ref-elev interval direction)
  (princ "\n--- PROPAGACION POR CLIC (1 clic = elevar + etiquetar) ---")
  (princ "\n  Seleccione curva de referencia y especifique elevacion.")
  (princ "\n  Luego, haga clic en cada curva siguiente.")
  (princ "\n  Presione Enter para terminar y colorear.\n")
  (setq ref-ent nil)
  (setq ent nil)
  (setq ent (car (entsel "\nSeleccione curva de REFERENCIA: ")))
  (if (not ent)
    (progn
      (princ "\nOperacion cancelada.")
      (exit)
    )
  )
  (if (/= (cdr (assoc 0 (entget ent))) "LWPOLYLINE")
    (progn
      (princ "\nLa entidad seleccionada no es una polilinea.")
      (exit)
    )
  )
  (setq ref-ent ent)
  (redraw ref-ent 3)
  (setq ref-elev (getreal "\nElevacion de la curva de referencia: "))
  (if (not ref-elev)
    (progn
      (princ "\nOperacion cancelada.")
      (redraw ref-ent 4)
      (exit)
    )
  )
  (set-elev ref-ent ref-elev)
  (create-single-label ref-ent ref-elev nil)
  (setq processed (list ref-ent))
  (setq count 1)
  (princ (strcat "\n  >>> Ref " (itoa count) ": Elev=" (format-number ref-elev *label-decimals*)))
  (setq interval (getreal "\nEquidistancia (incremento en Z): "))
  (if (or (not interval) (<= interval 0.0))
    (progn
      (princ "\nEquidistancia no valida. Usando 1.0")
      (setq interval 1.0)
    )
  )
  (initget "Positivo Negativo")
  (setq direction (getkword "\nSentido [Positivo/Negativo] <Positivo>: "))
  (if (not direction) (setq direction "Positivo"))
  (princ (strcat "\n  Incremento: " (format-number interval *label-decimals*) " (" direction ")"))
  (setq continue T)
  (while continue
    (princ "\n")
    (setq ent (car (entsel (strcat "\nCurva " (itoa (1+ count)) " (Enter para terminar): "))))
    (if (not ent)
      (progn
        (setq continue nil)
        (princ "\nFinalizando seleccion.")
      )
      (progn
        (if (/= (cdr (assoc 0 (entget ent))) "LWPOLYLINE")
          (princ "\nLa entidad seleccionada no es una polilinea.")
          (progn
            (if (= direction "Positivo")
              (setq new-elev (+ ref-elev (* count interval)))
              (setq new-elev (- ref-elev (* count interval)))
            )
            (set-elev ent new-elev)
            (create-single-label ent new-elev nil)
            (setq processed (append processed (list ent)))
            (setq count (1+ count))
            (princ (strcat "\n  >>> Curva " (itoa count) ": Elev=" (format-number new-elev *label-decimals*)))
          )
        )
      )
    )
  )
  (if (> (length processed) 0)
    (progn
      (princ "\n\nColoreando curvas y etiquetas...")
      (color-curves-and-labels processed)
      (princ "\n\n============================================")
      (princ "\n  RESULTADO PROPAGACION POR CLIC")
      (princ "\n============================================")
      (princ (strcat "\n  Curvas procesadas: " (itoa (length processed))))
      (princ (strcat "\n  Elevacion inicial: " (format-number ref-elev *label-decimals*)))
      (princ (strcat "\n  Equidistancia: " (format-number interval *label-decimals*)))
      (princ (strcat "\n  Sentido: " direction))
      (princ "\n============================================")
    )
    (princ "\nNo se procesaron curvas.")
  )
  (if (and ref-ent (entget ref-ent))
    (redraw ref-ent 4)
  )
  (princ)
)

;;; ===========================================================
;;; ECN-M - METODO MANUAL
;;; ===========================================================

(defun c:ECN-M (/ clist pt result ent dist cur_elev elev
                  last_elev msg e-min e-max processed ok)
  (princ "\n--- Metodo Manual ---")
  (setq ok T)
  (setq clist (build-contour-list *curv-layers*))
  (if (not clist)
    (progn
      (princ "\nNo hay curvas en las capas indicadas.")
      (setq ok nil)
    )
  )
  (if ok
    (progn
      (princ (strcat "\n" (itoa (length clist)) " curvas encontradas."))
      (setq last_elev nil)
      (setq e-min 1e99) (setq e-max -1e99)
      (setq processed nil)
      (save-undo clist)
      (while (setq pt (getpoint "\nSeleccione punto cerca de curva (Enter=terminar): "))
        (setq result (find-nearest pt clist))
        (if (not result)
          (princ "\nNo se encontro curva cercana.")
          (progn
            (setq ent (car result))
            (setq dist (cadddr result))
            (redraw ent 3)
            (setq cur_elev (get-elev ent))
            (if cur_elev
              (setq msg (strcat " - Elev actual: " (format-number cur_elev *label-decimals*)))
              (setq msg " - Sin elevacion")
            )
            (princ (strcat "\nCurva a " (rtos dist 2 2) msg))
            (if last_elev
              (setq elev (getreal (strcat "\nElevacion <" (format-number last_elev *label-decimals*) ">: ")))
              (setq elev (getreal "\nElevacion: "))
            )
            (if (not elev)
              (if last_elev (setq elev last_elev))
            )
            (if elev
              (progn
                (set-elev ent elev)
                (if (< elev e-min) (setq e-min elev))
                (if (> elev e-max) (setq e-max elev))
                (if (> (- e-max e-min) 0.0)
                  (set-entity-color ent (elev-to-color elev e-min e-max))
                  (set-entity-color ent 3)
                )
                (setq processed (cons (list ent elev) processed))
                (princ (strcat "\n>>> " (format-number elev *label-decimals*) " asignada."))
                (setq last_elev elev)
              )
              (princ "\nCurva saltada.")
            )
            (redraw ent 4)
          )
        )
      )
      (if processed
        (progn
          (princ "\n\n--- Resumen Manual ---")
          (princ (strcat "\nCurvas procesadas: " (itoa (length processed))))
          (princ (strcat "\nRango: " (format-number e-min *label-decimals*) " - " (format-number e-max *label-decimals*)))
        )
      )
    )
  )
  (princ)
)

;;; ===========================================================
;;; ECN-ETIQ - ETIQUETAS AUTOMATICAS
;;; ===========================================================

(defun c:ECN-ETIQ (/ clist count interval n ent elev total count-curves
                    largo-text use-interval)
  (princ "\n--- Etiquetas Automaticas (con intervalo) ---")
  (setq clist (build-contour-list *curv-layers*))
  (if (not clist)
    (progn
      (princ "\nNo hay curvas en las capas indicadas.")
      (exit)
    )
  )
  (if *label-interval*
    (princ (strcat "\n  Intervalo guardado: " (rtos *label-interval* 2 2) " m"))
    (princ "\n  Intervalo guardado: (ninguno - etiqueta al centro)")
  )
  (setq interval (getreal 
    (strcat "\nDistancia entre etiquetas en metros <" 
            (if *label-interval* (rtos *label-interval* 2 2) "centro")
            ">: ")))
  (if (not interval)
    (setq interval *label-interval*)
    (progn
      (if (> interval 0.0)
        (setq *label-interval* interval)
        (setq *label-interval* nil)
      )
    )
  )
  (setq use-interval interval)
  (if (or (not use-interval) (<= use-interval 0.0))
    (progn
      (princ "\n  Modo: una sola etiqueta al centro de cada curva.")
      (setq use-interval nil)
    )
    (princ (strcat "\n  Modo: una etiqueta cada " (rtos use-interval 2 2) " metros."))
  )
  (setq count 0)
  (setq count-curves 0)
  (foreach item clist
    (setq ent (car item))
    (setq elev (get-elev ent))
    (if elev
      (progn
        (delete-labels-on-curve ent)
        (setq n (label-curve-with-interval ent elev use-interval))
        (if (> n 0)
          (progn
            (setq count (+ count n))
            (setq count-curves (1+ count-curves))
            (setq total (get-polyline-length ent))
            (if (and use-interval (< total use-interval))
              (setq largo-text "corta")
              (setq largo-text "larga")
            )
            (princ (strcat "\n  Curva " largo-text 
                           " (" (rtos total 2 2) "m): " 
                           (itoa n) " etiqueta" 
                           (if (> n 1) "s" "") 
                           " @ " (format-number elev *label-decimals*)))
          )
        )
      )
    )
  )
  (princ "\n\n============================================")
  (princ "\n  RESULTADO ETIQUETAS AUTOMATICAS")
  (princ "\n============================================")
  (princ (strcat "\n  Curvas etiquetadas: " (itoa count-curves)))
  (princ (strcat "\n  Total etiquetas: " (itoa count)))
  (princ "\n============================================")
  (princ)
)

;;; ===========================================================
;;; ECN-ETIQM - ETIQUETA MANUAL
;;; ===========================================================

(defun c:ECN-ETIQM (/ ent pt elev text height color user-height
                      interval use-interval total-len n total
                      pos pos-data ang pt-data
                      count-curves count-labels)
  (princ "\n--- Etiquetar Curva Individual (con intervalo) ---")
  (setq user-height (getreal 
    (strcat "\nTamano de la etiqueta <" (rtos *label-height-base* 2 2) ">: ")))
  (if (not user-height)
    (setq user-height *label-height-base*)
  )
  (if (<= user-height 0.0)
    (progn
      (princ "\nEl tamano debe ser mayor que 0. Usando tamano base.")
      (setq user-height *label-height-base*)
    )
  )
  (if *label-interval*
    (princ (strcat "\n  Intervalo guardado: " (rtos *label-interval* 2 2) " m"))
    (princ "\n  Intervalo guardado: (ninguno - etiqueta al centro)")
  )
  (setq interval (getreal 
    (strcat "\nDistancia entre etiquetas en metros <"
            (if *label-interval* (rtos *label-interval* 2 2) "centro")
            ">: ")))
  (if (not interval)
    (setq interval *label-interval*)
    (progn
      (if (> interval 0.0)
        (setq *label-interval* interval)
        (setq *label-interval* nil)
      )
    )
  )
  (setq use-interval interval)
  (if (or (not use-interval) (<= use-interval 0.0))
    (progn
      (princ "\n  Modo: una etiqueta al centro de cada curva.")
      (setq use-interval nil)
    )
    (princ (strcat "\n  Modo: una etiqueta cada " (rtos use-interval 2 2) " metros."))
  )
  (princ (strcat "\n  Tamano etiqueta: " (rtos user-height 2 2)))
  (princ "\n  Haga clic en una curva para etiquetarla.")
  (princ "\n  Presione Enter para salir.")
  (setq count-curves 0)
  (setq count-labels 0)
  (while T
    (setq ent (car (entsel "\nSeleccione curva (Enter para salir): ")))
    (if (not ent)
      (progn
        (princ "\nFinalizando etiquetado manual.")
        (exit)
      )
      (progn
        (if (/= (cdr (assoc 0 (entget ent))) "LWPOLYLINE")
          (princ "\nLa entidad seleccionada no es una polilinea.")
          (progn
            (setq elev (get-elev ent))
            (if (not elev)
              (princ "\nEsta curva no tiene elevacion asignada.")
              (progn
                (delete-labels-on-curve ent)
                (setq total-len (get-polyline-length ent))
                (if (<= total-len 0.0)
                  (princ "\n  [aviso] Curva con longitud 0, saltando.")
                  (progn
                    (setq text (format-number elev *label-decimals*))
                    (setq height user-height)
                    (if (> (getvar "DIMSCALE") 1.0)
                      (setq height (* height (getvar "DIMSCALE")))
                    )
                    (setq color (cdr (assoc 62 (entget ent))))
                    (if (not color) (setq color 1))
                    (if (or (= color 7) (= color 255) (= color 256) (null color))
                      (setq color 1)
                    )
                    (setq n 0)
                    (foreach pos (get-label-positions total-len use-interval)
                      (setq pt-data (get-point-at-distance ent pos))
                      (if pt-data
                        (progn
                          (setq pt (car pt-data))
                          (setq ang (cadr pt-data))
                          (if (not (numberp ang)) (setq ang 0.0))
                          (entmake
                            (list
                              (cons 0 "TEXT")
                              (cons 8 *label-layer*)
                              (cons 10 (list (car pt) (cadr pt) 0.0))
                              (cons 11 (list (car pt) (cadr pt) 0.0))
                              (cons 1 text)
                              (cons 40 height)
                              (cons 50 ang)
                              (cons 62 color)
                              (cons 7 *label-text-style*)
                              (cons 72 1)
                              (cons 73 2)
                            )
                          )
                          (apply-mask-to-last-text T)
                          (setq n (1+ n))
                        )
                      )
                    )
                    (if (and use-interval (< total-len use-interval))
                      (princ (strcat "\n  Curva CORTA (" 
                                     (rtos total-len 2 2) "m): 1 etiqueta al centro"))
                      (if use-interval
                        (princ (strcat "\n  Curva LARGA (" 
                                       (rtos total-len 2 2) "m): "
                                       (itoa n) " etiquetas cada "
                                       (rtos use-interval 2 2) "m"))
                        (princ (strcat "\n  Curva (" 
                                       (rtos total-len 2 2) "m): 1 etiqueta al centro"))
                      )
                    )
                    (princ (strcat "  @ " text))
                    (setq count-curves (1+ count-curves))
                    (setq count-labels (+ count-labels n))
                  )
                )
              )
            )
          )
        )
      )
    )
  )
  (princ)
)
;;; ===========================================================
;;; FUNCIONES DE SOPORTE
;;; ===========================================================

(defun save-undo (clist / c ent elev)
  (foreach c clist
    (setq ent (car c))
    (if (not (assoc ent *undo-data*))
      (setq *undo-data* (cons (cons ent (get-elev ent)) *undo-data*))
    )
  )
)

(defun layer-match (lay layer-list / ll)
  (setq ll (mapcar (function strcase) layer-list))
  (member (strcase lay) ll)
)

(defun find-in-clist (ent clist / i)
  (setq i 0)
  (while (and (< i (length clist)) (/= (car (nth i clist)) ent))
    (setq i (1+ i))
  )
  (if (< i (length clist)) i -1)
)

(defun find-nearest (pt clist / i c d md best_idx)
  (setq md 1e99)
  (setq best_idx -1)
  (setq i 0)
  (foreach c clist
    (setq d (dist-pt-poly pt (car c)))
    (if (< d md)
      (progn (setq md d) (setq best_idx i))
    )
    (setq i (1+ i))
  )
  (if (>= best_idx 0)
    (list (car (nth best_idx clist))
          (cadr (nth best_idx clist))
          (caddr (nth best_idx clist))
          md)
    nil
  )
)

(defun safe-ssget-lwpoly (/ ss ent)
  (princ "\n  Buscando LWPOLYLINE...")
  (setq ss (ssget "X" (list (cons 0 "LWPOLYLINE"))))
  (if ss
    (progn
      (princ (strcat "\n  " (itoa (sslength ss)) " LWPOLYLINE encontradas."))
      ss
    )
    (progn
      (princ "\n  ssget fallo, intentando entnext...")
      (setq ss (ssadd))
      (setq ent (entnext))
      (while ent
        (if (= (cdr (assoc 0 (entget ent))) "LWPOLYLINE")
          (ssadd ent ss)
        )
        (setq ent (entnext ent))
      )
      (if (> (sslength ss) 0)
        (progn
          (princ (strcat "\n  " (itoa (sslength ss)) " encontradas (entnext)."))
          ss
        )
        nil
      )
    )
  )
)

(defun build-contour-list (layer-list / ss n ent edata lay cen result)
  (setq result nil)
  (setq ss (safe-ssget-lwpoly))
  (if ss
    (progn
      (setq n 0)
      (while (< n (sslength ss))
        (setq ent (ssname ss n))
        (setq edata (entget ent))
        (setq lay (cdr (assoc 8 edata)))
        (if (layer-match lay layer-list)
          (progn
            (setq cen (get-centroid ent))
            (if cen
              (setq result (cons (list ent (car cen) (cadr cen)) result))
            )
          )
        )
        (setq n (1+ n))
      )
    )
  )
  (if result
    (progn
      (setq result (reverse result))
      (princ (strcat "\n  " (itoa (length result)) " curvas en capas objetivo."))
      result
    )
    (progn
      (princ "\n  No se encontraron curvas en las capas objetivo.")
      nil
    )
  )
)

;;; ===========================================================
;;; ECN-QUITAR
;;; ===========================================================

(defun get-labels-ss ()
  (ssget "X" (list (cons 0 "TEXT") (cons 8 *label-layer*)))
)

(defun erase-ss (ss / n ent)
  (if ss
    (progn
      (setq n 0)
      (while (< n (sslength ss))
        (setq ent (ssname ss n))
        (entdel ent)
        (setq n (1+ n))
      )
    )
  )
)

(defun c:ECN-QUITAR (/ ss)
  (princ "\n--- Eliminando etiquetas ---")
  (setq ss (get-labels-ss))
  (if ss
    (progn
      (erase-ss ss)
      (princ (strcat "\n" (itoa (sslength ss)) " etiquetas eliminadas."))
    )
    (princ (strcat "\nNo hay etiquetas en la capa " *label-layer*))
  )
  (princ)
)

;;; ===========================================================
;;; ECN-RECOLOR
;;; ===========================================================

(defun c:ECN-RECOLOR ()
  (recolor-all-curves)
  (princ)
)

;;; ===========================================================
;;; ECN-LIMPIA
;;; ===========================================================

(defun c:ECN-LIMPIA (/ count ent orig)
  (princ "\n--- Restaurar Colores ---")
  (if (not *colored-ents*)
    (princ "\nNo hay colores para restaurar.")
    (progn
      (setq count 0)
      (foreach item *colored-ents*
        (setq ent (car item))
        (setq orig (cdr item))
        (if (and ent (entget ent))
          (if orig
            (set-entity-color ent (cdr orig))
            (set-entity-color ent nil)
          )
        )
      )
      (setq *colored-ents* nil)
      (princ "\n>>> Colores restaurados.")
    )
  )
  (princ)
)

;;; ===========================================================
;;; ECN-DESHACER
;;; ===========================================================

(defun c:ECN-DESHACER (/ ent orig count)
  (princ "\n--- Deshacer Elevaciones ---")
  (if (not *undo-data*)
    (princ "\nNo hay datos para deshacer.")
    (progn
      (setq count 0)
      (foreach item *undo-data*
        (setq ent (car item))
        (setq orig (cdr item))
        (if (and ent (entget ent))
          (if orig
            (set-elev ent (cdr orig))
            (remove-elev ent)
          )
        )
        (setq count (1+ count))
      )
      (princ (strcat "\n" (itoa count) " curvas restauradas."))
      (setq *undo-data* nil)
      (princ "\n>>> Elevaciones restauradas.")
    )
  )
  (princ)
)

;;; ===========================================================
;;; ECN-LISTA
;;; ===========================================================

(defun c:ECN-LISTA (/ ss n ent edata elay counts)
  (princ "\n\n=== DIAGNOSTICO LISTA-CAPAS ===")
  (princ "\n\n--- LWPOLYLINE por capa ---")
  (setq ss (ssget "X" (list (cons 0 "LWPOLYLINE"))))
  (if (not ss)
    (princ "\n  Ninguna encontrada.")
    (progn
      (princ (strcat "\n  Total: " (itoa (sslength ss))))
      (setq counts nil) (setq n 0)
      (while (< n (sslength ss))
        (setq ent (ssname ss n))
        (setq edata (entget ent))
        (setq elay (cdr (assoc 8 edata)))
        (if (assoc elay counts)
          (setq counts (subst (cons elay (1+ (cdr (assoc elay counts))))
                            (assoc elay counts) counts))
          (setq counts (append counts (list (cons elay 1))))
        )
        (setq n (1+ n))
      )
      (setq counts (vl-sort counts (function (lambda (a b) (> (cdr a) (cdr b))))))
      (foreach c counts
        (princ (strcat "\n  " (car c) ": " (itoa (cdr c))))
      )
    )
  )
  (princ "\n\n--- Capas objetivo para ECN ---")
  (foreach l *curv-layers*
    (princ (strcat "\n  " l))
  )
  (princ "\n")
)

;;; ===========================================================
;;; ECN-CONFIG
;;; ===========================================================

(defun c:ECN-CONFIG (/ new-min new-max new-base new-dist new-dec new-dup 
                       new-int new-mask new-margin)
  (princ "\n--- Configuracion de Etiquetas ---")
  (setq new-dec (getint 
    (strcat "\nNumero de decimales <" (itoa *label-decimals*) ">: ")))
  (if new-dec (setq *label-decimals* new-dec))
  (setq new-base (getreal 
    (strcat "\nTamano base <" (rtos *label-height-base* 2 2) ">: ")))
  (if new-base (setq *label-height-base* new-base))
  (setq new-dist (getreal 
    (strcat "\nDistancia minima para etiquetar <" (rtos *label-min-distance* 2 2) ">: ")))
  (if new-dist (setq *label-min-distance* new-dist))
  (setq new-min (getreal 
    (strcat "\nTamano minimo <" (rtos *label-height-min* 2 2) ">: ")))
  (if new-min (setq *label-height-min* new-min))
  (setq new-max (getreal 
    (strcat "\nTamano maximo <" (rtos *label-height-max* 2 2) ">: ")))
  (if new-max (setq *label-height-max* new-max))
  (setq new-dup (getreal 
    (strcat "\nTolerancia duplicados <" (rtos *label-dup-tolerance* 2 2) ">: ")))
  (if new-dup (setq *label-dup-tolerance* new-dup))
  (princ "\n")
  (if *label-interval*
    (princ (strcat "Intervalo actual entre etiquetas: " (rtos *label-interval* 2 2) " m"))
    (princ "Intervalo actual: (ninguno - etiqueta al centro)")
  )
  (setq new-int (getreal 
    "\nNuevo intervalo en metros (0 = una etiqueta al centro) <conservar>: "))
  (if new-int
    (progn
      (if (> new-int 0.0)
        (progn
          (setq *label-interval* new-int)
          (princ (strcat "\n  Intervalo guardado: " (rtos new-int 2 2) " m"))
        )
        (progn
          (setq *label-interval* nil)
          (princ "\n  Intervalo borrado (etiqueta al centro).")
        )
      )
    )
  )
  (princ "\n")
  (princ (strcat "\nCobertura tipo CivilCAD: " 
                 (if *label-mask-on* "ACTIVADA" "desactivada")))
  (initget "S N")
  (setq new-mask (getkword "\nActivar cobertura? [S/N] <conservar>: "))
  (if new-mask
    (if (= new-mask "S")
      (setq *label-mask-on* T)
      (setq *label-mask-on* nil)
    )
  )
  (if *label-mask-on*
    (progn
      (setq new-margin (getreal 
        (strcat "\nMargen de la cobertura <" 
                (rtos *label-mask-margin* 2 2) ">: ")))
      (if (and new-margin (> new-margin 0.0))
        (setq *label-mask-margin* new-margin)
      )
    )
  )
  (princ "\n\nConfiguracion actualizada:")
  (princ (strcat "\n   Decimales: " (itoa *label-decimals*)))
  (princ (strcat "\n   Tamano base: " (rtos *label-height-base* 2 2)))
  (princ (strcat "\n   Distancia minima: " (rtos *label-min-distance* 2 2)))
  (if *label-interval*
    (princ (strcat "\n   Intervalo etiquetas: " (rtos *label-interval* 2 2) " m"))
    (princ "\n   Intervalo etiquetas: al centro")
  )
  (princ (strcat "\n   Cobertura CivilCAD: " (if *label-mask-on* "SI" "NO")))
  (if *label-mask-on*
    (princ (strcat "\n   Margen cobertura: " (rtos *label-mask-margin* 2 2)))
  )
  (princ)
)

;;; ===========================================================
;;; ETM - ATAJO
;;; ===========================================================

(defun c:ETM ()
  (c:ECN-ETIQM)
)

;;; ===========================================================
;;; DCL - DIALOGO PRINCIPAL
;;; ===========================================================

(defun ECN-DCL (/ dcl_id dcl_file result)
  (setq dcl_file (strcat (getvar "TEMPPREFIX") "ECN.dcl"))
  (if (findfile dcl_file)
    (vl-file-delete dcl_file)
  )
  (setq dcl_id (open dcl_file "w"))
  (write-line "ECN : dialog {" dcl_id)
  (write-line "  label = \"ECN v9.0 - Elevacion Curvas de Nivel\";" dcl_id)
  (write-line "  : column {" dcl_id)
  (write-line "    : boxed_column {" dcl_id)
  (write-line "      label = \"Opciones Principales\";" dcl_id)
  (write-line "      : button { key = \"btn_propagacion\"; label = \"Propagacion por Clic\"; width = 30; }" dcl_id)
  (write-line "      : button { key = \"btn_manual\"; label = \"Metodo Manual\"; width = 30; }" dcl_id)
  (write-line "      : button { key = \"btn_etiquetas\"; label = \"Etiquetas Automaticas\"; width = 30; }" dcl_id)
  (write-line "      : button { key = \"btn_etiquetamanual\"; label = \"Etiqueta Manual\"; width = 30; }" dcl_id)
  (write-line "    }" dcl_id)
  (write-line "    : boxed_column {" dcl_id)
  (write-line "      label = \"Color / Mantenimiento\";" dcl_id)
  (write-line "      : button { key = \"btn_recolor\"; label = \"Colorear por Elevacion\"; width = 30; }" dcl_id)
  (write-line "      : button { key = \"btn_limpiar\"; label = \"Restaurar Colores\"; width = 30; }" dcl_id)
  (write-line "      : button { key = \"btn_deshacer\"; label = \"Deshacer Elevaciones\"; width = 30; }" dcl_id)
  (write-line "      : button { key = \"btn_quitar\"; label = \"Quitar Etiquetas\"; width = 30; }" dcl_id)
  (write-line "      : button { key = \"btn_duplicados\"; label = \"Limpiar Duplicados\"; width = 30; }" dcl_id)
  (write-line "    }" dcl_id)
  (write-line "    : boxed_column {" dcl_id)
  (write-line "      label = \"Configuracion\";" dcl_id)
  (write-line "      : button { key = \"btn_config\"; label = \"Configurar Etiquetas\"; width = 30; }" dcl_id)
  (write-line "    }" dcl_id)
  (write-line "    : row {" dcl_id)
  (write-line "      : button { key = \"btn_ayuda\"; label = \"Ayuda\"; width = 15; }" dcl_id)
  (write-line "      : button { key = \"btn_salir\"; label = \"Salir\"; width = 15; is_cancel = true; }" dcl_id)
  (write-line "    }" dcl_id)
  (write-line "  }" dcl_id)
  (write-line "}" dcl_id)
  (close dcl_id)
  (setq dcl_id (load_dialog dcl_file))
  (if (not (new_dialog "ECN" dcl_id))
    (progn
      (princ "\nError al cargar el dialogo.")
      (setq result 0)
    )
    (progn
      (action_tile "btn_propagacion" "(setq result 1) (done_dialog)")
      (action_tile "btn_manual" "(setq result 2) (done_dialog)")
      (action_tile "btn_etiquetas" "(setq result 3) (done_dialog)")
      (action_tile "btn_etiquetamanual" "(setq result 4) (done_dialog)")
      (action_tile "btn_recolor" "(setq result 5) (done_dialog)")
      (action_tile "btn_limpiar" "(setq result 6) (done_dialog)")
      (action_tile "btn_deshacer" "(setq result 7) (done_dialog)")
      (action_tile "btn_quitar" "(setq result 8) (done_dialog)")
      (action_tile "btn_config" "(setq result 9) (done_dialog)")
      (action_tile "btn_ayuda" "(setq result 10) (done_dialog)")
      (action_tile "btn_duplicados" "(setq result 11) (done_dialog)")
      (action_tile "btn_salir" "(setq result 0) (done_dialog)")
      (setq result 0)
      (start_dialog)
    )
  )
  (unload_dialog dcl_id)
  (vl-file-delete dcl_file)
  result
)

;;; ===========================================================
;;; ECN - COMANDO PRINCIPAL
;;; ===========================================================

(defun c:ECN (/ result)
  (setq result (ECN-DCL))
  (cond
    ((= result 1) (c:ECN-P))
    ((= result 2) (c:ECN-M))
    ((= result 3) (c:ECN-ETIQ))
    ((= result 4) (c:ECN-ETIQM))
    ((= result 5) (c:ECN-RECOLOR))
    ((= result 6) (c:ECN-LIMPIA))
    ((= result 7) (c:ECN-DESHACER))
    ((= result 8) (c:ECN-QUITAR))
    ((= result 9) (c:ECN-CONFIG))
    ((= result 10) 
     (princ "\nECN v9.0 - Elevacion Curvas de Nivel")
     (princ "\n  ECN-P           - Propagacion por Clic")
     (princ "\n  ECN-M           - Metodo Manual")
     (princ "\n  ECN-ETIQ        - Etiquetas Automaticas (con intervalo)")
     (princ "\n  ECN-ETIQM       - Etiqueta Manual (con intervalo)")
     (princ "\n  ECN-RECOLOR     - Colorear por Elevacion")
     (princ "\n  ECN-LIMPIA      - Restaurar Colores")
     (princ "\n  ECN-DESHACER    - Deshacer Elevaciones")
     (princ "\n  ECN-QUITAR      - Quitar etiquetas")
     (princ "\n  ECN-DUPLICADOS  - Limpiar etiquetas duplicadas")
     (princ "\n  ECN-CONFIG      - Configurar parametros")
     (princ "\n  ECN-LISTA       - Lista de capas")
     (princ "\n  ETM             - Atajo para ECN-ETIQM")
    )
    ((= result 11) (c:ECN-DUPLICADOS))
    (T (princ "\nOperacion cancelada."))
  )
  (princ)
)

;;; ===========================================================
;;; CARGA
;;; ===========================================================

(princ "\nOK ECN v9.0 cargado")
(princ "\n   - Elevacion Curvas de Nivel")
(princ "\n   - Un solo clic: elevar + etiquetar")
(princ "\n   - Cobertura tipo CivilCAD (background fill)")
(princ "\n   - Elimina etiquetas duplicadas automaticamente")
(princ "\n   - ECN-ETIQ  con intervalo configurable")
(princ "\n   - ECN-ETIQM con intervalo configurable")
(princ "\n   - Colorear por Elevacion")
(princ "\n   Comandos:")
(princ "\n     ECN               - Menu principal (DCL)")
(princ "\n     ECN-P             - Propagacion por Clic")
(princ "\n     ECN-M             - Metodo Manual")
(princ "\n     ECN-ETIQ          - Etiquetas Automaticas (con intervalo)")
(princ "\n     ECN-ETIQM         - Etiqueta Manual (con intervalo)")
(princ "\n     ECN-RECOLOR       - Colorear por Elevacion")
(princ "\n     ECN-DUPLICADOS    - Limpiar etiquetas duplicadas")
(princ "\n     ECN-CONFIG        - Configurar parametros")
(princ "\n     ETM               - Atajo para ECN-ETIQM")
(princ)