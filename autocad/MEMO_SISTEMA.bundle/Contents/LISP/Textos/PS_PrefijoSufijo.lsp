;;; MEMO SISTEMA 2.1.0 - archivo generado por construir_bundle.py
;;; Origen: LISP_Textos/PrefijoSufijo ( PS ).lsp

; Variables globales para almacenar los últimos valores
(setq *ultimo-prefijo* "")
(setq *ultimo-sufijo* "")

(defun c:PS (/ ss prefijo sufijo i ent txt nuevo_txt temp-pref temp-suf)
  (vl-load-com)
  
  ; Solicitar prefijo y sufijo al usuario con valores por defecto
  (setq temp-pref (getstring T (strcat "\nIntroduce el prefijo <" *ultimo-prefijo* ">: ")))
  (if (equal temp-pref "")
    (setq prefijo *ultimo-prefijo*)
    (setq prefijo temp-pref)
  )
  
  (setq temp-suf (getstring T (strcat "\nIntroduce el sufijo <" *ultimo-sufijo* ">: ")))
  (if (equal temp-suf "")
    (setq sufijo *ultimo-sufijo*)
    (setq sufijo temp-suf)
  )
  
  ; Guardar los nuevos valores para futuras ejecuciones
  (setq *ultimo-prefijo* prefijo)
  (setq *ultimo-sufijo* sufijo)
  
  ; Verificar si se ingresaron valores
  (if (and (equal prefijo "") (equal sufijo ""))
    (progn
      (alert "No se ingresó ningún prefijo ni sufijo. Operación cancelada.")
      (exit)
    )
  )
  
  ; Seleccionar objetos de texto
  (princ "\nSelecciona los textos a modificar: ")
  (setq ss (ssget '((0 . "TEXT,MTEXT"))))
  
  (if ss
    (progn
      ; Recorrer la selección
      (setq i 0)
      (repeat (sslength ss)
        (setq ent (ssname ss i))
        (setq txt (cdr (assoc 1 (entget ent))))
        
        ; Construir nuevo texto con prefijo y sufijo
        (setq nuevo_txt (strcat prefijo txt sufijo))
        
        ; Actualizar el texto en el dibujo
        (entmod (subst (cons 1 nuevo_txt) (assoc 1 (entget ent)) (entget ent)))
        
        (setq i (1+ i))
      )
      (princ (strcat "\nSe modificaron " (itoa i) " textos."))
      (princ (strcat "\nPrefijo guardado: \"" prefijo "\""))
      (princ (strcat "\nSufijo guardado: \"" sufijo "\""))
    )
    (princ "\nNo se seleccionaron textos válidos.")
  )
  (princ)
)

; Versión individual con memoria
(defun c:PREFSUFIND (/ ss i ent txt prefijo sufijo temp-pref temp-suf)
  (vl-load-com)
  
  (princ "\nSelecciona los textos a modificar: ")
  (setq ss (ssget '((0 . "TEXT,MTEXT"))))
  
  (if ss
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq ent (ssname ss i))
        (setq txt (cdr (assoc 1 (entget ent))))
        
        ; Preguntar prefijo y sufijo para cada texto con valores por defecto
        (princ (strcat "\nTexto actual: \"" txt "\""))
        
        (setq temp-pref (getstring T (strcat "\nPrefijo para este texto <" *ultimo-prefijo* ">: ")))
        (if (equal temp-pref "")
          (setq prefijo *ultimo-prefijo*)
          (setq prefijo temp-pref)
        )
        
        (setq temp-suf (getstring T (strcat "Sufijo para este texto <" *ultimo-sufijo* ">: ")))
        (if (equal temp-suf "")
          (setq sufijo *ultimo-sufijo*)
          (setq sufijo temp-suf)
        )
        
        ; Guardar los últimos valores utilizados
        (setq *ultimo-prefijo* prefijo)
        (setq *ultimo-sufijo* sufijo)
        
        ; Construir nuevo texto
        (setq nuevo_txt (strcat prefijo txt sufijo))
        
        ; Actualizar el texto
        (entmod (subst (cons 1 nuevo_txt) (assoc 1 (entget ent)) (entget ent)))
        
        (princ (strcat "\nTexto modificado: \"" nuevo_txt "\""))
        
        (setq i (1+ i))
      )
      (princ (strcat "\nProcesados " (itoa i) " textos."))
    )
    (princ "\nNo se seleccionaron textos válidos.")
  )
  (princ)
)

; Comando para ver los valores guardados actualmente
(defun c:VERPREFSUF ()
  (princ (strcat "\nÚltimo prefijo utilizado: \"" *ultimo-prefijo* "\""))
  (princ (strcat "\nÚltimo sufijo utilizado: \"" *ultimo-sufijo* "\""))
  (princ)
)

; Comando para limpiar la memoria
(defun c:LIMPIARPREFSUF ()
  (setq *ultimo-prefijo* "")
  (setq *ultimo-sufijo* "")
  (princ "\nMemoria de prefijos y sufijos limpiada.")
  (princ)
)

; Comando para establecer valores específicos
(defun c:SETPREFSUF (/ nuevo-pref nuevo-suf)
  (setq nuevo-pref (getstring T "\nIntroduce el nuevo prefijo por defecto: "))
  (setq nuevo-suf (getstring T "Introduce el nuevo sufijo por defecto: "))
  
  (setq *ultimo-prefijo* nuevo-pref)
  (setq *ultimo-sufijo* nuevo-suf)
  
  (princ (strcat "\nPrefijo por defecto establecido a: \"" *ultimo-prefijo* "\""))
  (princ (strcat "\nSufijo por defecto establecido a: \"" *ultimo-sufijo* "\""))
  (princ)
)

; Mensaje de carga mejorado
(princ "\nComandos cargados:")
(princ "\n  PS           - Añadir prefijo/sufijo a múltiples textos")
(princ "\n  PREFSUFIND   - Añadir prefijo/sufijo individualmente")
(princ "\n  VERPREFSUF   - Mostrar valores guardados")
(princ "\n  SETPREFSUF   - Establecer valores por defecto")
(princ "\n  LIMPIARPREFSUF - Limpiar memoria")
(princ (strcat "\n\nValores actuales: Prefijo=\"" *ultimo-prefijo* "\" Sufijo=\"" *ultimo-sufijo* "\""))
(princ)


;	 Comandos Adicionales:
;	VERPREFSUF - Muestra los valores actualmente guardados
;	SETPREFSUF - Establece valores por defecto manualmente
;	LIMPIAERPREFSUF - Limpia la memoria

;	?? Mejoras en la Usabilidad:
;	Mensajes más informativos mostrando los valores guardados
;	Preview de los textos modificados en modo individual
;	Los valores se mantienen entre sesiones de AutoCAD (mientras no se cierre el dibujo)

;	? Uso Recomendado:
;	1. Usa PS para modificaciones masivas rápidas
;	2. Los valores se guardan automáticamente
;	3. Presiona Enter en los prompts para reutilizar valores anteriores
;	4. Usa SETPREFSUF para establecer valores que uses frecuentemente
