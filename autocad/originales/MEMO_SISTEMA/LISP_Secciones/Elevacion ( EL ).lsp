(defun c:EL (/ *error* punto_base elev_base punto_nuevo elev_nueva delta_y y_base y_nuevo 
              old_osmode old_cmdecho altura_texto estilo_texto ent data layer_creada count
              punto_desplazado escala factor_escala text_content)
    ;; --- Función de manejo de errores mejorada ---
    (defun *error* (msg)
        (if old_osmode (setvar "OSMODE" old_osmode))
        (if old_cmdecho (setvar "CMDECHO" old_cmdecho))
        (if (not (member msg '("Function cancelled" "quit / exit abort" "Function ended")))
            (princ (strcat "\nError: " msg))
        )
        (princ)
    )
    
    ;; ==================================================
    ;; FLUJO DE TRABAJO MEJORADO CON ESCALA VERTICAL:
    ;; 1. Crear capa automáticamente si no existe
    ;; 2. Seleccionar escala vertical (1:1000 o 1:100)
    ;; 3. Opción de seleccionar texto de referencia o usar valores por defecto
    ;; 4. Definir punto base con mejores opciones
    ;; 5. Seleccionar puntos con feedback más claro
    ;; ==================================================
    
    (princ "\n*** COLOCADOR DE ELEVACIONES (EJE Y) ***")
    (princ "\nLa elevación se considera en el eje Y sobre la retícula")
    
    ;; Guardar variables del sistema
    (setq old_osmode (getvar "OSMODE"))
    (setq old_cmdecho (getvar "CMDECHO"))
    
    ;; Configurar entorno temporal
    (setvar "OSMODE" 32)     ; Intersección
    (setvar "CMDECHO" 0)
    
    ;; --- Crear capa automáticamente ---
    (if (not (tblsearch "LAYER" "ELEVACIONES"))
        (progn
            (command "._-LAYER" "_M" "ELEVACIONES" "_C" "3" "" "")
            (setq layer_creada T)
            (princ "\nCapa 'ELEVACIONES' creada automáticamente.")
        )
    )
    
    ;; --- SELECCIÓN DE ESCALA VERTICAL (ENTER activa 1:1000) ---
    (princ "\n\n--- ESCALA VERTICAL ---")
    (initget 0 "1000 100")  ; Cambiado de 1 a 0 para permitir Enter
    (setq escala (getkword "\nSeleccione escala vertical [1000/100] <1000>: "))
    (if (not escala)
        (setq escala "1000")  ; Si presiona Enter, asigna 1:1000
    )
    
    ;; Determinar factor de escala
    (if (= escala "100")
        (progn
            (setq factor_escala 10.0)
            (princ "\n? Escala vertical 1:100 seleccionada")
            (princ "\n  (?Y se dividirá entre 10 para obtener elevaciones reales)")
        )
        (progn
            (setq factor_escala 1.0)
            (princ "\n? Escala vertical 1:1000 seleccionada (por defecto)")
        )
    )
    
    ;; --- OBTENER PROPIEDADES DE TEXTO (con opción por defecto) ---
    (princ "\n\n--- PROPIEDADES DE TEXTO ---")
    (princ "\nSelecciona un texto o Enter para Default (MONOTXT4 - 0.45): ")
    (setq ent (entsel))
    
    (if ent
        (progn
            ;; Usuario seleccionó un texto
            (setq ent (car ent))
            (if (/= (cdr (assoc 0 (entget ent))) "TEXT")
                (progn
                    (princ "\n? El objeto seleccionado no es TEXTo. Usando valores por defecto.")
                    (setq estilo_texto "MONOTXT4")
                    (setq altura_texto 0.45)
                )
                (progn
                    (setq data (entget ent))
                    (setq altura_texto (cdr (assoc 40 data)))
                    (setq estilo_texto (cdr (assoc 7 data)))
                    
                    ;; Verificar si el estilo de texto existe
                    (if (not (tblsearch "STYLE" estilo_texto))
                        (progn
                            (princ (strcat "\n? Estilo de texto '" estilo_texto "' no encontrado. Usando MONOTXT4."))
                            (setq estilo_texto "MONOTXT4")
                        )
                    )
                    
                    (princ (strcat "\n? Altura de texto: " (rtos altura_texto 2 2)))
                    (princ (strcat "\n? Estilo de texto: " estilo_texto))
                )
            )
        )
        (progn
            ;; Usar valores por defecto (Enter presionado)
            (setq estilo_texto "MONOTXT4")
            (setq altura_texto 0.45)
            
            ;; Verificar si el estilo MONOTXT4 existe, si no usar el actual
            (if (not (tblsearch "STYLE" estilo_texto))
                (progn
                    (princ (strcat "\n? Estilo 'MONOTXT4' no encontrado. Usando estilo actual: " (getvar "TEXTSTYLE")))
                    (setq estilo_texto (getvar "TEXTSTYLE"))
                )
                (princ "\n? Usando valores por defecto:")
            )
            
            (princ (strcat "\n? Altura de texto: " (rtos altura_texto 2 2)))
            (princ (strcat "\n? Estilo de texto: " estilo_texto))
        )
    )
    
    ;; --- Obtener punto base ---
    (princ "\n\n--- PUNTO BASE ---")
    (while (not punto_base)
        (setq punto_base (getpoint "\nSelecciona el PUNTO BASE en la retícula: "))
        (if (not punto_base)
            (princ "\n? Punto base requerido. Intenta nuevamente.")
        )
    )
    
    (setq y_base (cadr punto_base))
    
    ;; --- Obtener elevación base con validación ---
    (while (not elev_base)
        (initget 1)
        (setq elev_base (getreal (strcat "\nIntroduce la elevación del punto base (Y=" (rtos y_base 2 2) "): ")))
    )
    
    ;; --- Colocar elevaciones ---
    (princ "\n\n--- COLOCANDO ELEVACIONES ---")
    (princ "\nSelecciona puntos en la retícula para colocar elevaciones...")
    (princ "\n[Enter] para terminar, [Esc] para cancelar")
    
    (setq count 0)
    (while (setq punto_nuevo (getpoint punto_base "\nSelecciona siguiente punto en la retícula: "))
        (setq y_nuevo (cadr punto_nuevo))
        (setq delta_y (- y_nuevo y_base))
        
        ;; APLICAR FACTOR DE ESCALA VERTICAL
        (setq delta_y_escalado (/ delta_y factor_escala))
        (setq elev_nueva (+ elev_base delta_y_escalado))
        
        ;; Aplicar desplazamiento en X de 0.17 unidades
        (setq punto_desplazado (list (+ (car punto_nuevo) 0.17) (cadr punto_nuevo) (caddr punto_nuevo)))
        
        ;; Crear texto con prefijo "T.N.=" y desplazamiento
        (setq text_content (strcat "T.N.=" (rtos elev_nueva 2 2)))
        (entmake
            (list
               '(0 . "TEXT")
               '(100 . "AcDbEntity")
               '(100 . "AcDbText")
                (cons 10 punto_desplazado)         ; Punto con desplazamiento en X
                (cons 1 text_content)              ; Texto con prefijo "T.N.="
                (cons 40 altura_texto)             ; Altura del texto
                (cons 50 (/ pi 2))                 ; Rotación 90 grados
                (cons 7 estilo_texto)              ; Estilo del texto
                (cons 8 "ELEVACIONES")             ; Capa (color por capa)
                '(72 . 0)                          ; Justificación horizontal: izquierda
                '(73 . 3)                          ; Justificación vertical: superior
                (cons 11 punto_desplazado)         ; Punto de alineación con desplazamiento
            )
        )
        
        ;; Feedback mejorado con información de la escala
        (princ (strcat "\n? Elevación " (itoa (setq count (1+ count))) ": " text_content))
        (if (= escala "100")
            (princ (strcat " (Y=" (rtos y_nuevo 2 2) 
                          ", ?Y=" (rtos delta_y 2 2) 
                          ", ?Y/10=" (rtos delta_y_escalado 2 2) ")"))
            (princ (strcat " (Y=" (rtos y_nuevo 2 2) 
                          ", ?Y=" (rtos delta_y 2 2) ")"))
        )
    )
    
    ;; Resumen final
    (princ "\n\n--- RESUMEN ---")
    (cond
        ((= count 0)
            (princ "\n? No se colocaron elevaciones."))
        ((= count 1)
            (princ "\n? Proceso completado: 1 elevación colocada."))
        (t
            (princ (strcat "\n? Proceso completado: " (itoa count) " elevaciones colocadas.")))
    )
    
    ;; Información adicional
    (princ (strcat "\n? Escala vertical utilizada: 1:" escala))
    (if (= escala "100")
        (princ " (?Y/10)")
        (princ " (?Y sin escala)")
    )
    (princ (strcat "\n? Estilo de texto utilizado: " estilo_texto))
    (princ (strcat "\n? Altura de texto utilizada: " (rtos altura_texto 2 2)))
    (princ "\n? Justificación: Superior Izquierda")
    (princ "\n? Color: Por capa")
    (princ "\n? Desplazamiento en X: 0.17 unidades")
    (princ "\n? Prefijo: T.N.=")
    
    ;; Restaurar variables
    (setvar "OSMODE" old_osmode)
    (setvar "CMDECHO" old_cmdecho)
    (princ)
)

(princ "\nComando EL cargado - Colocador de Elevaciones mejorado")
(princ "\n(Al seleccionar escala, presiona Enter para 1:1000 por defecto)")
(princ)