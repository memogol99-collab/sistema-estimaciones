;; ============================================================
;; SISTEMA COP5 - TABLAS DE 5 COLUMNAS (con Arial)
;; ============================================================
;; COMANDO: COP
;; FORMATO: No. | Codigo | Concepto | Unidad | Precio
;; ============================================================
;; MODIFICACIÓN: Encabezado "NO." desplazado 0.6 a la derecha
;; ============================================================

;; FUNCIÓN PARA CREAR ESTILOS DE TEXTO
(defun crearEstilosTexto (/ current_style)
  (setq current_style (getvar "TEXTSTYLE"))
  
  (if (not (tblsearch "STYLE" "MONOTXT4"))
    (progn
      (princ "\nCreando estilo MONOTXT4...")
      (if (findfile "monotxt.shx")
        (command "_.-STYLE" "MONOTXT4" "monotxt.shx" "0" "1.0" "0" "_N" "_N" "_N")
        (command "_.-STYLE" "MONOTXT4" "simplex.shx" "0" "0.8" "0" "_N" "_N" "_N")
      )
    )
  )
  
  (if (not (tblsearch "STYLE" "ARIAL"))
    (progn
      (princ "\nCreando estilo ARIAL...")
      (command "_.-STYLE" "ARIAL" "Arial" "0" "0.8" "0" "_N" "_N" "_N")
    )
  )
  
  (setvar "TEXTSTYLE" current_style)
  (princ "\n")
)

;; COMANDO PRINCIPAL COP5
(defun c:COP (/ base_pt datos num_filas ancho_no ancho_codigo_original ancho_codigo_nuevo
                 ancho_concepto ancho_unidad ancho_precio alto total_ancho
                 coords_datos coords_encabezados filaActual ancho_vistas base_x base_y i
                 y_offset nombre_vista p1 p2 old_osmode old_clayer entradaCompleta
                 y_encabezados linea)
  (setvar "CMDECHO" 0)
  (princ "\n=== PROCESO COMPLETO: TABLA (5 COLUMNAS) + VISTAS AUTOMÁTICAS ===")
  
  (setq base_pt (getpoint "\nSeleccione el punto SUPERIOR IZQUIERDO de la tabla (borde izquierdo de columna No.): "))
  
  (if base_pt
    (progn
      (princ "\n--- IMPORTAR TABLA DESDE EXCEL ---")
      (princ "\nFORMATO: No. | Codigo | Concepto | Unidad | Precio")
      (princ "\nEjemplo: 1 | 001 | Excavacion manual | M3 | 150.00")
      
      ;; CONFIGURACIÓN INICIAL
      (crearEstilosTexto)
      
      ;; Forzar estilo Arial para los datos
      (if (tblsearch "STYLE" "ARIAL")
        (setvar "TEXTSTYLE" "ARIAL")
        (progn
          (princ "\nAdvertencia: ARIAL no encontrado, creando...")
          (command "_.-STYLE" "ARIAL" "Arial" "0" "0.8" "0" "_N" "_N" "_N")
          (setvar "TEXTSTYLE" "ARIAL")
        )
      )
      
      (if (not (tblsearch "LAYER" "CONCEPTOS"))
        (command "_.-layer" "_M" "CONCEPTOS" "_C" "7" "" "")
      )
      
      (if (not (tblsearch "LAYER" "ENCABEZADOS"))
        (command "_.-layer" "_M" "ENCABEZADOS" "_C" "52" "" "")
      )
      
      (setvar "CLAYER" "CONCEPTOS")
      
      ;; DEFINIR ANCHOS
      (setq ancho_no 0.5)                              ; Ancho de la columna No.
      (setq ancho_codigo_original 4.6641)              ; Ancho original del código
      (setq ancho_codigo_nuevo (- ancho_codigo_original ancho_no)) ; Se reduce en 0.5
      (setq ancho_concepto 21.1083)
      (setq ancho_unidad 2.0596)
      (setq ancho_precio 2.0596)
      (setq alto 1.00)
      (setq total_ancho (+ ancho_codigo_original ancho_concepto ancho_unidad ancho_precio))
      
      (setq base_x (car base_pt))
      (setq base_y (cadr base_pt))
      
      ;; COORDENADAS PARA DATOS (5 columnas)
      (setq coords_datos
        (list
          ;; Columna No. (en base_x)
          (list (list base_x base_y) (list (+ base_x ancho_no) (- base_y alto)))
          ;; Columna Código (desplazada y reducida)
          (list (list (+ base_x ancho_no) base_y) (list (+ base_x ancho_codigo_original) (- base_y alto)))
          ;; Columna Concepto
          (list (list (+ base_x ancho_codigo_original) base_y) (list (+ base_x ancho_codigo_original ancho_concepto) (- base_y alto)))
          ;; Columna Unidad
          (list (list (+ base_x ancho_codigo_original ancho_concepto) base_y) (list (+ base_x ancho_codigo_original ancho_concepto ancho_unidad) (- base_y alto)))
          ;; Columna Precio
          (list (list (+ base_x ancho_codigo_original ancho_concepto ancho_unidad) base_y) (list (+ base_x total_ancho) (- base_y alto)))
        )
      )
      
      ;; COORDENADAS PARA ENCABEZADOS (5 columnas)
      (setq y_encabezados (+ base_y alto))
      (setq coords_encabezados
        (list
          (list (list base_x y_encabezados) (list (+ base_x ancho_no) (- y_encabezados alto)))
          (list (list (+ base_x ancho_no) y_encabezados) (list (+ base_x ancho_codigo_original) (- y_encabezados alto)))
          (list (list (+ base_x ancho_codigo_original) y_encabezados) (list (+ base_x ancho_codigo_original ancho_concepto) (- y_encabezados alto)))
          (list (list (+ base_x ancho_codigo_original ancho_concepto) y_encabezados) (list (+ base_x ancho_codigo_original ancho_concepto ancho_unidad) (- y_encabezados alto)))
          (list (list (+ base_x ancho_codigo_original ancho_concepto ancho_unidad) y_encabezados) (list (+ base_x total_ancho) (- y_encabezados alto)))
        )
      )
      
      ;; OBTENER DATOS
      (princ "\nPega los datos (Ctrl+V) con 5 columnas y presiona Enter 2 veces:")
      (setq entradaCompleta "")
      (setq linea (getstring T "\n>>> "))
      
      (while (and linea (/= linea ""))
        (setq entradaCompleta (strcat entradaCompleta linea "\n"))
        (setq linea (getstring T ""))
      )
      
      (if (/= entradaCompleta "")
        (progn
          (setq datos (procesarDatosExcel5 entradaCompleta))
          
          (if (and datos (> (length datos) 0))
            (progn
              ;; 1. CREAR RECTÁNGULO ENCABEZADOS
              (princ "\nCreando rectángulo para encabezados...")
              (crear-rectangulo-encabezados base_x y_encabezados total_ancho alto)
              
              ;; 2. INSERTAR ENCABEZADOS (con desplazamiento especial para "NO.")
              (princ "\nInsertando encabezados de columna...")
              (insertarEncabezadoConOffset (nth 0 coords_encabezados) "NO." 0 0 0.20)   ; este se desplazará 0.6
              (insertarEncabezadoConOffset (nth 1 coords_encabezados) "CODIGO" 0 1 0.20)
              (insertarEncabezadoConOffset (nth 2 coords_encabezados) "CONCEPTO" 0 2 0.20)
              (insertarEncabezadoConOffset (nth 3 coords_encabezados) "UNIDAD" 0 3 0.20)
              (insertarEncabezadoConOffset (nth 4 coords_encabezados) "PRECIO" 0 4 0.20)
              
              ;; 3. INSERTAR DATOS
              (princ (strcat "\nProcesando " (itoa (length datos)) " filas de datos..."))
              (setq filaActual 0)
              
              (foreach fila datos
                (insertarTextoEnCelda5 (nth 0 coords_datos) (nth 0 fila) filaActual 0)   ; No. (desplazado 0.5 a la derecha, justif izquierda)
                (insertarTextoEnCelda5 (nth 1 coords_datos) (nth 1 fila) filaActual 1)   ; Código
                (insertarMTextoEnCelda5 (nth 2 coords_datos) (nth 2 fila) filaActual 2)  ; Concepto
                (insertarTextoEnCelda5 (nth 3 coords_datos) (nth 3 fila) filaActual 3)   ; Unidad
                (insertarTextoEnCelda5 (nth 4 coords_datos) (nth 4 fila) filaActual 4)   ; Precio
                (setq filaActual (1+ filaActual))
              )
              
              (setq num_filas (length datos))
              (princ (strcat "\nTabla completada: " (itoa num_filas) " filas insertadas"))
              
              ;; 4. CREAR VISTAS
              (princ "\n--- Creando vistas automáticamente (una por fila) ---")
              (setq old_osmode (getvar "OSMODE"))
              (setq old_clayer (getvar "CLAYER"))
              
              ;; Apagar OSMODE durante la creación de las vistas
              (setvar "OSMODE" 0)
              
              ;; Cambiar a Model Space de forma segura (sin usar command)
              (if (= (getvar "TILEMODE") 0)
                (setvar "TILEMODE" 1)
              )
              
              (if (not (tblsearch "LAYER" "VISTAS"))
                (progn
                  (command "_.LAYER" "_N" "VISTAS" "")
                  (command "_.LAYER" "_C" "24" "VISTAS" "")
                )
              )
              
              (setvar "CLAYER" "VISTAS")
              (setq ancho_vistas total_ancho)
              (setq i 0)
              
              (repeat num_filas
                (setq y_offset (* i alto))
                ;; CORRECCIÓN: Se añade la coordenada Z = 0.0 para compatibilidad con AutoCAD
                (setq p1 (list base_x (- base_y y_offset) 0.0))
                (setq p2 (list (+ base_x ancho_vistas) (- base_y y_offset alto) 0.0))
                (setq nombre_vista (strcat (if (< (1+ i) 10) "0" "") (itoa (1+ i))))
                (command "_.-VIEW" "_W" nombre_vista "_non" p1 "_non" p2)
                (command "_.RECTANG" "_non" p1 "_non" p2)
                (setq i (1+ i))
              )
              
              ;; Restaurar variables de sistema DESPUÉS del bucle
              (setvar "OSMODE" old_osmode)
              (setvar "CLAYER" old_clayer)
              
              (princ (strcat "\nVistas creadas: " (itoa num_filas) " vistas"))
              (princ "\nRectángulos en capa VISTAS (color 24)")
              (princ "\nRectángulo de encabezados en capa ENCABEZADOS (color 52)")
              (princ "\n=== PROCESO COMPLETADO ===")
            )
            (princ "\nNo se ingresaron datos válidos para crear la tabla.")
          )
        )
        (princ "\nNo se ingresaron datos.")
      )
    )
    (princ "\nOperación cancelada.")
  )
  
  (setvar "CMDECHO" 1)
  (princ)
)

;; FUNCIONES DE INSERCIÓN DE TEXTO (con Arial)
(defun insertarEncabezadoConOffset (coord contenido numFila colIndex offset_abajo / x1 y1 x2 y2 centroX centroY puntoX)
  (setq x1 (caar coord))
  (setq y1 (cadar coord))
  (setq x2 (caadr coord))
  (setq y2 (cadadr coord))
  (setq centroX (/ (+ x1 x2) 2.0))
  (setq centroY (/ (+ y1 y2) 2.0))
  (setq centroY (- centroY offset_abajo))
  
  ;; Aplicar desplazamiento de 0.6 solo a la columna 0 (NO.)
  (if (= colIndex 0)
    (setq puntoX (+ centroX 0.6))
    (setq puntoX centroX)
  )
  
  (if (and contenido (/= contenido ""))
    (entmakex
      (list
        '(0 . "TEXT")
        '(100 . "AcDbEntity")
        '(100 . "AcDbText")
        (cons 8 "ENCABEZADOS")
        (cons 7 "ARIAL")
        (cons 1 (strcase contenido))
        (cons 10 (list puntoX centroY 0.0))
        (cons 11 (list puntoX centroY 0.0))
        (cons 40 0.2)
        (cons 50 0.0)
        (cons 72 1)
        (cons 73 1)
      )
    )
  )
)

(defun insertarTextoEnCelda5 (coord contenido numFila colIndex / x1 y1 x2 y2 centroX centroY puntoInsercion justificacionH justificacionV)
  (setq x1 (caar coord))
  (setq y1 (cadar coord))
  (setq x2 (caadr coord))
  (setq y2 (cadadr coord))
  (setq centroX (/ (+ x1 x2) 2.0))
  (setq centroY (- (/ (+ y1 y2) 2.0) (* numFila 1.0)))
  
  (cond
    ((= colIndex 0)  ; No. - desplazado 0.5 a la derecha (justificación izquierda)
     (setq justificacionH 0   ; 0 = Left
           justificacionV 1
           puntoInsercion (list (+ x1 0.5) centroY 0.0)))
    ((= colIndex 1)  ; Código centrado
     (setq justificacionH 1 justificacionV 1 puntoInsercion (list centroX centroY 0.0)))
    ((= colIndex 3)  ; Unidad centrado
     (setq justificacionH 1 justificacionV 1 puntoInsercion (list centroX centroY 0.0)))
    ((= colIndex 4)  ; Precio derecha con formato
     (setq justificacionH 2 justificacionV 1 puntoInsercion (list (- x2 0.4) centroY 0.0)))
    (t
     (setq justificacionH 1 justificacionV 1 puntoInsercion (list centroX centroY 0.0)))
  )
  
  (if (and contenido (/= contenido ""))
    (progn
      (if (and (= colIndex 4) (esNumero contenido))
        (setq contenido (strcat "$  " contenido))
      )
      
      (entmakex
        (list
          '(0 . "TEXT")
          '(100 . "AcDbEntity")
          '(100 . "AcDbText")
          (cons 8 "CONCEPTOS")
          (cons 7 "ARIAL")
          (cons 1 contenido)
          (cons 10 puntoInsercion)
          (cons 11 puntoInsercion)
          (cons 40 0.15)
          (cons 50 0.0)
          (cons 72 justificacionH)
          (cons 73 justificacionV)
        )
      )
    )
  )
)

(defun insertarMTextoEnCelda5 (coord contenido numFila colIndex / x1 y1 x2 y2 puntoInsercion ancho_mtext)
  (setq x1 (caar coord))
  (setq y1 (cadar coord))
  (setq x2 (caadr coord))
  (setq y2 (cadadr coord))
  (setq puntoInsercion (list (+ x1 0.05) (- y1 0.15 (* numFila 1.0)) 0.0))
  (setq ancho_mtext (- (- x2 x1) 0.1))
  
  (if (and contenido (/= contenido ""))
    (entmakex
      (list
        '(0 . "MTEXT")
        '(100 . "AcDbEntity")
        '(100 . "AcDbMText")
        (cons 8 "CONCEPTOS")
        (cons 7 "ARIAL")
        (cons 1 contenido)
        (cons 10 puntoInsercion)
        (cons 40 0.15)
        (cons 41 ancho_mtext)
        (cons 71 1)
        (cons 50 0.0)
      )
    )
  )
)

;; FUNCIONES AUXILIARES
(defun crear-rectangulo-encabezados (x y ancho alto)
  (setq old_layer (getvar "CLAYER"))
  (setvar "CLAYER" "ENCABEZADOS")
  ;; CORRECCIÓN: Se agregó la coordenada Z=0.0 y se eliminó el "" al final que causaba error en AutoCAD
  (command "_.RECTANG" "_non" (list x y 0.0) "_non" (list (+ x ancho) (- y alto) 0.0))
  (setvar "CLAYER" old_layer)
  (princ " [OK]")
)

(defun procesarDatosExcel5 (datosCadena / lineas datos numLinea linea)
  (setq lineas (split-string datosCadena "\n"))
  (setq datos '())
  (foreach linea lineas
    (if (and (/= linea "") (> (strlen (vl-string-trim " \t" linea)) 0))
      (progn
        (setq datosLinea (procesarLineaExcel5 linea))
        (if datosLinea (setq datos (cons datosLinea datos)))
      )
    )
  )
  (if datos (reverse datos) nil)
)

(defun procesarLineaExcel5 (linea / partes)
  (setq partes (split-string linea "\t"))
  (cond
    ((= (length partes) 5)
      (list (limpiarTexto (nth 0 partes)) (limpiarTexto (nth 1 partes)) 
            (limpiarTexto (nth 2 partes)) (limpiarTexto (nth 3 partes)) 
            (limpiarTexto (nth 4 partes)))
    )
    (t
      (setq partes (split-string-multiple linea))
      (procesarLineaConEspacios5 partes)
    )
  )
)

(defun procesarLineaConEspacios5 (partes / no codigo concepto unidad precio i)
  (cond
    ((= (length partes) 5)
      (list (nth 0 partes) (nth 1 partes) (nth 2 partes) (nth 3 partes) (nth 4 partes))
    )
    ((> (length partes) 5)
      (setq no (nth 0 partes))
      (setq precio (last partes))
      (setq unidad (nth (- (length partes) 2) partes))
      (cond
        ((and (>= (length partes) 5) (esPosibleCodigoConEspacio (nth 1 partes) (nth 2 partes)))
          (setq codigo (strcat (nth 1 partes) " " (nth 2 partes)))
          (setq concepto "")
          (setq i 3)
          (while (< i (- (length partes) 2))
            (setq concepto (strcat concepto (nth i partes) " "))
            (setq i (1+ i))
          )
        )
        (t
          (setq codigo (nth 1 partes))
          (setq concepto "")
          (setq i 2)
          (while (< i (- (length partes) 2))
            (setq concepto (strcat concepto (nth i partes) " "))
            (setq i (1+ i))
          )
        )
      )
      (setq concepto (vl-string-trim " " concepto))
      (list no codigo concepto unidad precio)
    )
    (t nil)
  )
)

(defun esNumero (str)
  (if (distof str) T nil)
)

(defun esPosibleCodigoConEspacio (parte1 parte2 / )
  (and (<= (strlen parte1) 3) (<= (strlen parte2) 3) (> (strlen parte1) 0) (> (strlen parte2) 0))
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

(defun split-string (str delim / pos result)
  (setq result '())
  (while (setq pos (vl-string-search delim str))
    (setq result (cons (substr str 1 pos) result))
    (setq str (substr str (+ pos 2)))
  )
  (reverse (cons str result))
)

(defun limpiarTexto (txt)
  (if txt (vl-string-trim " \t\n\r" txt) "")
)

(defun c:LIMPIARTABLA (/ ss)
  (princ "\nLimpiando textos y mtextos de las capas CONCEPTOS y ENCABEZADOS...")
  (setq ss (ssget "_X" '((0 . "TEXT,MTEXT") (8 . "CONCEPTOS,ENCABEZADOS"))))
  (if ss
    (progn
      (command "_.erase" ss "")
      (princ (strcat "\nSe eliminaron " (itoa (sslength ss)) " textos y mtextos"))
    )
    (princ "\nNo se encontraron textos ni mtextos en las capas CONCEPTOS o ENCABEZADOS")
  )
  (princ)
)

(princ "\n==================================================")
(princ "\n     SISTEMA COP5 - TABLAS DE 5 COLUMNAS         ")
(princ "\n   Texto de No. desplazado 0.5 a la derecha      ")
(princ "\n   Encabezado NO. desplazado 0.6 a la derecha    ")
(princ "\n   Fuente Arial en todos los textos              ")
(princ "\n==================================================")
(princ "\nCOMANDOS:")
(princ "\n  COP5 - Crear tabla completa (5 columnas)")
(princ "\n  LIMPIARTABLA - Limpiar capas")
(princ "\n==================================================")
(princ)