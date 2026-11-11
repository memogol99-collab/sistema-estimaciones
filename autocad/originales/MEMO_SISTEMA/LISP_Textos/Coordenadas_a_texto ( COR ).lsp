;; ACTUALIZAR COORDENADAS EN TEXTOS
;; COR - Comando principal

;; COR - Completo con opciones (decimales, prefijo)
;; COR2 - Rápido (3 decimales, siempre con prefijo)
;; CORA - Automático (selecciona 3 textos de una vez)

(vl-load-com)

(defun c:COR (/ old_cmdecho PuntoCoordenada decimales con_prefijo Este Norte Cota entSupE entSupN entSupZ)
  
  (defun *error* (msg)
    (if (not (wcmatch (strcase msg) "*CANCEL*,*EXIT*,*QUIT*"))
      (princ (strcat "\nError: " msg))
    )
    (if old_cmdecho (setvar "CMDECHO" old_cmdecho))
    (princ)
  )
  
  (defun seleccionar-texto (mensaje / ent obj)
    (while
      (progn
        (setq ent (car (entsel mensaje)))
        (cond
          ((null ent) nil) ; Presionó Enter - retorna nil
          ((not (wcmatch (cdr (assoc 0 (entget ent))) "TEXT,MTEXT"))
           (princ "\nError: No es texto. Seleccione un texto.")
           t) ; Repetir ciclo
          (t nil) ; Es texto - salir del ciclo
        )
      )
    )
    ent
  )
  
  (setq old_cmdecho (getvar "CMDECHO"))
  (setvar "CMDECHO" 0)
  
  (princ "\nACTUALIZAR COORDENADAS EN TEXTOS (COR)")
  
  (initget "2 3 4")
  (setq decimales (getint "\nDecimales [2/3/4] <3>: "))
  (if (not decimales) (setq decimales 3))
  
  (initget "Si No")
  (setq con_prefijo (getkword "\nPrefijo X=, Y=, Z=? [Si/No] <Si>: "))
  (setq con_prefijo (if (or (null con_prefijo) (= con_prefijo "Si")) T nil))
  
  (if (setq PuntoCoordenada (getpoint "\nPunto para coordenada: "))
    (progn
      (setq Este (rtos (car PuntoCoordenada) 2 decimales))
      (setq Norte (rtos (cadr PuntoCoordenada) 2 decimales))
      (setq Cota (rtos (caddr PuntoCoordenada) 2 decimales))
      
      (princ (strcat "\nCoordenadas: X=" Este " Y=" Norte " Z=" Cota))
      
      (if (setq entSupE (seleccionar-texto "\nTexto para Este (X) <Enter omite>: "))
        (progn
          (vla-put-TextString (vlax-ename->vla-object entSupE)
            (if con_prefijo (strcat "X=" Este) Este))
          (princ " ✓ Este actualizado.")
        )
        (princ " - Este omitido.")
      )
      
      (if (setq entSupN (seleccionar-texto "\nTexto para Norte (Y) <Enter omite>: "))
        (progn
          (vla-put-TextString (vlax-ename->vla-object entSupN)
            (if con_prefijo (strcat "Y=" Norte) Norte))
          (princ " ✓ Norte actualizado.")
        )
        (princ " - Norte omitido.")
      )
      
      (if (setq entSupZ (seleccionar-texto "\nTexto para Cota (Z) <Enter omite>: "))
        (progn
          (vla-put-TextString (vlax-ename->vla-object entSupZ)
            (if con_prefijo (strcat "Z=" Cota) Cota))
          (princ " ✓ Cota actualizada.")
        )
        (princ " - Cota omitida.")
      )
      
      (princ "\n✓ Proceso completado.")
    )
    (princ "\n✗ Operación cancelada.")
  )
  
  (setvar "CMDECHO" old_cmdecho)
  (princ)
)

;; Version rapida mejorada
(defun c:COR2 (/ pt x y z txt ent data tipo)
  (vl-load-com)
  
  (princ "\nCOR2 - Version rapida (3 decimales, con prefijo)")
  
  (if (setq pt (getpoint "\nPunto para coordenadas: "))
    (progn
      (setq x (rtos (car pt) 2 3))
      (setq y (rtos (cadr pt) 2 3))
      (setq z (rtos (caddr pt) 2 3))
      
      (princ "\nSeleccione textos para X, Y, Z (Enter para omitir):")
      
      (if (setq ent (car (entsel "\nTexto para X: ")))
        (progn
          (setq data (entget ent)
                tipo (cdr (assoc 0 data)))
          (if (wcmatch tipo "TEXT,MTEXT")
            (vla-put-TextString (vlax-ename->vla-object ent) (strcat "X=" x))
            (princ "\n✗ No es texto. X omitido.")
          )
        )
      )
      
      (if (setq ent (car (entsel "\nTexto para Y: ")))
        (progn
          (setq data (entget ent)
                tipo (cdr (assoc 0 data)))
          (if (wcmatch tipo "TEXT,MTEXT")
            (vla-put-TextString (vlax-ename->vla-object ent) (strcat "Y=" y))
            (princ "\n✗ No es texto. Y omitido.")
          )
        )
      )
      
      (if (setq ent (car (entsel "\nTexto para Z: ")))
        (progn
          (setq data (entget ent)
                tipo (cdr (assoc 0 data)))
          (if (wcmatch tipo "TEXT,MTEXT")
            (vla-put-TextString (vlax-ename->vla-object ent) (strcat "Z=" z))
            (princ "\n✗ No es texto. Z omitido.")
          )
        )
      )
      
      (princ "\n✓ Coordenadas actualizadas.")
    )
    (princ "\n✗ Cancelado.")
  )
  (princ)
)

;; Version completamente automatica - asume textos en orden
(defun c:CORA (/ pt x y z ss i ent)
  (vl-load-com)
  
  (princ "\nCORA - Version automatica (selecciona 3 textos)")
  
  (if (and (setq pt (getpoint "\nPunto para coordenadas: "))
           (setq ss (ssget '((0 . "TEXT,MTEXT")))))
    (progn
      (setq x (rtos (car pt) 2 3))
      (setq y (rtos (cadr pt) 2 3))
      (setq z (rtos (caddr pt) 2 3))
      
      (cond
        ((>= (sslength ss) 3)
         (vla-put-TextString (vlax-ename->vla-object (ssname ss 0)) (strcat "X=" x))
         (vla-put-TextString (vlax-ename->vla-object (ssname ss 1)) (strcat "Y=" y))
         (vla-put-TextString (vlax-ename->vla-object (ssname ss 2)) (strcat "Z=" z))
         (princ "\n✓ 3 textos actualizados automáticamente.")
        )
        (t
         (princ "\n✗ Seleccione al menos 3 textos.")
        )
      )
    )
    (princ "\n✗ Cancelado o no hay textos seleccionados.")
  )
  (princ)
)

(princ "\nComandos cargados: COR (completo), COR2 (rápido), CORA (automático)")
(princ)