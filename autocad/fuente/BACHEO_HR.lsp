;;; =====================================================================
;;;  HR - Sombreado de baches (MemoPRO)
;;;  Sin preguntas: a TODOS los rectángulos de la capa
;;;  GEOMETRIA_RECTANGULOS les pone un sombreado SÓLIDO con 70 % de
;;;  transparencia, en la capa SOMBREADOS_RECTANGULOS.
;;;  Si se vuelve a ejecutar, primero borra los sombreados que HR había
;;;  puesto antes (ya no se duplican).
;;;  Si hay objetos preseleccionados, sólo sombrea esos.
;;; =====================================================================
(setq hr:*capa* "SOMBREADOS_RECTANGULOS")
(setq hr:*transparencia* 70)

(defun hr:espacio (obj / r)
  ;; Espacio (modelo o layout) donde está el rectángulo
  (setq r (vl-catch-all-apply 'vla-ObjectIdToObject
            (list (vla-get-Document obj) (vla-get-OwnerID obj))))
  (if (vl-catch-all-error-p r)
    (vla-get-ModelSpace (vla-get-ActiveDocument (vlax-get-acad-object)))
    r))

(defun hr:sombrear (ent / obj h arr r)
  (setq obj (vlax-ename->vla-object ent))
  (setq r (vl-catch-all-apply
    '(lambda ()
       (setq h (vla-AddHatch (hr:espacio obj) acHatchPatternTypePreDefined "SOLID" :vlax-true))
       (setq arr (vlax-make-safearray vlax-vbObject '(0 . 0)))
       (vlax-safearray-put-element arr 0 obj)
       (vla-AppendOuterLoop h arr)
       (vla-put-Layer h hr:*capa*)
       (vla-Evaluate h)
       (vl-catch-all-apply 'vla-put-EntityTransparency (list h (itoa hr:*transparencia*))))))
  (if (vl-catch-all-error-p r)
    (progn (if h (vl-catch-all-apply 'vla-Delete (list h))) nil)
    T))

(defun c:HR (/ ss previos i ent n mal)
  ;; capa del sombreado
  (if (not (tblsearch "LAYER" hr:*capa*))
    (entmake (list '(0 . "LAYER") '(100 . "AcDbSymbolTableRecord") '(100 . "AcDbLayerTableRecord")
                   (cons 2 hr:*capa*) '(70 . 0) '(62 . 10) '(6 . "Continuous"))))
  ;; rectángulos: los preseleccionados o todos los de la capa
  (setq ss (ssget "_I" '((0 . "LWPOLYLINE,POLYLINE") (8 . "GEOMETRIA_RECTANGULOS"))))
  (if (not ss)
    (progn
      (setq ss (ssget "_X" '((0 . "LWPOLYLINE,POLYLINE") (8 . "GEOMETRIA_RECTANGULOS"))))
      ;; sombreados anteriores de HR: se reemplazan
      (if (setq previos (ssget "_X" (list '(0 . "HATCH") (cons 8 hr:*capa*))))
        (progn
          (setq i 0)
          (repeat (sslength previos) (entdel (ssname previos i)) (setq i (1+ i)))
          (princ (strcat "\nSe reemplazan " (itoa i) " sombreado(s) anteriores."))))))
  (if (not ss)
    (princ "\nNo hay rectángulos en la capa GEOMETRIA_RECTANGULOS.")
    (progn
      (setq i 0 n 0 mal 0)
      (repeat (sslength ss)
        (setq ent (ssname ss i) i (1+ i))
        (if (hr:sombrear ent) (setq n (1+ n)) (setq mal (1+ mal))))
      (princ (strcat "\nSombreado sólido al " (itoa hr:*transparencia*) "% de transparencia: "
                     (itoa n) " bache(s)"
                     (if (> mal 0) (strcat ", " (itoa mal) " no se pudieron (¿polilínea abierta?)") "")
                     "."))))
  (princ))
