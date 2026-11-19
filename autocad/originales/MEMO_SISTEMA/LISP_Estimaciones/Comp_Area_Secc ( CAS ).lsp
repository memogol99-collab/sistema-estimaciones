;; ============================================
;; PROGRAMA PARA CALCULO DE AREAS CON LISP
;; Comandos: CAS y QA
;; ============================================

(vl-load-com)

;; --------------------------------------------------
;; FUNCION PARA VERIFICAR SI ES RECTANGULO
;; --------------------------------------------------
(defun es_rectangulo (vertices / p1 p2 p3 p4 ang1 ang2 ang3 ang4 lado1 lado2 lado3 lado4)
  (if (= (length vertices) 4)
    (progn
      (setq p1 (nth 0 vertices)
            p2 (nth 1 vertices)
            p3 (nth 2 vertices)
            p4 (nth 3 vertices)
      )
      
      (setq lado1 (distance p1 p2)
            lado2 (distance p2 p3)
            lado3 (distance p3 p4)
            lado4 (distance p4 p1)
      )
      
      (setq lados_opuestos_iguales 
            (and 
              (equal lado1 lado3 0.001)
              (equal lado2 lado4 0.001)
            )
      )
      
      (setq ang1 (abs (- (angle p1 p2) (angle p1 p4)))
            ang2 (abs (- (angle p2 p3) (angle p2 p1)))
            ang3 (abs (- (angle p3 p4) (angle p3 p2)))
            ang4 (abs (- (angle p4 p1) (angle p4 p3)))
      )
      
      (if (> ang1 pi) (setq ang1 (- (* 2 pi) ang1)))
      (if (> ang2 pi) (setq ang2 (- (* 2 pi) ang2)))
      (if (> ang3 pi) (setq ang3 (- (* 2 pi) ang3)))
      (if (> ang4 pi) (setq ang4 (- (* 2 pi) ang4)))
      
      (setq angulos_rectos 
            (and
              (equal ang1 (/ pi 2) 0.05)
              (equal ang2 (/ pi 2) 0.05)
              (equal ang3 (/ pi 2) 0.05)
              (equal ang4 (/ pi 2) 0.05)
            )
      )
      
      (and lados_opuestos_iguales angulos_rectos)
    )
    nil
  )
)

;; --------------------------------------------------
;; COMANDO PRINCIPAL CAS (CON 0.15 POR DEFAULT)
;; --------------------------------------------------
(defun c:CAS (/ tam_texto ent area centro texto vertices_list vertices tipo color layer_name total_temp pt_resumen valores)
  (princ "\n+---------------------------------------+")
  (princ "\n¦   PROGRAMA DE CALCULO DE AREAS       ¦")
  (princ "\n¦   Versión final - Altura 0.15        ¦")
  (princ "\n+---------------------------------------+\n")
  
  ; Preguntar por el tamaño del texto con 0.15 por default
  (initget 6)  ; Permite Enter y valores positivos
  (setq tam_texto (getreal "\nTamaño del texto para las áreas [0.15]: "))
  
  (if (not tam_texto)
    (setq tam_texto 0.15)  ; Valor por defecto si el usuario presiona Enter
  )
  
  (princ (strcat "\nTamaño del texto establecido en: " (rtos tam_texto 2 2) "\n"))
  
  (princ "Selecciona un area cerrada (polilinea, circulo, etc.): ")
  
  (create_layers)
  (setq total_temp 0)
  
  (while (setq ent (entsel "\nSelecciona area cerrada o Enter para terminar: "))
    (setq ent (car ent))
    (if (entidad_cerrada ent)
      (progn
        (setq area (vla-get-area (vlax-ename->vla-object ent)))
        (setq centro (get_centro ent))
        (setq vertices_list (get_vertices ent))
        
        (if vertices_list
          (progn
            (setq vertices (length vertices_list))
            
            (cond
              ((= vertices 3) (setq tipo "TRIANGULO"))
              ((= vertices 4)
                (if (es_rectangulo vertices_list)
                  (setq tipo "RECTANGULO")
                  (setq tipo "TRAPECIO")
                )
              )
              ((= vertices 5) (setq tipo "PENTAGONO"))
              ((= vertices 6) (setq tipo "HEXAGONO"))
              ((= (cdr (assoc 0 (entget ent))) "CIRCLE") (setq tipo "CIRCULO"))
              (t (setq tipo (strcat "POLI-" (itoa vertices))))
            )
            
            (setq color (cond
                         ((= tipo "TRIANGULO") 1)
                         ((= tipo "TRAPECIO") 3)
                         ((= tipo "RECTANGULO") 5)
                         ((= tipo "CIRCULO") 2)
                         ((= vertices 5) 5)
                         ((= vertices 6) 6)
                         (t 7)
                       )
            )
            
            (setq layer_name (cond
                              ((= tipo "TRIANGULO") "TRIANGULOS")
                              ((= tipo "TRAPECIO") "TRAPECIOS")
                              ((= tipo "RECTANGULO") "RECTANGULOS")
                              ((= tipo "CIRCULO") "CIRCULOS")
                              ((= vertices 5) "PENTAGONOS")
                              ((= vertices 6) "HEXAGONOS")
                              (t "OTRAS-FIGURAS")
                            )
            )
            
            (cond
              ((= tipo "TRIANGULO")
                (setq valores (calcular_valores_triangulo ent area))
                (setq texto (get_desglose_triangulo ent tipo area valores))
              )
              ((= tipo "TRAPECIO")
                (setq valores (calcular_valores_trapecio ent area))
                (setq texto (get_desglose_trapecio ent tipo area valores))
                (dibujar_altura_trapecio ent valores tam_texto)
              )
              ((= tipo "RECTANGULO")
                (setq valores (calcular_valores_rectangulo ent area))
                (setq texto (get_desglose_rectangulo ent tipo area valores))
              )
              ((= tipo "CIRCULO")
                (setq texto (get_desglose_circulo ent tipo area))
              )
              (t
                (setq texto (strcat tipo "\n=" (rtos area 2 2) " m2"))
              )
            )
            
            (crear_texto centro texto color layer_name tam_texto)
            (setq total_temp (+ total_temp area))
            
            (princ (strcat "\nArea calculada: " (rtos area 2 2) " m2 - " tipo))
          )
          (princ "\nNo se pudieron obtener los vertices de la entidad.")
        )
      )
      (princ "\n¡La entidad no esta cerrada! Selecciona otra.")
    )
  )
  
  (mostrar_area_total total_temp tam_texto)
  (princ)
)

;; --------------------------------------------------
;; COMANDO RAPIDO QA (CON 0.15 POR DEFAULT)
;; --------------------------------------------------
(defun c:QA (/ tam_texto ent area centro vertices_list vertices tipo color layer_name total_temp texto valores)
  (princ "\n+---------------------------------------+")
  (princ "\n¦   PROGRAMA DE CALCULO DE AREAS       ¦")
  (princ "\n¦   Versión rápida - Altura 0.15       ¦")
  (princ "\n+---------------------------------------+\n")
  
  ; Preguntar por el tamaño del texto con 0.15 por default
  (initget 6)
  (setq tam_texto (getreal "\nTamaño del texto para las áreas [0.15]: "))
  
  (if (not tam_texto)
    (setq tam_texto 0.15)
  )
  
  (princ (strcat "\nTamaño del texto establecido en: " (rtos tam_texto 2 2) "\n"))
  
  (princ "Selecciona area cerrada para calcular: ")
  
  (create_layers)
  (setq total_temp 0)
  
  (while (setq ent (entsel "\nSelecciona otra area o Enter para terminar: "))
    (setq ent (car ent))
    (if (entidad_cerrada ent)
      (progn
        (setq area (vla-get-area (vlax-ename->vla-object ent))
              centro (get_centro ent)
              vertices_list (get_vertices ent)
        )
        
        (if vertices_list
          (progn
            (setq vertices (length vertices_list))
            
            (cond
              ((= vertices 3) (setq tipo "TRIANGULO"))
              ((= vertices 4)
                (if (es_rectangulo vertices_list)
                  (setq tipo "RECTANGULO")
                  (setq tipo "TRAPECIO")
                )
              )
              ((= vertices 5) (setq tipo "PENTAGONO"))
              ((= vertices 6) (setq tipo "HEXAGONO"))
              ((= (cdr (assoc 0 (entget ent))) "CIRCLE") (setq tipo "CIRCULO"))
              (t (setq tipo (strcat "POLI-" (itoa vertices))))
            )
            
            (setq color (cond
                         ((= tipo "TRIANGULO") 1)
                         ((= tipo "TRAPECIO") 3)
                         ((= tipo "RECTANGULO") 5)
                         ((= tipo "CIRCULO") 2)
                         ((= vertices 5) 5)
                         ((= vertices 6) 6)
                         (t 7)
                       )
                  layer_name (cond
                              ((= tipo "TRIANGULO") "TRIANGULOS")
                              ((= tipo "TRAPECIO") "TRAPECIOS")
                              ((= tipo "RECTANGULO") "RECTANGULOS")
                              ((= tipo "CIRCULO") "CIRCULOS")
                              ((= vertices 5) "PENTAGONOS")
                              ((= vertices 6) "HEXAGONOS")
                              (t "OTRAS-FIGURAS")
                            )
            )
            
            (cond
              ((= tipo "TRIANGULO")
                (setq valores (calcular_valores_triangulo ent area))
                (setq texto (get_desglose_triangulo ent tipo area valores))
              )
              ((= tipo "TRAPECIO")
                (setq valores (calcular_valores_trapecio ent area))
                (setq texto (get_desglose_trapecio ent tipo area valores))
                (dibujar_altura_trapecio ent valores tam_texto)
              )
              ((= tipo "RECTANGULO")
                (setq valores (calcular_valores_rectangulo ent area))
                (setq texto (get_desglose_rectangulo ent tipo area valores))
              )
              ((= tipo "CIRCULO")
                (setq texto (get_desglose_circulo ent tipo area))
              )
              (t
                (setq texto (strcat tipo "\n=" (rtos area 2 2) " m2"))
              )
            )
            
            (crear_texto centro texto color layer_name tam_texto)
            (setq total_temp (+ total_temp area))
            
            (princ (strcat "\nArea: " (rtos area 2 2) " m2 - " tipo))
          )
        )
      )
      (princ "\n¡La entidad no esta cerrada!")
    )
  )
  
  (mostrar_area_total total_temp tam_texto)
  (princ)
)

;; --------------------------------------------------
;; FUNCIONES DE CALCULO DE VALORES
;; --------------------------------------------------

(defun calcular_valores_triangulo (ent area / pts p1 p2 p3 a b c lados_ordenados base altura)
  (setq pts (get_vertices ent))
  
  (if (and pts (= (length pts) 3))
    (progn
      (setq p1 (nth 0 pts)
            p2 (nth 1 pts)
            p3 (nth 2 pts)
      )
      
      (setq a (distance p1 p2)
            b (distance p2 p3)
            c (distance p3 p1)
      )
      
      (setq lados_ordenados (vl-sort (list a b c) '<))
      
      (setq base (car lados_ordenados)
            altura (cadr lados_ordenados))
      
      (list base altura (caddr lados_ordenados))
    )
    (list 0.0 0.0 0.0)
  )
)

(defun calcular_valores_trapecio (ent area / pts p1 p2 p3 p4 lado1 lado2 lado3 lado4 B b h)
  (setq pts (get_vertices ent))
  
  (if (and pts (= (length pts) 4))
    (progn
      (setq p1 (nth 0 pts)
            p2 (nth 1 pts)
            p3 (nth 2 pts)
            p4 (nth 3 pts)
      )
      
      (setq lado1 (distance p1 p2)
            lado2 (distance p2 p3)
            lado3 (distance p3 p4)
            lado4 (distance p4 p1)
      )
      
      (if (>= lado1 lado3)
        (setq B lado1 b lado3)
        (setq B lado3 b lado1)
      )
      
      (setq h (/ (* 2 area) (+ B b)))
      
      (list B b h)
    )
    (list 0.0 0.0 0.0)
  )
)

(defun calcular_valores_rectangulo (ent area / pts p1 p2 p3 p4 lado1 lado2 base altura)
  (setq pts (get_vertices ent))
  
  (if (and pts (= (length pts) 4))
    (progn
      (setq p1 (nth 0 pts)
            p2 (nth 1 pts)
            p3 (nth 2 pts)
            p4 (nth 3 pts)
      )
      
      (setq lado1 (distance p1 p2)
            lado2 (distance p2 p3)
      )
      
      (if (>= lado1 lado2)
        (setq base lado1 altura lado2)
        (setq base lado2 altura lado1)
      )
      
      (list base altura)
    )
    (list 0.0 0.0)
  )
)

;; --------------------------------------------------
;; FUNCION PARA DIBUJAR ALTURA DE TRAPECIO
;; --------------------------------------------------
(defun dibujar_altura_trapecio (ent valores tam_texto / pts p1 p2 p3 p4 B b h punto_medio1 punto_medio2 ang_linea 
                                     punto_medio_linea punto_texto ang_perpendicular ang_texto)
  (if (and valores (setq pts (get_vertices ent)))
    (progn
      (setq B (nth 0 valores)
            b (nth 1 valores)
            h (nth 2 valores)
      )
      
      (setq p1 (nth 0 pts)
            p2 (nth 1 pts)
            p3 (nth 2 pts)
            p4 (nth 3 pts)
      )
      
      (setq punto_medio1 (list (/ (+ (car p1) (car p2)) 2.0) (/ (+ (cadr p1) (cadr p2)) 2.0))
            punto_medio2 (list (/ (+ (car p3) (car p4)) 2.0) (/ (+ (cadr p3) (cadr p4)) 2.0))
      )
      
      (setq punto_medio1 (list (car punto_medio1) (cadr punto_medio1) 0.0)
            punto_medio2 (list (car punto_medio2) (cadr punto_medio2) 0.0))
      
      (setq ang_linea (angle punto_medio1 punto_medio2))
      
      (if (not (tblsearch "LTYPE" "DASHED"))
        (command "_.linetype" "_load" "DASHED" "acad.lin" "_y")
      )
      
      (entmake (list
                '(0 . "LINE")
                '(100 . "AcDbEntity")
                '(100 . "AcDbLine")
                (cons 10 punto_medio1)
                (cons 11 punto_medio2)
                (cons 62 2)
                (cons 8 "LINEAS-ALTURA")
                (cons 6 "DASHED")
                (cons 48 0.20)
               )
      )
      
      (setq punto_medio_linea (list
                               (/ (+ (car punto_medio1) (car punto_medio2)) 2.0)
                               (/ (+ (cadr punto_medio1) (cadr punto_medio2)) 2.0)
                               0.0
                              )
      )
      
      (setq ang_perpendicular (+ ang_linea (/ pi 2)))
      (setq punto_texto (polar punto_medio_linea ang_perpendicular (* tam_texto 1.2)))
      
      (setq ang_texto ang_linea)
      (if (and (> ang_texto (/ pi 2)) (< ang_texto (* 3 (/ pi 2))))
        (setq ang_texto (+ ang_texto pi))
      )
      
      (entmake (list
                '(0 . "TEXT")
                '(100 . "AcDbEntity")
                '(100 . "AcDbText")
                (cons 10 punto_texto)
                (cons 1 (strcat "h=" (rtos h 2 2)))
                (cons 40 tam_texto)
                (cons 7 (getvar "TEXTSTYLE"))
                (cons 62 2)
                (cons 8 "LINEAS-ALTURA")
                (cons 50 ang_texto)
                (cons 72 1)
                (cons 11 punto_texto)
               )
      )
      
      (princ (strcat "\nAltura del trapecio: h=" (rtos h 2 2)))
    )
  )
)

;; --------------------------------------------------
;; FUNCIONES DE DESGLOSE
;; --------------------------------------------------

(defun get_desglose_triangulo (ent tipo area valores / base altura)
  (if (and valores (> (nth 0 valores) 0) (> (nth 1 valores) 0))
    (progn
      (setq base (nth 0 valores)
            altura (nth 1 valores)
      )
      
      (strcat "TRIANGULO\n"
              "=(b*a)/2\n"
              "=(" (rtos base 2 2) "*" (rtos altura 2 2) ")/2\n"
              "=" (rtos area 2 2) " m2")
    )
    (strcat "TRIANGULO\n"
            "=(b*a)/2\n"
            "=" (rtos area 2 2) " m2")
  )
)

(defun get_desglose_trapecio (ent tipo area valores / B b h suma producto resultado)
  (if (and valores (> (nth 0 valores) 0) (> (nth 1 valores) 0) (> (nth 2 valores) 0))
    (progn
      (setq B (nth 0 valores)
            b (nth 1 valores)
            h (nth 2 valores)
      )
      
      (setq suma (+ B b)
            producto (* suma h)
            resultado (/ producto 2.0)
      )
      
      (strcat "TRAPECIO\n"
              "=(B+b)*h/2\n"
              "=(" (rtos B 2 2) "+" (rtos b 2 2) ")*" (rtos h 2 2) "/2\n"
              "=" (rtos resultado 2 2) " m2")
    )
    (strcat "TRAPECIO\n"
            "=(B+b)*h/2\n"
            "=" (rtos area 2 2) " m2")
  )
)

(defun get_desglose_rectangulo (ent tipo area valores / base altura)
  (if (and valores (> (nth 0 valores) 0) (> (nth 1 valores) 0))
    (progn
      (setq base (nth 0 valores)
            altura (nth 1 valores)
      )
      
      (strcat "RECTANGULO\n"
              "=b*a\n"
              "=" (rtos base 2 2) "*" (rtos altura 2 2) "\n"
              "=" (rtos area 2 2) " m2")
    )
    (strcat "RECTANGULO\n"
            "=b*a\n"
            "=" (rtos area 2 2) " m2")
  )
)

(defun get_desglose_circulo (ent tipo area / radio)
  (setq radio (cdr (assoc 40 (entget ent))))
  (strcat "CIRCULO\n"
          "=p*r²\n"
          "=p*" (rtos radio 2 2) "²\n"
          "=" (rtos area 2 2) " m2")
)

;; --------------------------------------------------
;; FUNCIONES AUXILIARES
;; --------------------------------------------------

(defun entidad_cerrada (ent)
  (setq datos (entget ent)
        tipo (cdr (assoc 0 datos)))
  
  (cond
    ((= tipo "LWPOLYLINE")
      (= (logand (cdr (assoc 70 datos)) 1) 1)
    )
    ((or (= tipo "CIRCLE") (= tipo "ELLIPSE"))
      T
    )
    (T nil)
  )
)

(defun create_layers ()
  (crear_capa "TRIANGULOS" 1)
  (crear_capa "TRAPECIOS" 3)
  (crear_capa "RECTANGULOS" 5)
  (crear_capa "PENTAGONOS" 5)
  (crear_capa "HEXAGONOS" 6)
  (crear_capa "CIRCULOS" 2)
  (crear_capa "OTRAS-FIGURAS" 7)
  (crear_capa "TEXTOS-AREAS" 4)
  (crear_capa "LINEAS-ALTURA" 2)
  (princ)
)

(defun crear_capa (nombre color)
  (if (not (tblsearch "LAYER" nombre))
    (entmake (list
              '(0 . "LAYER")
              '(100 . "AcDbSymbolTableRecord")
              '(100 . "AcDbLayerTableRecord")
              (cons 2 nombre)
              '(70 . 0)
              (cons 62 color)
              '(6 . "Continuous")
             )
    )
  )
)

(defun crear_texto (punto texto color capa altura)
  (entmake (list
            '(0 . "MTEXT")
            '(100 . "AcDbEntity")
            '(100 . "AcDbMText")
            (cons 10 punto)
            (cons 1 texto)
            (cons 40 altura)
            (cons 7 (getvar "TEXTSTYLE"))
            (cons 62 color)
            (cons 8 capa)
            (cons 71 1)
            (cons 50 0.0)
           )
  )
)

(defun mostrar_area_total (total_temp tam_base)
  (if (> total_temp 0)
    (progn
      (setq pt_resumen (getpoint "\nPunto para colocar el area total de la sesion: "))
      (if pt_resumen
        (progn
          (setq texto_total (strcat "AREA TOTAL = " (rtos total_temp 2 2) " m2"))
          (crear_texto pt_resumen texto_total 2 "TEXTOS-AREAS" (* tam_base 1.5))
          (princ (strcat "\nArea total colocada: " (rtos total_temp 2 2) " m2"))
        )
      )
    )
    (princ "\nNo se calcularon areas en esta sesion.\n")
  )
)

(defun get_centro (ent / datos tipo pts centro n)
  (setq datos (entget ent)
        tipo (cdr (assoc 0 datos)))
  
  (cond
    ((= tipo "CIRCLE")
      (cdr (assoc 10 datos))
    )
    ((= tipo "LWPOLYLINE")
      (setq pts (get_vertices ent))
      (if pts
        (progn
          (setq centro '(0.0 0.0 0.0)
                n (length pts))
          (foreach vert pts
            (setq centro (mapcar '+ centro vert))
          )
          (mapcar '/ centro (list n n n))
        )
        '(0.0 0.0 0.0)
      )
    )
    (T
      '(0.0 0.0 0.0)
    )
  )
)

(defun get_vertices (ent / datos tipo pts item ent2 centro radio)
  (setq datos (entget ent)
        tipo (cdr (assoc 0 datos))
        pts nil)
  
  (cond
    ((= tipo "LWPOLYLINE")
      (foreach item datos
        (if (= (car item) 10)
          (setq pts (cons (cdr item) pts))
        )
      )
      (reverse pts)
    )
    ((= tipo "POLYLINE")
      (setq ent2 (entnext ent))
      (while (and ent2 (= (cdr (assoc 0 (entget ent2))) "VERTEX"))
        (setq pts (cons (cdr (assoc 10 (entget ent2))) pts))
        (setq ent2 (entnext ent2))
      )
      (reverse pts)
    )
    ((= tipo "CIRCLE")
      (setq centro (cdr (assoc 10 datos))
            radio (cdr (assoc 40 datos)))
      (list
        (list (- (car centro) radio) (cadr centro) 0.0)
        (list (car centro) (+ (cadr centro) radio) 0.0)
        (list (+ (car centro) radio) (cadr centro) 0.0)
        (list (car centro) (- (cadr centro) radio) 0.0)
      )
    )
    (T nil)
  )
)

;; ============================================
;; MENSAJE INICIAL
;; ============================================
(princ "\n+------------------------------------------+")
(princ "\n¦   PROGRAMA DE CALCULO DE AREAS v5.0     ¦")
(princ "\n¦   Versión final - Altura default 0.15   ¦")
(princ "\n+------------------------------------------+")
(princ "\nComandos disponibles:")
(princ "\n  CAS - Calculo detallado con formulas y valores")
(princ "\n  QA  - Calculo rapido con valores sustituidos")
(princ "\n")
(princ "\nCaracterísticas:")
(princ "\n  • Altura de texto por defecto: 0.15 (presiona Enter)")
(princ "\n  • Texto sin espacios: 'h=valor'")
(princ "\n  • Detección automática de RECTÁNGULOS")
(princ "\n  • Calculo para triángulos, trapecios, rectángulos y círculos")
(princ "\n  • Todas las áreas en 'm2'")
(princ "\n  • Escala de línea punteada: 0.01")
(princ "\n  • Área total 50% más grande para mejor visibilidad")
(princ)