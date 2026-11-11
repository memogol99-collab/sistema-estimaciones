;;; MEMO SISTEMA 2.0.0 - archivo generado por construir_bundle.py
;;; Origen: LISP_VistasLayout/Restaurar Vistas ( AV ).lsp

        ; PARA GUARDAR VISTAS RAPIDAS
;	Solo números: AG ? "5" ? Guarda como 5
;	Con prefijo: AG ? "V5" ? Guarda como V5
;	Con cualquier nombre: AG ? "PLANTA1" ? Guarda como PLANTA1

        ; PARA RESTAURAR VISTAS RAPIDAS
;	AV ? "5" ? Restaura vista 5
;	AV ? "V5" ? Restaura vista V5
;	AV ? "PLANTA1" ? Restaura vista PLANTA1


(defun c:AV (/ num)
  ; Restaurar vista - acepta número solo o con prefijo
  (setq num (getstring "\nNúmero o nombre de vista a restaurar: "))
  (if (/= num "")
    (progn
      (command "_.-view" "_restore" num)
      (princ (strcat "\nVista '" num "' restaurada"))
    )
    (princ "\nNombre inválido")
  )
  (princ)
)

(defun c:GV (/ num)
  ; Guardar vista - acepta número solo o con prefijo
  (setq num (getstring "\nNúmero o nombre de vista para guardar: "))
  (if (/= num "")
    (progn
      (command "_.-view" "_save" num)
      (princ (strcat "\nVista guardada como: '" num "'"))
    )
    (princ "\nNombre inválido")
  )
  (princ)
)

; Cargar automáticamente
(princ "\n=== COMANDOS DE VISTAS FLEXIBLES ===")
(princ "\nAG - Guardar vista (ej: 5, V5, PLANTA1, etc.)")
(princ "\nAV - Restaurar vista (ej: 5, V5, PLANTA1, etc.)")
(princ)