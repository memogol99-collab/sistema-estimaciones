;;; MEMO SISTEMA 2.0.0 - archivo generado por construir_bundle.py
;;; Origen: LISP_Secciones/Area_m2 ( AM2 ).lsp

; =============================================
; COMANDOS DE ACTUALIZACIÓN DE ÁREAS EN HATCHES
; Versión mejorada - Más robusta y eficiente
; =============================================

(defun c:AM2 (/ *error* hatch_ent text_ent hatch_obj area_val texto_datos nuevo_texto ent_data)
  (vl-load-com)
  
  ; Función local de manejo de errores
  (defun *error* (msg)
    (cond
      ((not msg)) ; Salida normal
      ((wcmatch (strcase msg) "*CANCEL*,*QUIT*,*ESCAPE*")
       (princ "\nComando cancelado por usuario."))
      (t (princ (strcat "\nError: " msg))))
    (princ))
  
  (princ "\n*** ACTUALIZAR ÁREA INDIVIDUAL ***")
  
  ; Seleccionar hatch con verificación
  (while (not hatch_ent)
    (princ "\nSelecciona el HATCH: ")
    (setq hatch_ent (car (entsel)))
    (cond
      ((not hatch_ent) (princ "\nNo se seleccionó ningún objeto."))
      ((/= (cdr (assoc 0 (setq ent_data (entget hatch_ent)))) "HATCH")
       (princ "\nEl objeto seleccionado no es un HATCH.")
       (setq hatch_ent nil))))
  
  ; Obtener área del hatch
  (setq hatch_obj (vlax-ename->vla-object hatch_ent))
  (setq area_val (vla-get-area hatch_obj))
  (setq area_val (rtos area_val 2 2)) ; Formato con 2 decimales
  
  ; Seleccionar texto con verificación
  (while (not text_ent)
    (princ " Selecciona el TEXT o MTEXT: ")
    (setq text_ent (car (entsel)))
    (cond
      ((not text_ent) (princ "\nNo se seleccionó ningún objeto."))
      ((not (wcmatch (cdr (assoc 0 (entget text_ent))) "TEXT,MTEXT"))
       (princ "\nEl objeto seleccionado no es TEXT o MTEXT.")
       (setq text_ent nil))))
  
  ; Actualizar el texto
  (setq texto_datos (entget text_ent))
  (setq nuevo_texto (strcat "A= " area_val " m²"))  ; Usar símbolo de m²
  
  (entmod (subst (cons 1 nuevo_texto) (assoc 1 texto_datos) texto_datos))
  (entupd text_ent)
  
  (princ (strcat "\n? Texto actualizado: " nuevo_texto))
  (princ))


; =============================================
; MENSAJES DE CARGA MEJORADOS
; =============================================

(princ "\n+----------------------------------------+")
(princ "\n¦   HERRAMIENTAS DE ÁREA - VERSIÓN 2.0   ¦")
(princ "\n+----------------------------------------+")
(princ "\nComandos disponibles:")
(princ "\n• AM2 - Individual  (selección guiada)")
(princ "\n• HA2 - Múltiples   (selección por ventana)") 
(princ "\n• HA3 - Ultra-rápida(selección mixta automática)")
(princ "\n")
(princ "\nFormato: A= [área] m²  (2 decimales)")
(princ)