;;; MEMO SISTEMA 2.1.1 - archivo generado por construir_bundle.py
;;; Origen: LISP_Secciones/Area Pref Guard ( HA ).lsp

;	?? Resumen de los Comandos HA Disponibles:
;	Comandos Principales:
;	HA2 - Versión completa con opciones (pregunta prefijo y si agregar "=")
;	HA - Versión rápida (usa directamente el último prefijo guardado)

;	Comandos de Gestión:
;	HAPREF - Ver/Cambiar el prefijo guardado
;	HARESET - Resetear el prefijo a "A="
;	HAINFO - Mostrar ayuda e información

;	?? Flujo de Trabajo Recomendado:
;	1. Primer uso: Ejecuta HA2 e introduce tu prefijo
;	2. Usos siguientes: Usa HA para máxima velocidad
;	3. Cambiar prefijo: Usa HAPREF o HARESET

;	?? Ejemplos de Resultados:
;	"A=25.50m2"
;	"Area=30.75m2"
;	"Superficie=15.20m2"

(defun c:HA2 (/ *error* hatch_ent text_ent hatch_obj area_val texto_datos nuevo_texto prefijo resp)
  (vl-load-com)
  
  ; Función de error local
  (defun *error* (msg)
    (if (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*EXIT*"))
      (princ (strcat "\nError: " msg))
    )
    (princ)
  )
  
  ; Inicializar variable global si no existe
  (if (not *ultimo_prefijo_ha2*)
    (setq *ultimo_prefijo_ha2* "A=")  ; Sin espacios
  )
  
  ; Solicitar prefijo con valor por defecto
  (setq prefijo (getstring T (strcat "\nIntroduce el prefijo <" *ultimo_prefijo_ha2* ">: ")))
  (if (= prefijo "")
    (setq prefijo *ultimo_prefijo_ha2*)
    (progn
      ; Preguntar si agregar "=" automáticamente (sin espacios)
      (initget "Sí No")
      (setq resp (getkword (strcat "\n¿Agregar '=' al prefijo? [Sí/No] <Sí>: ")))
      (if (or (not resp) (= resp "Sí"))
        (if (not (wcmatch prefijo "*="))
          (setq prefijo (strcat prefijo "="))  ; Sin espacios
        )
      )
      ; Guardar el nuevo prefijo
      (setq *ultimo_prefijo_ha2* prefijo)
    )
  )
  
  ; Seleccionar el hatch con filtro
  (princ "\nSelecciona el HATCH: ")
  (setq hatch_ent (car (entsel "\nSelecciona el HATCH: ")))
  
  (if (not hatch_ent)
    (progn
      (princ "\nNo se seleccionó ningún objeto.")
      (exit)
    )
  )
  
  (if (/= (cdr (assoc 0 (entget hatch_ent))) "HATCH")
    (progn
      (princ "\nEl objeto seleccionado no es un HATCH.")
      (exit)
    )
  )
  
  ; Obtener área del hatch con manejo de errores
  (setq hatch_obj (vlax-ename->vla-object hatch_ent))
  (setq area_val (vla-get-area hatch_obj))
  (setq area_val (rtos area_val 2 2)) ; Formato con 2 decimales
  
  ; Seleccionar el texto con filtro
  (princ "\nSelecciona el TEXT o MTEXT: ")
  (setq text_ent (car (entsel "\nSelecciona el TEXT o MTEXT: ")))
  
  (if (not text_ent)
    (progn
      (princ "\nNo se seleccionó ningún objeto.")
      (exit)
    )
  )
  
  (if (not (wcmatch (cdr (assoc 0 (entget text_ent))) "TEXT,MTEXT"))
    (progn
      (princ "\nEl objeto seleccionado no es un TEXT o MTEXT.")
      (exit)
    )
  )
  
  ; Actualizar el texto
  (setq texto_datos (entget text_ent))
  (setq nuevo_texto (strcat prefijo area_val "m2"))  ; Sin espacio antes de m2
  
  (entmod (subst (cons 1 nuevo_texto) (assoc 1 texto_datos) texto_datos))
  (entupd text_ent)
  
  ; Mensaje de confirmación
  (princ (strcat "\n? Texto actualizado: \"" nuevo_texto "\""))
  (princ (strcat "\n? Prefijo guardado: \"" *ultimo_prefijo_ha2* "\""))
  
  (princ)
)

; Versión rápida sin preguntas
(defun c:HA (/ hatch_ent text_ent hatch_obj area_val texto_datos nuevo_texto)
  (vl-load-com)
  
  (if (not *ultimo_prefijo_ha2*)
    (setq *ultimo_prefijo_ha2* "A=")  ; Sin espacios
  )
  
  ; Usar directamente el último prefijo sin preguntar
  (setq prefijo *ultimo_prefijo_ha2*)
  
  ; Seleccionar hatch
  (setq hatch_ent (car (entsel "\nSelecciona HATCH: ")))
  (if (and hatch_ent (= (cdr (assoc 0 (entget hatch_ent))) "HATCH"))
    (progn
      ; Obtener área
      (setq hatch_obj (vlax-ename->vla-object hatch_ent))
      (setq area_val (vla-get-area hatch_obj))
      (setq area_val (rtos area_val 2 2))
      
      ; Seleccionar texto
      (setq text_ent (car (entsel "\nSelecciona TEXT: ")))
      (if (and text_ent (wcmatch (cdr (assoc 0 (entget text_ent))) "TEXT,MTEXT"))
        (progn
          ; Actualizar texto
          (setq texto_datos (entget text_ent))
          (setq nuevo_texto (strcat prefijo area_val "m2"))  ; Sin espacio antes de m2
          
          (entmod (subst (cons 1 nuevo_texto) (assoc 1 texto_datos) texto_datos))
          (entupd text_ent)
          
          (princ (strcat "\n» " nuevo_texto))
        )
        (princ "\n! Texto no válido")
      )
    )
    (princ "\n! Hatch no válido")
  )
  (princ)
)

; Comando para gestión de prefijos
(defun c:HAPREF (/ nuevo_prefijo resp)
  (if (not *ultimo_prefijo_ha2*)
    (setq *ultimo_prefijo_ha2* "A=")  ; Sin espacios
  )
  
  (princ (strcat "\nPrefijo actual: \"" *ultimo_prefijo_ha2* "\""))
  (setq nuevo_prefijo (getstring T (strcat "\nNuevo prefijo <" *ultimo_prefijo_ha2* ">: ")))
  
  (if (/= nuevo_prefijo "")
    (progn
      (initget "Sí No")
      (setq resp (getkword "\n¿Incluir '=' automáticamente? [Sí/No] <Sí>: "))
      (if (or (not resp) (= resp "Sí"))
        (if (not (wcmatch nuevo_prefijo "*="))
          (setq nuevo_prefijo (strcat nuevo_prefijo "="))  ; Sin espacios
        )
      )
      (setq *ultimo_prefijo_ha2* nuevo_prefijo)
      (princ (strcat "\n? Nuevo prefijo: \"" *ultimo_prefijo_ha2* "\""))
    )
    (princ "\n? Prefijo mantiene igual.")
  )
  (princ)
)

; Comando para resetear
(defun c:HARESET ()
  (setq *ultimo_prefijo_ha2* "A=")  ; Sin espacios
  (princ "\n? Prefijo reseteado a \"A=\"")
  (princ)
)

; Comando para mostrar información
(defun c:HAINFO ()
  (princ "\n=== COMANDOS HA - AYUDÁ ===")
  (princ "\nHA2    - Completo (pregunta prefijo)")
  (princ "\nHA     - Rápido (usa último prefijo)")
  (princ "\nHAPREF - Gestionar prefijos")
  (princ "\nHARESET- Resetear a \"A=\"")
  (princ (strcat "\n\nPrefijo actual: \"" (if *ultimo_prefijo_ha2* *ultimo_prefijo_ha2* "A=") "\""))
  (princ)
)

; Mensaje de carga mejorado
(princ "\n=== COMANDOS HA CARGADOS ===")
(princ "\nHA2, HA, HAPREF, HARESET, HAINFO")
(princ (strcat "\nPrefijo actual: \"" (if *ultimo_prefijo_ha2* *ultimo_prefijo_ha2* "A=") "\""))
(princ)


