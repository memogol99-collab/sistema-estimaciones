;;; MEMO SISTEMA 2.0.0 - archivo generado por construir_bundle.py
;;; Origen: LISP_VistasLayout/Crear Vistas ( CV ).lsp

(defun c:CV (/ pt1 num_vistas ancho alto base_x base_y i y_offset nombre_vista p1 p2 old_osmode old_clayer)
  (setvar "CMDECHO" 0) ; Desactiva mensajes en línea de comandos
  
  ; Guardar configuraciones actuales
  (setq old_osmode (getvar "OSMODE"))
  (setq old_clayer (getvar "CLAYER"))
  
  ; Configurar OSNAP para nodo (valor 8) antes de pedir el punto
  (setvar "OSMODE" 8)
  
  ; Asegurar que estamos en el espacio modelo
  (if (= (getvar "TILEMODE") 0)
    (command "_.TILEMODE" "1")
  )
  
  ; Crear capa VISTAS si no existe, con color 24
  (if (not (tblsearch "LAYER" "VISTAS"))
    (progn
      (command "_.LAYER" "_N" "VISTAS" "")
      (command "_.LAYER" "_C" "24" "VISTAS" "")
    )
  )
  
  ; Cambiar a la capa VISTAS
  (setvar "CLAYER" "VISTAS")
  
  (setq pt1 (getpoint "\nSeleccione el punto SUPERIOR IZQUIERDO de la primera vista: "))
  
  ; Restaurar OSNAP original después de seleccionar el punto
  (setvar "OSMODE" old_osmode)
  
  (setq num_vistas (getint "\n¿Cuántas vistas modelo deseas crear? "))
  
  (setq ancho 29.8915) ; Ancho fijo
  (setq alto 1.00)   ; Alto fijo
  
  (setq base_x (car pt1))
  (setq base_y (cadr pt1))
  
  (setq i 1) ; Empezamos desde 1
  
  (repeat num_vistas
    ; Calcular desplazamiento hacia ABAJO desde el punto superior izquierdo
    (setq y_offset (* (- i 1) alto))
    
    ; Puntos para definir la vista (ventana)
    (setq p1 (list base_x (- base_y y_offset))) ; Superior izquierdo
    (setq p2 (list (+ base_x ancho) (- base_y y_offset alto))) ; Inferior derecho
    
    ; Crear el nombre de la vista con formato 01, 02, 03...
    (setq nombre_vista (strcat (if (< i 10) "0" "") (itoa i)))
    
    ; Crear la vista guardada usando el comando -VIEW
    (command "_.-VIEW" "_W" nombre_vista p1 p2)
    
    ; Crear rectángulo en cada vista (en capa VISTAS)
    (command "_.RECTANG" "_non" p1 "_non" p2)
    
    (setq i (1+ i))
  )
  
  ; Restaurar capa original
  (setvar "CLAYER" old_clayer)
  (setvar "CMDECHO" 1)
  (princ (strcat "\nSe crearon " (itoa num_vistas) " vistas guardadas con sus rectángulos en la capa VISTAS (color 24)."))
  (princ)
)

; Cargar el comando
(princ "\nComando 'CV' cargado. Escribe CV para ejecutar.")
(princ)