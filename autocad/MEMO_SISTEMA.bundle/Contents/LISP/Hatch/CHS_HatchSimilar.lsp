;;; MEMO SISTEMA 2.1.0 - archivo generado por construir_bundle.py
;;; Origen: LISP_Hatch/Crear Hatch Similar ( CHS ).lsp


(defun c:CHS (/ ent ref_hatch)
    (vl-load-com)
    
    (princ "\n?? HATCH BY REFERENCE - CS")
    
    (if (setq ent (car (entsel "\nSelecciona hatch referencia: ")))
        (if (= (cdr (assoc 0 (entget ent))) "HATCH")
            (progn
                (setq ref_hatch ent)
                
                ; Configurar propiedades
                (setvar "HPNAME" (cdr (assoc 2 (entget ref_hatch))))
                (setvar "HPSCALE" (cdr (assoc 41 (entget ref_hatch))))
                (setvar "HPANG" (cdr (assoc 52 (entget ref_hatch))))
                (setvar "HPANNOTATIVE" 0)
                (setvar "CLAYER" (cdr (assoc 8 (entget ref_hatch))))
                
                (princ "\n? Listo! Ahora crea el hatch con clics internos...")
                
                ; Usar BHATCH que es más interactivo
                (command "._BHATCH")
                
            )
            (princ "\n? Debe ser un HATCH.")
        )
        (princ "\n? Nada seleccionado.")
    )
    (princ)
)