;;; MEMO SISTEMA 2.1.1 - archivo generado por construir_bundle.py
;;; Origen: LISP_Textos/Rot-Text ( RTT ).lsp

(Defun C:RTT ( / sel i value minExt maxExt pt_mid)

;;Rutina realizada por Nospherathus © Jul, 2013 

  (prompt "\n-Seleccione el texto a rotar: ")

  (setq sel (ssget '((0 . "TEXT,Mtext")) ))

  (while (null sel)

    (prompt "\n-Seleccione el texto a rotar: ")

    (setq sel (ssget '((0 . "TEXT,Mtext")) ))

    )

  (setq i 0)

  ;(setq value (getreal "ingrese el angulo de rotacion del objeto: "))

  (setq value 180)

  (repeat (sslength sel)

    (setq obj

      (vlax-ename->vla-object

   (ssname sel i)

   ) )

    (vla-GetBoundingBox obj 'minExt 'maxExt)
    
    (setq minExt (vlax-safearray->list minExt))
    
    (setq maxExt (vlax-safearray->list maxExt))
    
    (setq pt_mid (list
         
         (/ (+(nth 0 minExt) (nth 0 maxExt)) 2)
         
         (/ (+(nth 1 minExt) (nth 1 maxExt)) 2)
         
         (nth 2 minExt)

         ))

    (vla-Rotate obj (vlax-3d-point pt_mid) (* PI(/ value 180.0)))

    (setq i (+ i 1))

    )

  (terpri)

  (vl-princ-to-string

    (strcat

      (rtos (sslength sel) 2 0)

      " textos seleccionados han sido rotatos <- 180 degree ->")

    )

  )
