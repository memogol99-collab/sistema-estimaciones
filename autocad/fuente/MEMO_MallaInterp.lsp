;;; =====================================================================
;;;  MEMO_MallaInterp.lsp - Interpolación ENTRE curvas de nivel
;;;  (se agrega al inicio de MP_MallaPuntos.lsp al construir el bundle)
;;;
;;;  Método anterior (IDW): promediaba todas las curvas "cercanas" con
;;;  peso 1/d². Daba escalones junto a cada curva, dejaba huecos cuando
;;;  las curvas estaban separadas más de ~20 m y curvas lejanas de otros
;;;  niveles se colaban en el promedio.
;;;
;;;  Método nuevo (ENTRECURVAS), como CivilCAD:
;;;   1. Busca la curva más cercana al punto (z1, distancia d1).
;;;   2. Busca la curva más cercana del OTRO LADO del punto con otra
;;;      elevación (z2, d2).
;;;   3. z = z1 + (z2 - z1) * d1 / (d1 + d2)   (lineal entre las dos)
;;;   En cimas, fondos y bordes (no hay curva del otro lado) toma z1.
;;;  Usa la distancia a los SEGMENTOS (no sólo a los vértices) y un índice
;;;  por celdas para no revisar todas las curvas en cada punto.
;;;
;;;  MEMO_CONFIG:
;;;   MALLA_METODO  ENTRECURVAS (defecto) o IDW (el método anterior)
;;;   MALLA_RADIO   distancia máxima de búsqueda; 0 = automática
;;; =====================================================================

;;; Distancia de p al segmento (x1 y1 x2 y2 ...) -> (d qx qy)
(defun mpi:dist-seg (px py seg / ax ay bx by dx dy l2 tt qx qy)
  (setq ax (nth 0 seg) ay (nth 1 seg) bx (nth 2 seg) by (nth 3 seg)
        dx (- bx ax) dy (- by ay)
        l2 (+ (* dx dx) (* dy dy)))
  (if (< l2 1e-12)
    (setq qx ax qy ay)
    (progn
      (setq tt (/ (+ (* (- px ax) dx) (* (- py ay) dy)) (float l2)))
      (if (< tt 0.0) (setq tt 0.0))
      (if (> tt 1.0) (setq tt 1.0))
      (setq qx (+ ax (* tt dx)) qy (+ ay (* tt dy)))
    )
  )
  (list (sqrt (+ (* (- px qx) (- px qx)) (* (- py qy) (- py qy)))) qx qy)
)

;;; Celda (ix iy) -> lista de segmentos
(defun mpi:celda (ix iy / fila)
  (if (setq fila (cdr (assoc iy mpi:*filas*)))
    (cdr (assoc ix fila))
  )
)

;;; Celdas del anillo r alrededor de (cx cy), sólo las que existen
(defun mpi:anillo (cx cy r / res ix iy)
  (if (= r 0)
    (setq res (list (list cx cy)))
    (progn
      (setq ix (- cx r))
      (while (<= ix (+ cx r))
        (setq res (cons (list ix (- cy r)) (cons (list ix (+ cy r)) res))
              ix (1+ ix))
      )
      (setq iy (1+ (- cy r)))
      (while (< iy (+ cy r))
        (setq res (cons (list (- cx r) iy) (cons (list (+ cx r) iy) res))
              iy (1+ iy))
      )
    )
  )
  res
)

;;; Prepara la interpolación (llamado una vez por MALLA-PUNTOS)
(defun mpi:preparar (contour-data)
  (setq mpi:*metodo* (mpi:metodo))
  (if (/= mpi:*metodo* "IDW")
    (mpi:construir-indice contour-data)
    0
  )
)

;;; Construye el índice a partir de contour-data: ((z verts cerrada) ...)
(defun mpi:construir-indice (contour-data / id v a lsum nseg trip seg x0 x1 y0 y1
                                    ix ix1 iy iy1 diag ord filas fila celda
                                    iyact ixact radio)
  (setq id 0 mpi:*segs* nil lsum 0.0 nseg 0
        mpi:*x0* 1e99 mpi:*y0* 1e99 mpi:*xmax* -1e99 mpi:*ymax* -1e99)
  ;; 1. Segmentos (x1 y1 x2 y2 z id)
  (foreach c contour-data
    (setq id (1+ id) v (cadr c))
    (if (and (caddr c) (> (length v) 2)) (setq v (append v (list (car v)))))
    (if (= (length v) 1) (setq v (list (car v) (car v))))
    (setq a (car v) v (cdr v))
    (foreach b v
      (setq mpi:*segs* (cons (list (car a) (cadr a) (car b) (cadr b) (car c) id) mpi:*segs*)
            lsum (+ lsum (distance (list (car a) (cadr a)) (list (car b) (cadr b))))
            nseg (1+ nseg)
            mpi:*x0* (min mpi:*x0* (car a) (car b)) mpi:*xmax* (max mpi:*xmax* (car a) (car b))
            mpi:*y0* (min mpi:*y0* (cadr a) (cadr b)) mpi:*ymax* (max mpi:*ymax* (cadr a) (cadr b))
            a b)
    )
  )
  ;; 2. Tamaño de celda
  (setq diag (distance (list mpi:*x0* mpi:*y0*) (list mpi:*xmax* mpi:*ymax*)))
  (if (< diag 1e-6) (setq diag 1.0))
  (setq mpi:*s* (max (/ diag 150.0) (if (> nseg 0) (/ lsum nseg) 0.0) 1e-3)
        mpi:*nx* (fix (/ (- mpi:*xmax* mpi:*x0*) mpi:*s*))
        mpi:*ny* (fix (/ (- mpi:*ymax* mpi:*y0*) mpi:*s*)))
  ;; 3. Índice: cada segmento va a las celdas de su rectángulo
  (setq trip nil)
  (foreach seg mpi:*segs*
    (setq x0 (min (nth 0 seg) (nth 2 seg)) x1 (max (nth 0 seg) (nth 2 seg))
          y0 (min (nth 1 seg) (nth 3 seg)) y1 (max (nth 1 seg) (nth 3 seg))
          ix1 (fix (/ (- x1 mpi:*x0*) mpi:*s*))
          iy (fix (/ (- y0 mpi:*y0*) mpi:*s*))
          iy1 (fix (/ (- y1 mpi:*y0*) mpi:*s*)))
    (while (<= iy iy1)
      (setq ix (fix (/ (- x0 mpi:*x0*) mpi:*s*)))
      (while (<= ix ix1)
        (setq trip (cons (list iy ix seg) trip) ix (1+ ix))
      )
      (setq iy (1+ iy))
    )
  )
  ;; ordenar por fila y columna y agrupar: ((iy (ix seg...) ...) ...)
  (setq ord (vl-sort trip '(lambda (p q) (if (= (car p) (car q)) (< (cadr p) (cadr q)) (< (car p) (car q)))))
        filas nil fila nil celda nil iyact nil ixact nil)
  (foreach t3 ord
    (if (/= (car t3) iyact)
      (progn
        (if celda (setq fila (cons (cons ixact (reverse celda)) fila)))
        (if fila (setq filas (cons (cons iyact (reverse fila)) filas)))
        (setq iyact (car t3) ixact (cadr t3) fila nil celda nil)
      )
    )
    (if (/= (cadr t3) ixact)
      (progn
        (if celda (setq fila (cons (cons ixact (reverse celda)) fila)))
        (setq ixact (cadr t3) celda nil)
      )
    )
    (setq celda (cons (caddr t3) celda))
  )
  (if celda (setq fila (cons (cons ixact (reverse celda)) fila)))
  (if fila (setq filas (cons (cons iyact (reverse fila)) filas)))
  (setq mpi:*filas* filas trip nil ord nil)
  ;; 4. Radio máximo de búsqueda
  (setq radio (if memo:cfg-num (memo:cfg-num "MALLA_RADIO") 0.0))
  (setq mpi:*rmax* (* 0.25 diag))
  (if (> radio 0.0)
    (setq mpi:*rmax* radio)
    (setq mpi:*rmax* (mpi:radio-auto mpi:*rmax*))
  )
  nseg
)

;;; Separación típica entre curvas (mediana de una muestra) x 3
(defun mpi:radio-auto (tope / paso i lista d n med)
  (setq paso (max 1 (/ (length mpi:*segs*) 150)) i 0 lista nil)
  (foreach seg mpi:*segs*
    (if (= (rem i paso) 0)
      (if (setq d (mpi:dist-otra-z (nth 0 seg) (nth 1 seg) (nth 4 seg) tope))
        (setq lista (cons d lista))
      )
    )
    (setq i (1+ i))
  )
  (if lista
    (progn
      (setq lista (vl-sort lista '<) n (length lista)
            med (nth (/ n 2) lista))
      (max (* 3.0 med) (* 2.0 mpi:*s*))
    )
    tope
  )
)

;;; Distancia desde (px py) a la curva más cercana con elevación /= z
(defun mpi:dist-otra-z (px py z tope / cx cy r mejor fin lim r3)
  (setq cx (fix (/ (- px mpi:*x0*) mpi:*s*)) cy (fix (/ (- py mpi:*y0*) mpi:*s*))
        r 0 fin nil mejor nil)
  (while (not fin)
    (foreach c (mpi:anillo cx cy r)
      (foreach seg (mpi:celda (car c) (cadr c))
        (if (not (equal (nth 4 seg) z 1e-9))
          (progn
            (setq r3 (car (mpi:dist-seg px py seg)))
            (if (or (null mejor) (< r3 mejor)) (setq mejor r3))
          )
        )
      )
    )
    (setq lim (* r mpi:*s*))
    (if (or (and mejor (<= mejor lim)) (> lim tope) (mpi:fuera-p cx cy r))
      (setq fin T))
    (setq r (1+ r))
  )
  mejor
)

;;; T si el anillo r ya cubre todo el índice
(defun mpi:fuera-p (cx cy r)
  (and (<= (- cx r) 0) (>= (+ cx r) mpi:*nx*)
       (<= (- cy r) 0) (>= (+ cy r) mpi:*ny*))
)

;;; Elevación por interpolación entre curvas, o nil si no hay curva cerca
(defun mpi:entre-curvas (pt / px py cx cy r fin cand seg res id prev lim
                              b1 b2 d z dx1 dy1 dx2 dy2 e)
  (setq px (car pt) py (cadr pt)
        cx (fix (/ (- px mpi:*x0*) mpi:*s*)) cy (fix (/ (- py mpi:*y0*) mpi:*s*))
        r 0 fin nil cand nil)
  (while (not fin)
    ;; cand: lista de (id d qx qy z) con la menor distancia por curva
    (foreach c (mpi:anillo cx cy r)
      (foreach seg (mpi:celda (car c) (cadr c))
        (setq res (mpi:dist-seg px py seg) id (nth 5 seg)
              prev (assoc id cand))
        (cond
          ((null prev)
           (setq cand (cons (list id (car res) (cadr res) (caddr res) (nth 4 seg)) cand)))
          ((< (car res) (cadr prev))
           (setq cand (subst (list id (car res) (cadr res) (caddr res) (nth 4 seg)) prev cand)))
        )
      )
    )
    (setq lim (* r mpi:*s*) b1 nil b2 nil)
    ;; b1 = curva más cercana
    (foreach e cand (if (or (null b1) (< (cadr e) (cadr b1))) (setq b1 e)))
    ;; b2 = la más cercana del otro lado y con otra elevación
    (if b1
      (progn
        (setq dx1 (- (caddr b1) px) dy1 (- (cadddr b1) py))
        (foreach e cand
          (if (not (equal (nth 4 e) (nth 4 b1) 1e-9))
            (progn
              (setq dx2 (- (caddr e) px) dy2 (- (cadddr e) py))
              (if (and (< (+ (* dx1 dx2) (* dy1 dy2)) 0.0)
                       (or (null b2) (< (cadr e) (cadr b2))))
                (setq b2 e))
            )
          )
        )
      )
    )
    ;; Todo segmento a menos de "lim" ya fue revisado, así que:
    (cond
      ((and b1 (< (cadr b1) 1e-6)) (setq fin T))                 ; sobre la curva
      ((and b2 (<= (cadr b2) lim)) (setq fin T))                 ; b1 y b2 definitivos
      ((and b1 (<= (cadr b1) lim) (> lim mpi:*rmax*)) (setq fin T)) ; no hay curva del otro lado
      ((> lim (* 2.0 mpi:*rmax*)) (setq fin T))                  ; lejos de todo
      ((mpi:fuera-p cx cy r) (setq fin T))
    )
    (setq r (1+ r))
  )
  (cond
    ((or (null b1) (> (cadr b1) (* 2.0 mpi:*rmax*))) nil)        ; sin curvas cerca: sin punto
    ((< (cadr b1) 1e-6) (nth 4 b1))
    (b2 (+ (nth 4 b1) (* (- (nth 4 b2) (nth 4 b1)) (/ (cadr b1) (+ (cadr b1) (cadr b2))))))
    (T (nth 4 b1))                                               ; cima, fondo o borde
  )
)

;;; IDW: exactamente el método anterior de MALLA-PUNTOS v4.7
(defun mpi:idw (pt prepared-curves power / sum_w sum_we elev verts is-closed cl-result d w)
  (setq sum_w 0.0 sum_we 0.0)
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
  (if (> sum_w 0.0) (/ sum_we sum_w))
)

(defun mpi:metodo ()
  (if (and memo:cfg (= (strcase (memo:cfg "MALLA_METODO")) "IDW")) "IDW" "ENTRECURVAS")
)

;;; Punto de entrada usado por MALLA-PUNTOS
(defun mpi:elevacion (pt prepared-curves power)
  (if (= mpi:*metodo* "IDW")
    (mpi:idw pt prepared-curves power)
    (mpi:entre-curvas pt)
  )
)
