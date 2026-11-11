(defun c:CL (/ doc layoutActivo numCopias prefijo i nuevoNombre)
  (vl-load-com)
  
  ;; Obtener el layout activo
  (setq doc (vla-get-ActiveDocument (vlax-get-Acad-Object)))
  (setq layoutActivo (vla-get-ActiveLayout doc))
  
  (princ (strcat "\nLayout activo: " (vla-get-Name layoutActivo)))
  
  ;; Número de copias y prefijo
  (setq numCopias (getint "\nNúmero de copias: "))
  (setq prefijo (getstring T "\nPrefijo para las copias: "))
  
  ;; Loop de copias
  (setq i 0)
  (repeat numCopias
    (setq i (1+ i))
    (setq nuevoNombre (strcat prefijo (if (< i 10) "0" "") (itoa i)))
    
    ;; Verificar si el nombre ya existe
    (if (not (existe-layout nuevoNombre))
      (progn
        ;; Usar comando de AutoCAD para copiar layout
        (command "_.-LAYOUT" "_C" (vla-get-Name layoutActivo) nuevoNombre)
        (princ (strcat "\nLayout creado: " nuevoNombre))
      )
      (princ (strcat "\nEl layout " nuevoNombre " ya existe. Saltando..."))
    )
  )
  
  (princ (strcat "\nSe crearon " (itoa i) " copias del layout activo."))
  (princ)
)

;; Función auxiliar para verificar si un layout existe
(defun existe-layout (nombre-layout)
  (if (vl-catch-all-error-p 
        (vl-catch-all-apply 'vla-Item (list (vla-get-Layouts (vla-get-ActiveDocument (vlax-get-Acad-Object))) nombre-layout)))
    nil
    T
  )
)

(princ "\nComando ClonLayout cargado. Ejecute ClonLayout para copiar el layout activo.")
(princ)