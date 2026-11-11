;;; MEMO SISTEMA 2.1.1 - archivo generado por construir_bundle.py
;;; Origen: LISP_VistasLayout/SuprimirLayouts ( SL ).lsp
;;; Parches aplicados: prefijo:sl

(defun c:SL ( / *error* doc layouts layout_names layout_list sel_indexes to_delete i layout)
  
  ; Función de manejo de errores
  (defun *error* (msg)
    (if (not (wcmatch (strcase msg) "*CANCEL*,*EXIT*"))
      (princ (strcat "\nError: " msg))
    )
    (princ)
  )
  
  ; Obtener el documento actual
  (setq doc (vla-get-activedocument (vlax-get-acad-object)))
  
  ; Verificar si estamos en un dibujo
  (if (= (getvar "tilemode") 1)
    (progn
      (alert "Debe estar en el espacio papel (pestaña de layout) para usar este comando.")
      (princ)
      (exit)
    )
  )
  
  ; Obtener la colección de layouts
  (setq layouts (vla-get-layouts doc))
  
  ; Crear lista de nombres de layouts (excluyendo Modelo)
  (setq layout_names '())
  (vlax-for layout layouts
    (if (/= (vla-get-name layout) "Model")
      (setq layout_names (cons (vla-get-name layout) layout_names))
    )
  )
  
  ; Verificar si hay layouts para eliminar
  (if (null layout_names)
    (progn
      (alert "No hay layouts (presentaciones) para eliminar, solo existe el espacio modelo.")
      (princ)
      (exit)
    )
  )
  
  ; Invertir la lista para mostrar en orden
  (setq layout_names (reverse layout_names))
  
  ; Crear lista para mostrar en la interfaz
  (setq layout_list "")
  (setq i 1)
  (foreach name layout_names
    (setq layout_list (strcat layout_list (itoa i) ". " name "\n"))
    (setq i (1+ i))
  )
  
  ; Mostrar diálogo de selección
  (initget 1)
  (setq sel (getstring (strcat "\nSeleccione layouts a eliminar (ej: 1,3,5 o 1-3):\n" 
                               layout_list 
                               "\nIngrese números separados por comas o rangos: ")))
  
  ; Procesar la selección del usuario
  (setq sel_indexes (sl:procesar-seleccion sel (length layout_names)))
  
  ; Validar la selección
  (if (null sel_indexes)
    (progn
      (alert "Selección no válida.")
      (princ)
      (exit)
    )
  )
  
  ; Confirmar eliminación
  (setq confirm (getstring "\n¿Está seguro de eliminar los layouts seleccionados? (S/N): "))
  (if (or (= (strcase confirm) "S") (= (strcase confirm) "SI") (= (strcase confirm) "Y"))
    (progn
      ; Eliminar los layouts seleccionados
      (setq to_delete '())
      (foreach idx sel_indexes
        (setq to_delete (cons (nth (1- idx) layout_names) to_delete))
      )
      
      ; Eliminar cada layout
      (foreach layout_name to_delete
        (princ (strcat "\nEliminando layout: " layout_name))
        (vl-catch-all-apply
          '(lambda ()
             (setq layout (vla-item layouts layout_name))
             (vla-delete layout)
           )
        )
      )
      
      (princ (strcat "\nSe eliminaron " (itoa (length to_delete)) " layout(s)."))
    )
    (princ "\nOperación cancelada.")
  )
  (princ)
)

; Función para procesar la entrada del usuario (números y rangos)
(defun sl:procesar-seleccion (str total / lst items item range start end result)
  (setq result '())
  
  ; Separar por comas
  (setq items (sl:split-string str ","))
  
  (foreach item items
    ; Verificar si es un rango
    (if (wcmatch item "*-*")
      (progn
        (setq range (sl:split-string item "-"))
        (if (and (= (length range) 2)
                 (setq start (atoi (car range)))
                 (setq end (atoi (cadr range)))
                 (<= 1 start total)
                 (<= 1 end total)
                 (<= start end))
          (progn
            (repeat (1+ (- end start))
              (setq result (cons start result))
              (setq start (1+ start))
            )
          )
        )
      )
      ; Si no es rango, es un número individual
      (if (and (setq start (atoi item))
               (<= 1 start total))
        (setq result (cons start result))
      )
    )
  )
  
  ; Eliminar duplicados y ordenar
  (reverse (sl:unique result))
)

; Función para dividir cadenas
(defun sl:split-string (str delim / pos lst)
  (while (setq pos (vl-string-search delim str))
    (setq lst (cons (substr str 1 pos) lst))
    (setq str (substr str (+ pos 2)))
  )
  (reverse (cons str lst))
)

; Función para eliminar duplicados de una lista
(defun sl:unique (lst)
  (if lst
    (cons (car lst) (sl:unique (vl-remove (car lst) (cdr lst))))
  )
)

; Mensaje de carga
(princ "\nComando Cargado: EliminarLayouts - Escribe ELIMINARLAYOUTS o EL para ejecutar")
(princ)