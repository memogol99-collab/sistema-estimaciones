;;; MEMO SISTEMA 2.1.0 - archivo generado por construir_bundle.py
;;; Origen: LISP_Secciones/Extraer Area de Cont ( AC ).LSP

; MACRO PARA CÁLCULO Y ACTUALIZACIÓN AUTOMÁTICA DE ÁREAS DE SECCIONES TRANSVERSALES
(DEFUN C:AC (/ LIP CAD1 A N T1 C AC ACA AB ASR AT ent lastEnt areaValue oldLast 
                cadenamientoPoint ss i entText textObj textPos dist minDist foundText oldText newText)
  (vl-load-com)
  
  ; FUNCIÓN PARA CALCULAR ÁREA DE CUALQUIER OBJETO
  (defun getObjectArea (entName)
    (if entName
      (progn
        (setq areaValue 0.0)
        (setq obj (vlax-ename->vla-object entName))
        (if (vl-catch-all-error-p (vl-catch-all-apply 'vla-get-Area (list obj)))
          (progn
            (command "._AREA" "_O" entName)
            (setq areaValue (getvar "AREA"))
          )
          (setq areaValue (vla-get-Area obj))
        )
        areaValue
      )
      0.0
    )
  )

  ; FUNCIÓN PARA REEMPLAZAR VALOR DESPUÉS DEL PATRÓN ESPECÍFICO
  (defun replaceAfterPattern (oldText pattern newValue / patternPos equalsPos valueStart valueEnd)
    (setq patternPos (vl-string-search pattern oldText))
    (if patternPos
      (progn
        (setq equalsPos (+ patternPos (strlen pattern)))
        ; Buscar el inicio del valor numérico (después del "=")
        (setq valueStart equalsPos)
        ; Buscar el final del valor numérico (hasta espacio o fin de texto)
        (setq valueEnd (strlen oldText))
        (setq i equalsPos)
        (while (and (< i (strlen oldText))
                   (not (wcmatch (substr oldText (1+ i) 1) " ,")))
          (setq i (1+ i))
        )
        (setq valueEnd i)
        
        ; Reemplazar solo la parte del valor
        (strcat (substr oldText 1 valueStart)
                newValue
                (substr oldText (1+ valueEnd)))
      )
      oldText  ; Si no encuentra el patrón, devolver texto original
    )
  )

  ; FUNCIÓN PARA BUSCAR Y ACTUALIZAR EL TEXTO MÁS CERCANO CON EL PATRÓN ESPECÍFICO
  (defun updateLayerText (newValue pattern layerName / ss i entText textObj textPos dist minDist foundText oldText newText)
    (setq minDist 1e308
          foundText nil
    )
    
    ; Buscar todos los textos en el dibujo
    (if (setq ss (ssget "_X" '((0 . "TEXT,MTEXT"))))
      (progn
        (repeat (setq i (sslength ss))
          (setq entText (ssname ss (setq i (1- i))))
          (setq textObj (vlax-ename->vla-object entText))
          (setq textPos (vlax-get textObj 'InsertionPoint))
          (setq dist (distance cadenamientoPoint (list (car textPos) (cadr textPos))))
          
          ; Verificar si el texto contiene el patrón y está más cerca que los anteriores
          (if (and (wcmatch (setq oldText (vla-get-TextString textObj)) (strcat "*" pattern "*"))
                   (< dist minDist))
            (progn
              (setq minDist dist)
              (setq foundText entText)
            )
          )
        )
        
        ; Si se encontró un texto con el patrón, actualizarlo
        (if foundText
          (progn
            (setq textObj (vlax-ename->vla-object foundText))
            (setq oldText (vla-get-TextString textObj))
            (setq newText (replaceAfterPattern oldText pattern newValue))
            (vla-put-TextString textObj newText)
            (princ (strcat "\n>>> " layerName " actualizado: " oldText " -> " newText))
          )
          (princ (strcat "\n>>> " layerName ": No se encontró texto con '" pattern "' cercano al cadenamiento"))
        )
      )
      (princ (strcat "\n>>> " layerName ": No se encontraron textos en el dibujo"))
    )
  )

  ; ========== PRIMERO SELECCIONAR CADENAMIENTO ==========
  (princ "\nSelecciona el texto del cadenamiento: ")
  (SETQ ent (ENTSEL "\nSelecciona el texto del cadenamiento: "))
  (if ent
    (progn
      (SETQ LIP (ENTGET (CAR ent)))
      (SETQ CAD1 (CDR (ASSOC 1 LIP)))
      ; Guardar la posición del cadenamiento para buscar textos cercanos
      (setq cadenamientoPoint (cdr (assoc 10 LIP)))
      (princ (strcat "\nCadenamiento capturado: " CAD1))
    )
    (progn
      (princ "\n>>> No se seleccionó ningún texto. Saliendo...")
      (exit)
    )
  )

  ; ========== APAGAR CAPAS TEMPORALES ==========
  (princ "\nApagando capas temporales...")
  (command "._-LAYER" "_OFF" "XGRID" "")
  (command "._-LAYER" "_OFF" "APV-Cotas" "")
  (command "._-LAYER" "_OFF" "XGRIDT" "")
  (command "._-LAYER" "_OFF" "APV-Textosdatos" "")
  (command "._-LAYER" "_OFF" "XFG" "")
  (princ " >>> Capas apagadas")

  ; ========== AREA DE CORTE ==========
  (princ "\n--- AREA DE CORTE ---")
  (SETQ A (GETINT "\n¿Cuántas áreas de corte son? : "))
  (SETQ N 1)
  (SETQ C 0.0)
  
  (if (or (not A) (= A 0))
    (progn
      (SETQ AC "0.00")
      (princ "\nÁrea de corte: 0.00")
    )
    (progn
      (while (<= N A)
        (princ (strcat "\nÁrea " (itoa N) " de " (itoa A) " - Toca dentro del área de corte: "))
        
        (setq oldLast (entlast))
        (command "._BOUNDARY" PAUSE "")
        
        (if (not (equal oldLast (entlast)))
          (progn
            (SETQ lastEnt (entlast))
            (SETQ T1 (getObjectArea lastEnt))
            (command "._ERASE" lastEnt "")
            (SETQ C (+ T1 C))
            (princ (strcat "Área calculada: " (rtos T1 2 2)))
          )
          (progn
            (princ ">>> No se pudo crear el boundary. Intenta de nuevo.")
            (setq N (1- N))
          )
        )
        (SETQ N (1+ N))
      )
      (SETQ AC (RTOS C 2 2))
      (princ (strcat "\nÁrea TOTAL de corte: " AC " m²"))
      
      ; ACTUALIZAR AUTOMÁTICAMENTE EL TEXTO MÁS CERCANO CON "AC="
      (updateLayerText AC "AC=" "CORTE")
    )
  )
  
  ; ========== CONFIGURAR CAPAS PARA CARPETA ASFALTICA ==========
  (command "._-LAYER" "_ON" "XFG" "")
  (command "._-LAYER" "_OFF" "AC" "")
  (command "._-LAYER" "_OFF" "XEG" "")

  ; ========== CARPETA ASFALTICA ==========
  (princ "\n--- CARPETA ASFALTICA ---")
  (SETQ A (GETINT "\n¿Cuántas áreas de carpeta asfáltica son? : "))
  (SETQ N 1)
  (SETQ C 0.0)
  
  (if (or (not A) (= A 0))
    (progn
      (SETQ ACA "0.00")
      (princ "\nÁrea carpeta asfáltica: 0.00")
    )
    (progn
      (while (<= N A)
        (princ (strcat "\nÁrea " (itoa N) " de " (itoa A) " - Toca dentro del área de carpeta asfáltica: "))
        
        (setq oldLast (entlast))
        (command "._BOUNDARY" PAUSE "")
        
        (if (not (equal oldLast (entlast)))
          (progn
            (SETQ lastEnt (entlast))
            (SETQ T1 (getObjectArea lastEnt))
            (command "._ERASE" lastEnt "")
            (SETQ C (+ T1 C))
            (princ (strcat "Área calculada: " (rtos T1 2 2)))
          )
          (progn
            (princ ">>> No se pudo crear el boundary. Intenta de nuevo.")
            (setq N (1- N))
          )
        )
        (SETQ N (1+ N))
      )
      (SETQ ACA (RTOS C 2 2))
      (princ (strcat "\nÁrea TOTAL carpeta asfáltica: " ACA " m²"))
      
      ; ACTUALIZAR AUTOMÁTICAMENTE EL TEXTO MÁS CERCANO CON "ACA="
      (updateLayerText ACA "ACA=" "CARPETA ASFALTICA")
    )
  )

  ; ========== BASE ==========
  (princ "\n--- BASE ---")
  (SETQ A (GETINT "\n¿Cuántas áreas de base son? : "))
  (SETQ N 1)
  (SETQ C 0.0)
  
  (if (or (not A) (= A 0))
    (progn
      (SETQ AB "0.00")
      (princ "\nÁrea base: 0.00")
    )
    (progn
      (while (<= N A)
        (princ (strcat "\nÁrea " (itoa N) " de " (itoa A) " - Toca dentro del área de base: "))
        
        (setq oldLast (entlast))
        (command "._BOUNDARY" PAUSE "")
        
        (if (not (equal oldLast (entlast)))
          (progn
            (SETQ lastEnt (entlast))
            (SETQ T1 (getObjectArea lastEnt))
            (command "._ERASE" lastEnt "")
            (SETQ C (+ T1 C))
            (princ (strcat "Área calculada: " (rtos T1 2 2)))
          )
          (progn
            (princ ">>> No se pudo crear el boundary. Intenta de nuevo.")
            (setq N (1- N))
          )
        )
        (SETQ N (1+ N))
      )
      (SETQ AB (RTOS C 2 2))
      (princ (strcat "\nÁrea TOTAL base: " AB " m²"))
      
      ; ACTUALIZAR AUTOMÁTICAMENTE EL TEXTO MÁS CERCANO CON "AB="
      (updateLayerText AB "AB=" "BASE")
    )
  )

  ; ========== SUBRASANTE ==========
  (princ "\n--- SUBRASANTE ---")
  (SETQ A (GETINT "\n¿Cuántas áreas de subrasante son? : "))
  (SETQ N 1)
  (SETQ C 0.0)
  
  (if (or (not A) (= A 0))
    (progn
      (SETQ ASR "0.00")
      (princ "\nÁrea subrasante: 0.00")
    )
    (progn
      (while (<= N A)
        (princ (strcat "\nÁrea " (itoa N) " de " (itoa A) " - Toca dentro del área de subrasante: "))
        
        (setq oldLast (entlast))
        (command "._BOUNDARY" PAUSE "")
        
        (if (not (equal oldLast (entlast)))
          (progn
            (SETQ lastEnt (entlast))
            (SETQ T1 (getObjectArea lastEnt))
            (command "._ERASE" lastEnt "")
            (SETQ C (+ T1 C))
            (princ (strcat "Área calculada: " (rtos T1 2 2)))
          )
          (progn
            (princ ">>> No se pudo crear el boundary. Intenta de nuevo.")
            (setq N (1- N))
          )
        )
        (SETQ N (1+ N))
      )
      (SETQ ASR (RTOS C 2 2))
      (princ (strcat "\nÁrea TOTAL subrasante: " ASR " m²"))
      
      ; ACTUALIZAR AUTOMÁTICAMENTE EL TEXTO MÁS CERCANO CON "ASR="
      (updateLayerText ASR "ASR=" "SUBRASANTE")
    )
  )

  ; ========== CONFIGURAR CAPAS PARA TERRAPLEN ==========
  (command "._-LAYER" "_ON" "XEG" "")
  (command "._-LAYER" "_ON" "AC" "")

  ; ========== TERRAPLEN ==========
  (princ "\n--- TERRAPLEN ---")
  (SETQ A (GETINT "\n¿Cuántas áreas de terraplen son? : "))
  (SETQ N 1)
  (SETQ C 0.0)
  
  (if (or (not A) (= A 0))
    (progn
      (SETQ AT "0.00")
      (princ "\nÁrea terraplén: 0.00")
    )
    (progn
      (while (<= N A)
        (princ (strcat "\nÁrea " (itoa N) " de " (itoa A) " - Toca dentro del área de terraplen: "))
        
        (setq oldLast (entlast))
        (command "._BOUNDARY" PAUSE "")
        
        (if (not (equal oldLast (entlast)))
          (progn
            (SETQ lastEnt (entlast))
            (SETQ T1 (getObjectArea lastEnt))
            (command "._ERASE" lastEnt "")
            (SETQ C (+ T1 C))
            (princ (strcat "Área calculada: " (rtos T1 2 2)))
          )
          (progn
            (princ ">>> No se pudo crear el boundary. Intenta de nuevo.")
            (setq N (1- N))
          )
        )
        (SETQ N (1+ N))
      )
      (SETQ AT (RTOS C 2 2))
      (princ (strcat "\nÁrea TOTAL terraplén: " AT " m²"))
      
      ; ACTUALIZAR AUTOMÁTICAMENTE EL TEXTO MÁS CERCANO CON "AT="
      (updateLayerText AT "AT=" "TERRAPLEN")
    )
  )

  ; ========== RESTAURAR TODAS LAS CAPAS ==========
  (princ "\nRestaurando todas las capas...")
  (command "._-LAYER" "_ON" "*" "")
  (princ " >>> Todas las capas restauradas")

  ; ========== RESUMEN FINAL ==========
  (princ "\n--- RESUMEN FINAL ---")
  (princ (strcat "\nCadenamiento: " CAD1))
  (princ (strcat "\nCorte: " AC " m²"))
  (princ (strcat "\nCarpeta Asfáltica: " ACA " m²"))
  (princ (strcat "\nBase: " AB " m²"))
  (princ (strcat "\nSubrasante: " ASR " m²"))
  (princ (strcat "\nTerraplén: " AT " m²"))
  (princ "\n>>> ¡PROCESO COMPLETADO! Todos los valores han sido actualizados automáticamente.")
  
  (princ)
)