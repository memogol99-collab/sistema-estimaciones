(defun c:IBCZ ( / *error* old_cmd old_osmode blk_list blk_name layer_filter final_layer escala_x escala_y angulo ss pt_count i pt_ent pt found)
  
  ; Función de manejo de errores
  (defun *error* (msg)
    (if old_cmd (setvar "CMDECHO" old_cmd))
    (if old_osmode (setvar "OSMODE" old_osmode))
    (if (not (member msg '("Function cancelled" "quit / exit abort")))
      (princ (strcat "\nError: " msg))
    )
    (princ)
  )
  
  ; Guardar variables del sistema
  (setq old_cmd (getvar "CMDECHO")
        old_osmode (getvar "OSMODE"))
  
  ; Configurar variables
  (setvar "CMDECHO" 0)
  (setvar "OSMODE" 0)
  
  ; Lista de bloques, capas de origen, capas finales Y ESCALAS DEFINIDAS
  (setq blk_list '(
    ; Formato: ("NombreBloque" "PrefijoCapaOrigen" "CapaFinal" escala_x escala_y angulo)
    ("Arbol" "AR" "V-ARBOL" 760.32 760.32 0)
    ("RAP" "RAP" "AP-Registro de AP" 1100.0 1100.0 0)
    ("Descarga" "DES" "DS-Reg Alb Existente" 1100.0 1100.0 0)
    ("PV Existente" "PV" "DS-PV Existente" 1100.0 1100.0 0)
    ("Poste de TM" "TM" "T-Poste TM" 1100.0 1100.0 0)
    ("Poste de CFE" "CF" "L-Poste CFE" 1100.0 1100.0 0)
  ))
  
  (setq found nil)
  
  ; Procesar cada bloque de la lista
  (foreach blk_pair blk_list
    (setq blk_name (car blk_pair))
    (setq layer_filter (strcat (cadr blk_pair) "*"))
    (setq final_layer (caddr blk_pair))
    (setq escala_x (cadddr blk_pair))
    (setq escala_y (nth 4 blk_pair))
    (setq angulo (nth 5 blk_pair))
    
    ; Verificar si el bloque existe
    (if (tblsearch "BLOCK" blk_name)
      (progn
        ; Verificar si existe la capa final, si no crearla
        (if (not (tblsearch "LAYER" final_layer))
          (command "_-LAYER" "_M" final_layer "")
        )
        
        ; Seleccionar puntos en capas que coincidan con el filtro
        (setq ss (ssget "_X" (list (cons 0 "POINT") (cons 8 layer_filter))))
        
        (if ss
          (progn
            (setq pt_count 0)
            (setq i 0)
            (setq found T)
            
            ; Recorrer todos los puntos seleccionados
            (while (< i (sslength ss))
              (setq pt_ent (ssname ss i))
              (setq pt (cdr (assoc 10 (entget pt_ent))))
              
              ; Guardar la capa actual
              (setq current_layer (getvar "CLAYER"))
              
              ; Insertar bloque con la escala definida en la lista
              (setvar "CLAYER" final_layer)
              (command "_-INSERT" blk_name pt escala_x escala_y angulo)
              
              ; Restaurar capa actual
              (setvar "CLAYER" current_layer)
              
              (setq pt_count (1+ pt_count))
              (setq i (1+ i))
            )
            
            (princ (strcat "\n» " (itoa pt_count) " bloques '" blk_name "' insertados en capa '" final_layer "' (Escala: " (rtos escala_x) ")"))
          )
          (princ (strcat "\n? No hay puntos en capas '" layer_filter "' para el bloque '" blk_name "'"))
        )
      )
      (princ (strcat "\n? El bloque '" blk_name "' no existe en el dibujo"))
    )
  )
  
  ; Restaurar variables del sistema
  (setvar "CMDECHO" old_cmd)
  (setvar "OSMODE" old_osmode)
  
  (if found
    (princ "\n¡Proceso completado!")
    (princ "\nNo se insertó ningún bloque.")
  )
  (princ)
)

; Función auxiliar modificada para usar escalas definidas
(defun INSBLOQUE (blk_name layer_filter final_layer escala_x escala_y angulo / ss pt_count i pt_ent pt current_layer)
  (if (tblsearch "BLOCK" blk_name)
    (progn
      ; Verificar si existe la capa final, si no crearla
      (if (not (tblsearch "LAYER" final_layer))
        (command "_-LAYER" "_M" final_layer "")
      )
      
      (setq ss (ssget "_X" (list (cons 0 "POINT") (cons 8 (strcat layer_filter "*")))))
      
      (if ss
        (progn
          (setq pt_count 0)
          (setq i 0)
          (setq current_layer (getvar "CLAYER"))
          
          (while (< i (sslength ss))
            (setq pt_ent (ssname ss i))
            (setq pt (cdr (assoc 10 (entget pt_ent))))
            
            ; Insertar bloque con la escala definida
            (setvar "CLAYER" final_layer)
            (command "_-INSERT" blk_name pt escala_x escala_y angulo)
            
            (setq pt_count (1+ pt_count))
            (setq i (1+ i))
          )
          
          ; Restaurar capa actual
          (setvar "CLAYER" current_layer)
          
          (princ (strcat "\nSe insertaron " (itoa pt_count) " bloques '" blk_name "' en capa '" final_layer "' (Escala: " (rtos escala_x) ")"))
        )
        (princ (strcat "\nNo se encontraron puntos en capas '" layer_filter "*'"))
      )
    )
    (princ (strcat "\nEl bloque '" blk_name "' no existe"))
  )
)

; Comandos individuales con escalas específicas
(defun c:ARBOLES ( / old_cmd old_osmode)
  (setq old_cmd (getvar "CMDECHO")
        old_osmode (getvar "OSMODE"))
  (setvar "CMDECHO" 0)
  (setvar "OSMODE" 0)
  
  (INSBLOQUE "Arbol" "AR" "V-ARBOL" 760.32 760.32 0)
  
  (setvar "CMDECHO" old_cmd)
  (setvar "OSMODE" old_osmode)
  (princ)
)

(defun c:RAP ( / old_cmd old_osmode)
  (setq old_cmd (getvar "CMDECHO")
        old_osmode (getvar "OSMODE"))
  (setvar "CMDECHO" 0)
  (setvar "OSMODE" 0)
  
  (INSBLOQUE "RAP" "RAP" "AP-RAP" 1.0 1.0 0)
  
  (setvar "CMDECHO" old_cmd)
  (setvar "OSMODE" old_osmode)
  (princ)
)

(defun c:DES ( / old_cmd old_osmode)
  (setq old_cmd (getvar "CMDECHO")
        old_osmode (getvar "OSMODE"))
  (setvar "CMDECHO" 0)
  (setvar "OSMODE" 0)
  
  (INSBLOQUE "Descarga" "DES" "DS-Descarga" 1.0 1.0 0)
  
  (setvar "CMDECHO" old_cmd)
  (setvar "OSMODE" old_osmode)
  (princ)
)

(defun c:PV ( / old_cmd old_osmode)
  (setq old_cmd (getvar "CMDECHO")
        old_osmode (getvar "OSMODE"))
  (setvar "CMDECHO" 0)
  (setvar "OSMODE" 0)
  
  (INSBLOQUE "PV Existente" "PV" "DS-PV Existente" 1.0 1.0 0)
  
  (setvar "CMDECHO" old_cmd)
  (setvar "OSMODE" old_osmode)
  (princ)
)

(defun c:TM ( / old_cmd old_osmode)
  (setq old_cmd (getvar "CMDECHO")
        old_osmode (getvar "OSMODE"))
  (setvar "CMDECHO" 0)
  (setvar "OSMODE" 0)
  
  (INSBLOQUE "Poste de TM" "TM" "T-Poste TM" 1.0 1.0 0)
  
  (setvar "CMDECHO" old_cmd)
  (setvar "OSMODE" old_osmode)
  (princ)
)

(defun c:CFE ( / old_cmd old_osmode)
  (setq old_cmd (getvar "CMDECHO")
        old_osmode (getvar "OSMODE"))
  (setvar "CMDECHO" 0)
  (setvar "OSMODE" 0)
  
  (INSBLOQUE "Poste de CFE" "CF" "L-Poste CFE" 1.0 1.0 0)
  
  (setvar "CMDECHO" old_cmd)
  (setvar "OSMODE" old_osmode)
  (princ)
)

; Función para verificar bloques
(defun c:VERBLOQUES ( / blk_list blk_name)
  (princ "\n=== BLOQUES EXISTENTES EN EL DIBUJO ===")
  (setq blk_list '(
    "Arbol"
    "RAP" 
    "Descarga"
    "PV Existente"
    "Poste de TM"
    "Poste de CFE"
  ))
  
  (foreach blk_name blk_list
    (if (tblsearch "BLOCK" blk_name)
      (princ (strcat "\n? " blk_name))
      (princ (strcat "\n? " blk_name " - NO EXISTE"))
    )
  )
  (princ "\n=== FIN DE LA LISTA ===")
  (princ)
)

; Función para verificar capas
(defun c:VERCAPAS ( / layer_list layer_name)
  (princ "\n=== CAPAS REQUERIDAS ===")
  (setq layer_list '(
    "V-ARBOL"
    "AP-RAP"
    "DS-Descarga"
    "DS-PV Existente"
    "T-Poste TM"
    "L-Poste CFE"
  ))
  
  (foreach layer_name layer_list
    (if (tblsearch "LAYER" layer_name)
      (princ (strcat "\n? " layer_name))
      (princ (strcat "\n? " layer_name " - NO EXISTE (se creará automáticamente)"))
    )
  )
  (princ "\n=== FIN DE LA LISTA ===")
  (princ)
)

; Función para modificar escalas fácilmente
(defun c:CONFIGESCALAS ()
  (princ "\n=== ESCALAS ACTUALES CONFIGURADAS ===")
  (princ "\nArbol: 760.32")
  (princ "\nRAP: 1.0")
  (princ "\nDescarga: 1.0")
  (princ "\nPV Existente: 1.0")
  (princ "\nPoste de TM: 1.0")
  (princ "\nPoste de CFE: 1.0")
  (princ "\n\nPara modificar escalas, edita los valores en el código LISP:")
  (princ "\nBusca la línea: (\"Arbol\" \"AR\" \"V-ARBOL\" 760.32 760.32 0)")
  (princ "\ny cambia los números 760.32 por la escala que necesites.")
  (princ)
)

; Mensaje de carga actualizado
(princ "\nComandos cargados:")
(princ "\n  IBC           - Inserta todos los bloques automáticamente")
(princ "\n  VERBLOQUES    - Muestra qué bloques existen en el dibujo")
(princ "\n  VERCAPAS      - Muestra las capas finales requeridas")
(princ "\n  CONFIGESCALAS - Muestra las escalas actuales configuradas")
(princ "\n  ARBOLES       - Inserta 'Arbol' en escala 760.32")
(princ "\n  RAP           - Inserta 'RAP' en escala 1.0")
(princ "\n  DES           - Inserta 'Descarga' en escala 1.0")
(princ "\n  PV            - Inserta 'PV Existente' en escala 1.0")
(princ "\n  TM            - Inserta 'Poste de TM' en escala 1.0")
(princ "\n  CFE           - Inserta 'Poste de CFE' en escala 1.0")
(princ)