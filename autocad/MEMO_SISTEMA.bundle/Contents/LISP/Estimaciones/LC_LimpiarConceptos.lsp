;;; MEMO SISTEMA 2.1.1 - archivo generado por construir_bundle.py
;;; Origen: LISP_Estimaciones/Limpiar Conceptos ( LC ).lsp
;;; Parches aplicados: renombrar:LC=LCO

;	Comandos disponibles:
;	LIMPIARTABLA - Limpiar textos de la capa CONCEPTOS

;; COMANDO ADICIONAL MODIFICADO: Para limpiar TEXTOS Y MTEXTOS de la capa CONCEPTOS
(defun c:LCO (/ ss)
  (princ "\nLimpiando textos y mtextos de la capa CONCEPTOS...")
  ;; MODIFICADO: Ahora incluye TEXT y MTEXT
  (setq ss (ssget "_X" '((0 . "TEXT,MTEXT") (8 . "CONCEPTOS"))))
  (if ss
    (progn
      (command "_.erase" ss "")
      (princ (strcat "\nSe eliminaron " (itoa (sslength ss)) " textos y mtextos de la capa CONCEPTOS"))
    )
    (princ "\nNo se encontraron textos ni mtextos en la capa CONCEPTOS")
  )
  (princ)
)


(princ "\n==================================================")
(princ "\nCOMANDOS DISPONIBLES:")
(princ "\n  LCO - Eliminar TEXT y MTEXT de capa CONCEPTOS") 
(princ "\n==================================================")
(princ)