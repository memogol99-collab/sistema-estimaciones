;;================================================
;; ColorearPorElevacion_CCN_Puntos_v5.lsp
;; Solo PUNTOS AutoCAD
;; Comando: CPEC
;;================================================

(defun CPEC-Z (e / d p)
  (setq d (entget e))
  (setq p (cdr (assoc 10 d)))
  (if (and p (listp p))
    (caddr p)
  )
)

(defun CPEC-COLOR (z zmin zmax modo / f)
  (setq f (/ (- z zmin) (- zmax zmin)))
  (if (= modo 2)
    (setq f (- 1.0 f))
  )
  (cond
    ((< f 0.125) 16)
    ((< f 0.250) 1)
    ((< f 0.375) 30)
    ((< f 0.500) 2)
    ((< f 0.625) 3)
    ((< f 0.750) 4)
    ((< f 0.875) 5)
    (T 150)
  )
)

(defun CPEC-SETCOLOR (e c / d)
  (setq d (entget e))
  (if (assoc 62 d)
    (setq d (subst (cons 62 c) (assoc 62 d) d))
    (setq d (append d (list (cons 62 c))))
  )
  (entmod d)
  (entupd e)
)

(defun c:CPEC (/ modo ss i e z zs zmin zmax)
  (setq modo (getint "\nEscala [1=Topografica / 2=Batimetrica]: "))

  (if (setq ss (ssget '((0 . "POINT"))))
    (progn
      (setq zs '()
            i 0)
      (repeat (sslength ss)
        (setq e (ssname ss i)
              z (CPEC-Z e))
        (if (numberp z)
          (setq zs (cons z zs))
        )
        (setq i (1+ i))
      )

      (if zs
        (progn
          (setq zmin (apply 'min zs)
                zmax (apply 'max zs)
                i 0)

          (repeat (sslength ss)
            (setq e (ssname ss i)
                  z (CPEC-Z e))
            (if (numberp z)
              (CPEC-SETCOLOR e (CPEC-COLOR z zmin zmax modo))
            )
            (setq i (1+ i))
          )

          (princ "\nRango Z: ")
          (princ zmin)
          (princ " - ")
          (princ zmax)
          (princ "\nPuntos coloreados.")
        )
      )
    )
    (princ "\nNo se seleccionaron puntos POINT.")
  )
  (princ)
)

(princ "\nCPEC Puntos CCN v5 cargado.")
(princ)
