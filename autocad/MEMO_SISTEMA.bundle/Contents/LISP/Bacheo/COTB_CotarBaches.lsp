;;; MEMO SISTEMA 2.0.0 - archivo generado por construir_bundle.py
;;; Origen: LISP_Estimaciones/COTAR_BACHES  (COTB ).lsp

(vl-load-com)
;; ===================================================================
;; COTAR_BACHES v2.1
;; ===================================================================
;; Rutina que anota el LARGO y ANCHO de cada rectángulo (bache)
;; en la capa "GEOMETRIA_RECTANGULOS", colocando un SOLO texto
;; de largo y un SOLO texto de ancho por rectángulo.
;;
;; CONFIGURACIÓN:
;;   - Capa origen:    GEOMETRIA_RECTANGULOS  (donde están los rects)
;;   - Capa destino:   COTAS_RECTANGULOS      (donde se crean los textos)
;;   - Estilo texto:   MONOTXT
;;   - Altura texto:   0.45
;;   - Relación A/H:   0.70
;;   - Precisión:      2 decimales (sin suprimir ceros)
;;
;; COMANDO: COTAR_BACHES
;;
;; NOTA: Cada vez que se ejecuta, elimina los textos existentes
;;       en la capa COTAS_RECTANGULOS y los recrea.
;;
;; v2.0: Correccion de justificacion vertical dinamica.
;;       Elige Superior/Inferior automaticamente para que el
;;       cuerpo del texto SIEMPRE quede fuera del rectangulo.
;; v2.1: Rotacion > 90 grados -> suma 180 para evitar texto volteado.
;; ===================================================================

(defun c:COTB ( /
  ;; -- Configuración ------------------------------------------
  layer_src layer_dst style_name text_h width_f offset_dist
  round_dec tol
  ;; -- Selección ----------------------------------------------
  ss ss_old j
  ;; -- Entidad ------------------------------------------------
  ent data pts z pt closed_flag
  ;; -- Geometría ----------------------------------------------
  d01 d12 d23 d30 lado_a lado_b
  largo ancho es_cuadrado
  p_l1 p_l2 p_a1 p_a2
  mid_l mid_a ang_l ang_a
  norm_l norm_a pos_l pos_a
  cx cy centroid
  ;; -- Texto --------------------------------------------------
  text_l text_a vjust_l vjust_a
  ;; -- Contadores ---------------------------------------------
  i n_rect n_skip
  ;; -- Temporales ---------------------------------------------
  old_cmdecho old_dimzin
  norm_ang top_body_dot
)

  ;; --------------------------------------------------------------
  ;;                    CONFIGURACIÓN
  ;; --------------------------------------------------------------
  (setq layer_src   "GEOMETRIA_RECTANGULOS")
  (setq layer_dst   "COTAS_RECTANGULOS")
  (setq style_name  "MONOTXT")
  (setq text_h      0.45)
  (setq width_f     0.70)
  (setq offset_dist 0.25)   ;; Separación del texto al borde
  (setq round_dec   2)       ;; Decimales
  (setq tol         0.01)    ;; Tolerancia para igualdad de lados

  ;; Guardar estado
  (setq old_cmdecho (getvar "CMDECHO"))
  (setq old_dimzin  (getvar "DIMZIN"))
  (setvar "CMDECHO" 0)
  (setvar "DIMZIN"  0)    ;; No suprimir ceros: "1.00" en vez de "1"

  (prompt "\n")
  (prompt "+----------------------------------------------------+")
  (prompt "\n¦       COTAR_BACHES v2.1 - Cotar Baches          ¦")
  (prompt "\n+----------------------------------------------------+")

  ;; --------------------------------------------------------------
  ;;         PASO 1: ELIMINAR TEXTOS EXISTENTES EN CAPA DESTINO
  ;; --------------------------------------------------------------
  (prompt (strcat "\nLimpiando textos previos en capa '" layer_dst "'..."))
  (setq ss_old (ssget "_X" (list '(0 . "*TEXT") (cons 8 layer_dst))))
  (if ss_old
    (progn
      (setq j 0)
      (while (< j (sslength ss_old))
        (entdel (ssname ss_old j))
        (setq j (1+ j))
      )
      (prompt (strcat "\n  Eliminados " (itoa (sslength ss_old)) " texto(s) anterior(es)."))
    )
    (prompt "\n  No hay textos previos que limpiar.")
  )

  ;; --------------------------------------------------------------
  ;;         PASO 2: CREAR CAPA DESTINO SI NO EXISTE
  ;; --------------------------------------------------------------
  (if (not (tblsearch "LAYER" layer_dst))
    (progn
      (entmake
        (list '(0 . "LAYER")
              '(100 . "AcDbSymbolTableRecord")
              '(100 . "AcDbLayerTableRecord")
              (cons 2 layer_dst)
              '(70 . 0)              ;; No congelada, no bloqueada
              '(62 . 7)              ;; Color blanco (7)
              '(6 . "CONTINUOUS")))  ;; Tipo de línea
      (prompt (strcat "\n  Creada capa '" layer_dst "'."))
    )
  )

  ;; --------------------------------------------------------------
  ;;         PASO 3: VERIFICAR ESTILO DE TEXTO
  ;; --------------------------------------------------------------
  (if (not (tblsearch "STYLE" style_name))
    (progn
      (prompt (strcat "\n  El estilo '" style_name "' no existe."))
      (prompt "\n  Intentando crear estilo con fuente simplex.shx...")
      (entmake
        (list '(0 . "STYLE")
              '(100 . "AcDbSymbolTableRecord")
              '(100 . "AcDbTextStyleTableRecord")
              (cons 2 style_name)
              '(70 . 0)          ;; No backward, no vertical
              '(40 . 0.0)        ;; Altura variable (se define al crear)
              '(41 . 1.0)        ;; Width factor default del estilo
              '(50 . 0.0)        ;; Angulo oblicuo
              '(71 . 0)          ;; Generation flags
              '(42 . 0.2)        ;; Ultima altura usada
              '(3 . "simplex.shx")  ;; Fuente
              '(4 . "")))        ;; Big font (ninguno)
      (if (tblsearch "STYLE" style_name)
        (prompt (strcat "\n  Creado estilo '" style_name "' con simplex.shx."))
        (prompt "\n  ERROR: No se pudo crear el estilo. Verifique permisos.")
      )
    )
  )

  ;; --------------------------------------------------------------
  ;;         PASO 4: SELECCIONAR RECTÁNGULOS
  ;; --------------------------------------------------------------
  (setq ss (ssget "_X" (list '(0 . "LWPOLYLINE") (cons 8 layer_src))))

  (if (not ss)
    (progn
      (prompt (strcat "\n\n  No se encontraron polilineas en la capa '"
                      layer_src "'."))
      (prompt (strcat "\n  Verifique que la capa exista y tenga objetos."))
      (setvar "CMDECHO" old_cmdecho)
      (setvar "DIMZIN"  old_dimzin)
      (princ)
      (exit)
    )
  )

  (prompt (strcat "\n  Encontrados " (itoa (sslength ss))
                  " objeto(s) en '" layer_src "'."))

  ;; --------------------------------------------------------------
  ;;         PASO 5: PROCESAR CADA RECTÁNGULO
  ;; --------------------------------------------------------------
  (setq i 0)
  (setq n_rect 0)
  (setq n_skip 0)

  (while (< i (sslength ss))
    (setq ent  (ssname ss i))
    (setq data (entget ent))

    ;; 5a. Verificar que sea polilinea CERRADA
    (setq closed_flag (cdr (assoc 70 data)))
    (if (/= (logand closed_flag 1) 1)
      (progn
        (prompt "\n  Advertencia: Polilinea no cerrada. Saltando.")
        (setq n_skip (1+ n_skip))
        (setq i (1+ i))
      ) ;; fin progn skip
      (progn ;; polilinea CERRADA -> procesar

        ;; 5b. Obtener elevación Z
        (setq z (cdr (assoc 38 data)))
        (if (null z) (setq z 0.0))

        ;; 5c. Extraer vértices y convertir de OCS a WCS
        (setq pts nil)
        (foreach item data
          (if (= (car item) 10)
            (progn
              (setq pt (list (cadr item) (caddr item) z))
              (setq pt (trans pt ent 0))   ;; OCS -> WCS
              (setq pts (cons pt pts))
            )
          )
        )
        (setq pts (reverse pts))

        ;; 5d. Procesar solo si tiene exactamente 4 vértices
        (if (/= (length pts) 4)
          (progn
            (setq n_skip (1+ n_skip))
          )
          (progn
            ;; --------------------------------------------------
            ;;  CALCULAR LADOS Y CENTROIDE
            ;; --------------------------------------------------
            (setq d01 (distance (nth 0 pts) (nth 1 pts)))
            (setq d12 (distance (nth 1 pts) (nth 2 pts)))
            (setq d23 (distance (nth 2 pts) (nth 3 pts)))
            (setq d30 (distance (nth 3 pts) (nth 0 pts)))

            (setq lado_a (/ (+ d01 d23) 2.0))
            (setq lado_b (/ (+ d12 d30) 2.0))

            (setq cx (/ (+ (car (nth 0 pts)) (car (nth 1 pts))
                           (car (nth 2 pts)) (car (nth 3 pts))) 4.0))
            (setq cy (/ (+ (cadr (nth 0 pts)) (cadr (nth 1 pts))
                           (cadr (nth 2 pts)) (cadr (nth 3 pts))) 4.0))
            (setq centroid (list cx cy))

            ;; --------------------------------------------------
            ;;  IDENTIFICAR LARGO vs ANCHO
            ;; --------------------------------------------------
            (if (< (abs (- lado_a lado_b)) tol)
              (progn
                (setq es_cuadrado T)
                (setq largo lado_a)
                (setq p_l1 (nth 0 pts) p_l2 (nth 1 pts))
              )
              (if (> lado_a lado_b)
                (progn
                  (setq es_cuadrado nil)
                  (setq largo lado_a  ancho lado_b)
                  (setq p_l1 (nth 0 pts) p_l2 (nth 1 pts))
                  (setq p_a1 (nth 1 pts) p_a2 (nth 2 pts))
                )
                (progn
                  (setq es_cuadrado nil)
                  (setq largo lado_b  ancho lado_a)
                  (setq p_l1 (nth 1 pts) p_l2 (nth 2 pts))
                  (setq p_a1 (nth 0 pts) p_a2 (nth 1 pts))
                )
              )
            )

            ;; --------------------------------------------------
            ;;  CREAR TEXTO DEL LARGO
            ;; --------------------------------------------------
            (setq mid_l (list (/ (+ (car p_l1) (car p_l2)) 2.0)
                              (/ (+ (cadr p_l1) (cadr p_l2)) 2.0)))
            (setq ang_l (angle p_l1 p_l2))
            ;; Corregir rotacion para que nunca quede boca abajo:
            ;; Normalizar a [0, 2*pi) y voltear si esta entre 90 y 270
            (while (< ang_l 0.0) (setq ang_l (+ ang_l (* 2.0 pi))))
            (while (>= ang_l (* 2.0 pi)) (setq ang_l (- ang_l (* 2.0 pi))))
            (if (and (>= ang_l (* 0.5 pi)) (< ang_l (* 1.5 pi)))
              (setq ang_l (+ ang_l pi))
            )
            ;; Normal apuntando hacia afuera
            (setq norm_l (CB:get-outward-normal p_l1 p_l2 centroid))
            ;; Posición del texto
            (setq pos_l (list (+ (car mid_l) (* (car norm_l) offset_dist))
                              (+ (cadr mid_l) (* (cadr norm_l) offset_dist))
                              0.0))
            ;; -- Justificación vertical DINÁMICA -------------
            ;; Verificar si el cuerpo del texto se extiende hacia
            ;; afuera o hacia adentro con justificación Superior (73=3).
            ;; Si se mete adentro, usar Inferior (73=0).
            (setq norm_ang (atan (cadr norm_l) (car norm_l)))
            (setq top_body_dot
              (+ (* (cos (- ang_l (/ pi 2.0))) (cos norm_ang))
                 (* (sin (- ang_l (/ pi 2.0))) (sin norm_ang))))
            (if (> top_body_dot 0.0)
              (setq vjust_l 3)   ;; Superior: cuerpo va hacia afuera
              (setq vjust_l 0)   ;; Inferior: cuerpo va hacia afuera
            )
            ;; Valor del texto (2 decimales, sin suprimir ceros)
            (setq text_l (rtos largo 2 round_dec))

            ;; Crear la entidad TEXT
            (entmake
              (list '(0 . "TEXT")
                    (cons 10 pos_l)
                    (cons 11 pos_l)
                    (cons 40 text_h)
                    (cons 41 width_f)
                    (cons 1  text_l)
                    (cons 50 ang_l)
                    (cons 7  style_name)
                    (cons 8  layer_dst)
                    '(72 . 1)              ;; Horizontal: Centro
                    (cons 73 vjust_l)))    ;; Vertical: dinámica

            ;; --------------------------------------------------
            ;;  CREAR TEXTO DEL ANCHO (solo si NO es cuadrado)
            ;; --------------------------------------------------
            (if (not es_cuadrado)
              (progn
                (setq mid_a (list (/ (+ (car p_a1) (car p_a2)) 2.0)
                                  (/ (+ (cadr p_a1) (cadr p_a2)) 2.0)))
                (setq ang_a (angle p_a1 p_a2))
                ;; Corregir rotacion para que nunca quede boca abajo:
                ;; Normalizar a [0, 2*pi) y voltear si esta entre 90 y 270
                (while (< ang_a 0.0) (setq ang_a (+ ang_a (* 2.0 pi))))
                (while (>= ang_a (* 2.0 pi)) (setq ang_a (- ang_a (* 2.0 pi))))
                (if (and (>= ang_a (* 0.5 pi)) (< ang_a (* 1.5 pi)))
                  (setq ang_a (+ ang_a pi))
                )
                (setq norm_a (CB:get-outward-normal p_a1 p_a2 centroid))
                (setq pos_a (list (+ (car mid_a) (* (car norm_a) offset_dist))
                                  (+ (cadr mid_a) (* (cadr norm_a) offset_dist))
                                  0.0))
                ;; -- Justificación vertical DINÁMICA ---------
                (setq norm_ang (atan (cadr norm_a) (car norm_a)))
                (setq top_body_dot
                  (+ (* (cos (- ang_a (/ pi 2.0))) (cos norm_ang))
                     (* (sin (- ang_a (/ pi 2.0))) (sin norm_ang))))
                (if (> top_body_dot 0.0)
                  (setq vjust_a 3)
                  (setq vjust_a 0)
                )
                ;; Valor del texto
                (setq text_a (rtos ancho 2 round_dec))

                ;; Crear la entidad TEXT
                (entmake
                  (list '(0 . "TEXT")
                        (cons 10 pos_a)
                        (cons 11 pos_a)
                        (cons 40 text_h)
                        (cons 41 width_f)
                        (cons 1  text_a)
                        (cons 50 ang_a)
                        (cons 7  style_name)
                        (cons 8  layer_dst)
                        '(72 . 1)
                        (cons 73 vjust_a)))
              )
            ) ;; fin if not cuadrado

            (setq n_rect (1+ n_rect))

          ) ;; fin progn 4 vértices
        ) ;; fin if 4 vértices

      ) ;; fin progn cerrada
    ) ;; fin if cerrada

    (setq i (1+ i))
  ) ;; fin while

  ;; --------------------------------------------------------------
  ;;                    RESULTADO FINAL
  ;; --------------------------------------------------------------
  (prompt "\n")
  (prompt (strcat "\n  Resultado: " (itoa n_rect) " rectangulo(s) cotado(s)."))
  (if (> n_skip 0)
    (prompt (strcat "\n  Omitidos: " (itoa n_skip)
                    " objeto(s) (no cerrados o sin 4 vertices)."))
  (prompt "\n")
  )

  ;; Restaurar estado
  (setvar "CMDECHO" old_cmdecho)
  (setvar "DIMZIN"  old_dimzin)
  (princ)
)


;; ===================================================================
;; FUNCIÓN AUXILIAR: CB:get-outward-normal
;; ===================================================================
;; Calcula la normal unitaria (2D) de un lado de polígono que apunta
;; HACIA AFUERA (alejada del centroide).
;; ===================================================================
(defun CB:get-outward-normal (p1 p2 centroid /
                               dx dy len nx1 ny1 nx2 ny2
                               mx my d1 d2)

  (setq dx (- (car p2) (car p1)))
  (setq dy (- (cadr p2) (cadr p1)))
  (setq len (sqrt (+ (* dx dx) (* dy dy))))
  (if (< len 1e-10) (setq len 1e-10))

  (setq nx1  (/  dy len))
  (setq ny1  (- (/ dx len)))
  (setq nx2  (- (/ dy len)))
  (setq ny2  (/  dx len))

  (setq mx (/ (+ (car p1) (car p2)) 2.0))
  (setq my (/ (+ (cadr p1) (cadr p2)) 2.0))

  (setq d1 (+ (* (- (+ mx nx1) (car centroid))
                 (- (+ mx nx1) (car centroid)))
              (* (- (+ my ny1) (cadr centroid))
                 (- (+ my ny1) (cadr centroid)))))
  (setq d2 (+ (* (- (+ mx nx2) (car centroid))
                 (- (+ mx nx2) (car centroid)))
              (* (- (+ my ny2) (cadr centroid))
                 (- (+ my ny2) (cadr centroid)))))

  (if (> d1 d2)
    (list nx1 ny1)
    (list nx2 ny2)
  )
)


;; ===================================================================
;; CARGA DE LA RUTINA
;; ===================================================================
(princ "\n")
(princ "+----------------------------------------------------+")
(princ "\n¦     COTAR_BACHES v2.1 cargado correctamente      ¦")
(princ "\n¦                                                    ¦")
(princ "\n¦  Comando: COTB                                    ¦")
(princ "\n¦  Capa origen:   GEOMETRIA_RECTANGULOS             ¦")
(princ "\n¦  Capa destino:  COTAS_RECTANGULOS                 ¦")
(princ "\n¦  Estilo texto:  MONOTXT                           ¦")
(princ "\n¦  Altura:        0.45                              ¦")
(princ "\n¦  Relación A/H:  0.70                              ¦")
(princ "\n¦  Justificación: Superior/Inferior automática      ¦")
(princ "\n¦  Decimales:     2 (sin suprimir ceros)            ¦")
(princ "\n+----------------------------------------------------+")
(princ)