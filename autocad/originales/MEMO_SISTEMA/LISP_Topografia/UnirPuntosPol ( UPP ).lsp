(defun c:UPP (/ *error* ssPts ptsList colorMA oldOsnap oldOsmode numPts i pEnt pEd pPt 
                cerrarPoligono ptsListOrdenada puntoInicio ssInicio pEntInicio pEdInicio)
  
  ;; Función de manejo de errores
  (defun *error* (msg)
    (if (not (member msg '("Function cancelled" "quit / exit abort")))
      (princ (strcat "\n? Error: " msg))
    )
    (setvar "CMDECHO" 1)
    (setvar "OSMODE" oldOsnap)
    (princ)
  )
  
  (princ "\n?? Unir puntos seleccionados con polilínea 2D...")
  
  ;; Configuración inicial
  (setvar "CMDECHO" 0)
  (setq oldOsnap (getvar "OSMODE"))
  
  ;; === Obtener color de la capa MA ===
  (setq colorMA 256)
  (if (tblsearch "LAYER" "MA")
    (progn
      (setq layerInfo (tblsearch "LAYER" "MA"))
      (setq colorMA (cdr (assoc 62 layerInfo)))
      (if (not colorMA) (setq colorMA 256))
    )
    (progn
      (command "_.-LAYER" "_M" "MA" "_C" "3" "" "")
      (setq colorMA 3)
      (princ "\n?? Capa 'MA' creada con color verde")
    )
  )
  
  ;; === FUNCIONES AUXILIARES ===
  
  ;; Distancia 2D (ignora Z)
  (defun dist2d (p1 p2)
    (sqrt (+ (expt (- (car p1) (car p2)) 2)
             (expt (- (cadr p1) (cadr p2)) 2)))
  )
  
  ;; === ALGORITMO: Ordenar desde punto elegido ===
  (defun OrdenarDesdePuntoElegido (listaPuntos puntoInicio / ruta pendientes actual 
                                                          distTotal masCercano)
    (if (<= (length listaPuntos) 1)
      listaPuntos
      (progn
        (setq ruta (list puntoInicio)
              pendientes (vl-remove puntoInicio listaPuntos)
              actual puntoInicio
              distTotal 0.0)
        
        ;; Conectar siempre al más cercano
        (while pendientes
          (setq masCercano
                (car (vl-sort pendientes
                             (function (lambda (a b)
                                        (< (dist2d actual a) (dist2d actual b))
                                      )
                             )
                     )
                )
          )
          
          (setq distTotal (+ distTotal (dist2d actual masCercano)))
          (setq ruta (cons masCercano ruta)
                pendientes (vl-remove masCercano pendientes)
                actual masCercano)
        )
        
        ;; Invertir para orden correcto
        (setq ruta (reverse ruta))
        
        (princ (strcat "\n?? Distancia total polilínea: " (rtos distTotal 2 2)))
        ruta
      )
    )
  )
  
  ;; === Función para crear polilínea ===
  (defun CrearPolilinea (ruta cerrar / ent)
    (if (and ruta (> (length ruta) 1))
      (progn
        ;; Temporalmente desactivar OSMODE para crear polilínea
        (setvar "OSMODE" 0)
        
        (command "_.PLINE")
        (foreach pt ruta
          (command "_NON" (list (car pt) (cadr pt) 0.0))
        )
        
        (if cerrar 
          (command "_C" "") 
          (command "")
        )
        
        (setq ent (entlast))
        (if ent
          (progn
            (entmod (append (entget ent)
                           (list (cons 8 "MA")
                                 (cons 62 colorMA)
                                 (cons 70 (if cerrar 1 0))
                                 (cons 370 25))))
            
            (princ (strcat "\n? Polilínea creada con " (itoa (length ruta)) " puntos"
                           (if cerrar " (CERRADA)" " (ABIERTA)")))
            T
          )
        )
        
        ;; Restaurar OSMODE original
        (setvar "OSMODE" oldOsnap)
      )
    )
  )
  
  ;; === PROGRAMA PRINCIPAL ===
  
  ;; PRIMERO: Seleccionar todos los puntos
  (princ "\n?? Seleccione TODOS los puntos a unir...")
  (setq ssPts (ssget '((0 . "POINT"))))
  
  (if ssPts
    (progn
      (setq ptsList '()
            numPts (sslength ssPts))
      
      ;; Recopilar puntos (solo XY)
      (repeat (setq i numPts)
        (setq pEnt (ssname ssPts (setq i (1- i)))
              pEd (entget pEnt)
              pPt (cdr (assoc 10 pEd)))
        
        ;; Solo tomar coordenadas XY (ignorar Z)
        (if (and (listp pPt) (>= (length pPt) 2))
          (setq ptsList (cons (list (car pPt) (cadr pPt)) ptsList))
        )
      )
      
      (princ (strcat "\n?? " (itoa (length ptsList)) " puntos seleccionados"))
      
      (if (>= (length ptsList) 2)
        (progn
          ;; SEGUNDO: Pedir al usuario que seleccione punto de INICIO
          ;; Activar solo OSNAP NODO para facilitar la selección
          (setq oldOsmode (getvar "OSMODE"))
          (setvar "OSMODE" 512) ; 512 = NODO (NODE) solamente
          
          (princ "\n?? Ahora seleccione el punto de INICIO (con NODO activado)...")
          (setq ssInicio (ssget ":S" '((0 . "POINT"))))
          
          ;; Restaurar OSNAP original
          (setvar "OSMODE" oldOsmode)
          
          (if ssInicio
            (progn
              ;; Obtener el punto de inicio seleccionado
              (setq pEntInicio (ssname ssInicio 0)
                    pEdInicio (entget pEntInicio)
                    puntoInicio (cdr (assoc 10 pEdInicio)))
              
              ;; Convertir a solo XY
              (setq puntoInicio (list (car puntoInicio) (cadr puntoInicio)))
              
              ;; Verificar que el punto de inicio esté en la lista original
              (if (not (member puntoInicio ptsList))
                (progn
                  ;; Si no está, agregarlo a la lista
                  (setq ptsList (cons puntoInicio ptsList))
                  (princ "\n?? Punto de inicio agregado a la selección")
                )
              )
              
              (princ (strcat "\n?? Punto inicial seleccionado: X=" 
                             (rtos (car puntoInicio) 2 2) " Y=" 
                             (rtos (cadr puntoInicio) 2 2)))
              
              ;; TERCERO: Preguntar si cerrar el polígono
              (initget "Sí No")
              (setq cerrarPoligono (getkword "\n?? ¿Cerrar polígono? [Sí/No] <No>: "))
              (if (not cerrarPoligono) 
                (setq cerrarPoligono "No")
              )
              
              (setq cerrarPoligono (eq cerrarPoligono "Sí"))
              
              ;; CUARTO: Ordenar puntos desde el punto inicial
              (princ "\n?? Ordenando puntos desde punto inicial...")
              (setq ptsListOrdenada (OrdenarDesdePuntoElegido ptsList puntoInicio))
              
              ;; QUINTO: Crear polilínea
              (if (CrearPolilinea ptsListOrdenada cerrarPoligono)
                (progn
                  (princ "\n?? Polilínea creada exitosamente")
                  (princ (strcat "\n?? Inicio en: X=" (rtos (car puntoInicio) 2 2) 
                                 " Y=" (rtos (cadr puntoInicio) 2 2)))
                )
                (princ "\n? Error al crear polilínea")
              )
            )
            (princ "\n? No se seleccionó punto de inicio")
          )
        )
        (princ "\n? Se necesitan al menos 2 puntos")
      )
    )
    (princ "\n? No se seleccionaron puntos")
  )
  
  ;; Restaurar configuración final
  (setvar "CMDECHO" 1)
  (setvar "OSMODE" oldOsnap)
  (princ)
)

;; Versión alternativa con OSNAP automático (NODO + PUNTO MEDIO + INTERSECCIÓN)
(defun c:UPPA (/ oldOsnap)
  (setq oldOsnap (getvar "OSMODE"))
  (setvar "OSMODE" 545) ; 512 (NODO) + 32 (PUNTO MEDIO) + 1 (INTERSECCIÓN)
  (princ "\n?? OSNAP configurado: NODO + PUNTO MEDIO + INTERSECCIÓN")
  (c:UPP)
  (setvar "OSMODE" oldOsnap)
)

(princ "\n?? Comandos cargados:")
(princ "\n??   UPP  - Unir puntos con selección manual de inicio")
(princ "\n??   UPPA - UPP con OSNAP automático (NODO+P.MEDIO+INTERSECCIÓN)")
(princ)