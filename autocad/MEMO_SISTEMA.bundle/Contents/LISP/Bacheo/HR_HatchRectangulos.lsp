;;; MEMO SISTEMA 2.0.0 - archivo generado por construir_bundle.py
;;; Origen: LISP_Estimaciones/HatchRectangulos.lsp
;;; Parches aplicados: msg-hr

(defun c:HR (/ *error* osm clayer ss i ent angulo escala capa_hatch respuesta)
  ;; Definir función de manejo de errores
  (defun *error* (msg)
    (if osm (setvar 'osmode osm))
    (if clayer (setvar 'clayer clayer))
    (if msg (princ (strcat "\nError: " msg)))
    (princ)
  )

  ;; Guardar configuración actual del sistema
  (setq osm (getvar 'osmode))
  (setq clayer (getvar 'clayer))
  
  ;; Desactivar el modo de referencia a objetos temporalmente
  (setvar 'osmode 0)
  
  ;; Definir nombre de la capa para sombreados
  (setq capa_hatch "SOMBREADOS_RECTANGULOS")
  
  ;; Crear o verificar la capa para sombreados
  (if (not (tblsearch "LAYER" capa_hatch))
    (progn
      (command "_.LAYER" 
               "_NEW" capa_hatch
               "_COLOR" "10" capa_hatch
               "")
      (princ (strcat "\nCapa " capa_hatch " creada con color 10."))
    )
    (princ (strcat "\nUsando capa existente: " capa_hatch))
  )
  
  ;; Establecer la capa de sombreados como actual
  (setvar 'clayer capa_hatch)
  
  ;; Preguntar al usuario el ÁNGULO (lo que ves en propiedades)
  (princ "\n--- CONFIGURACIÓN DEL SOMBREADO ---")
  (princ "\nNOTA: Lo que ingreses aquí será lo que veas en PROPIEDADES:")
  (princ "\n-----------------------------------")
  
  (setq respuesta (getreal "\nIngresa el ÁNGULO (lo que quieres ver en propiedades) [0]: "))
  (if (null respuesta)
    (setq angulo 0.0)
    (setq angulo respuesta)
  )
  
  ;; Preguntar al usuario la ESCALA (lo que ves en propiedades)
  (setq respuesta (getreal "\nIngresa la ESCALA (lo que quieres ver en propiedades) [45]: "))
  (if (null respuesta)
    (setq escala 45.0)
    (setq escala respuesta)
  )
  
  ;; Buscar TODOS los objetos en la capa GEOMETRIA_RECTANGULOS
  (princ "\nBuscando rectángulos en la capa GEOMETRIA_RECTANGULOS...")
  
  ;; Crear un conjunto de selección con TODOS los objetos en la capa especificada
  (if (setq ss (ssget "X" (list (cons 8 "GEOMETRIA_RECTANGULOS"))))
    (progn
      (setq i 0)
      
      (repeat (sslength ss)
        (setq ent (ssname ss i))
        
        ;; Crear sombreado para el rectángulo actual
        (command "_.HATCH" 
                 "_P"             ; Opción para patrón predefinido
                 "LINE"           ; Nombre del patrón
                 angulo           ; Ángulo (lo que ves en propiedades)
                 escala           ; Escala (lo que ves en propiedades)
                 "_S"             ; Opción para seleccionar objetos
                 ent              ; Seleccionar el rectángulo
                 ""               ; Terminar selección
                 ""               ; Aceptar (cerrar comando HATCH)
        )
        
        (setq i (1+ i))
      )
      
      (princ (strcat "\n¡Proceso completado! Se crearon " (itoa i) " sombreados."))
      (princ "\nVERIFICA EN PROPIEDADES:")
      (princ (strcat "\n  • Ángulo en propiedades: " (rtos angulo 2 2) "°"))
      (princ (strcat "\n  • Escala en propiedades: " (rtos escala 2 4)))
      (princ (strcat "\n  • Intervalo en propiedades: " (rtos escala 2 4)))
    )
    (princ "\nNo se encontraron objetos en la capa GEOMETRIA_RECTANGULOS.")
  )
  
  ;; Restaurar configuración original
  (setvar 'osmode osm)
  (setvar 'clayer clayer)
  (princ)
)

;; Mensaje de carga
(princ "\nRutina HatchRectangulos cargada. Escribe HR para ejecutar.")
(princ)