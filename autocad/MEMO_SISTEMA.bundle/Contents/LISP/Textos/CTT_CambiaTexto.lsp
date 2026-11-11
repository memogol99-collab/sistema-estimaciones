;;; MEMO SISTEMA 2.1.0 - archivo generado por construir_bundle.py
;;; Origen: LISP_Textos/Cambia Texto ( CTT ).lsp
;;; Parches aplicados: renombrar:CTT=CTX

; Cambia el texto seleccionado por un texto tecleado

(defun c:CTX (/ ss i ent obj texto_nuevo contador)
  (vl-load-com)
  
  (setq texto_nuevo (getstring T "\nNuevo texto: "))
  (setq contador 0)
  
  (princ "\nSelecciona textos: ")
  (setq ss (ssget '((0 . "TEXT,MTEXT"))))
  
  (if ss
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq ent (ssname ss i))
        (setq obj (vlax-ename->vla-object ent))
        (vlax-put-property obj 'TextString texto_nuevo)
        (setq contador (1+ contador))
        (setq i (1+ i))
      )
      (princ (strcat "\nTextos cambiados: " (itoa contador)))
    )
    (princ "\nNo se seleccionaron textos.")
  )
  (princ)
)

(princ "\nComandos cargados: CTE")
(princ)