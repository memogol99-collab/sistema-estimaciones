;;; MEMO SISTEMA 2.0.0 - archivo generado por construir_bundle.py
;;; Origen: LISP_NubePuntos/PTO-INS-TEXTO  ( PIT ).lsp

(vl-load-com)

;; Reemplaza el primer espacio entre digitos por punto decimal
;; Ejemplo: "-18 36" -> "-18.36"
(defun fix-space-decimal (str / pos)
  (setq pos (vl-string-search " " str))
  (if (and pos
           (> pos 0)
           (< (+ pos 1) (strlen str))
           (wcmatch (substr str pos 1) "#*")
           (wcmatch (substr str (+ pos 2) 1) "#*"))
    (vl-string-subst "." " " str)
    str
  )
)

(defun c:PIT ( / sel n ent edata etype
                           inspt txt zval numZ newpt
                           subent subdata blkIns)

  (prompt "\nSeleccione texto(s) o bloque(s): ")
  (if (not (setq sel (ssget '((0 . "TEXT,MTEXT,INSERT")))))
    (progn (princ "\nNo se selecciono nada.") (exit))
  )

  (setq n 0)
  (while (< n (sslength sel))
    (setq ent   (ssname sel n))
    (setq edata (entget ent))
    (setq etype (cdr (assoc 0 edata)))

    (cond

      ;; TEXT o MTEXT
      ((or (= etype "TEXT") (= etype "MTEXT"))
       (if (cdr (assoc 11 edata))
         (setq inspt (cdr (assoc 11 edata)))
         (setq inspt (cdr (assoc 10 edata)))
       )
       (setq txt  (cdr (assoc 1 edata)))
       (setq zval (caddr inspt))
       (if (equal zval 0.0 1e-6)
         (progn
           (setq numZ (atof (fix-space-decimal txt)))
           (if (not (equal numZ 0.0 1e-6))
             (setq zval numZ)
           )
         )
       )
       (setq newpt (list (car inspt) (cadr inspt) zval))
       (entmake
         (list '(0 . "POINT") (cons 10 newpt) (cons 62 1))
       )
      )

      ;; INSERT (bloque)
      ((= etype "INSERT")
       (setq subent (entnext ent))
       (if (and subent
                (= (cdr (assoc 0 (entget subent))) "ATTRIB"))
         ;; Bloque con atributos visibles
         (progn
           (setq blkIns (cdr (assoc 10 edata)))
           (while (and subent
                       (setq subdata (entget subent))
                       (= (cdr (assoc 0 subdata)) "ATTRIB"))
             (if (and
                   (/= (logand (cdr (assoc 70 subdata)) 1) 1)
                   (/= (logand (cdr (assoc 70 subdata)) 2) 2))
               (progn
                 (setq txt (cdr (assoc 1 subdata)))
                 (if (cdr (assoc 11 subdata))
                   (setq inspt (cdr (assoc 11 subdata)))
                   (setq inspt (cdr (assoc 10 subdata)))
                 )
                 (setq zval (caddr inspt))
                 (if (equal zval 0.0 1e-6)
                   (progn
                     (setq numZ (atof (fix-space-decimal txt)))
                     (if (not (equal numZ 0.0 1e-6))
                       (setq zval numZ)
                     )
                   )
                 )
                 (setq newpt (list (car inspt) (cadr inspt) zval))
                 (entmake
                   (list '(0 . "POINT") (cons 10 newpt) (cons 62 1))
                 )
               )
             )
             (setq subent (entnext subent))
           )
         )
         ;; Bloque simple (sin atributos)
         (progn
           (setq inspt (cdr (assoc 10 edata)))
           (setq newpt (list (car inspt) (cadr inspt) (caddr inspt)))
           (entmake
             (list '(0 . "POINT") (cons 10 newpt) (cons 62 1))
           )
         )
       )
      )
    )
    (setq n (1+ n))
  )
  (princ "\nListo.")
  (princ)
)

(princ "\n>> PTO-INS-TEXTO v5.1 cargado.")
(princ)
