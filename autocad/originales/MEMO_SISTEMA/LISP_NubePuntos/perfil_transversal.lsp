;;; ============================================================
;;; seccion_transversal.lsp
;;; Rutina LISP para AutoCAD
;;; Genera secciones transversales batimetricas con reticula.
;;; - Distancias centradas en 0 (positivas a la derecha, negativas a la izquierda)
;;; - Calculo de area entre la seccion y la elevacion de referencia
;;; - Soporte multiples lineas con deteccion automatica de estacion
;;; - Organizacion en columnas
;;; ============================================================
;;; Uso: Cargar el archivo y ejecutar PERFIL
;;; ============================================================

;;; --------------------------------------------------------
;;; Buscar texto de estacion cerca de los EXTREMOS de una linea
;;; --------------------------------------------------------
(defun buscar_estacion (p1 p2 lista_textos radio / 
  dx dy largo largo2 best_text best_dist item tpos vx vy dist_perp t_par d)
  
  (setq dx (- (car p2) (car p1)))
  (setq dy (- (cadr p2) (cadr p1)))
  (setq largo (sqrt (+ (* dx dx) (* dy dy))))
  (setq largo2 (* largo largo))
  
  (if (= largo 0.0)
    nil
    (progn
      (setq best_text nil)
      (setq best_dist 1e9)
      
      (foreach item lista_textos
        (setq tpos (car item))
        (setq vx (- (car tpos) (car p1)))
        (setq vy (- (cadr tpos) (cadr p1)))
        (setq dist_perp (/ (abs (- (* vx dy) (* vy dx))) largo))
        (setq t_par (/ (+ (* vx dx) (* vy dy)) largo2))
        
        (if (and (<= dist_perp radio) (>= t_par -0.15) (<= t_par 1.15))
          (progn
            (setq d (min (distance tpos p1) (distance tpos p2)))
            (if (< d best_dist)
              (progn
                (setq best_dist d)
                (setq best_text (cadr item))
              )
            )
          )
        )
      )
      best_text
    )
  )
)

;;; --------------------------------------------------------
;;; Convertir nombre de estacion a valor numerico para ordenamiento
;;; Formato: "KM+MMM.MM" -> KM*1000 + MMM.MM
;;; Ejemplo: "0+000.00" -> 0.0, "0+010.00" -> 10.0, "1+020.50" -> 1020.5
;;; --------------------------------------------------------
(defun estacion_a_numero (nombre / pos km m)
  (setq nombre (vl-string-trim " \t" nombre))
  (setq pos (vl-string-search "+" nombre))
  (if pos
    (progn
      (setq km (atof (substr nombre 1 pos)))
      (setq m (atof (substr nombre (+ pos 2))))
      (+ (* km 1000.0) m)
    )
    (atof nombre)
  )
)

;;; --------------------------------------------------------
;;; Calcular limites de la grilla horizontal (centrada en 0)
;;; Devuelve (list grid_min grid_max) donde grid_min <= 0, grid_max >= 0
;;; --------------------------------------------------------
(defun calc_grilla_X (datos_ordenados esp_reticula / 
  min_dist max_dist grid_min grid_max)
  
  (setq min_dist (car (car datos_ordenados)))
  (setq max_dist min_dist)
  (foreach d datos_ordenados
    (if (< (car d) min_dist) (setq min_dist (car d)))
    (if (> (car d) max_dist) (setq max_dist (car d)))
  )
  
  ;; Redondear al multiplo de espaciado
  (setq grid_min (* (fix (/ min_dist esp_reticula)) esp_reticula))
  (if (> grid_min min_dist) (setq grid_min (- grid_min esp_reticula)))
  
  (setq grid_max (* (fix (+ (/ max_dist esp_reticula) 0.999)) esp_reticula))
  (if (< grid_max max_dist) (setq grid_max (+ grid_max esp_reticula)))
  
  (list grid_min grid_max)
)

;;; --------------------------------------------------------
;;; Proyectar puntos sobre una linea.
;;; Las distancias se centran en 0 (positivas a la derecha,
;;; negativas a la izquierda respecto al centro de la linea).
;;; --------------------------------------------------------
(defun proyectar_puntos (p1 p2 ss_puntos ancho / 
  dx dy largo largo2 half_largo datos i ent_pto pt vx vy dot_val t_par dist_perp dist_centrada)
  
  (setq dx (- (car p2) (car p1)))
  (setq dy (- (cadr p2) (cadr p1)))
  (setq largo (distance p1 p2))
  (setq largo2 (* largo largo))
  (setq half_largo (/ largo 2.0))
  
  (setq datos nil)
  (setq i 0)
  (while (< i (sslength ss_puntos))
    (setq ent_pto (ssname ss_puntos i))
    (setq pt (cdr (assoc 10 (entget ent_pto))))
    
    (setq vx (- (car pt) (car p1)))
    (setq vy (- (cadr pt) (cadr p1)))
    (setq dot_val (+ (* vx dx) (* vy dy)))
    (setq t_par (/ dot_val largo2))
    (setq dist_perp (/ (abs (- (* vx dy) (* vy dx))) largo))
    
    (if (and (<= dist_perp ancho) (>= t_par 0.0) (<= t_par 1.0))
      (progn
        ;; Centrar: distancia desde el punto medio de la linea
        ;; Positivo hacia p2 (derecha), negativo hacia p1 (izquierda)
        (setq dist_centrada (- (* t_par largo) half_largo))
        (setq datos (cons (list dist_centrada (caddr pt)) datos))
      )
    )
    (setq i (1+ i))
  )
  
  (if datos
    (vl-sort datos (function (lambda (a b) (< (car a) (car b)))))
    nil
  )
)

;;; --------------------------------------------------------
;;; Calcular areas de corte (dragado) y relleno (deposito)
;;; entre la seccion y la elevacion de referencia.
;;; Regla del trapecio con separacion por signo de profundidad.
;;; Devuelve (list area_corte area_relleno)
;;; --------------------------------------------------------
(defun calc_areas (datos_ordenados elev_ref / 
  ac ar n d1 e1 d2 e2 h1 h2 j frac ancho_seg)
  
  (setq ac 0.0)  ; area de corte (perfil debajo de ref)
  (setq ar 0.0)  ; area de relleno (perfil sobre ref)
  (setq n (length datos_ordenados))
  (if (< n 2)
    (list 0.0 0.0)
    (progn
      (setq j 0)
      (while (< j (1- n))
        (setq d1 (car (nth j datos_ordenados)))
        (setq e1 (cadr (nth j datos_ordenados)))
        (setq d2 (car (nth (1+ j) datos_ordenados)))
        (setq e2 (cadr (nth (1+ j) datos_ordenados)))
        
        ;; Profundidad: positiva = bajo ref (corte), negativa = sobre ref (relleno)
        (setq h1 (- elev_ref e1))
        (setq h2 (- elev_ref e2))
        (setq ancho_seg (- d2 d1))
        
        (cond
          ;; Ambos bajo referencia: todo es corte
          ((and (>= h1 0.0) (>= h2 0.0))
           (setq ac (+ ac (* (/ (+ h1 h2) 2.0) ancho_seg))))
          ;; Ambos sobre referencia: todo es relleno
          ((and (< h1 0.0) (< h2 0.0))
           (setq ar (+ ar (* (/ (+ (abs h1) (abs h2)) 2.0) ancho_seg))))
          ;; Cruza la referencia (h1>0, h2<0): triangulo de corte
          ((and (> h1 0.0) (<= h2 0.0))
           (setq frac (/ h1 (- h1 h2)))
           (setq ac (+ ac (* 0.5 h1 ancho_seg frac)))
           (setq ar (+ ar (* 0.5 (abs h2) ancho_seg (- 1.0 frac)))))
          ;; Cruza la referencia (h1<0, h2>0): triangulo de relleno
          (T
           (setq frac (/ (abs h1) (+ (abs h1) h2)))
           (setq ar (+ ar (* 0.5 (abs h1) ancho_seg frac)))
           (setq ac (+ ac (* 0.5 h2 ancho_seg (- 1.0 frac)))))
        )
        
        (setq j (1+ j))
      )
      (list ac ar)
    )
  )
)

;;; --------------------------------------------------------
;;; Dibujar una seccion completa.
;;; Recibe datos ordenados (distancias centradas en 0) y punto base.
;;; Devuelve la altura utilizada y el area calculada.
;;; --------------------------------------------------------
(defun dibujar_seccion (datos_ordenados 
                         ancho escala_v esp_reticula elev_ref nombre base_pt / 
  largo minZ maxZ grilla ejeY_min ejeY_max
  origen_x perfil_base_y margen_izq margen_inf
  gy gy_dibujo gx_val px py sup_y lista_pline
  alto_total areas area_corte area_relleno area_txt_x area_txt_y
  grid_min grid_max grid_ancho)
  
  ;; Rango de profundidades
  (setq minZ (cadr (car datos_ordenados)))
  (setq maxZ minZ)
  (foreach d datos_ordenados
    (if (< (cadr d) minZ) (setq minZ (cadr d)))
    (if (> (cadr d) maxZ) (setq maxZ (cadr d)))
  )
  
  ;; Calcular areas de corte y relleno
  (setq areas (calc_areas datos_ordenados elev_ref))
  (setq area_corte (car areas))
  (setq area_relleno (cadr areas))
  
  ;; Limites de la grilla horizontal (centrada en 0)
  (setq grilla (calc_grilla_X datos_ordenados esp_reticula))
  (setq grid_min (car grilla))
  (setq grid_max (cadr grilla))
  (setq grid_ancho (- grid_max grid_min))
  
  ;; Limites de la grilla vertical
  ;; Cubrir desde el minimo (entre datos y ref) hasta el maximo
  (setq ejeY_min (min minZ elev_ref))
  (setq ejeY_max (max maxZ elev_ref 0.0))
  ;; Redondear al multiplo de espaciado
  (setq ejeY_min (* (fix (/ ejeY_min esp_reticula)) esp_reticula))
  (if (> ejeY_min (min minZ elev_ref)) (setq ejeY_min (- ejeY_min esp_reticula)))
  (setq ejeY_max (* (fix (/ ejeY_max esp_reticula)) esp_reticula))
  (if (< ejeY_max (max maxZ elev_ref 0.0)) (setq ejeY_max (+ ejeY_max esp_reticula)))
  
  ;; Margenes y origen
  ;; origen_x es el borde izquierdo de la grilla
  ;; Las distancias negativas caen a la izquierda del origen_x + abs(grid_min)
  (setq margen_izq 8.0)
  (setq margen_inf 3.0)
  (setq origen_x (+ (car base_pt) margen_izq))
  (setq perfil_base_y (+ (cadr base_pt) margen_inf))
  
  ;; ========================================================
  ;; Ejes principales
  ;; ========================================================
  ;; Eje horizontal inferior
  (entmake
    (list '(0 . "LINE") '(100 . "AcDbEntity") '(62 . 7)
          '(8 . "PERFIL_EJES") '(100 . "AcDbLine")
          (cons 10 (list origen_x perfil_base_y))
          (cons 11 (list (+ origen_x grid_ancho) perfil_base_y))))
  
  ;; Eje vertical izquierdo
  (entmake
    (list '(0 . "LINE") '(100 . "AcDbEntity") '(62 . 7)
          '(8 . "PERFIL_EJES") '(100 . "AcDbLine")
          (cons 10 (list origen_x perfil_base_y))
          (cons 11 (list origen_x (+ perfil_base_y 
            (* (- ejeY_max ejeY_min) escala_v))))))

  ;; ========================================================
  ;; Reticula vertical (distancias centradas en 0)
  ;; ========================================================
  (setq gx_val grid_min)
  (while (<= gx_val grid_max)
    ;; Linea de grilla
    (if (= gx_val 0.0)
      ;; La linea del 0 se dibuja blanca (eje) en vez de gris
      (progn
        (entmake
          (list '(0 . "LINE") '(100 . "AcDbEntity") '(62 . 7)
                '(8 . "PERFIL_EJES") '(100 . "AcDbLine")
                (cons 10 (list (+ origen_x (- gx_val grid_min)) perfil_base_y))
                (cons 11 (list (+ origen_x (- gx_val grid_min)) 
                  (+ perfil_base_y (* (- ejeY_max ejeY_min) escala_v))))))
        ;; Tick del 0 mas largo
        (entmake
          (list '(0 . "LINE") '(100 . "AcDbEntity") '(62 . 7)
                '(8 . "PERFIL_EJES") '(100 . "AcDbLine")
                (cons 10 (list (+ origen_x (- gx_val grid_min)) perfil_base_y))
                (cons 11 (list (+ origen_x (- gx_val grid_min)) (- perfil_base_y 2.0)))))
      )
      (progn
        (entmake
          (list '(0 . "LINE") '(100 . "AcDbEntity") '(62 . 252)
                '(8 . "PERFIL_RETICULA") '(100 . "AcDbLine")
                (cons 10 (list (+ origen_x (- gx_val grid_min)) perfil_base_y))
                (cons 11 (list (+ origen_x (- gx_val grid_min)) 
                  (+ perfil_base_y (* (- ejeY_max ejeY_min) escala_v))))))
        ;; Tick
        (entmake
          (list '(0 . "LINE") '(100 . "AcDbEntity") '(62 . 7)
                '(8 . "PERFIL_EJES") '(100 . "AcDbLine")
                (cons 10 (list (+ origen_x (- gx_val grid_min)) perfil_base_y))
                (cons 11 (list (+ origen_x (- gx_val grid_min)) (- perfil_base_y 1.5)))))
      )
    )
    ;; Etiqueta de distancia (valor real, puede ser negativo)
    (entmake
      (list '(0 . "TEXT") '(100 . "AcDbEntity") '(62 . 7)
            '(8 . "PERFIL_ETIQUETAS") '(100 . "AcDbText")
            (cons 10 (list (+ origen_x (- gx_val grid_min)) (- perfil_base_y 2.5)))
            (cons 40 1.2) (cons 1 (rtos gx_val 2 0))
            '(72 . 1)
            (cons 11 (list (+ origen_x (- gx_val grid_min)) (- perfil_base_y 2.5)))
            '(73 . 0)))
    (setq gx_val (+ gx_val esp_reticula))
  )

  ;; ========================================================
  ;; Reticula horizontal (elevaciones)
  ;; ========================================================
  (setq gy ejeY_min)
  (while (<= gy ejeY_max)
    (setq gy_dibujo (+ perfil_base_y (* (- gy ejeY_min) escala_v)))
    (entmake
      (list '(0 . "LINE") '(100 . "AcDbEntity") '(62 . 252)
            '(8 . "PERFIL_RETICULA") '(100 . "AcDbLine")
            (cons 10 (list origen_x gy_dibujo))
            (cons 11 (list (+ origen_x grid_ancho) gy_dibujo))))
    (entmake
      (list '(0 . "LINE") '(100 . "AcDbEntity") '(62 . 7)
            '(8 . "PERFIL_EJES") '(100 . "AcDbLine")
            (cons 10 (list origen_x gy_dibujo))
            (cons 11 (list (- origen_x 1.0) gy_dibujo))))
    ;; Etiqueta de elevacion (solo numero, sin "m")
    (entmake
      (list '(0 . "TEXT") '(100 . "AcDbEntity") '(62 . 7)
            '(8 . "PERFIL_ETIQUETAS") '(100 . "AcDbText")
            (cons 10 (list (- origen_x 1.5) gy_dibujo))
            (cons 40 1.2) (cons 1 (rtos gy 2 1))
            '(72 . 2)
            (cons 11 (list (- origen_x 1.5) gy_dibujo))
            '(73 . 0)))
    (setq gy (+ gy esp_reticula))
  )

  ;; ========================================================
  ;; Linea de superficie (elevacion de referencia)
  ;; ========================================================
  ;; La linea de referencia se dibuja en la posicion de elev_ref (no en ejeY_max)
  (setq sup_y (+ perfil_base_y (* (- elev_ref ejeY_min) escala_v)))
  (entmake
    (list '(0 . "LINE") '(100 . "AcDbEntity") '(62 . 2)
          '(8 . "PERFIL_REF") '(100 . "AcDbLine")
          (cons 10 (list origen_x sup_y))
          (cons 11 (list (+ origen_x grid_ancho) sup_y))))
  (entmake
    (list '(0 . "TEXT") '(100 . "AcDbEntity") '(62 . 2)
          '(8 . "PERFIL_ETIQUETAS") '(100 . "AcDbText")
          (cons 10 (list (+ origen_x grid_ancho 1.5) sup_y))
          (cons 40 1.2) (cons 1 (strcat "Elev. " (rtos elev_ref 2 2))) '(72 . 0)))

  ;; ========================================================
  ;; Polilinea del lecho (distancias centradas en 0)
  ;; ========================================================
  (setq lista_pline nil)
  (foreach dato datos_ordenados
    (setq lista_pline 
      (cons (list 
              ;; X en dibujo = origen + (distancia_centrada - grid_min)
              (+ origen_x (- (car dato) grid_min))
              (+ perfil_base_y (* (- (cadr dato) ejeY_min) escala_v)))
            lista_pline)))
  (setq lista_pline (reverse lista_pline))
  
  (entmake
    (append
      (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity") '(62 . 4)
            '(8 . "PERFIL_LECHO") '(100 . "AcDbPolyline")
            (cons 90 (length lista_pline)) '(70 . 0))
      (mapcar (function (lambda (p) (cons 10 p))) lista_pline)))

  ;; ========================================================
  ;; Lineas verticales y etiquetas de profundidad (verdes, rotadas 90)
  ;; ========================================================
  (foreach dato datos_ordenados
    (setq px (+ origen_x (- (car dato) grid_min)))
    (setq py (+ perfil_base_y (* (- (cadr dato) ejeY_min) escala_v)))
    (entmake
      (list '(0 . "LINE") '(100 . "AcDbEntity") '(62 . 8)
            '(8 . "PERFIL_AUX") '(100 . "AcDbLine")
            (cons 10 (list px sup_y))
            (cons 11 (list px py))))
    ;; Etiqueta verde rotada 90 sobre el perfil
    (entmake
      (list '(0 . "TEXT") '(100 . "AcDbEntity") '(62 . 3)
            '(8 . "PERFIL_ETIQUETAS") '(100 . "AcDbText")
            (cons 10 (list (+ px 0.8) py))
            (cons 40 0.9) (cons 50 (/ pi 2.0))
            (cons 1 (rtos (cadr dato) 2 2))
            '(72 . 0)
            (cons 11 (list (+ px 0.8) py))
            '(73 . 0)))
  )

  ;; ========================================================
  ;; Etiqueta de AREA dentro de la reticula, extremo inferior derecho
  ;; ========================================================
  (setq area_txt_x (- (+ origen_x grid_ancho) 2.0))
  (setq area_txt_y (+ perfil_base_y 2.0))
  ;; Linea 1: Area de dragado (corte)
  (entmake
    (list '(0 . "TEXT") '(100 . "AcDbEntity") '(62 . 1)
          '(8 . "PERFIL_ETIQUETAS") '(100 . "AcDbText")
          (cons 10 (list area_txt_x area_txt_y))
          (cons 40 1.3)
          (cons 1 (strcat "A dragado = " (rtos area_corte 2 2) " m2"))
          '(72 . 2)
          (cons 11 (list area_txt_x area_txt_y))
          '(73 . 0)))
  ;; Linea 2: Area de deposito (relleno), solo si existe
  (if (> area_relleno 0.001)
    (entmake
      (list '(0 . "TEXT") '(100 . "AcDbEntity") '(62 . 30)
            '(8 . "PERFIL_ETIQUETAS") '(100 . "AcDbText")
            (cons 10 (list area_txt_x (- area_txt_y 2.0)))
            (cons 40 1.3)
            (cons 1 (strcat "A deposito = " (rtos area_relleno 2 2) " m2"))
            '(72 . 2)
            (cons 11 (list area_txt_x (- area_txt_y 2.0)))
            '(73 . 0)))
  )

  ;; ========================================================
  ;; Titulo de seccion y datos tecnicos
  ;; ========================================================
  (entmake
    (list '(0 . "TEXT") '(100 . "AcDbEntity") '(62 . 7)
          '(8 . "PERFIL_ETIQUETAS") '(100 . "AcDbText")
          (cons 10 (list (+ origen_x (/ grid_ancho 2.0))
                        (+ perfil_base_y (* (- ejeY_max ejeY_min) escala_v) 3.0)))
          (cons 40 2.0) 
          (cons 1 (strcat "SECCION  " nombre))
          '(72 . 1)
          (cons 11 (list (+ origen_x (/ grid_ancho 2.0))
                        (+ perfil_base_y (* (- ejeY_max ejeY_min) escala_v) 3.0)))
          '(73 . 0)))

  (entmake
    (list '(0 . "TEXT") '(100 . "AcDbEntity") '(62 . 7)
          '(8 . "PERFIL_ETIQUETAS") '(100 . "AcDbText")
          (cons 10 (list (+ origen_x (/ grid_ancho 2.0))
                        (+ perfil_base_y (* (- ejeY_max ejeY_min) escala_v) 1.0)))
          (cons 40 1.2)
          (cons 1 (strcat "Dragado: " (rtos area_corte 2 2) " m2"
                         (if (> area_relleno 0.001)
                           (strcat "  |  Deposito: " (rtos area_relleno 2 2) " m2")
                           "")
                         "  |  Escala V: " (rtos escala_v 2 1) "x  |  "
                         (itoa (length datos_ordenados)) " ptos"))
          '(72 . 1)
          (cons 11 (list (+ origen_x (/ grid_ancho 2.0))
                        (+ perfil_base_y (* (- ejeY_max ejeY_min) escala_v) 1.0)))
          '(73 . 0)))

  ;; ========================================================
  ;; Etiquetas de ejes
  ;; ========================================================
  (entmake
    (list '(0 . "TEXT") '(100 . "AcDbEntity") '(62 . 7)
          '(8 . "PERFIL_ETIQUETAS") '(100 . "AcDbText")
          (cons 10 (list (+ origen_x (/ grid_ancho 2.0)) (- perfil_base_y 4.5)))
          (cons 40 1.3) (cons 1 "Distancia (m)")
          '(72 . 1)
          (cons 11 (list (+ origen_x (/ grid_ancho 2.0)) (- perfil_base_y 4.5)))
          '(73 . 0)))

  (entmake
    (list '(0 . "TEXT") '(100 . "AcDbEntity") '(62 . 7)
          '(8 . "PERFIL_ETIQUETAS") '(100 . "AcDbText")
          (cons 10 (list (- origen_x 6.0)
                        (+ perfil_base_y (/ (* (- ejeY_max ejeY_min) escala_v) 2.0))))
          (cons 40 1.3) (cons 50 (/ pi 2.0))
          (cons 1 "Elevacion (m)")
          '(72 . 1)
          (cons 11 (list (- origen_x 6.0)
                        (+ perfil_base_y (/ (* (- ejeY_max ejeY_min) escala_v) 2.0))))
          '(73 . 0)))

  ;; --- Alto total de esta seccion ---
  (setq alto_total (+ 5.0
                      (* (- ejeY_max ejeY_min) escala_v)
                      5.0
                      3.0))
  alto_total
)

;;; ============================================================
;;; COMANDO PRINCIPAL: PERFIL
;;; ============================================================

;;; --- DCL incrustado (se escribe como archivo temporal) ---
(setq *perfil_dcl_str* (strcat
  "perfil_dlg : dialog {\n"
  "  label = \"PERFIL - Secciones Transversales Batimetricas\";\n"
  "  : column {\n"
  "    : boxed_column {\n"
  "      label = \"Parametros de Busqueda\";\n"
  "      : edit_box { label = \"Ancho de busqueda perpendicular:\"; key = \"ancho\"; edit_width = 12; value = \"5.0\"; }\n"
  "      : edit_box { label = \"Radio de busqueda texto estacion:\"; key = \"radio_texto\"; edit_width = 12; value = \"15.0\"; }\n"
  "    }\n"
  "    : boxed_column {\n"
  "      label = \"Escala y Reticula\";\n"
  "      : edit_box { label = \"Escala vertical:\"; key = \"escala_v\"; edit_width = 12; value = \"1.0\"; }\n"
  "      : edit_box { label = \"Espaciado de reticula:\"; key = \"esp_reticula\"; edit_width = 12; value = \"5.0\"; }\n"
  "      : edit_box { label = \"Elevacion de referencia:\"; key = \"elev_ref\"; edit_width = 12; value = \"0.0\"; }\n"
  "    }\n"
  "    : boxed_column {\n"
  "      label = \"Disposicion en Columnas\";\n"
  "      : edit_box { label = \"Espacio entre secciones:\"; key = \"esp_entre_sec\"; edit_width = 12; value = \"40.0\"; }\n"
  "      : edit_box { label = \"Secciones por columna:\"; key = \"sec_por_col\"; edit_width = 12; value = \"5\"; }\n"
  "    }\n"
  "  }\n"
  "  : row {\n"
  "    : button { label = \"Aceptar\"; key = \"aceptar\"; width = 12; fixed_width = true; is_default = true; }\n"
  "    : button { label = \"Cancelar\"; key = \"cancelar\"; width = 12; fixed_width = true; is_cancel = true; }\n"
  "  }\n"
  "}"
))

(defun c:PERFIL ( / 
  ss_lineas ss_puntos ss_textos
  ancho escala_v esp_reticula elev_ref
  radio_texto esp_entre_secciones sec_por_col
  base_pt offset_x offset_y
  lista_textos lista_secciones sec
  idx ent_linea p1 p2
  nombre datos_ordenados
  i ent_pto pt vx vy
  alto_seccion
  col_idx col_num ancho_col max_ancho_grilla
  fname archivo grilla_tmp areas_exp
  total_secciones
  dcl_id dlg_stat dcl_tmp fp)
  
  (vl-load-com)

  ;; ========================================================
  ;; INTERFAZ GRAFICA (DCL incrustado)
  ;; ========================================================
  ;; Escribir el DCL como archivo temporal
  (setq dcl_tmp (strcat (getvar "TEMPPREFIX") "perfil_dialog.dcl"))
  (setq fp (open dcl_tmp "w"))
  (if (not fp)
    (progn
      (alert "Error: no se pudo crear archivo temporal para el dialogo.")
      (vl-exit-with-error "")
    )
  )
  (write-line *perfil_dcl_str* fp)
  (close fp)

  (setq dcl_id (load_dialog dcl_tmp))
  (if (< dcl_id 0)
    (progn
      (alert "Error al cargar el dialogo DCL.")
      (vl-exit-with-error "")
    )
  )
  (if (not (new_dialog "perfil_dlg" dcl_id))
    (progn
      (alert "Error al inicializar el dialogo.")
      (unload_dialog dcl_id)
      (vl-exit-with-error "")
    )
  )
  ;; Accion: Aceptar - capturar valores antes de cerrar
  (action_tile "aceptar"
    "(progn
       (setq *p_ancho* (get_tile \"ancho\"))
       (setq *p_escala_v* (get_tile \"escala_v\"))
       (setq *p_esp_reticula* (get_tile \"esp_reticula\"))
       (setq *p_elev_ref* (get_tile \"elev_ref\"))
       (setq *p_radio_texto* (get_tile \"radio_texto\"))
       (setq *p_esp_entre_sec* (get_tile \"esp_entre_sec\"))
       (setq *p_sec_por_col* (get_tile \"sec_por_col\"))
       (done_dialog 1))")
  ;; Accion: Cancelar
  (action_tile "cancelar" "(done_dialog 0)")
  ;; Mostrar dialogo
  (setq dlg_stat (start_dialog))
  (unload_dialog dcl_id)
  ;; Borrar archivo temporal
  (vl-file-delete dcl_tmp)

  (if (= dlg_stat 0)
    (vl-exit-with-error "")
  )

  ;; Leer valores capturados del dialogo
  (setq ancho (atof *p_ancho*))
  (if (= ancho 0.0) (setq ancho 10.0))
  (setq escala_v (atof *p_escala_v*))
  (if (= escala_v 0.0) (setq escala_v 1.0))
  (setq esp_reticula (atof *p_esp_reticula*))
  (if (= esp_reticula 0.0) (setq esp_reticula 5.0))
  (setq elev_ref (atof *p_elev_ref*))
  (setq radio_texto (atof *p_radio_texto*))
  (if (= radio_texto 0.0) (setq radio_texto 15.0))
  (setq esp_entre_secciones (atof *p_esp_entre_sec*))
  (if (= esp_entre_secciones 0.0) (setq esp_entre_secciones 40.0))
  (setq sec_por_col (atoi *p_sec_por_col*))
  (if (= sec_por_col 0) (setq sec_por_col 5))
  ;; Limpiar variables globales
  (setq *p_ancho* nil *p_escala_v* nil *p_esp_reticula* nil
        *p_elev_ref* nil *p_radio_texto* nil *p_esp_entre_sec* nil
        *p_sec_por_col* nil)

  ;; ========================================================
  ;; SELECCION DE ENTIDADES
  ;; ========================================================
  (prompt "\nSeleccione las LINEAS de seccion transversal: ")
  (setq ss_lineas (ssget '((0 . "LINE"))))
  (if (not ss_lineas)
    (vl-exit-with-error ""))
  
  (prompt "\nSeleccione los PUNTOS de sondeo: ")
  (setq ss_puntos (ssget '((0 . "POINT"))))
  (if (not ss_puntos)
    (vl-exit-with-error ""))
  
  ;; Recopilar TEXT y MTEXT del dibujo
  (setq ss_textos (ssget "X" '((0 . "TEXT"))))
  (setq lista_textos nil)
  (if ss_textos
    (progn
      (setq i 0)
      (while (< i (sslength ss_textos))
        (setq ent_pto (ssname ss_textos i))
        (setq pt (cdr (assoc 10 (entget ent_pto))))
        (setq lista_textos 
          (cons (list (list (car pt) (cadr pt)) 
                      (cdr (assoc 1 (entget ent_pto))))
                lista_textos))
        (setq i (1+ i))
      )
    )
  )
  (setq ss_textos (ssget "X" '((0 . "MTEXT"))))
  (if ss_textos
    (progn
      (setq i 0)
      (while (< i (sslength ss_textos))
        (setq ent_pto (ssname ss_textos i))
        (setq pt (cdr (assoc 10 (entget ent_pto))))
        (setq lista_textos 
          (cons (list (list (car pt) (cadr pt))
                      (cdr (assoc 1 (entget ent_pto))))
                lista_textos))
        (setq i (1+ i))
      )
    )
  )
  
  (prompt (strcat "\nTextos encontrados en el dibujo: " 
                   (itoa (length lista_textos))))

  ;; ========================================================
  ;; RECOPILAR Y ORDENAR SECCIONES POR ESTACION
  ;; Solo se almacena (sort_key idx nombre) — los puntos se
  ;; re-extraen del selection set al procesar para evitar
  ;; corruption por vl-sort (que es destructivo).
  ;; ========================================================
  (setq lista_secciones nil)
  (setq idx 0)
  (setq total_secciones (sslength ss_lineas))
  (while (< idx total_secciones)
    (setq ent_linea (ssname ss_lineas idx))
    (setq p1 (cdr (assoc 10 (entget ent_linea))))
    (setq p2 (cdr (assoc 11 (entget ent_linea))))
    (setq nombre (buscar_estacion p1 p2 lista_textos radio_texto))
    (if (not nombre)
      (setq nombre (strcat "Sec-" (itoa (1+ idx)))))
    (setq lista_secciones
      (cons (list (estacion_a_numero nombre) idx nombre) lista_secciones))
    (setq idx (1+ idx))
  )
  ;; Ordenar por valor numerico de estacion (menor primero)
  (setq lista_secciones
    (vl-sort lista_secciones
      (function (lambda (a b) (< (car a) (car b))))))
  (setq total_secciones (length lista_secciones))
  (prompt (strcat "\nSecciones ordenadas: " (itoa total_secciones)))

  ;; ========================================================
  ;; PRE-CALCULAR ANCHO DE COLUMNA
  ;; ========================================================
  (setq max_ancho_grilla 0.0)
  (foreach sec lista_secciones
    (setq idx (cadr sec))
    (setq ent_linea (ssname ss_lineas idx))
    (setq p1 (cdr (assoc 10 (entget ent_linea))))
    (setq p2 (cdr (assoc 11 (entget ent_linea))))
    (setq datos_ordenados (proyectar_puntos p1 p2 ss_puntos ancho))
    (if datos_ordenados
      (progn
        (setq grilla_tmp (calc_grilla_X datos_ordenados esp_reticula))
        (setq i (- (cadr grilla_tmp) (car grilla_tmp)))
        (if (> i max_ancho_grilla) (setq max_ancho_grilla i))
      )
    )
  )
  (setq ancho_col (+ 8.0 max_ancho_grilla 15.0))

  ;; ========================================================
  ;; PROCESAR CADA SECCION (en orden de estacion)
  ;; ========================================================
  (setq base_pt (getpoint "\nPunto base para la primera seccion: "))
  (if (not base_pt)
    (vl-exit-with-error ""))
  
  (setq offset_x 0.0)
  (setq offset_y 0.0)
  (setq col_idx 0)
  (setq col_num 0)
  
  (foreach sec lista_secciones
    (setq nombre (caddr sec))
    (setq idx (cadr sec))
    (setq ent_linea (ssname ss_lineas idx))
    (setq p1 (cdr (assoc 10 (entget ent_linea))))
    (setq p2 (cdr (assoc 11 (entget ent_linea))))
    
    (prompt (strcat "\nProcesando: " nombre))
    
    ;; Proyectar puntos (centrados en 0)
    (setq datos_ordenados (proyectar_puntos p1 p2 ss_puntos ancho))
    
    (if (not datos_ordenados)
      (prompt "  -> Sin puntos, se salta.")
      (progn
        (setq alto_seccion
          (dibujar_seccion datos_ordenados
                          ancho escala_v esp_reticula elev_ref nombre
                          (list (+ (car base_pt) offset_x)
                                (+ (cadr base_pt) offset_y))))
        
        (setq offset_y (+ offset_y alto_seccion esp_entre_secciones))
        (setq col_idx (1+ col_idx))
        
        (if (>= col_idx sec_por_col)
          (progn
            (setq col_idx 0)
            (setq col_num (1+ col_num))
            (setq offset_x (+ offset_x ancho_col))
            (setq offset_y 0.0)
            (prompt (strcat "  -> Columna " (itoa (1+ col_num))))
          )
        )
        
        (prompt (strcat "  -> " (itoa (length datos_ordenados)) " puntos."))
      )
    )
  )
  
  ;; ========================================================
  ;; EXPORTAR DATOS (en orden de estacion)
  ;; ========================================================
  (setq fname (getfiled "Exportar secciones como" "C:/" "txt" 1))
  (if fname
    (progn
      (setq archivo (open fname "w"))
      
      (foreach sec lista_secciones
        (setq nombre (caddr sec))
        (setq idx (cadr sec))
        (setq ent_linea (ssname ss_lineas idx))
        (setq p1 (cdr (assoc 10 (entget ent_linea))))
        (setq p2 (cdr (assoc 11 (entget ent_linea))))
        
        (setq datos_ordenados (proyectar_puntos p1 p2 ss_puntos ancho))
        
        (if datos_ordenados
          (progn
            (write-line (strcat "=== " nombre " ===") archivo)
            (setq areas_exp (calc_areas datos_ordenados elev_ref))
            (write-line (strcat "Dragado: " (rtos (car areas_exp) 2 2) " m2") archivo)
            (if (> (cadr areas_exp) 0.001)
              (write-line (strcat "Deposito: " (rtos (cadr areas_exp) 2 2) " m2") archivo)
            )
            (foreach dato datos_ordenados
              (write-line (strcat (rtos (car dato) 2 4) "\t"
                                 (rtos (cadr dato) 2 4)) archivo)
            )
            (write-line "" archivo)
          )
        )
      )
      
      (close archivo)
      (prompt (strcat "\nSecciones exportadas a: " fname))
    )
  )
  
  ;; ========================================================
  ;; RESUMEN
  ;; ========================================================
  (prompt "\n--- Resumen ---")
  (prompt (strcat "\nLineas procesadas: " (itoa total_secciones)))
  (prompt (strcat "\nSecciones por columna: " (itoa sec_por_col)))
  (prompt (strcat "\nColumnas generadas: " (itoa (1+ col_num))))
  (prompt (strcat "\nAncho de columna: " (rtos ancho_col 2 1)))
  (prompt "\nCapas: PERFIL_EJES, PERFIL_RETICULA, PERFIL_LECHO, PERFIL_AUX, PERFIL_ETIQUETAS, PERFIL_REF")
  (prompt "\n--- Secciones transversales completadas ---\n")
  
  (princ)
)

(princ "\n=== Rutina cargada. Ejecute PERFIL para generar secciones transversales. ===")
(princ)