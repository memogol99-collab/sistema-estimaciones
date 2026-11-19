;;
;; ALINEACIÓN AUTOMÁTICA DE TEXTOS - VERSIÓN COMPLETA
;; Alinea textos (TEXT/MTEXT) en dirección vertical u horizontal
;; Programa desarrollado por Mario Torres Pejerrey
;; http://www.construcgeek.com/
;;

(vl-load-com)

(defun c:ALIT (/ *error* old_osmode old_cmdecho base_entity base_data base_type 
                  base_point direction ss aligned_count i entity entity_data 
                  current_point new_point new_data valid_selection)
  
  ;; Manejo robusto de errores
  (defun *error* (msg)
    (if (not (wcmatch (strcase msg) "*CANCEL*,*EXIT*"))
      (princ (strcat "\nError: " msg))
    )
    (if old_osmode (setvar "OSMODE" old_osmode))
    (if old_cmdecho (setvar "CMDECHO" old_cmdecho))
    (princ)
  )
  
  ;; Función para obtener punto de inserción según tipo de texto
  (defun obtener-punto-insercion (ent_data / ent_type just)
    (setq ent_type (cdr (assoc 0 ent_data)))
    
    (cond
      ((= ent_type "MTEXT")
       (cdr (assoc 10 ent_data)) ; MTEXT siempre usa código 10
      )
      ((= ent_type "TEXT")
       (setq just (cdr (assoc 72 ent_data)))
       (cond
         ((= just 0) (cdr (assoc 10 ent_data)))  ; Left - código 10
         ((= just 1) (cdr (assoc 11 ent_data)))  ; Center - código 11
         ((= just 2) (cdr (assoc 11 ent_data)))  ; Right - código 11
         ((= just 3) (cdr (assoc 11 ent_data)))  ; Aligned - código 11
         ((= just 4) (cdr (assoc 11 ent_data)))  ; Middle - código 11
         ((= just 5) (cdr (assoc 11 ent_data)))  ; Fit - código 11
         (t (cdr (assoc 10 ent_data)))           ; Default - código 10
       )
      )
      (t nil) ; Tipo no soportado
    )
  )
  
  ;; Función para actualizar posición de texto
  (defun actualizar-posicion-texto (ent_data new_point / ent_type just code)
    (setq ent_type (cdr (assoc 0 ent_data)))
    
    (cond
      ((= ent_type "MTEXT")
       ; MTEXT - actualizar código 10
       (subst (cons 10 new_point) (assoc 10 ent_data) ent_data)
      )
      ((= ent_type "TEXT")
       (setq just (cdr (assoc 72 ent_data)))
       (setq code (cond
                  ((= just 0) 10)  ; Left
                  ((= just 1) 11)  ; Center
                  ((= just 2) 11)  ; Right
                  ((= just 3) 11)  ; Aligned
                  ((= just 4) 11)  ; Middle
                  ((= just 5) 11)  ; Fit
                  (t 10)           ; Default
                ))
       (subst (cons code new_point) (assoc code ent_data) ent_data)
      )
      (t ent_data) ; No cambiar si no es texto
    )
  )
  
  ;; --- INICIO DEL PROGRAMA PRINCIPAL ---
  
  ; Guardar variables de AutoCAD
  (setq old_osmode (getvar "OSMODE")
        old_cmdecho (getvar "CMDECHO"))
  
  (setvar "OSMODE" 0)
  (setvar "CMDECHO" 0)
  
  (princ "\nALINEACION DE TEXTOS - VERSION MEJORADA")
  
  ; Bucle principal para múltiples operaciones
  (while T
    ; Seleccionar entidad base con validación
    (setq valid_selection nil)
    (while (not valid_selection)
      (setq base_entity (car (entsel "\nSeleccione texto base (TEXT/MTEXT) <Enter para terminar>: ")))
      
      (cond
        ((null base_entity) 
         (setq valid_selection T) ; Usuario presionó Enter - salir
        )
        ((not (wcmatch (cdr (assoc 0 (entget base_entity))) "TEXT,MTEXT"))
         (princ "\nError: La entidad debe ser TEXT o MTEXT. Intente nuevamente.")
        )
        (t (setq valid_selection T))
      )
    )
    
    (if (null base_entity)
      (progn
        (princ "\nOperacion finalizada por el usuario.")
        (exit)
      )
    )
    
    ; Obtener datos de la entidad base
    (setq base_data (entget base_entity))
    (setq base_type (cdr (assoc 0 base_data)))
    (setq base_point (obtener-punto-insercion base_data))
    
    (if (null base_point)
      (progn
        (princ "\nError: No se pudo obtener el punto de insercion del texto base.")
        (exit)
      )
    )
    
    ; Seleccionar dirección de alineación
    (initget "Vertical Horizontal")
    (setq direction (getkword "\nDireccion de alineacion [Vertical/Horizontal] <Vertical>: "))
    (if (not direction) (setq direction "Vertical"))
    
    ; Seleccionar textos a alinear
    (princ "\nSeleccione textos a alinear: ")
    (setq ss (ssget '((0 . "TEXT,MTEXT"))))
    
    (if (and ss (> (sslength ss) 0))
      (progn
        (setq aligned_count 0
              i 0)
        
        (repeat (sslength ss)
          (setq entity (ssname ss i))
          
          ; Evitar alinear el texto base consigo mismo
          (if (not (equal entity base_entity))
            (progn
              (setq entity_data (entget entity))
              (setq current_point (obtener-punto-insercion entity_data))
              
              (if current_point
                (progn
                  ; Calcular nuevo punto según dirección
                  (if (= direction "Vertical")
                    (setq new_point (list (car base_point) (cadr current_point) (caddr current_point)))
                    (setq new_point (list (car current_point) (cadr base_point) (caddr current_point)))
                  )
                  
                  ; Actualizar posición
                  (setq new_data (actualizar-posicion-texto entity_data new_point))
                  (entmod new_data)
                  
                  (setq aligned_count (1+ aligned_count))
                )
              )
            )
          )
          (setq i (1+ i))
        )
        
        ; Mostrar resumen
        (princ (strcat "\n" (itoa aligned_count) " textos alineados en direccion " direction))
        (princ (strcat "\nPunto base: " (rtos (car base_point) 2 2) ", " (rtos (cadr base_point) 2 2)))
        
      )
      (princ "\nNo se seleccionaron textos validos para alinear.")
    )
    
    (princ "\n") ; Línea en blanco para separar operaciones
  )
  
  ; Restaurar variables (en caso de salida inesperada)
  (setvar "OSMODE" old_osmode)
  (setvar "CMDECHO" old_cmdecho)
  (princ)
)

;; Mensaje de carga
(princ "\nComando ALIT cargado - Alineacion de textos mejorada")
(princ)