;;; MEMO SISTEMA 2.1.0 - archivo generado por construir_bundle.py
;;; Origen: LISP_VistasLayout/Borrar Vistas ( BV ).lsp
;;; Parches aplicados: prefijo:bv

(defun c:BV (/ doc vistas_lista seleccion i)
  ; Función para listar y gestionar VISTAS GUARDADAS (Named Views)
  (vl-load-com)
  
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq vistas_lista '())
  
  ; Obtener todas las vistas guardadas del documento
  (vlax-for vista (vla-get-Views doc)
    (setq vistas_lista (cons (vla-get-Name vista) vistas_lista))
  )
  
  ; Revertir la lista para orden correcto
  (setq vistas_lista (reverse vistas_lista))
  
  (if (null vistas_lista)
    (progn
      (alert "No se encontraron vistas guardadas en el dibujo.")
      (princ)
    )
    (progn
      ; Mostrar lista de vistas
      (princ "\n--- VISTAS GUARDADAS ENCONTRADAS ---")
      (setq i 1)
      (foreach vista vistas_lista
        (princ (strcat "\n" (itoa i) ". " vista))
        (setq i (1+ i))
      )
      (princ (strcat "\n-----------------------------------"))
      (princ (strcat "\nTotal: " (itoa (length vistas_lista)) " vistas"))
      
      ; Solicitar selección al usuario
      (princ "\n\nSeleccione vistas a borrar:")
      (princ "\n[1] Números separados por comas (ej: 1,3,5)")
      (princ (strcat "\n[2] Rango (ej: 1-" (itoa (length vistas_lista)) ")"))
      (princ "\n[3] 'TODAS' para borrar todas")
      (princ "\n[4] ENTER para cancelar")
      
      (setq seleccion (getstring t "\nSu selección: "))
      
      (cond
        ; Borrar todas las vistas
        ((or (equal seleccion "TODAS") (equal seleccion "todas") (equal seleccion "T"))
         (vlax-for vista (vla-get-Views doc)
           (vla-Delete vista)
         )
         (princ "\n¡Todas las vistas guardadas han sido borradas!")
        )
        
        ; Procesar selección específica
        ((> (strlen seleccion) 0)
         (bv:procesar-seleccion seleccion vistas_lista)
        )
        
        ; Cancelar
        (t
         (princ "\nOperación cancelada.")
        )
      )
    )
  )
  (princ)
)

; Función principal para procesar la selección
(defun bv:procesar-seleccion (seleccion vistas_lista / numeros total max_vistas)
  (setq max_vistas (length vistas_lista))
  (setq numeros (bv:obtener-numeros seleccion max_vistas))
  
  (if numeros
    (progn
      (setq numeros (vl-sort numeros '>)) ; Ordenar de mayor a menor
      (setq total 0)
      
      (foreach num numeros
        (if (and (>= num 1) (<= num max_vistas))
          (progn
            (bv:borrar-vista-por-nombre (nth (1- num) vistas_lista))
            (princ (strcat "\nVista borrada: " (nth (1- num) vistas_lista)))
            (setq total (1+ total))
          )
          (princ (strcat "\nNúmero fuera de rango [" (itoa num) "]. Máximo: " (itoa max_vistas)))
        )
      )
      (princ (strcat "\nProceso completado. " (itoa total) " vistas borradas."))
    )
    (princ "\nSelección inválida.")
  )
)

; Función para obtener números de la selección (soporta rangos y comas)
(defun bv:obtener-numeros (seleccion max_num / numeros partes inicio fin i token)
  (setq numeros '())
  (setq seleccion (vl-string-trim " " seleccion))
  
  ; Verificar si es un rango (contiene "-")
  (if (vl-string-search "-" seleccion)
    (progn
      (setq partes (bv:split-string seleccion "-"))
      (if (and (= (length partes) 2) 
               (bv:es-numero (car partes)) 
               (bv:es-numero (cadr partes)))
        (progn
          (setq inicio (atoi (car partes)))
          (setq fin (atoi (cadr partes)))
          (if (and (>= inicio 1) (<= fin max_num) (<= inicio fin))
            (progn
              (setq i inicio)
              (while (<= i fin)
                (setq numeros (cons i numeros))
                (setq i (1+ i))
              )
            )
            (progn
              (princ (strcat "\nError: Rango inválido. Use 1-" (itoa max_num)))
              (setq numeros nil)
            )
          )
        )
        (progn
          (princ "\nError: Formato de rango inválido")
          (setq numeros nil)
        )
      )
    )
    ; Si no es rango, procesar números separados por comas
    (progn
      (setq partes (bv:split-string seleccion ","))
      (foreach parte partes
        (setq parte (vl-string-trim " " parte))
        (if (bv:es-numero parte)
          (setq numeros (cons (atoi parte) numeros))
        )
      )
    )
  )
  numeros
)

; Función simple para dividir cadena
(defun bv:split-string (str delim / pos result token)
  (setq result '())
  (while (setq pos (vl-string-search delim str))
    (setq token (substr str 1 pos))
    (setq str (substr str (+ pos 2)))
    (setq result (cons (vl-string-trim " " token) result))
  )
  (setq result (cons (vl-string-trim " " str) result))
  (reverse result)
)

; Función para borrar vista por nombre
(defun bv:borrar-vista-por-nombre (nombre_vista / doc vista_encontrada)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq vista_encontrada nil)
  
  (vlax-for vista (vla-get-Views doc)
    (if (equal (vla-get-Name vista) nombre_vista)
      (setq vista_encontrada vista)
    )
  )
  
  (if vista_encontrada
    (vla-Delete vista_encontrada)
  )
)

; Función para verificar si una cadena es número
(defun bv:es-numero (str)
  (if (distof str) T nil)
)

(princ "\nRutina LVA cargada. Escribe LVA para listar y administrar VISTAS GUARDADAS.")
(princ)