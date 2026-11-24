(defun c:IBM (/ ssblock ent ed basept ss i en ed2 pt vlaBlock copy-block-vla)

  (vl-load-com) ;; Cargar funciones Visual LISP necesarias
  (princ "\n--- Copiar bloque manteniendo escala, rotación y ATRIBUTOS ---")

  ;; --- Seleccionar bloque de referencia ---
  (setq ssblock (ssget "_+.:E:S" '((0 . "INSERT"))))
  (if (not ssblock)
    (progn (princ "\n¡¡ No se seleccionó un bloque.") (exit))
  )

  (setq ent (ssname ssblock 0))
  (setq ed  (entget ent))
  (setq basept (cdr (assoc 10 ed))) ; Punto de inserción original
  
  ;; Convertir el nombre de entidad a objeto VLA-OBJECT
  (setq vlaBlock (vlax-ename->vla-object ent))

  ;; --- Función interna para copiar y mover (Método Seguro) ---
  ;; Esta función copia el objeto completo y luego lo mueve al destino
  (setq copy-block-vla
    (lambda (newpt / newObj)
      ;; 1. Copiar el bloque (copia exacta incluyendo atributos)
      (setq newObj (vla-copy vlaBlock))
      
      ;; 2. Mover la copia desde el punto original al nuevo punto
      (vla-move newObj 
                (vlax-3d-point basept) 
                (vlax-3d-point newpt)
      )
    )
  )

  ;; --- Seleccionar objetos destino ---
  (princ "\nSeleccione objetos destino (POINT, CIRCLE, ARC, TEXT, MTEXT, INSERT, LWPOLYLINE): ")
  (setq ss (ssget '((0 . "POINT,CIRCLE,ARC,TEXT,MTEXT,INSERT,LWPOLYLINE"))))

  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq en (ssname ss i))
        (setq ed2 (entget en))
        (setq pt nil)

        ;; Determinar punto de inserción
        (cond
          ((= (cdr (assoc 0 ed2)) "POINT")  (setq pt (cdr (assoc 10 ed2))))
          ((= (cdr (assoc 0 ed2)) "CIRCLE") (setq pt (cdr (assoc 10 ed2))))
          ((= (cdr (assoc 0 ed2)) "ARC")    (setq pt (cdr (assoc 10 ed2))))
          ((= (cdr (assoc 0 ed2)) "TEXT")   (setq pt (cdr (assoc 10 ed2))))
          ((= (cdr (assoc 0 ed2)) "MTEXT")  (setq pt (cdr (assoc 10 ed2))))
          ((= (cdr (assoc 0 ed2)) "INSERT") (setq pt (cdr (assoc 10 ed2))))
          
          ;; Caso especial para LWPOLYLINE: Iterar vértices
          ((= (cdr (assoc 0 ed2)) "LWPOLYLINE")
            (foreach v (mapcar 'cdr (vl-remove-if-not '(lambda (x) (= (car x) 10)) ed2))
              (copy-block-vla v)
            )
          )
        )

        ;; Para los objetos estándar (no polilíneas)
        (if pt
          (copy-block-vla pt)
        )

        (setq i (1+ i))
      )
      (princ "\n? Bloques copiados exitosamente. Atributos regenerados correctamente.")
    )
    (princ "\n¡¡ No se seleccionaron objetos.")
  )

  (princ)
)