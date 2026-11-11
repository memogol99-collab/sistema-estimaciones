(defun c:BTR (/ ss_rect i ent_rect ent_data pts pt z j ent_text del_list)
  (vl-load-com)
  
  (prompt "\nSeleccione los rectángulos (polilíneas) para procesar: ")
  ; Seleccionamos solo LWPOLYLINE
  (if (setq ss_rect (ssget '((0 . "LWPOLYLINE"))))
    (progn
      (setq i 0)
      (setq del_list nil)
      
      (prompt "\nAnalizando geometría y buscando textos...")
      
      (while (< i (sslength ss_rect))
        (setq ent_rect (ssname ss_rect i))
        (setq ent_data (entget ent_rect))
        
        ; 1. Obtener elevación (Z)
        (setq z (cdr (assoc 38 ent_data)))
        (if (null z) (setq z 0.0))
        
        ; 2. Construir lista de puntos para el polígono
        (setq pts nil)
        (foreach item ent_data
          (if (= (car item) 10)
            (progn
              ; Construir punto 3D en OCS
              (setq pt (list (cadr item) (caddr item) z))
              ; Convertir a UCS actual (Donde trabaja ssget)
              (setq pt (trans pt ent_rect 1))
              ; IMPORTANTE: ssget "WP" prefiere puntos 2D proyectados en el plano actual
              ; Extraemos solo X e Y para evitar errores de "cadena de modo"
              (setq pts (cons (list (car pt) (cadr pt)) pts))
            )
          )
        )
        
        ; 3. Seleccionar textos con "_WP" (Window Polygon)
        ; El guion bajo _ asegura compatibilidad de idioma
        (if pts
          ; Intentamos seleccionar textos. Ignoramos errores si la vista no es válida para WP
          (setq ss_text (ssget "_WP" pts '((0 . "*TEXT"))))
        )
        
        ; 4. Agregar a la lista de eliminación
        (if ss_text
          (progn
            (setq j 0)
            (while (< j (sslength ss_text))
              (setq ent_text (ssname ss_text j))
              (if (not (member ent_text del_list))
                (setq del_list (cons ent_text del_list))
              )
              (setq j (1+ j))
            )
          )
        )
        (setq i (1+ i))
      )
      
      ; 5. Eliminar
      (if del_list
        (progn
          (foreach txt del_list (entdel txt))
          (prompt (strcat "\nListo. Se eliminaron " (itoa (length del_list)) " textos."))
        )
        (prompt "\nNo se encontraron textos dentro de los rectángulos.")
      )
    )
    (prompt "\nNo se seleccionaron objetos.")
  )
  (princ)
)