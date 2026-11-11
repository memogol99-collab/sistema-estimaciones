;;; MEMO SISTEMA 2.0.0 - archivo generado por construir_bundle.py
;;; Origen: LISP_Secciones/Cambia Numeros x 00.00 ( R00 ).LSP

; Versión simple - conserva "M2" al final del texto
(defun c:R00 (/ ss n e d t1 t2)
    (if (setq ss (ssget '((0 . "TEXT,MTEXT"))))
        (repeat (setq n (sslength ss))
            (setq e (ssname ss (setq n (1- n)))
                  d (entget e)
                  t1 (cdr (assoc 1 d))
            )
            ; Verificar si termina con "M2" (mayúsculas o minúsculas)
            (if (wcmatch (strcase t1) "*M2")
                (progn
                  ; Reemplazar números en todo excepto las últimas 2 letras
                  (setq t2 (vl-string-translate "123456789" "000000000" 
                           (substr t1 1 (- (strlen t1) 2))))
                  (setq t2 (strcat t2 (substr t1 (- (strlen t1) 1))))
                )
                ; Si no termina con "M2", reemplazar normalmente
                (setq t2 (vl-string-translate "123456789" "000000000" t1))
            )
            (if (/= t1 t2)
                (entmod (subst (cons 1 t2) (assoc 1 d) d))
            )
        )
    )
    (princ)
)