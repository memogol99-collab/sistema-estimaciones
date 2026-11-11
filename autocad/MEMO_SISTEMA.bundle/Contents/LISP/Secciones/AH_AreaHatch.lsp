;;; MEMO SISTEMA 2.1.1 - archivo generado por construir_bundle.py
;;; Origen: LISP_Secciones/Extraer Area de Hatch ( AH ).lsp

; === COMANDOS AH - AUTOMATIZACION DE AREAS DE HATCH ===
; Version con texto en mayusculas y "AREA DE"

(defun c:AH2 (/ *error* ss_hatches i hatch_ent area_val text_ent prefijo_texto layer_name keyword)
  (vl-load-com)
  
  ; Funcion de error
  (defun *error* (msg)
    (if (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*EXIT*"))
      (princ (strcat "\nError: " msg))
    )
    (princ)
  )
  
  ; Seleccion multiple de hatches
  (princ "\nSELECCIONA HATCHES por ventana o crossing: ")
  (setq ss_hatches (ssget '((0 . "HATCH"))))
  
  (if (not ss_hatches)
    (progn
      (princ "\nNo se seleccionaron hatches.")
      (exit)
    )
  )
  
  (princ (strcat "\nProcesando " (itoa (sslength ss_hatches)) " hatches..."))
  
  ; Procesar cada hatch
  (setq i 0)
  (repeat (sslength ss_hatches)
    (setq hatch_ent (ssname ss_hatches i))
    (setq i (1+ i))
    
    ; Obtener nombre de capa
    (setq layer_name (cdr (assoc 8 (entget hatch_ent))))
    
    ; Determinar palabra clave
    (setq keyword (get-keyword-from-layer layer_name))
    (setq prefijo_texto (get-prefix-text keyword))
    
    (princ (strcat "\nHatch " (itoa i) " - Capa: " layer_name))
    (princ (strcat "\nKeyword: " keyword " - Texto: " prefijo_texto))
    
    ; Obtener area del hatch
    (setq area_val (get-hatch-area hatch_ent))
    
    (if area_val
      (progn
        ; Buscar texto vecino que contenga la palabra clave
        (setq text_ent (find-text-with-keyword-near-hatch hatch_ent keyword))
        
        (if text_ent
          (progn
            ; Actualizar texto con nuevo valor
            (update-text-with-new-content text_ent area_val prefijo_texto)
            (princ (strcat "\nOK Texto actualizado: " prefijo_texto area_val "M2"))
          )
          (princ (strcat "\nAVISO No se encontro texto con: " keyword))
        )
      )
      (princ "\nERROR No se pudo obtener area")
    )
  )
  
  (princ "\nProceso completado.")
  (princ)
)

; === FUNCIONES AUXILIARES ACTUALIZADAS ===

(defun get-keyword-from-layer (layer_name)
  "Obtiene la palabra clave especifica de la capa"
  (cond
    ((wcmatch (strcase layer_name) "*CORTE*") "CORTE")
    ((wcmatch (strcase layer_name) "*RELLENO*") "RELLENO") 
    ((wcmatch (strcase layer_name) "*TERRAPLEN*") "TERRAPLEN")
    ((wcmatch (strcase layer_name) "*ARENA*") "ARENA")
    ((wcmatch (strcase layer_name) "*EXCAVACION*") "EXCAVACION")
    ((wcmatch (strcase layer_name) "*DESMONTE*") "DESMONTE")
    ((wcmatch (strcase layer_name) "*CARPETA*") "CARPETA")
    ((wcmatch (strcase layer_name) "*AFINE*") "AFINE")
    ((wcmatch (strcase layer_name) "*CORAZA*") "CORAZA")
    ((wcmatch (strcase layer_name) "*BASE*") "BASE")
    ((wcmatch (strcase layer_name) "*NUCLEO*") "NUCLEO")
    (T "CORTE") ; Por defecto
  )
)

(defun get-prefix-text (keyword)
  "Obtiene el texto completo en mayusculas con 'AREA DE'"
  (cond
    ((= keyword "CORTE") "AREA DE CORTE=")
    ((= keyword "RELLENO") "AREA DE RELLENO=") 
    ((= keyword "TERRAPLEN") "AREA DE TERRAPLEN=")
    ((= keyword "ARENA") "AREA DE ARENA=")
    ((= keyword "EXCAVACION") "AREA DE EXCAVACION=")
    ((= keyword "DESMONTE") "AREA DE DESMONTE=")
    ((= keyword "CARPETA") "AREA DE CARPETA=")
    ((= keyword "AFINE") "AREA DE AFINE=")
    ((= keyword "CORAZA") "AREA DE CORAZA=")
    ((= keyword "BASE") "AREA DE BASE=")
    ((= keyword "NUCLEO") "AREA DE NUCLEO=")
    (T "AREA=") ; Por defecto
  )
)

(defun find-text-with-keyword-near-hatch (hatch_ent keyword / hatch_pt ss_texts j text_ent text_content text_pt distancia min_dist found_text)
  "Busca el texto mas cercano que contenga la palabra clave"
  
  (setq hatch_pt (get-entity-center hatch_ent))
  (setq min_dist 500) ; Distancia maxima de busqueda
  (setq found_text nil)
  
  (if (and hatch_pt keyword)
    (progn
      ; Buscar textos cerca del hatch
      (setq ss_texts (ssget "_X" '((0 . "TEXT,MTEXT"))))
      
      (if ss_texts
        (progn
          (setq j 0)
          (repeat (sslength ss_texts)
            (setq text_ent (ssname ss_texts j))
            (setq text_content (cdr (assoc 1 (entget text_ent))))
            (setq text_pt (get-entity-center text_ent))
            
            (if (and text_pt text_content)
              (progn
                (setq distancia (distance hatch_pt text_pt))
                
                ; Si esta cerca y contiene la keyword (case insensitive)
                (if (and (< distancia min_dist) 
                         (wcmatch (strcase text_content) (strcat "*" (strcase keyword) "*")))
                  (progn
                    (setq min_dist distancia)
                    (setq found_text text_ent)
                    (princ (strcat "\n  Texto cercano: \"" text_content "\" - Dist: " (rtos distancia 2 2)))
                  )
                )
              )
            )
            (setq j (1+ j))
          )
        )
      )
    )
  )
  found_text
)

(defun get-entity-center (ent / minpt maxpt)
  "Obtiene el punto central de una entidad"
  (if (vlax-ename->vla-object ent)
    (progn
      (vla-getboundingbox (vlax-ename->vla-object ent) 'minpt 'maxpt)
      (mapcar '(lambda (a b) (/ (+ a b) 2.0)) 
              (vlax-safearray->list minpt) 
              (vlax-safearray->list maxpt))
    )
    nil
  )
)

(defun update-text-with-new-content (text_ent area_val prefijo_texto / texto_datos texto_actual nuevo_texto)
  "Actualiza el contenido del texto con el nuevo formato en MAYUSCULAS"
  
  (setq texto_datos (entget text_ent))
  (setq texto_actual (cdr (assoc 1 texto_datos)))
  
  (princ (strcat "\n  Texto original: " texto_actual))
  
  ; Crear nuevo texto en MAYUSCULAS
  (setq nuevo_texto (strcat prefijo_texto area_val "M2"))
  
  ; Reemplazar el contenido
  (entmod (subst (cons 1 nuevo_texto) (assoc 1 texto_datos) texto_datos))
  (entupd text_ent)
  
  (princ (strcat "\n  Texto nuevo: " nuevo_texto))
  T
)

(defun get-hatch-area (hatch-entity / hatch-obj area-val)
  "Obtiene el area de un hatch"
  (setq hatch-obj (vlax-ename->vla-object hatch-entity))
  (if (vl-catch-all-error-p 
        (setq area-val (vl-catch-all-apply 'vla-get-area (list hatch-obj))))
    (progn
      (princ "\nERROR: No se pudo obtener el area")
      nil)
    (rtos area-val 2 2)
  )
)

; === COMANDO RAPIDO AH ===

(defun c:AH (/ ss_hatches i hatch_ent area_val text_ent prefijo_texto layer_name keyword)
  (vl-load-com)
  
  ; Seleccion multiple de hatches
  (princ "\nSELECCIONA HATCHES: ")
  (setq ss_hatches (ssget '((0 . "HATCH"))))
  
  (if ss_hatches
    (progn
      (princ (strcat "\nProcesando " (itoa (sslength ss_hatches)) " hatches..."))
      
      (setq i 0)
      (repeat (sslength ss_hatches)
        (setq hatch_ent (ssname ss_hatches i))
        (setq i (1+ i))
        
        ; Obtener nombre de capa
        (setq layer_name (cdr (assoc 8 (entget hatch_ent))))
        
        ; Determinar palabra clave y texto
        (setq keyword (get-keyword-from-layer layer_name))
        (setq prefijo_texto (get-prefix-text keyword))
        
        (setq area_val (get-hatch-area hatch_ent))
        
        (if (and area_val (setq text_ent (find-text-with-keyword-near-hatch hatch_ent keyword)))
          (progn
            (update-text-with-new-content text_ent area_val prefijo_texto)
            (princ (strcat "\n>> " prefijo_texto area_val "M2"))
          )
          (princ (strcat "\n! Sin texto con: " keyword))
        )
      )
    )
    (princ "\n! No se seleccionaron hatches")
  )
  (princ)
)

; === COMANDO DE INFORMACION ===

(defun c:AHINFO ()
  (princ "\n================================================")
  (princ "\nCOMANDOS AH - AUTOMATIZACION DE AREAS")
  (princ "\n================================================")
  (princ "\nAH2     - Proceso multiple completo")
  (princ "\nAH      - Version rapida")  
  (princ "\nAHINFO  - Esta ayuda")
  (princ "\n-----------------------------------------------")
  (princ "\nFORMATO DE SALIDA EN MAYUSCULAS:")
  (princ "\nCORTE      -> AREA DE CORTE=25.50M2")
  (princ "\nRELLENO    -> AREA DE RELLENO=30.75M2") 
  (princ "\nTERRAPLEN  -> AREA DE TERRAPLEN=15.20M2")
  (princ "\nEXCAVACION -> AREA DE EXCAVACION=18.40M2")
  (princ "\nDESMONTE   -> AREA DE DESMONTE=22.10M2")
  (princ "\nCARPETA    -> AREA DE CARPETA=03.10M2")
  (princ "\nAFINE      -> AREA DE AFINE=12.80M2")
  (princ "\nCORAZA     -> AREA DE CORAZA=8.50M2")
  (princ "\nZANJA      -> AREA DE BASE=5.25M2")
  (princ "\nNUCLEO     -> AREA DE NUCLEO=45.30M2")
  (princ "\n================================================")
  (princ)
)

; === MENSAJE DE CARGA ===
(princ "\nCOMANDOS AH CARGADOS - AH2, AH, AHINFO")
(princ "\nFORMATO: AREA DE [TIPO]=[VALOR]M2 (MAYUSCULAS)")
(princ)