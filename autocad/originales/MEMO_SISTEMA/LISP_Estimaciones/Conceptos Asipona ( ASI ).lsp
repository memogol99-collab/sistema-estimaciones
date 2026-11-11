;; ============================================================
;; SISTEMA ASI - TABLAS DE 7 COLUMNAS
;; ============================================================
;; COMANDO: ASI
;; FORMATO: No. | Codigo | Descripcion | Unidad | P.U. | Cantidad | Importe
;; ============================================================

;; Variables globales configurables
(setq *mp-ancho-no* 0.9841)
(setq *mp-ancho-codigo* 1.7887)          ;; Ancho de columna CODIGO (AMPLIADO +0.7113)
(setq *mp-ancho-descripcion* 14.8620)    ;; Ancho de columna DESCRIPCION (AMPLIADO +0.6000)
(setq *mp-ancho-unidad* 1.1700)          ;; Ancho de columna UNIDAD (REDUCIDO -0.7113)
(setq *mp-ancho-pu* 1.7250)
(setq *mp-ancho-cantidad* 1.6997)
(setq *mp-ancho-importe* 1.9849)         ;; Ancho de columna IMPORTE (REDUCIDO -0.6000)
(setq *mp-alto-fila* 1.00)

;; FUNCIÓN PARA CREAR ESTILOS DE TEXTO
(defun crearEstilosTexto (/ current_style)
  (setq current_style (getvar "TEXTSTYLE"))
  
  (if (not (tblsearch "STYLE" "MONOTXT4"))
    (progn
      (princ "\nCreando estilo MONOTXT4...")
      (if (findfile "monotxt.shx")
        (progn
          (command "_.-STYLE" "MONOTXT4" "monotxt.shx" "0" "1.0" "0" "_N" "_N" "_N")
          (princ " [con monotxt.shx]")
        )
        (progn
          (command "_.-STYLE" "MONOTXT4" "simplex.shx" "0" "0.8" "0" "_N" "_N" "_N")
          (princ " [con simplex.shx]")
        )
      )
    )
  )
  
  (if (not (tblsearch "STYLE" "SIMPLEX"))
    (progn
      (princ "\nCreando estilo SIMPLEX...")
      (command "_.-STYLE" "SIMPLEX" "simplex.shx" "0" "1.0" "0" "_N" "_N" "_N")
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

;; ============================================================
;; FUNCIÓN PARA DIVIDIR CÓDIGO EN DOS LÍNEAS
;; ============================================================
(defun dividirCodigo (codigo / parte1 parte2 pos)
  (setq codigo (vl-string-trim " " codigo))
  
  (cond
    ;; Si ya tiene espacio, dividir en ese espacio
    ((vl-string-search " " codigo)
     (setq pos (vl-string-search " " codigo))
     (setq parte1 (substr codigo 1 pos))
     (setq parte2 (substr codigo (+ pos 2)))
     (strcat parte1 "\\P" parte2)
    )
    ;; Si es un código largo (más de 10 caracteres), dividir en la mitad
    ((> (strlen codigo) 10)
     (setq pos (/ (strlen codigo) 2))
     (setq parte1 (substr codigo 1 pos))
     (setq parte2 (substr codigo (1+ pos)))
     (strcat parte1 "\\P" parte2)
    )
    ;; Código corto, mantener en una línea
    (t codigo)
  )
)

;; COMANDO PRINCIPAL ASI
(defun c:ASI (/ base_pt datos num_filas ancho_no ancho_codigo ancho_descripcion ancho_unidad 
                ancho_pu ancho_cantidad ancho_importe alto total_ancho 
                coords_datos coords_encabezados filaActual ancho_vistas base_x base_y i y_offset 
                nombre_vista p1 p2 old_osmode old_clayer entradaCompleta y_encabezados y_datos
                linea total_importe)
  (setvar "CMDECHO" 0)
  (princ "\n=== PROCESO COMPLETO: TABLA + VISTAS AUTOMATICAS (7 COLUMNAS) ===")
  
  (setq base_pt (getpoint "\nSeleccione el punto SUPERIOR IZQUIERDO para la tabla (esquina de encabezados): "))
  
  (if base_pt
    (progn
      (princ "\n--- IMPORTAR TABLA DESDE EXCEL ---")
      (princ "\nFORMATO: No. | Codigo | Descripcion | Unidad | P.U. | Cantidad | Importe")
      (princ "\nEjemplo: 1 001 Excavacion manual M3 150.00 10.00 1500.00")
      
      ;; CONFIGURACIÓN INICIAL
      (crearEstilosTexto)
      
      (if (tblsearch "STYLE" "MONOTXT4")
        (setvar "TEXTSTYLE" "MONOTXT4")
        (progn
          (princ "\nAdvertencia: MONOTXT4 no encontrado, usando SIMPLEX...")
          (setvar "TEXTSTYLE" "SIMPLEX")
        )
      )
      
      (if (not (tblsearch "LAYER" "CONCEPTOS"))
        (command "_.-layer" "_M" "CONCEPTOS" "_C" "7" "" "")
      )
      
      (if (not (tblsearch "LAYER" "ENCABEZADOS"))
        (command "_.-layer" "_M" "ENCABEZADOS" "_C" "52" "" "")
      )
      
      (setvar "CLAYER" "CONCEPTOS")
      
      (if (not (tblsearch "STYLE" "ARIAL"))
        (progn
          (princ "\nCreando estilo ARIAL...")
          (command "_.-STYLE" "ARIAL" "Arial" "0" "0.2" "0" "_N" "_N" "_N")
        )
      )
      
      ;; DEFINIR ANCHOS (7 COLUMNAS)
      (setq ancho_no *mp-ancho-no*)
      (setq ancho_codigo *mp-ancho-codigo*)
      (setq ancho_descripcion *mp-ancho-descripcion*)
      (setq ancho_unidad *mp-ancho-unidad*)
      (setq ancho_pu *mp-ancho-pu*)
      (setq ancho_cantidad *mp-ancho-cantidad*)
      (setq ancho_importe *mp-ancho-importe*)
      (setq alto *mp-alto-fila*)
      (setq total_ancho (+ ancho_no ancho_codigo ancho_descripcion ancho_unidad ancho_pu ancho_cantidad ancho_importe))
      
      (setq base_x (car base_pt))
      (setq base_y (cadr base_pt))
      
      ;; ========================================
      ;; CALCULAR COORDENADAS PARA ENCABEZADOS (EN EL PUNTO BASE)
      ;; ========================================
      (setq y_encabezados base_y)  ; ENCABEZADOS EN EL PUNTO BASE
      
      ;; ========================================
      ;; CALCULAR COORDENADAS PARA DATOS (UNA FILA ABAJO)
      ;; ========================================
      (setq y_datos (- base_y alto))
      
      ;; COORDENADAS PARA DATOS (UNA FILA ABAJO DE ENCABEZADOS)
      (setq coords_datos
        (list
          ;; Columna No. (columna 0)
          (list
            (list base_x y_datos)                                   ; Superior izquierdo
            (list (+ base_x ancho_no) (- y_datos alto))             ; Inferior derecho
          )
          ;; Columna CODIGO (columna 1)
          (list
            (list (+ base_x ancho_no) y_datos)                      ; Superior izquierdo
            (list (+ base_x ancho_no ancho_codigo) (- y_datos alto)) ; Inferior derecho
          )
          ;; Columna DESCRIPCION (columna 2)
          (list
            (list (+ base_x ancho_no ancho_codigo) y_datos)         ; Superior izquierdo
            (list (+ base_x ancho_no ancho_codigo ancho_descripcion) (- y_datos alto)) ; Inferior derecho
          )
          ;; Columna UNIDAD (columna 3)
          (list
            (list (+ base_x ancho_no ancho_codigo ancho_descripcion) y_datos) ; Superior izquierdo
            (list (+ base_x ancho_no ancho_codigo ancho_descripcion ancho_unidad) (- y_datos alto)) ; Inferior derecho
          )
          ;; Columna P.U. (columna 4)
          (list
            (list (+ base_x ancho_no ancho_codigo ancho_descripcion ancho_unidad) y_datos) ; Superior izquierdo
            (list (+ base_x ancho_no ancho_codigo ancho_descripcion ancho_unidad ancho_pu) (- y_datos alto)) ; Inferior derecho
          )
          ;; Columna CANTIDAD (columna 5)
          (list
            (list (+ base_x ancho_no ancho_codigo ancho_descripcion ancho_unidad ancho_pu) y_datos) ; Superior izquierdo
            (list (+ base_x ancho_no ancho_codigo ancho_descripcion ancho_unidad ancho_pu ancho_cantidad) (- y_datos alto)) ; Inferior derecho
          )
          ;; Columna IMPORTE (columna 6)
          (list
            (list (+ base_x ancho_no ancho_codigo ancho_descripcion ancho_unidad ancho_pu ancho_cantidad) y_datos) ; Superior izquierdo
            (list (+ base_x total_ancho) (- y_datos alto)) ; Inferior derecho
          )
        )
      )
      
      ;; COORDENADAS PARA ENCABEZADOS (EN EL PUNTO BASE)
      (setq coords_encabezados
        (list
          ;; Columna No. (columna 0)
          (list
            (list base_x y_encabezados)                                   ; Superior izquierdo
            (list (+ base_x ancho_no) (- y_encabezados alto))             ; Inferior derecho
          )
          ;; Columna CODIGO (columna 1)
          (list
            (list (+ base_x ancho_no) y_encabezados)                      ; Superior izquierdo
            (list (+ base_x ancho_no ancho_codigo) (- y_encabezados alto)) ; Inferior derecho
          )
          ;; Columna DESCRIPCION (columna 2)
          (list
            (list (+ base_x ancho_no ancho_codigo) y_encabezados)         ; Superior izquierdo
            (list (+ base_x ancho_no ancho_codigo ancho_descripcion) (- y_encabezados alto)) ; Inferior derecho
          )
          ;; Columna UNIDAD (columna 3)
          (list
            (list (+ base_x ancho_no ancho_codigo ancho_descripcion) y_encabezados) ; Superior izquierdo
            (list (+ base_x ancho_no ancho_codigo ancho_descripcion ancho_unidad) (- y_encabezados alto)) ; Inferior derecho
          )
          ;; Columna P.U. (columna 4)
          (list
            (list (+ base_x ancho_no ancho_codigo ancho_descripcion ancho_unidad) y_encabezados) ; Superior izquierdo
            (list (+ base_x ancho_no ancho_codigo ancho_descripcion ancho_unidad ancho_pu) (- y_encabezados alto)) ; Inferior derecho
          )
          ;; Columna CANTIDAD (columna 5)
          (list
            (list (+ base_x ancho_no ancho_codigo ancho_descripcion ancho_unidad ancho_pu) y_encabezados) ; Superior izquierdo
            (list (+ base_x ancho_no ancho_codigo ancho_descripcion ancho_unidad ancho_pu ancho_cantidad) (- y_encabezados alto)) ; Inferior derecho
          )
          ;; Columna IMPORTE (columna 6)
          (list
            (list (+ base_x ancho_no ancho_codigo ancho_descripcion ancho_unidad ancho_pu ancho_cantidad) y_encabezados) ; Superior izquierdo
            (list (+ base_x total_ancho) (- y_encabezados alto)) ; Inferior derecho
          )
        )
      )
      
      ;; OBTENER DATOS
      (princ "\nPega los datos (Ctrl+V) y presiona Enter 2 veces:")
      (princ "\nFORMATO: No. Codigo Descripcion Unidad P.U. Cantidad Importe")
      (setq entradaCompleta "")
      (setq linea (getstring T "\n>>> "))
      
      (while (and linea (/= linea ""))
        (setq entradaCompleta (strcat entradaCompleta linea "\n"))
        (setq linea (getstring T ""))
      )
      
      (if (/= entradaCompleta "")
        (progn
          (setq datos (procesarDatos7Columnas entradaCompleta))
          
          (if (and datos (> (length datos) 0))
            (progn
              ;; 1. CREAR RECTÁNGULO ENCABEZADOS
              (princ "\nCreando rectángulo para encabezados...")
              (crear-rectangulo-encabezados base_x y_encabezados total_ancho alto)
              
              ;; 2. INSERTAR ENCABEZADOS
              (princ "\nInsertando encabezados de columna...")
              (insertarEncabezado7Columnas coords_encabezados)
              
              ;; 3. INSERTAR DATOS
              (princ (strcat "\nProcesando " (itoa (length datos)) " filas de datos..."))
              (setq filaActual 0)
              
              (foreach fila datos
                (insertarTextoEnCelda7Columnas (nth 0 coords_datos) (nth 0 fila) filaActual 0)
                (insertarTextoEnCelda7Columnas (nth 1 coords_datos) (dividirCodigo (nth 1 fila)) filaActual 1)
                (insertarMTextoEnCelda7Columnas (nth 2 coords_datos) (nth 2 fila) filaActual 2)
                (insertarTextoEnCelda7Columnas (nth 3 coords_datos) (nth 3 fila) filaActual 3)
                (insertarTextoEnCelda7Columnas (nth 4 coords_datos) (nth 4 fila) filaActual 4)
                (insertarTextoEnCelda7Columnas (nth 5 coords_datos) (nth 5 fila) filaActual 5)
                (insertarTextoEnCelda7Columnas (nth 6 coords_datos) (nth 6 fila) filaActual 6)
                (setq filaActual (1+ filaActual))
              )
              
              (setq num_filas (length datos))
              (princ (strcat "\nTabla completada: " (itoa num_filas) " filas insertadas"))
              
              ;; 4. CALCULAR TOTALES
              (setq total_importe (calcularTotalImporte datos))
              
              (if (> total_importe 0.0)
                (progn
                  (crearLineaSeparadora base_x base_y num_filas total_ancho)
                  (insertarFilaTotal base_x base_y total_ancho num_filas total_importe coords_datos)
                )
              )
              
              ;; 5. CREAR VISTAS (ALINEADAS EXACTAMENTE CON LAS FILAS DE DATOS)
              (princ "\n--- Creando vistas automáticamente (una por fila) ---")
              (setq old_osmode (getvar "OSMODE"))
              (setq old_clayer (getvar "CLAYER"))
              (setvar "OSMODE" 0)  ; Desactivar todos los snaps
              
              (if (= (getvar "TILEMODE") 0)
                (command "_.TILEMODE" "1")
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
                ;; Calcular coordenadas EXACTAS para cada fila
                ;; Las filas de datos empiezan en y_datos y bajan con cada fila
                (setq y_superior (- y_datos (* i alto)))           ; Y superior de la fila
                (setq y_inferior (- y_superior alto))              ; Y inferior de la fila
                
                ;; Puntos para la vista (coordenadas EXACTAS de la fila)
                (setq p1 (list base_x y_superior))                 ; Superior izquierdo
                (setq p2 (list (+ base_x ancho_vistas) y_inferior)) ; Inferior derecho
                
                ;; Crear nombre de vista
                (setq nombre_vista (strcat (if (< (1+ i) 10) "0" "") (itoa (1+ i))))
                
                ;; Crear vista con las coordenadas EXACTAS de la fila
                (command "_.-VIEW" "_W" nombre_vista p1 p2)
                
                ;; Crear rectángulo de vista con las MISMAS coordenadas
                (command "_.RECTANG" "_non" p1 "_non" p2)
                
                (setq i (1+ i))
              )
              
              (setvar "CLAYER" old_clayer)
              (setvar "OSMODE" old_osmode)
              
              (princ (strcat "\nVistas creadas: " (itoa num_filas) " vistas"))
              (princ "\nRectángulos en capa VISTAS (color 24)")
              (princ "\nRectángulo de encabezados en capa ENCABEZADOS (color 52)")
              (princ (strcat "\nTOTAL IMPORTE: $" (rtos total_importe 2 2)))
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

;; FUNCIONES PRINCIPALES (7 COLUMNAS)
(defun insertarEncabezadoConOffset (coord contenido numFila colIndex offset_abajo / x1 y1 x2 y2 centroX centroY)
  (setq x1 (caar coord))
  (setq y1 (cadar coord))
  (setq x2 (caadr coord))
  (setq y2 (cadadr coord))
  (setq centroX (/ (+ x1 x2) 2.0))
  (setq centroY (/ (+ y1 y2) 2.0))
  (setq centroY (- centroY offset_abajo))
  
  (if (and contenido (/= contenido ""))
    (entmakex
      (list
        '(0 . "TEXT")
        '(100 . "AcDbEntity")
        '(100 . "AcDbText")
        (cons 8 "ENCABEZADOS")
        (cons 7 "ARIAL")
        (cons 1 (strcase contenido))
        (cons 10 (list centroX centroY 0.0))
        (cons 11 (list centroX centroY 0.0))
        (cons 40 0.2)
        (cons 50 0.0)
        (cons 72 1)
        (cons 73 1)
      )
    )
  )
)

(defun insertarEncabezado7Columnas (coords_encabezados)
  (insertarEncabezadoConOffset (nth 0 coords_encabezados) "No." 0 0 0.20)
  (insertarEncabezadoConOffset (nth 1 coords_encabezados) "CODIGO" 0 1 0.20)
  (insertarEncabezadoConOffset (nth 2 coords_encabezados) "DESCRIPCION" 0 2 0.20)
  (insertarEncabezadoConOffset (nth 3 coords_encabezados) "UNIDAD" 0 3 0.20)
  (insertarEncabezadoConOffset (nth 4 coords_encabezados) "P.U." 0 4 0.20)
  (insertarEncabezadoConOffset (nth 5 coords_encabezados) "CANTIDAD" 0 5 0.20)
  (insertarEncabezadoConOffset (nth 6 coords_encabezados) "IMPORTE" 0 6 0.20)
)

;; ============================================================
;; FUNCIÓN MODIFICADA: CODIGO COMO MTEXT + P.U. e IMPORTE COMO MTEXT CON ESPACIOS
;; ============================================================
(defun insertarTextoEnCelda7Columnas (coord contenido numFila colIndex / x1 y1 x2 y2 centroX centroY puntoInsercion justificacionH justificacionV ancho_codigo)
  (setq x1 (caar coord))
  (setq y1 (cadar coord))
  (setq x2 (caadr coord))
  (setq y2 (cadadr coord))
  (setq centroX (/ (+ x1 x2) 2.0))
  (setq centroY (- (/ (+ y1 y2) 2.0) (* numFila 1.0)))
  (setq ancho_codigo *mp-ancho-codigo*)
  
  (cond
    ((or (= colIndex 0) (= colIndex 1) (= colIndex 3))
     (setq justificacionH 1 justificacionV 1 puntoInsercion (list centroX centroY 0.0)))
    ((= colIndex 4)  ; P.U.
     (setq justificacionH 2 justificacionV 1 puntoInsercion (list (- x2 0.1) centroY 0.0)))
    ((= colIndex 5)  ; CANTIDAD - RECORRIDA A LA IZQUIERDA
     (setq justificacionH 2 justificacionV 1 puntoInsercion (list (- x2 0.6) centroY 0.0)))
    ((= colIndex 6)  ; IMPORTE
     (setq justificacionH 2 justificacionV 1 puntoInsercion (list (- x2 0.1) centroY 0.0)))
    (t
     (setq justificacionH 1 justificacionV 1 puntoInsercion (list centroX centroY 0.0)))
  )
  
  (if (and contenido (/= contenido ""))
    (progn
      ;; ==========================================================
      ;; COLUMNA CODIGO (colIndex = 1) ? USAR MTEXT CON DOS LÍNEAS
      ;; ==========================================================
      (if (= colIndex 1)
        (progn
          (entmakex
            (list
              '(0 . "MTEXT")
              '(100 . "AcDbEntity")
              '(100 . "AcDbMText")
              (cons 8 "CONCEPTOS")
              (cons 7 "MONOTXT4")
              (cons 1 contenido)
              (cons 10 (list (- x1 0.05) (- centroY 0.075) 0.0))
              (cons 40 0.15)
              (cons 41 ancho_codigo)
              (cons 71 4)
              (cons 72 5)
              (cons 50 0.0)
            )
          )
        )
        ;; ==========================================================
        ;; COLUMNAS P.U. (4) e IMPORTE (6) ? USAR MTEXT CON ESPACIOS
        ;; ==========================================================
        ((or (= colIndex 4) (= colIndex 6))
         (progn
           (if (esNumero contenido)
             (setq contenido (strcat "$  " contenido))
           )
           (entmakex
             (list
               '(0 . "MTEXT")
               '(100 . "AcDbEntity")
               '(100 . "AcDbMText")
               (cons 8 "CONCEPTOS")
               (cons 7 "MONOTXT4")
               (cons 1 contenido)
               (cons 10 (list (- x2 0.5) (- centroY 0.075) 0.0))
               (cons 40 0.15)
               (cons 41 (- x2 x1))
               (cons 71 2)           ; Justificación derecha
               (cons 72 5)           ; Centrado vertical
               (cons 50 0.0)
             )
           )
         )
        )
        ;; ==========================================================
        ;; OTRAS COLUMNAS ? USAR TEXT NORMAL
        ;; ==========================================================
        (t
         (entmakex
           (list
             '(0 . "TEXT")
             '(100 . "AcDbEntity")
             '(100 . "AcDbText")
             (cons 8 "CONCEPTOS")
             (cons 7 "MONOTXT4")
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
  )
)

(defun insertarMTextoEnCelda7Columnas (coord contenido numFila colIndex / x1 y1 x2 y2 puntoInsercion ancho_mtext)
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
        (cons 7 "MONOTXT4")
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

(defun crear-rectangulo-encabezados (x y ancho alto)
  (setq old_layer (getvar "CLAYER"))
  (setvar "CLAYER" "ENCABEZADOS")
  (command "_.RECTANG" "_non" (list x y) "_non" (list (+ x ancho) (- y alto)) "")
  (setvar "CLAYER" old_layer)
  (princ " [OK]")
)

;; FUNCIONES DE PROCESAMIENTO (7 COLUMNAS)
(defun procesarDatos7Columnas (datosCadena / lineas datos numLinea linea datosLinea)
  (setq lineas (split-string datosCadena "\n"))
  (setq datos '())
  (setq numLinea 0)
  
  (foreach linea lineas
    (setq numLinea (1+ numLinea))
    (if (and (/= linea "") (> (strlen (vl-string-trim " \t" linea)) 0))
      (progn
        (setq datosLinea (procesarLinea7Columnas linea))
        (if datosLinea
          (setq datos (cons datosLinea datos))
        )
      )
    )
  )
  
  (if datos (reverse datos) nil)
)

(defun procesarLinea7Columnas (linea / partes)
  (setq partes (split-string linea "\t"))
  
  (cond
    ((= (length partes) 7)
      (list 
        (limpiarTexto (nth 0 partes))
        (limpiarTexto (nth 1 partes))
        (limpiarTexto (nth 2 partes))
        (limpiarTexto (nth 3 partes))
        (limpiarTexto (nth 4 partes))
        (limpiarTexto (nth 5 partes))
        (limpiarTexto (nth 6 partes))
      )
    )
    (t
      (setq partes (split-string-multiple linea))
      (procesarLineaConEspacios7Columnas partes)
    )
  )
)

(defun procesarLineaConEspacios7Columnas (partes / no codigo descripcion unidad pu cantidad importe i)
  (cond
    ((= (length partes) 7)
      (list (nth 0 partes) (nth 1 partes) (nth 2 partes) (nth 3 partes) (nth 4 partes) (nth 5 partes) (nth 6 partes))
    )
    ((> (length partes) 7)
      (setq no (nth 0 partes))
      (setq codigo (nth 1 partes))
      (setq importe (last partes))
      (setq cantidad (nth (- (length partes) 2) partes))
      (setq pu (nth (- (length partes) 3) partes))
      (setq unidad (nth (- (length partes) 4) partes))
      
      (setq descripcion "")
      (setq i 2)
      (while (< i (- (length partes) 4))
        (setq descripcion (strcat descripcion (nth i partes) " "))
        (setq i (1+ i))
      )
      
      (setq descripcion (vl-string-trim " " descripcion))
      (list no codigo descripcion unidad pu cantidad importe)
    )
    (t
      (setq no (if (> (length partes) 0) (nth 0 partes) ""))
      (setq codigo (if (> (length partes) 1) (nth 1 partes) ""))
      (setq descripcion (if (> (length partes) 2) (nth 2 partes) ""))
      (setq unidad (if (> (length partes) 3) (nth 3 partes) ""))
      (setq pu (if (> (length partes) 4) (nth 4 partes) ""))
      (setq cantidad (if (> (length partes) 5) (nth 5 partes) ""))
      (setq importe (if (> (length partes) 6) (nth 6 partes) ""))
      
      (list no codigo descripcion unidad pu cantidad importe)
    )
  )
)

;; FUNCIONES PARA CALCULAR TOTALES
(defun calcularTotalImporte (datos / total importe_str importe)
  (setq total 0.0)
  
  (foreach fila datos
    (setq importe_str (nth 6 fila))
    
    (if importe_str
      (progn
        (setq importe_str (vl-string-trim " $" importe_str))
        (setq importe_str (vl-string-translate "," "." importe_str))
        
        (if (setq importe (distof importe_str))
          (setq total (+ total importe))
        )
      )
    )
  )
  
  total
)

(defun insertarFilaTotal (base_x base_y total_ancho num_filas total_importe coords_datos / y_pos)
  (crearLineaSeparadora base_x base_y num_filas total_ancho)
  (insertarTextoEnCelda7Columnas (nth 2 coords_datos) "T O T A L" num_filas 2)
  (insertarTextoEnCelda7Columnas (nth 6 coords_datos) (strcat "$  " (rtos total_importe 2 2)) num_filas 6)
)

(defun crearLineaSeparadora (x_base y_base num_fila ancho_total / y_pos)
  (setq y_pos (- y_base (* (1+ num_fila) 1.0) 0.5))
  
  (entmakex
    (list
      '(0 . "LINE")
      '(100 . "AcDbEntity")
      '(100 . "AcDbLine")
      (cons 8 "CONCEPTOS")
      (cons 10 (list x_base y_pos 0.0))
      (cons 11 (list (+ x_base ancho_total) y_pos 0.0))
      (cons 62 1)
    )
  )
)

;; FUNCIONES AUXILIARES
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

;; COMANDO ADICIONAL
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

;; MENSAJE DE CARGA
(princ "\n==================================================")
(princ "\n       SISTEMA ASI - VERSIÓN 7 COLUMNAS          ")
(princ "\n==================================================")
(princ "\nCOLUMNAS:")
(princ "\n• No. (0.9841) | CODIGO (1.7887) | DESCRIPCION (14.8620)")
(princ "\n• UNIDAD (1.1700) | P.U. (1.7250) | CANTIDAD (1.6997)")
(princ "\n• IMPORTE (1.9849)")
(princ "\nTOTAL ANCHO: 24.2144 unidades")
(princ "\n==================================================")
(princ "\nCARACTERÍSTICAS:")
(princ "\n• 7 columnas completas")
(princ "\n• Altura de fila: 1.00")
(princ "\n• Cálculo automático de total de importes")
(princ "\n• Vistas automáticas por cada fila (EXACTAMENTE ALINEADAS)")
(princ "\n• CODIGO en MTEXT con dos líneas")
(princ "\n• CANTIDAD recorrida a la izquierda")
(princ "\n• P.U. e IMPORTE en MTEXT con dos espacios después del $")
(princ "\n• SIN números de fila a la izquierda")
(princ "\n• ESTILOS DE TEXTO AUTOMÁTICOS")
(princ "\n==================================================")
(princ "\nCOMANDOS:")
(princ "\n  ASI - Crear tabla completa (7 columnas)")
(princ "\n  LIMPIARTABLA - Limpiar capas")
(princ "\n==================================================")
(princ)