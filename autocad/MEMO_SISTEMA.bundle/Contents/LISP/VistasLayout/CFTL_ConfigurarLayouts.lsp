;;; MEMO SISTEMA 2.1.0 - archivo generado por construir_bundle.py
;;; Origen: LISP_VistasLayout/Configurar Layouts  ( CFTL ).lsp

(defun c:CFTL ( / *error* doc layouts lay_obj nombre_lay lista_lays
                          opt_metodo opt_destino 
                          impresora tamano estilo 
                          src_layout src_name temp_obj i
                          contador)

  ;; --- MANEJO DE ERRORES ---
  (defun *error* (msg)
    (if (and msg (not (wcmatch (strcase msg) "*CANCEL*,*EXIT*,*INTERRUMPIDO*")))
      (princ (strcat "\nError: " msg))
    )
    (if (= (type doc) 'VLA-OBJECT) (vla-EndUndoMark doc))
    (princ)
  )

  ;; --- INICIO ---
  (vl-load-com)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  
  ;; Verificar si hay una marca de deshacer activa y cerrarla para evitar anidamiento
  (if (not (vla-StartUndoMark doc)) ; Intenta empezar, si falla es que ya hay una
    (vla-EndUndoMark doc) ; Cerramos la anterior
  )
  (vla-StartUndoMark doc)

  (princ "\n--- CONFIGURACIÓN MASIVA DE LAYOUTS (v2.0) ---")

  ;; 1. SELECCIONAR MÉTODO DE CONFIGURACIÓN
  (initget "Manual Copiar")
  (setq opt_metodo 
    (getkword 
      "\n¿Cómo deseas configurar? [Manual/Escribir datos] <Copiar de layout existente>: "
    )
  )

  (cond
    ;; --- OPCIÓN A: COPIAR DE UN LAYOUT EXISTENTE (RECOMENDADO) ---
    ((or (null opt_metodo) (= opt_metodo "Copiar"))
      (setq src_name (getstring T "\nNombre del layout FUENTE (el que ya está bien configurado) <Actual>: "))
      (if (= src_name "") (setq src_name (vla-get-Name (vla-get-ActiveLayout doc))))
      
      (setq src_layout (vla-Item (vla-get-Layouts doc) src_name))
      
      (if src_layout
        (progn
          (princ (strcat "\n>> Leyendo configuración de: " src_name))
          ;; Obtenemos datos del layout fuente
          (setq impresora (vla-get-ConfigName src_layout))
          (setq tamano    (vla-get-CanonicalMediaName src_layout))
          (setq estilo    (vla-get-StyleSheet src_layout))
          
          ;; Validamos que tenga impresora asignada
          (if (or (null impresora) (= impresora "") (= impresora "None"))
            (progn
              (princ (strcat "\n¡Advertencia! El layout " src_name " no tiene impresora asignada."))
              (setq impresora nil)
            )
          )
        )
        (progn
          (princ (strcat "\nError: No se encontró el layout '" src_name "'."))
          (exit)
        )
      )
    )

    ;; --- OPCIÓN B: MANUAL (ESCRIBIR DATOS) ---
    ((= opt_metodo "Manual")
      (princ "\nIntroduce los datos exactos (sensible a mayúsculas/minúsculas).")
      
      (setq impresora (getstring T "\nNombre exacto de la Impresora (PC3) <Mantener actual>: "))
      (if (= impresora "") (setq impresora nil))
      
      (setq tamano (getstring T "\nNombre exacto del Tamaño de Papel <Mantener actual>: "))
      (if (= tamano "") (setq tamano nil))
      
      (setq estilo (getstring T "\nNombre del Estilo de Trazado (CTB/STB) <Mantener actual>: "))
      (if (= estilo "") (setq estilo nil))
    )
  )

  ;; 2. VERIFICAR SI HAY CAMBIOS QUE APLICAR
  (if (not (or impresora tamano estilo))
    (progn
      (princ "\nNo se especificaron cambios. Saliendo...")
      (*error* nil)
    )
    ;; 3. SELECCIONAR DESTINO
    (progn
      (initget "Todos Actual Lista")
      (setq opt_destino (getkword "\n¿Aplicar a? [Todos/Actual/Lista de nombres] <Todos>: "))
      
      ;; Construimos la lista de layouts a procesar
      (setq lista_lays '())
      
      (cond
        ;; -- TODOS --
        ((or (null opt_destino) (= opt_destino "Todos"))
          (vlax-for lay (vla-get-Layouts doc)
            (if (/= (vla-get-Name lay) "Model")
              (setq lista_lays (cons lay lista_lays))
            )
          )
        )
        ;; -- ACTUAL --
        ((= opt_destino "Actual")
          (setq lista_lays (list (vla-get-ActiveLayout doc)))
        )
        ;; -- LISTA (Escribir nombres separados por coma) --
        ((= opt_destino "Lista")
          (setq temp_obj (getstring T "\nEscribe nombres de layouts separados por coma (ej: Layout1, Layout2): "))
          (foreach n (str-sep temp_obj ",")
            (setq n (vl-string-trim " " n)) ; Quitamos espacios extra
            (if (and (/= n "") (/= (strcase n) "MODEL"))
              (if (not (vl-catch-all-error-p (setq temp_obj (vl-catch-all-apply 'vla-Item (list (vla-get-Layouts doc) n)))))
                (setq lista_lays (cons temp_obj lista_lays))
                (princ (strcat "\nAdvertencia: Layout '" n "' no encontrado."))
              )
            )
          )
        )
      )

      ;; 4. APLICAR CAMBIOS
      (if lista_lays
        (progn
          (setq contador 0)
          (princ "\n\nProcesando layouts...")
          (foreach lay_obj lista_lays
            (setq nombre_lay (vla-get-Name lay_obj))
            
            ;; Función interna para aplicar cambios seguros
            (if impresora
              (vl-catch-all-apply 'vla-put-ConfigName (list lay_obj impresora))
            )
            ;; Nota: El tamaño de papel depende de la impresora.
            ;; Si se cambia la impresora, a veces el nombre del papel antiguo no es válido.
            ;; Es mejor cambiar impresora primero.
            (if tamano
              (vl-catch-all-apply 'vla-put-CanonicalMediaName (list lay_obj tamano))
            )
            (if estilo
              (vl-catch-all-apply 'vla-put-StyleSheet (list lay_obj estilo))
            )
            
            (princ (strcat "\n  - Configurado: " nombre_lay))
            (setq contador (1+ contador))
          )
          (princ (strcat "\n\n¡Proceso completado! " (itoa contador) " layouts modificados."))
        )
        (princ "\nNo se encontraron layouts válidos para procesar.")
      )
    )
  )

  (vla-EndUndoMark doc)
  (princ)
)

;; --- FUNCIÓN AUXILIAR PARA SEPARAR TEXTO ---
(defun str-sep (str del / pos lst)
  (while (setq pos (vl-string-search del str))
    (setq lst (cons (substr str 1 pos) lst))
    (setq str (substr str (+ pos 1 (strlen del))))
  )
  (reverse (cons str lst))
)

(princ "\nComando CFTL cargado.")
(princ)