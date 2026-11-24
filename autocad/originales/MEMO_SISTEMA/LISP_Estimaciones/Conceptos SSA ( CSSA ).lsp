;; ============================================================
;; SISTEMA CSSA - VERSIÓN COMPLETA CON RECUADROS BLANCOS
;; ============================================================

;; 1. FUNCIÓN PARA CREAR ESTILOS DE TEXTO
(defun crearEstilosTexto (/ current_style found)
  (setq current_style (getvar "TEXTSTYLE"))
  
  (if (not (tblsearch "STYLE" "MONOTXT4"))
    (progn
      (princ "\nCreando estilo MONOTXT4...")
      (setq found nil)
      
      (foreach font '("monotxt.shx" "simplex.shx" "txt.shx" "romans.shx")
        (if (and (not found) (findfile font))
          (progn
            (vl-cmdf "_.-STYLE" "MONOTXT4" font "0" "1.0" "0" "_N" "_N" "_N")
            (princ (strcat " [con " font "]"))
            (setq found T)
          )
        )
      )
      
      (if (not found)
        (progn
          (foreach ttf '("Arial" "Verdana" "Tahoma")
            (if (and (not found) (findfile (strcat ttf ".ttf")))
              (progn
                (vl-cmdf "_.-STYLE" "MONOTXT4" ttf "0" "0.8" "0" "_N" "_N" "_N")
                (princ (strcat " [con " ttf ".ttf]"))
                (setq found T)
              )
            )
          )
        )
      )
    )
  )
  
  (if (not (tblsearch "STYLE" "ARIAL"))
    (progn
      (princ "\nCreando estilo ARIAL...")
      (cond
        ((findfile "arial.ttf")
          (vl-cmdf "_.-STYLE" "ARIAL" "Arial" "0" "0.8" "0" "_N" "_N" "_N"))
        ((findfile "verdana.ttf")
          (vl-cmdf "_.-STYLE" "ARIAL" "Verdana" "0" "0.8" "0" "_N" "_N" "_N")
          (princ " [usando Verdana]"))
        (t
          (vl-cmdf "_.-STYLE" "ARIAL" "simplex.shx" "0" "1.0" "0" "_N" "_N" "_N")
          (princ " [usando simplex.shx]"))
      )
    )
  )
  
  (setvar "TEXTSTYLE" current_style)
  (princ "\n")
  (princ)
)

;; 2. FUNCIÓN PARA CREAR CAPAS NECESARIAS (CON COLOR 7 PARA RECUADROS)
(defun crearCapasNecesarias ()
  (foreach capa '("DATOS_NUMEROS" "DATOS_CONCEPTO" "ENCABEZADOS" "RECUADROS" "VISTAS")
    (if (not (tblsearch "LAYER" capa))
      (progn
        (cond
          ((= capa "DATOS_NUMEROS") 
            (vl-cmdf "_.-LAYER" "_M" capa "_C" "7" "" ""))
          ((= capa "DATOS_CONCEPTO") 
            (vl-cmdf "_.-LAYER" "_M" capa "_C" "7" "" ""))
          ((= capa "ENCABEZADOS") 
            (vl-cmdf "_.-LAYER" "_M" capa "_C" "52" "" ""))
          ;; CAMBIO: Recuadros en color 7 (blanco)
          ((= capa "RECUADROS") 
            (vl-cmdf "_.-LAYER" "_M" capa "_C" "7" "" "_L" "CONTINUOUS" "" ""))
          ((= capa "VISTAS") 
            (vl-cmdf "_.-LAYER" "_M" capa "_C" "24" "" "_L" "CONTINUOUS" "" ""))
        )
      )
    )
  )
  (princ)
)

;; 3. FUNCIÓN PARA PROCESAR DATOS
(defun procesarDatosNuevoFormato (datosCadena / lineas datos linea_limpia partes)
  (setq lineas (split-string datosCadena "\n"))
  (setq datos '())
  
  (foreach linea lineas
    (setq linea_limpia (vl-string-trim " \t\n\r" linea))
    
    (if (> (strlen linea_limpia) 0)
      (progn
        (setq partes (split-string linea_limpia "\t"))
        
        (cond
          ((= (length partes) 4)
            (setq datos (cons (list 
                                (nth 0 partes)
                                (nth 1 partes)
                                (nth 2 partes)
                                (nth 3 partes)
                              ) datos)))
          (t
            (setq partes (split-string-multiple linea_limpia))
            (setq datos_linea (procesarLineaConEspaciosNuevo partes))
            (if datos_linea
              (setq datos (cons datos_linea datos))
            )
          )
        )
      )
    )
  )
  
  (if datos
    (reverse datos)
    nil
  )
)

(defun procesarLineaConEspaciosNuevo (partes / numero concepto unidad cantidad i)
  (cond
    ((= (length partes) 4)
      (list 
        (nth 0 partes)
        (nth 1 partes)
        (nth 2 partes)
        (nth 3 partes)
      )
    )
    ((> (length partes) 4)
      (setq numero (nth 0 partes))
      (setq cantidad (last partes))
      (setq unidad (nth (- (length partes) 2) partes))
      
      (setq concepto "")
      (setq i 1)
      (while (< i (- (length partes) 2))
        (setq concepto (strcat concepto (nth i partes) " "))
        (setq i (1+ i))
      )
      
      (setq concepto (vl-string-trim " " concepto))
      (list numero concepto unidad cantidad)
    )
    (t
      (cond
        ((= (length partes) 3) 
          (list 
            (nth 0 partes)
            (nth 1 partes)
            (nth 2 partes)
            ""
          )
        )
        ((= (length partes) 2) 
          (list 
            (nth 0 partes)
            (nth 1 partes)
            ""
            ""
          )
        )
        ((= (length partes) 1) 
          (list 
            (nth 0 partes)
            ""
            ""
            ""
          )
        )
        (t (list "" "" "" ""))
      )
    )
  )
)

;; 4. FUNCIONES AUXILIARES PARA STRINGS
(defun split-string (str delim / pos result)
  (setq result '())
  (while (setq pos (vl-string-search delim str))
    (setq result (cons (substr str 1 pos) result))
    (setq str (substr str (+ pos 2)))
  )
  (reverse (cons str result))
)

(defun split-string-multiple (str / result temp)
  (setq result '())
  (setq temp (vl-string-trim " \t" str))
  
  (while (vl-string-search "  " temp)
    (setq temp (vl-string-subst " " "  " temp))
  )
  
  (setq result (split-string temp " "))
  result
)

;; 5. FUNCIONES DE DIBUJO
(defun insertar-concepto-mtext (x y ancho alto concepto)
  (if (and concepto (/= concepto ""))
    (progn
      (setq x_centro (+ x (/ ancho 2.0)))
      (setq y_centro (- y (/ alto 2.0)))
      
      (entmakex
        (list
          '(0 . "MTEXT")
          '(100 . "AcDbEntity")
          '(100 . "AcDbMText")
          (cons 8 "DATOS_CONCEPTO")
          (cons 7 "MONOTXT4")
          (cons 1 concepto)
          (cons 10 (list x_centro y_centro 0.0))
          (cons 40 0.20)
          (cons 41 (- ancho 0.3))
          (cons 71 5)
          (cons 50 0.0)
        )
      )
    )
  )
)

(defun insertar-dato-centrado-ajustado (x y texto capa altura)
  (entmakex
    (list
      '(0 . "TEXT")
      '(100 . "AcDbEntity")
      '(100 . "AcDbText")
      (cons 8 capa)
      (cons 7 "MONOTXT4")
      (cons 1 texto)
      (cons 10 (list x y 0.0))
      (cons 11 (list x y 0.0))
      (cons 40 altura)
      (cons 50 0.0)
      (cons 72 1)
      (cons 73 2)
    )
  )
)

(defun crear-recuadro (x y ancho alto capa)
  (setq old_layer (getvar "CLAYER"))
  (setvar "CLAYER" capa)
  
  (vl-cmdf "_.RECTANG" 
    "_non" (list x y)
    "_non" (list (+ x ancho) (- y alto))
  )
  
  (setvar "CLAYER" old_layer)
)

(defun crear-linea-vertical (x y ancho alto num_columna)
  (setq x_pos (+ x (* num_columna (/ ancho 3.0))))
  
  (entmakex
    (list
      '(0 . "LINE")
      '(100 . "AcDbEntity")
      (cons 8 "RECUADROS")
      (cons 10 (list x_pos y 0.0))
      (cons 11 (list x_pos (- y alto) 0.0))
    )
  )
)

(defun crear-vista-por-fila (nombre_vista p1 p2)
  (setq vista_creada nil)
  
  (if (= (getvar "TILEMODE") 0)
    (vl-cmdf "_.TILEMODE" "1")
  )
  
  (if (not (tblsearch "VIEW" nombre_vista))
    (progn
      (vl-cmdf "_.-VIEW" "_W" nombre_vista p1 p2)
      (setq vista_creada T)
    )
    (progn
      (vl-cmdf "_.-VIEW" "_D" nombre_vista)
      (vl-cmdf "_.-VIEW" "_W" nombre_vista p1 p2)
      (setq vista_creada T)
    )
  )
  
  vista_creada
)

;; 6. COMANDO PARA LIMPIAR
(defun c:LIMPIARCSSA (/ ss i)
  (princ "\nLimpiando elementos creados por CSSA...")
  
  (setq ss (ssget "_X" '((0 . "TEXT,MTEXT,LINE") (8 . "DATOS_NUMEROS,DATOS_CONCEPTO,ENCABEZADOS,RECUADROS,VISTAS"))))
  
  (if ss
    (progn
      (vl-cmdf "_.erase" ss "")
      (princ (strcat "\nSe eliminaron " (itoa (sslength ss)) " elementos gráficos"))
    )
    (princ "\nNo se encontraron elementos gráficos para limpiar")
  )
  
  (setq i 1)
  (while (<= i 99)
    (setq nombre_vista (strcat (if (< i 10) "0" "") (itoa i)))
    (if (tblsearch "VIEW" nombre_vista)
      (vl-cmdf "_.-VIEW" "_D" nombre_vista)
    )
    (setq i (1+ i))
  )
  
  (princ "\nVistas eliminadas: 01 a 99")
  (princ)
)

;; ============================================================
;; COMANDO PRINCIPAL CSSA
;; ============================================================

(defun c:CSSA (/ *error* old_vars base_pt datos num_filas ancho_total alto_total 
                 ancho_columna alto_fila x_base y_base offset_x filaActual 
                 entradaCompleta linea rect_p1 rect_p2 y_pos_encabezado
                 alto_concepto y_pos_actual y_concepto_actual 
                 ancho_concepto y_fin_concepto nombre_vista old_osmode)
  
  (defun *error* (msg)
    (if old_osmode (setvar "OSMODE" old_osmode))
    (if (and old_vars (listp old_vars))
      (mapcar 'setvar '("CMDECHO" "OSMODE" "CLAYER" "TEXTSTYLE") old_vars)
    )
    (if (not (member msg '("Function cancelled" "quit / exit abort")))
      (princ (strcat "\nError: " msg))
    )
    (princ)
  )
  
  (setq old_vars (mapcar 'getvar '("CMDECHO" "OSMODE" "CLAYER" "TEXTSTYLE")))
  
  (setvar "CMDECHO" 0)
  
  (setq old_osmode (getvar "OSMODE"))
  (setvar "OSMODE" 512)
  
  (princ "\n=== SISTEMA CSSA - VERSIÓN CON RECUADROS BLANCOS ===")
  (princ "\nORDEN DE ENTRADA: No. | Concepto | Unidad | Cantidad")
  (princ "\nCARACTERÍSTICAS:")
  (princ "\n• Encabezados: +0.7 unidades hacia ARRIBA")
  (princ "\n• Altura de texto: 0.20")
  (princ "\n• Recuadros: Color 7 (blanco)")
  (princ "\n• Una vista por fila (01, 02, 03...)")
  
  (princ "\n\nSNAP NODO ACTIVADO - Seleccione punto...")
  (setq base_pt (getpoint "\nSeleccione el punto SUPERIOR IZQUIERDO para la primera fila: "))
  
  (setvar "OSMODE" old_osmode)
  
  (if base_pt
    (progn
      (crearEstilosTexto)
      (crearCapasNecesarias)
      
      (cond
        ((tblsearch "STYLE" "MONOTXT4")
          (setvar "TEXTSTYLE" "MONOTXT4"))
        (t
          (setvar "TEXTSTYLE" "STANDARD")
          (princ "\nAdvertencia: MONOTXT4 no encontrado, usando STANDARD..."))
      )
      
      (setvar "CLAYER" "DATOS_NUMEROS")
      
      (setq ancho_total 24.0964)
      (setq alto_total 0.4226)
      (setq ancho_columna (/ ancho_total 3.0))
      (setq alto_fila alto_total)
      
      (setq ancho_concepto ancho_total)
      (setq alto_concepto 4.1336)
      
      (setq x_base (car base_pt))
      (setq y_base (cadr base_pt))
      
      (princ "\n1. Ingresando datos...")
      (princ "\nFormato: No. | Concepto | Unidad | Cantidad")
      (princ "\nEjemplo: CONC1 Concepto detallado M3 150.00")
      (princ "\n(Pega los datos y presiona Enter 2 veces):")
      
      (setq entradaCompleta "")
      (setq linea (getstring T "\n>>> "))
      
      (while (and linea (/= linea ""))
        (setq entradaCompleta (strcat entradaCompleta linea "\n"))
        (setq linea (getstring T ">>> "))
      )
      
      (if (and entradaCompleta (> (strlen entradaCompleta) 0))
        (progn
          (setq datos (procesarDatosNuevoFormato entradaCompleta))
          
          (if (and datos (> (length datos) 0))
            (progn
              (setq num_filas (length datos))
              (princ (strcat "\n2. Procesando " (itoa num_filas) " filas..."))
              
              (setq offset_x (/ (- ancho_total (* 3 ancho_columna)) 2.0))
              
              (setq filaActual 0)
              (setq y_pos_actual y_base)
              
              (foreach registro datos
                (setq numero (nth 0 registro))
                (setq concepto (nth 1 registro))
                (setq unidad (nth 2 registro))
                (setq cantidad (nth 3 registro))
                
                (princ (strcat "\n   Fila " (itoa (1+ filaActual)) ": "))
                
                ;; Crear recuadro superior (color 7 - blanco)
                (crear-recuadro x_base y_pos_actual ancho_total alto_total "RECUADROS")
                (crear-linea-vertical x_base y_pos_actual ancho_total alto_total 1)
                (crear-linea-vertical x_base y_pos_actual ancho_total alto_total 2)
                
                (if (= filaActual 0)
                  (progn
                    (setq y_pos_encabezado (+ (- y_pos_actual (/ alto_total 2.0)) 0.7))
                    
                    (princ (strcat "\n     Encabezados Y=" (rtos y_pos_encabezado 2 2) " "))
                    
                    (insertar-encabezado-columna x_base y_pos_encabezado ancho_columna 0 "No.")
                    (insertar-encabezado-columna x_base y_pos_encabezado ancho_columna 1 "CANTIDAD")
                    (insertar-encabezado-columna x_base y_pos_encabezado ancho_columna 2 "UNIDAD")
                    
                    (princ "[OK] ")
                  )
                )
                
                (setq y_pos_datos (- y_pos_actual (/ alto_total 2.0)))
                
                (princ (strcat "Datos Y=" (rtos y_pos_datos 2 2) " "))
                
                (insertar-dato-centrado-ajustado 
                  (+ x_base offset_x (/ ancho_columna 2.0)) 
                  y_pos_datos 
                  numero 
                  "DATOS_NUMEROS" 
                  0.20)
                
                (insertar-dato-centrado-ajustado 
                  (+ x_base offset_x ancho_columna (/ ancho_columna 2.0)) 
                  y_pos_datos 
                  cantidad 
                  "DATOS_NUMEROS" 
                  0.20)
                
                (insertar-dato-centrado-ajustado 
                  (+ x_base offset_x (* 2 ancho_columna) (/ ancho_columna 2.0)) 
                  y_pos_datos 
                  (strcase unidad)
                  "DATOS_NUMEROS" 
                  0.20)
                
                (princ "[OK] ")
                
                ;; Crear recuadro concepto (color 7 - blanco)
                (setq y_concepto_actual (- y_pos_actual 0.8664))
                (crear-recuadro x_base y_concepto_actual ancho_concepto alto_concepto "RECUADROS")
                
                (insertar-concepto-mtext 
                  x_base 
                  y_concepto_actual 
                  ancho_concepto 
                  alto_concepto 
                  concepto)
                
                (princ "Concepto [OK] ")
                
                (setq y_fin_concepto (- y_concepto_actual alto_concepto))
                (setq nombre_vista (strcat 
                                    (if (< (1+ filaActual) 10) "0" "") 
                                    (itoa (1+ filaActual))))
                
                ;; Crear rectángulo de vista
                (setvar "CLAYER" "VISTAS")
                (vl-cmdf "_.RECTANG" 
                         "_non" (list x_base y_pos_actual)
                         "_non" (list (+ x_base ancho_total) y_fin_concepto))
                
                (crear-vista-por-fila nombre_vista 
                                    (list x_base y_pos_actual) 
                                    (list (+ x_base ancho_total) y_fin_concepto))
                
                (setvar "CLAYER" "DATOS_NUMEROS")
                
                (princ (strcat "Vista " nombre_vista " [OK]"))
                
                ;; Preparar posición para siguiente fila
                (setq y_pos_actual y_fin_concepto)
                (setq filaActual (1+ filaActual))
              )
              
              (princ "\n\n=== PROCESO COMPLETADO ===")
              (princ (strcat "\nTotal filas creadas: " (itoa num_filas)))
              (princ (strcat "\nVistas creadas: 01 a " 
                            (if (< num_filas 10) "0" "") 
                            (itoa num_filas)))
              
              (princ "\n\nCOLORES APLICADOS:")
              (princ "\n• Recuadros: Color 7 (blanco)")
              (princ "\n• Datos: Color por capa (blanco)")
              (princ "\n• Encabezados: Color 52 (azul)")
              (princ "\n• Vistas: Color 24 (gris)")
              
            )
            (princ "\nError: No se pudieron procesar los datos.")
          )
        )
        (princ "\nError: No se ingresaron datos.")
      )
    )
    (princ "\nOperación cancelada por el usuario.")
  )
  
  (setvar "OSMODE" old_osmode)
  (mapcar 'setvar '("CMDECHO" "OSMODE" "CLAYER" "TEXTSTYLE") old_vars)
  (princ)
)

;; 7. FUNCIÓN PARA INSERTAR ENCABEZADOS
(defun insertar-encabezado-columna (x y ancho_columna col_index texto)
  (setq x_centro (+ x (* col_index ancho_columna) (/ ancho_columna 2.0)))
  
  (entmakex
    (list
      '(0 . "TEXT")
      '(100 . "AcDbEntity")
      '(100 . "AcDbText")
      (cons 8 "ENCABEZADOS")
      (cons 7 "ARIAL")
      (cons 1 (strcase texto))
      (cons 10 (list x_centro y 0.0))
      (cons 11 (list x_centro y 0.0))
      (cons 40 0.20)
      (cons 50 0.0)
      (cons 72 1)
      (cons 73 2)
    )
  )
)

;; ============================================================
;; MENSAJE DE CARGA
;; ============================================================

(princ "\n==================================================")
(princ "\n   SISTEMA CSSA - RECUADROS BLANCOS            ")
(princ "\n==================================================")
(princ "\nCOMANDOS DISPONIBLES:")
(princ "\n  CSSA       - Crear tabla completa")
(princ "\n  LIMPIARCSSA - Limpiar elementos creados")
(princ "\n")
(princ "\nCARACTERÍSTICAS:")
(princ "\n• Formato entrada: No. | Concepto | Unidad | Cantidad")
(princ "\n• Encabezados: +0.7 unidades hacia arriba")
(princ "\n• Altura texto: 0.20")
(princ "\n• Recuadros: Color 7 (blanco)")
(princ "\n• Una vista por fila (01, 02, 03...)")
(princ "\n• Snap nodo activado al seleccionar punto")
(princ "\n==================================================")
(princ)