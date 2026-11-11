;;; MEMO SISTEMA 2.1.1 - archivo generado por construir_bundle.py
;;; Origen: LISP_Estimaciones/RenumerarRectangulos ( RV ).lsp
;;; Parches aplicados: renombrar:RV=RNB

;;; ============================================================================
;;; RENUMERARVECINO.LSP - Versión MEJORADA v3.1
;;; Renumeración por vecino más cercano
;;; SOLO elimina números de los rectángulos SELECCIONADOS
;;; Números CENTRADOS y ALINEADOS con el LADO LARGO (usando vértices reales)
;;; ============================================================================

;;; Variable global
(setq *rectangulos-lista* '())

;;; ============================================================================
;;; FUNCIÓN: obtener-vertices-rectangulo
;;; Devuelve la lista de vértices del rectángulo
;;; ============================================================================
(defun obtener-vertices-rectangulo (ent / elist vertices x y)
  (setq elist (entget ent))
  (setq vertices '())
  
  (foreach item elist
    (if (= (car item) 10)
      (progn
        (setq x (cadr item))
        (setq y (caddr item))
        (setq vertices (append vertices (list (list x y 0.0))))
      )
    )
  )
  
  vertices
)

;;; ============================================================================
;;; FUNCIÓN: obtener-centro-rapido
;;; ============================================================================
(defun obtener-centro-rapido (ent / elist minx miny maxx maxy x y)
  (setq minx 1e308 miny 1e308 maxx -1e308 maxy -1e308)
  (setq elist (entget ent))
  
  (foreach item elist
    (if (= (car item) 10)
      (progn
        (setq x (cadr item))
        (setq y (caddr item))
        (if (< x minx) (setq minx x))
        (if (< y miny) (setq miny y))
        (if (> x maxx) (setq maxx x))
        (if (> y maxy) (setq maxy y))
      )
    )
  )
  
  (list (/ (+ minx maxx) 2) (/ (+ miny maxy) 2) 0.0)
)

;;; ============================================================================
;;; FUNCIÓN: distancia-2d
;;; Calcula la distancia entre dos puntos 2D
;;; ============================================================================
(defun distancia-2d (p1 p2)
  (sqrt (+ (expt (- (car p1) (car p2)) 2)
           (expt (- (cadr p1) (cadr p2)) 2)))
)

;;; ============================================================================
;;; FUNCIÓN: angulo-entre-puntos
;;; Calcula el ángulo entre dos puntos (en radianes)
;;; ============================================================================
(defun angulo-entre-puntos (p1 p2)
  (angle p1 p2)
)

;;; ============================================================================
;;; FUNCIÓN: obtener-datos-lado-largo-v2
;;; Analiza los vértices para encontrar el lado más largo y su ángulo
;;; Devuelve el ángulo del lado largo (ajustado para texto legible)
;;; ============================================================================
(defun obtener-datos-lado-largo-v2 (ent / vertices n i p1 p2 dist1 dist2 
                                       angulo-lado1 angulo-lado2 longitud-lado1 longitud-lado2)
  (setq vertices (obtener-vertices-rectangulo ent))
  (setq n (length vertices))
  
  (if (< n 4)
    ;; Si no hay suficientes vértices, usar método anterior
    (progn
      (setq angulo-lado1 0.0)
      (setq longitud-lado1 1.0)
      (setq longitud-lado2 1.0)
    )
    (progn
      ;; Calcular distancia del lado 0-1 y lado 1-2
      (setq p1 (nth 0 vertices))
      (setq p2 (nth 1 vertices))
      (setq longitud-lado1 (distancia-2d p1 p2))
      (setq angulo-lado1 (angulo-entre-puntos p1 p2))
      
      (setq p1 (nth 1 vertices))
      (setq p2 (nth 2 vertices))
      (setq longitud-lado2 (distancia-2d p1 p2))
      (setq angulo-lado2 (angulo-entre-puntos p1 p2))
      
      ;; Determinar cuál es el lado largo y devolver su ángulo
      ;; El texto va PARALELO al lado largo (no perpendicular)
      (if (> longitud-lado1 longitud-lado2)
        ;; Lado 1 es el largo - el texto va paralelo a este lado
        (setq angulo-lado1 angulo-lado1)
        ;; Lado 2 es el largo - el texto va paralelo a este lado
        (setq angulo-lado1 angulo-lado2)
      )
    )
  )
  
  ;; Normalizar el ángulo entre 0 y 2*pi
  (while (> angulo-lado1 (* 2 pi))
    (setq angulo-lado1 (- angulo-lado1 (* 2 pi)))
  )
  (while (< angulo-lado1 0)
    (setq angulo-lado1 (+ angulo-lado1 (* 2 pi)))
  )
  
  ;; Si el ángulo está entre 90° y 270° (pi/2 y 3*pi/2), 
  ;; el texto quedaría de cabeza, así que giramos 180°
  (if (and (> angulo-lado1 (/ pi 2))
           (< angulo-lado1 (* 1.5 pi)))
    (setq angulo-lado1 (+ angulo-lado1 pi))
  )
  
  ;; Normalizar nuevamente
  (while (> angulo-lado1 (* 2 pi))
    (setq angulo-lado1 (- angulo-lado1 (* 2 pi)))
  )
  (while (< angulo-lado1 0)
    (setq angulo-lado1 (+ angulo-lado1 (* 2 pi)))
  )
  
  ;; Devolver el ángulo
  angulo-lado1
)

;;; ============================================================================
;;; FUNCIÓN: distancia-entre-puntos
;;; ============================================================================
(defun distancia-entre-puntos (p1 p2)
  (sqrt (+ (expt (- (car p1) (car p2)) 2)
           (expt (- (cadr p1) (cadr p2)) 2)))
)

;;; ============================================================================
;;; FUNCIÓN: encontrar-vecino-mas-cercano
;;; ============================================================================
(defun encontrar-vecino-mas-cercano (punto lista-rectangulos visitados / 
                                      menor-distancia rect-cercano distancia ent)
  (setq menor-distancia 1e308)
  (setq rect-cercano nil)
  
  (foreach rect lista-rectangulos
    (setq ent (nth 0 rect))
    (if (not (member ent visitados))
      (progn
        (setq distancia (distancia-entre-puntos punto (nth 4 rect)))
        (if (< distancia menor-distancia)
          (progn
            (setq menor-distancia distancia)
            (setq rect-cercano rect)
          )
        )
      )
    )
  )
  
  rect-cercano
)

;;; ============================================================================
;;; FUNCIÓN: entidad-igual
;;; ============================================================================
(defun entidad-igual (ent1 ent2)
  (= (cdr (assoc 5 (entget ent1))) (cdr (assoc 5 (entget ent2))))
)

;;; ============================================================================
;;; FUNCIÓN: crear-estilo-texto-arial
;;; ============================================================================
(defun crear-estilo-texto-arial ()
  (if (not (tblsearch "STYLE" "ARIAL"))
    (command "._-STYLE" "ARIAL" "arial.ttf" "0" "1" "0" "N" "N" "N")
  )
)

;;; ============================================================================
;;; FUNCIÓN: punto-dentro-de-lista-centros
;;; Verifica si un punto está cerca de algún centro de la lista de rectángulos
;;; ============================================================================
(defun punto-dentro-de-lista-centros (punto lista-rects tolerancia / 
                                       centro dist encontrado)
  (setq encontrado nil)
  (foreach rect lista-rects
    (setq centro (nth 4 rect))
    (if centro
      (progn
        (setq dist (distancia-entre-puntos punto centro))
        (if (< dist tolerancia)
          (setq encontrado T)
        )
      )
    )
  )
  encontrado
)

;;; ============================================================================
;;; FUNCIÓN: borrar-textos-solo-seleccionados
;;; Elimina SOLO los textos que están cerca del centro de los rectángulos 
;;; que fueron SELECCIONADOS por el usuario
;;; ============================================================================
(defun borrar-textos-solo-seleccionados (lista-rects / contador-elim ent ent-data
                                          insert-point pt10 pt11 dist tolerancia
                                          lista-a-borrar)
  (setq contador-elim 0)
  (setq lista-a-borrar '())
  (setq tolerancia 2.0)  ; Tolerancia de distancia
  
  ;; PASO 1: Recorrer TODAS las entidades de texto en la capa
  (setq ent (entnext))
  
  (while ent
    (setq ent-data (entget ent))
    
    ;; Verificar si es TEXT y está en la capa NUMEROS_RECTANGULOS
    (if (and (= (cdr (assoc 0 ent-data)) "TEXT")
             (= (strcase (cdr (assoc 8 ent-data))) "NUMEROS_RECTANGULOS"))
      (progn
        ;; Obtener punto de inserción del texto
        (setq pt10 (cdr (assoc 10 ent-data)))
        (setq pt11 (cdr (assoc 11 ent-data)))
        
        ;; Usar pt11 si existe (texto justificado), sino pt10
        (if (and pt11 (/= (car pt11) 0.0) (/= (cadr pt11) 0.0))
          (setq insert-point pt11)
          (setq insert-point pt10)
        )
        
        ;; Verificar si el texto está cerca del centro de los rectángulos SELECCIONADOS
        (if (and insert-point 
                 (punto-dentro-de-lista-centros insert-point lista-rects tolerancia))
          (setq lista-a-borrar (cons ent lista-a-borrar))
        )
      )
    )
    
    (setq ent (entnext ent))
  )
  
  ;; PASO 2: Eliminar los textos encontrados
  (foreach ent-borrar lista-a-borrar
    (entdel ent-borrar)
    (setq contador-elim (1+ contador-elim))
  )
  
  ;; Retornar cantidad eliminada
  contador-elim
)

;;; ============================================================================
;;; FUNCIÓN: crear-texto-numero-alineado
;;; Crea el texto CENTRADO en el rectángulo y ALINEADO con el lado largo
;;; Usa ENTMAKE con códigos DXF correctos
;;; ============================================================================
(defun crear-texto-numero-alineado (ent-rect numero / altura centro angulo texto-str ent-texto ent-data)
  (setq altura 0.6)
  
  ;; Obtener centro del rectángulo
  (setq centro (obtener-centro-rapido ent-rect))
  
  ;; Obtener ángulo del lado largo (analizando vértices reales)
  (setq angulo (obtener-datos-lado-largo-v2 ent-rect))
  
  ;; Crear el texto como string
  (setq texto-str (itoa numero))
  
  ;; Crear texto usando ENTMAKE
  (entmake
    (list
      (cons 0 "TEXT")                    ; Tipo de entidad
      (cons 100 "AcDbEntity")            ; Subclase
      (cons 8 "NUMEROS_RECTANGULOS")     ; Capa
      (cons 100 "AcDbText")              ; Subclase
      (cons 10 centro)                   ; Punto de inserción
      (cons 40 altura)                   ; Altura del texto
      (cons 1 texto-str)                 ; Contenido del texto
      (cons 7 "ARIAL")                   ; Estilo de texto
      (cons 50 angulo)                   ; Rotación en radianes
      (cons 100 "AcDbText")              ; Subclase
    )
  )
  
  ;; Obtener la entidad creada
  (setq ent-texto (entlast))
  (setq ent-data (entget ent-texto))
  
  ;; Agregar justificación Middle Center
  (setq ent-data 
    (append ent-data
      (list
        (cons 72 4)      ; Alineación horizontal: 4 = Centro
        (cons 11 centro) ; Punto de alineación
      )
    )
  )
  (entmod ent-data)
  
  ;; Agregar alineación vertical
  (setq ent-data (entget ent-texto))
  (setq ent-data 
    (append ent-data
      (list
        (cons 73 2)      ; Alineación vertical: 2 = Medio
      )
    )
  )
  (entmod ent-data)
)

;;; ============================================================================
;;; FUNCIÓN: actualizar-xdata-rectangulo
;;; ============================================================================
(defun actualizar-xdata-rectangulo (ent nuevo-numero largo ancho / xdata app-name nueva-xdata)
  ;; Obtener XDATA actual
  (setq xdata (entget ent '("RECTANGULOS_APP")))
  
  (if (assoc -3 xdata)
    (progn
      ;; Obtener nombre de la aplicación
      (setq app-name (car (cdr (assoc -3 xdata))))
      (setq app-name (car app-name))
      
      ;; Crear nueva XDATA
      (setq nueva-xdata (list -3 
                              (list app-name
                                    (cons 1000 (itoa nuevo-numero))
                                    (cons 1040 largo)
                                    (cons 1040 ancho))))
      
      ;; Actualizar entidad
      (entmod (subst nueva-xdata (assoc -3 xdata) xdata))
    )
  )
)

;;; ============================================================================
;;; FUNCIÓN: reconstruir-lista-desde-dibujo
;;; ============================================================================
(defun reconstruir-lista-desde-dibujo (/ ss i ent xdata datos num largo ancho)
  (setq ss (ssget "X" '((8 . "GEOMETRIA_RECTANGULOS"))))
  (setq *rectangulos-lista* '())
  
  (if ss
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq ent (ssname ss i))
        (setq xdata (entget ent '("RECTANGULOS_APP")))
        
        (if (assoc -3 xdata)
          (progn
            (setq datos (cdr (assoc -3 xdata)))
            (setq datos (car datos))
            (setq datos (cdr datos))
            
            (setq num (atoi (cdr (assoc 1000 datos))))
            (setq largo (cdr (assoc 1040 datos)))
            (setq datos (cdr (member (assoc 1040 datos) datos)))
            (setq ancho (cdr (assoc 1040 datos)))
            
            (setq *rectangulos-lista* 
                  (append *rectangulos-lista* 
                         (list (list num largo ancho))))
          )
        )
        (setq i (1+ i))
      )
    )
  )
)

;;; ============================================================================
;;; COMANDO: RENUMERARVECINO (RV)
;;; ============================================================================
(defun c:RENUMERARVECINO (/ old-cmdecho old-clayer ss i ent 
                            xdata lista-rectangulos nuevo-numero contador
                            rectangulo datos num-viejo largo ancho
                            punto-inicial rect-actual visitados centro
                            ent-inicial opcion num-buscar encontrado ent-lista
                            textos-eliminados)
  
  ;; Guardar variables
  (setq old-cmdecho (getvar "CMDECHO"))
  (setq old-clayer (getvar "CLAYER"))
  (setvar "CMDECHO" 0)
  
  (princ "\n")
  (princ "\n+--------------------------------------------------------------+")
  (princ "\n¦       RENUMERARVECINO v3.1                                   ¦")
  (princ "\n¦       Renumeración por vecino más cercano                    ¦")
  (princ "\n+--------------------------------------------------------------+")
  
  ;; Crear estilo ARIAL si no existe
  (crear-estilo-texto-arial)
  
  ;; Seleccionar rectángulos a renumerar
  (princ "\nSeleccione los rectángulos a renumerar (o Enter para todos): ")
  (setq ss (ssget '((8 . "GEOMETRIA_RECTANGULOS"))))
  
  (if (not ss)
    (princ "\nNo se seleccionaron rectángulos.")
    (progn
      (princ (strcat "\nRectángulos seleccionados: " (itoa (sslength ss))))
      
      ;; Crear lista con los rectángulos seleccionados y sus datos
      (setq lista-rectangulos '())
      (setq i 0)
      
      (repeat (sslength ss)
        (setq ent (ssname ss i))
        (setq xdata (entget ent '("RECTANGULOS_APP")))
        
        (if (assoc -3 xdata)
          (progn
            (setq datos (cdr (assoc -3 xdata)))
            (setq datos (car datos))
            (setq datos (cdr datos))
            
            (setq num-viejo (atoi (cdr (assoc 1000 datos))))
            (setq largo (cdr (assoc 1040 datos)))
            (setq datos (cdr (member (assoc 1040 datos) datos)))
            (setq ancho (cdr (assoc 1040 datos)))
            (setq centro (obtener-centro-rapido ent))
            
            (setq lista-rectangulos 
                  (append lista-rectangulos 
                         (list (list ent num-viejo largo ancho centro))))
          )
        )
        (setq i (1+ i))
      )
      
      (princ (strcat "\nRectángulos con datos XDATA: " (itoa (length lista-rectangulos))))
      
      (if (= (length lista-rectangulos) 0)
        (princ "\nNingún rectángulo seleccionado tiene datos XDATA.")
        (progn
          ;; Preguntar número inicial
          (initget 4)
          (setq nuevo-numero (getint "\nNúmero inicial para la renumeración: "))
          (if (not nuevo-numero)
            (setq nuevo-numero 1)
          )
          
          ;; Preguntar método de selección del rectángulo inicial
          (initget "Seleccionar Numero")
          (setq opcion (getkword "\n¿Seleccionar rectángulo inicial por [Seleccionar/Numero]? <Seleccionar>: "))
          
          (if (or (not opcion) (= opcion "Seleccionar"))
            (progn
              ;; SELECCIÓN GRÁFICA
              (setq ent-inicial (car (entsel "\nSeleccione el rectángulo inicial: ")))
              
              (if (not ent-inicial)
                (princ "\nNo se seleccionó rectángulo inicial.")
                (progn
                  ;; Buscar el rectángulo seleccionado en la lista
                  (setq rect-actual nil)
                  (setq encontrado nil)
                  (foreach rect lista-rectangulos
                    (setq ent-lista (car rect))
                    (if (entidad-igual ent-lista ent-inicial)
                      (progn
                        (setq rect-actual rect)
                        (setq encontrado T)
                      )
                    )
                  )
                  
                  (if (not encontrado)
                    (princ "\nEl rectángulo seleccionado no tiene datos XDATA válidos.")
                  )
                )
              )
            )
            (progn
              ;; SELECCIÓN POR NÚMERO
              (princ "\nRectángulos disponibles:")
              (foreach rect lista-rectangulos
                (princ (strcat "\n  Número " (itoa (cadr rect)) " - Ubicación: " 
                       (rtos (car (nth 4 rect)) 2 2) "," 
                       (rtos (cadr (nth 4 rect)) 2 2)))
              )
              
              (setq num-buscar (getint "\nIngrese el NÚMERO del rectángulo inicial: "))
              
              ;; Buscar el rectángulo con ese número
              (setq rect-actual nil)
              (foreach rect lista-rectangulos
                (if (= (cadr rect) num-buscar)
                  (setq rect-actual rect)
                )
              )
              
              (if (not rect-actual)
                (princ "\nNo se encontró un rectángulo con ese número.")
              )
            )
          )
          
          ;; Si se encontró el rectángulo inicial, proceder con la renumeración
          (if rect-actual
            (progn
              (setvar "CLAYER" "NUMEROS_RECTANGULOS")
              
              ;; ============================================================
              ;; ELIMINAR SOLO LOS NÚMEROS DE LOS RECTÁNGULOS SELECCIONADOS
              ;; ============================================================
              (princ "\n")
              (princ "\nEliminando números anteriores de la selección...")
              (setq textos-eliminados (borrar-textos-solo-seleccionados lista-rectangulos))
              (princ (strcat "\n? " (itoa textos-eliminados) " números eliminados de la selección."))
              (princ "\n")
              
              ;; ============================================================
              ;; INICIAR RENUMERACIÓN
              ;; ============================================================
              (setq contador nuevo-numero)
              (setq visitados (list (car rect-actual)))
              
              ;; Renumerar el primer rectángulo
              (setq ent (car rect-actual))
              (setq num-viejo (cadr rect-actual))
              (setq largo (caddr rect-actual))
              (setq ancho (cadddr rect-actual))
              (setq centro (nth 4 rect-actual))
              
              ;; Actualizar XDATA
              (actualizar-xdata-rectangulo ent contador largo ancho)
              
              ;; Crear nuevo texto centrado y alineado al lado largo
              (crear-texto-numero-alineado ent contador)
              
              (princ (strcat "\nRectángulo " (itoa num-viejo) " ? " (itoa contador)))
              (setq contador (1+ contador))
              (setq punto-inicial centro)
              
              ;; Renumerar el resto por vecino más cercano
              (while (< (length visitados) (length lista-rectangulos))
                (setq rect-actual (encontrar-vecino-mas-cercano 
                                    punto-inicial lista-rectangulos visitados))
                
                (if rect-actual
                  (progn
                    (setq ent (car rect-actual))
                    (setq num-viejo (cadr rect-actual))
                    (setq largo (caddr rect-actual))
                    (setq ancho (cadddr rect-actual))
                    (setq centro (nth 4 rect-actual))
                    
                    ;; Actualizar XDATA
                    (actualizar-xdata-rectangulo ent contador largo ancho)
                    
                    ;; Crear nuevo texto centrado y alineado al lado largo
                    (crear-texto-numero-alineado ent contador)
                    
                    (princ (strcat "\nRectángulo " (itoa num-viejo) " ? " (itoa contador)))
                    
                    (setq visitados (append visitados (list ent)))
                    (setq punto-inicial centro)
                    (setq contador (1+ contador))
                  )
                )
              )
              
              (princ "\n")
              (princ "\n------------------------------------------------------------")
              (princ (strcat "\n? Renumeración completada. Último número: " (itoa (1- contador))))
              (princ "\n------------------------------------------------------------")
              
              ;; Reconstruir la lista global
              (reconstruir-lista-desde-dibujo)
            )
          )
        )
      )
    )
  )
  
  ;; Restaurar variables
  (setvar "CMDECHO" old-cmdecho)
  (setvar "CLAYER" old-clayer)
  (princ)
)

;;; ============================================================================
;;; COMANDO CORTO: RV
;;; ============================================================================
(defun c:RNB ()
  (c:RENUMERARVECINO)
)

;;; ============================================================================
;;; MENSAJE DE CARGA
;;; ============================================================================
(princ "\n")
(princ "\n+--------------------------------------------------------------+")
(princ "\n¦       RENUMERARVECINO v3.1 - Cargado                         ¦")
(princ "\n¦--------------------------------------------------------------¦")
(princ "\n¦  Comandos disponibles:                                       ¦")
(princ "\n¦  RENUMERARVECINO (o RNB)- Renumerar por vecino más cercano  ¦")
(princ "\n¦--------------------------------------------------------------¦")
(princ "\n¦  • Elimina SOLO los números de los rectángulos SELECCIONADOS ¦")
(princ "\n¦  • Los otros rectángulos del dibujo NO se modifican          ¦")
(princ "\n¦  • Números CENTRADOS dentro del rectángulo                   ¦")
(princ "\n¦  • Números PARALELOS al LADO LARGO (usando vértices)         ¦")
(princ "\n¦  • Usa estilo ARIAL para los números                         ¦")
(princ "\n¦  • Renumeración ordenada por proximidad                      ¦")
(princ "\n+--------------------------------------------------------------+")
(princ "\n")
(princ)