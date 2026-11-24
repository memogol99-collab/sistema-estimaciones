(defun C:CLIPIT ()
  (princ "\nSelecciona el rectángulo (perímetro de recorte): ")
  (setq rectangulo (entsel))
  
  (if rectangulo
    (progn
      (setq rectangulo_ent (car rectangulo))
      
      (princ "\nSelecciona la imagen a recortar: ")
      (setq imagen (entsel))
      
      (if imagen
        (progn
          (setq imagen_ent (car imagen))
          
          ;; Obtener la información necesaria del rectángulo
          (setq rectangulo_data (entget rectangulo_ent))
          (setq tipo_rectangulo (cdr (assoc 0 rectangulo_data)))
          
          ;; Verificar si el rectángulo es una polilínea cerrada
          (if (eq tipo_rectangulo "LWPOLYLINE")
            (progn
              ;; Recortar la imagen usando el rectángulo
              (command "IMAGECLIP" imagen_ent "" "P" rectangulo_ent "")
              (princ "\nImagen recortada exitosamente.")
            )
            (princ "\nEl perímetro debe ser una polilínea cerrada.")
          )
        )
        (princ "\nNo se seleccionó ninguna imagen.")
      )
    )
    (princ "\nNo se seleccionó ningún rectángulo.")
  )
  (princ)
)

(princ "\nComando CLIPIMAGE_RECT cargado. Escribe CLIPIMAGE_RECT para ejecutar.")
(princ)