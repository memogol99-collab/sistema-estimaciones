;;; MEMO SISTEMA 2.1.1 - archivo generado por construir_bundle.py
;;; Origen: LISP_Topografia/Exportar_Coord_POL ( X-Y ).lsp
;;; Parches aplicados: getfiled-c

;;; ============================================================
;;; exportar_coordenadas.lsp
;;; Rutina LISP para AutoCAD
;;; Exporta las coordenadas X Y de un poligono (LWPOLYLINE)
;;; a un archivo .txt separado por tabulacion.
;;; ============================================================
;;; Uso: Cargar el archivo en AutoCAD y ejecutar el comando EXPORCOOR
;;; ============================================================

(defun c:X-Y ( / sel ent obj coords coordX coordY fname archivo n lista)
  (vl-load-com)

  ;; --- Seleccionar el poligono ---
  (prompt "\nSeleccione un poligono (LWPOLYLINE): ")
  (setq sel (entsel "\nSeleccione un poligono (LWPOLYLINE): "))

  (if (not sel)
    (progn
      (prompt "\nNo se selecciono ningun objeto.")
      (princ)
      (exit)
    )
  )

  (setq ent (car sel))

  ;; --- Verificar que sea una LWPOLYLINE ---
  (if (not (and (= (type ent) 'ENAME)
               (= (cdr (assoc 0 (entget ent))) "LWPOLYLINE")))
    (progn
      (prompt "\nEl objeto seleccionado no es una polilinea (LWPOLYLINE).")
      (prompt "\nPor favor seleccione un poligono valido.")
      (princ)
      (exit)
    )
  )

  ;; --- Obtener el objeto via ActiveX ---
  (setq obj (vlax-ename->vla-object ent))

  ;; --- Extraer coordenadas con vla-get-coordinates ---
  (setq coords (vlax-safearray->list
                  (vlax-variant-value
                    (vla-get-coordinates obj))))

  ;; --- Pedir nombre de archivo ---
  (setq fname (getfiled "Guardar coordenadas como" (getvar "DWGPREFIX") "txt" 1))

  (if (not fname)
    (progn
      (prompt "\nOperacion cancelada por el usuario.")
      (princ)
      (exit)
    )
  )

  ;; --- Abrir archivo y escribir coordenadas ---
  (setq archivo (open fname "w"))

  ;; Iterar sobre las coordenadas (lista plana: X Y X Y X Y ...)
  (setq n 0)
  (while (< n (length coords))
    (setq coordX (rtos (nth n coords) 2 3))
    (setq coordY (rtos (nth (1+ n) coords) 2 3))
    (write-line (strcat coordX "\t" coordY) archivo)
    (setq n (+ n 2))
  )

  (close archivo)

  ;; --- Resumen ---
  (prompt (strcat "\nCoordenadas exportadas correctamente.\n"
                   "Archivo: " fname "\n"
                   "Total de vertices: " (itoa (/ (length coords) 2)) "\n"))

  (princ)
)

(princ "\n=== Rutina cargada. Ejecute EXPORCOOR para comenzar. ===")
(princ)
