;;; MEMO SISTEMA 2.0.0 - archivo generado por construir_bundle.py
;;; Origen: LISP_Estimaciones/ExportaRectangulos ( EXR ).lsp

;;; ============================================================================
;;; EXPORTARECTANGULOS.LSP - v5.0 SIN PYTHON
;;; Exporta baches a CSV: 6 columnas, 22 filas por grupo, 3 grupos por bloque
;;; ============================================================================
;;; Columnas por grupo: Numero, Largo, Ancho, Area, Volumen, Acumulado
;;; Area = Largo * Ancho  |  Volumen = Area * 0.10
;;; Acumulado = suma corrida de Volumen (continua entre grupos)
;;; 3 grupos maximos por bloque horizontal; si hay mas, se agregan abajo
;;; SIN DEPENDENCIAS EXTERNAS
;;; ============================================================================

(vl-load-com)
(setq *rectangulos-lista* '())

;;; ============================================================================
;;; FUNCIÓN: numero-a-string
;;; Convierte numero a string con PUNTO decimal y 2 decimales
;;; ============================================================================
(defun numero-a-string (num / entero decimal str-ent str-dec)
  (setq entero (fix num))
  (setq decimal (- num entero))
  (if (< entero 0)
    (progn
      (setq entero (abs entero))
      (setq decimal (- (abs num) entero))
      (setq str-ent (strcat "-" (itoa entero)))
    )
    (setq str-ent (itoa entero))
  )
  (setq decimal (fix (+ (* (abs decimal) 100) 0.5)))
  (if (= decimal 100)
    (progn
      (setq decimal 0)
      (if (= (substr str-ent 1 1) "-")
        (setq str-ent (strcat "-" (itoa (1+ (atoi (substr str-ent 2))))))
        (setq str-ent (itoa (1+ (atoi str-ent))))
      )
    )
  )
  (setq str-dec (itoa decimal))
  (if (< decimal 10)
    (setq str-dec (strcat "0" str-dec))
  )
  (strcat str-ent "." str-dec)
)

;;; ============================================================================
;;; FUNCIÓN: redondear-2-decimales
;;; ============================================================================
(defun redondear-2-decimales (numero)
  (* (atoi (rtos (* numero 100) 2 0)) 0.01)
)

;;; ============================================================================
;;; FUNCIÓN: obtener-datos-rectangulo
;;; Extrae XDATA: retorna (numero largo ancho area perimetro)
;;; ============================================================================
(defun obtener-datos-rectangulo (ent / xdata datos num largo ancho area perimetro)
  (setq xdata (entget ent '("RECTANGULOS_APP")))
  (if (assoc -3 xdata)
    (progn
      (setq datos (cdr (assoc -3 xdata)))
      (setq datos (car datos))
      (setq datos (cdr datos))
      (setq num (atoi (cdr (assoc 1000 datos))))
      (setq largo (cdr (assoc 1040 datos)))
      (setq datos (cdr (member (assoc 1040 datos) datos)))
      (setq ancho (cdr (assoc 1040 datos)))
      (setq area (* largo ancho))
      (setq perimetro (* 2 (+ largo ancho)))
      (list num largo ancho area perimetro)
    )
    nil
  )
)

;;; ============================================================================
;;; FUNCIÓN: obtener-rectangulos-seleccion
;;; ============================================================================
(defun obtener-rectangulos-seleccion (/ ss)
  (princ "\n+--------------------------------------------------------------+")
  (princ "\n|       SELECCION DE RECTANGULOS                               |")
  (princ "\n|  Dibuje ventana de seleccion o Enter para TODOS              |")
  (princ "\n+--------------------------------------------------------------+")
  (princ "\n")
  (setq ss (ssget '((8 . "GEOMETRIA_RECTANGULOS"))))
  ss
)

;;; ============================================================================
;;; FUNCIÓN: reconstruir-lista-desde-seleccion
;;; ============================================================================
(defun reconstruir-lista-desde-seleccion (ss / i ent datos contador)
  (setq *rectangulos-lista* '())
  (setq contador 0)
  (if ss
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq ent (ssname ss i))
        (setq datos (obtener-datos-rectangulo ent))
        (if datos
          (progn
            (setq *rectangulos-lista* 
                  (append *rectangulos-lista* (list datos)))
            (setq contador (1+ contador))
          )
        )
        (setq i (1+ i))
      )
      (setq *rectangulos-lista* 
            (vl-sort *rectangulos-lista* 
                    '(lambda (a b) (< (car a) (car b)))))
      (princ (strcat "\n> " (itoa contador) " rectangulos procesados."))
    )
    (princ "\n> No se encontraron rectangulos.")
  )
  (princ)
)

;;; ============================================================================
;;; FUNCIÓN: exr-lista-a-csv
;;; Convierte una lista de campos (strings o nil) a una linea CSV
;;; nil se convierte en campo vacio
;;; ============================================================================
(defun exr-lista-a-csv (campos / linea i val)
  (setq linea "")
  (setq i 0)
  (while (< i (length campos))
    (if (> i 0)
      (setq linea (strcat linea ","))
    )
    (setq val (nth i campos))
    (if val
      (setq linea (strcat linea val))
    )
    (setq i (1+ i))
  )
  linea
)

;;; ============================================================================
;;; FUNCIÓN: exr-generar-csv
;;; Genera CSV con:
;;;   - 6 columnas por grupo: Numero,Largo,Ancho,Area,Volumen,Acumulado
;;;   - 1 columna vacia separadora entre grupos
;;;   - 22 filas de datos por grupo
;;;   - Fila Suma por grupo (suma de Area y Volumen)
;;;   - Maximo 3 grupos por bloque horizontal
;;;   - Si hay mas de 3 grupos, se agregan bloques abajo con filas separador
;;;   - Acumulado es continuo entre todos los grupos
;;; ============================================================================
(defun exr-generar-csv (ruta-salida / 
                                archivo rect num largo ancho area volumen
                                n-baches num-grupos datos-procesados
                                acumulado g grupos-en-bloque
                                fila lg gg datos-idx d
                                campos linea
                                g-start g-end g-area g-vol last-acum
                                hay-mas-bloques)

  (setq n-baches (length *rectangulos-lista*))

  ;; ========================================================================
  ;; PRE-CALCULAR datos con Acumulado continuo
  ;; Cada bache: (num largo ancho area volumen acumulado)
  ;; ========================================================================
  (setq datos-procesados '())
  (setq acumulado 0.0)
  (foreach rect *rectangulos-lista*
    (setq num   (car   rect))
    (setq largo (cadr  rect))
    (setq ancho (caddr rect))
    (setq area  (redondear-2-decimales (* largo ancho)))
    (setq volumen (redondear-2-decimales (* area 0.10)))
    (setq acumulado (redondear-2-decimales (+ acumulado volumen)))
    (setq datos-procesados 
          (append datos-procesados 
                  (list (list num largo ancho area volumen acumulado))))
  )

  ;; Numero de grupos (22 baches c/u)
  (setq num-grupos (/ (+ n-baches 21) 22))

  ;; ========================================================================
  ;; ABRIR ARCHIVO
  ;; ========================================================================
  (setq archivo (open ruta-salida "w"))
  (if (not archivo)
    (progn
      (princ (strcat "\n> ERROR: No se pudo crear el archivo."))
      nil
    )
    (progn
      ;; ==================================================================
      ;; RECORRER BLOQUES (3 grupos max por bloque)
      ;; ==================================================================
      (setq g 0)
      (while (< g num-grupos)
        (setq grupos-en-bloque (min 3 (- num-grupos g)))
        (setq hay-mas-bloques (< (+ g grupos-en-bloque) num-grupos))

        ;; ==============================================================
        ;; ENCABEZADO
        ;; ==============================================================
        (setq campos nil)
        (setq lg 0)
        (while (< lg grupos-en-bloque)
          (if (> lg 0)
            (setq campos (append campos (list nil)))  ;; columna separadora
          )
          (setq campos (append campos 
                    (list "Numero" "Largo" "Ancho" "Area" "Volumen" "Acumulado")))
          (setq lg (1+ lg))
        )
        (write-line (exr-lista-a-csv campos) archivo)

        ;; ==============================================================
        ;; 22 FILAS DE DATOS
        ;; ==============================================================
        (setq fila 0)
        (while (< fila 22)
          (setq campos nil)
          (setq lg 0)
          (while (< lg grupos-en-bloque)
            ;; Columna separadora entre grupos
            (if (> lg 0)
              (setq campos (append campos (list nil)))
            )

            ;; Indice global del grupo
            (setq gg (+ g lg))
            ;; Indice del bache en la lista procesada
            (setq datos-idx (+ (* gg 22) fila))

            (if (< datos-idx n-baches)
              ;; Hay bache para esta posicion
              (progn
                (setq d (nth datos-idx datos-procesados))
                (setq campos (append campos
                  (list (itoa (nth 0 d))
                        (numero-a-string (nth 1 d))
                        (numero-a-string (nth 2 d))
                        (numero-a-string (nth 3 d))
                        (numero-a-string (nth 4 d))
                        (numero-a-string (nth 5 d)))))
              )
              ;; Sin bache: 6 campos vacios
              (setq campos (append campos '(nil nil nil nil nil nil)))
            )
            (setq lg (1+ lg))
          )
          (write-line (exr-lista-a-csv campos) archivo)
          (setq fila (1+ fila))
        )

        ;; ==============================================================
        ;; FILA SUMA (una por grupo en el bloque)
        ;; ==============================================================
        (setq campos nil)
        (setq lg 0)
        (while (< lg grupos-en-bloque)
          (if (> lg 0)
            (setq campos (append campos (list nil)))
          )

          (setq gg (+ g lg))
          (setq g-start (* gg 22))
          (setq g-end (min (+ g-start 22) n-baches))

          (if (> g-end g-start)
            ;; Grupo con datos: calcular sumas
            (progn
              (setq g-area 0.0)
              (setq g-vol 0.0)
              (setq i g-start)
              (while (< i g-end)
                (setq g-area (+ g-area (nth 3 (nth i datos-procesados))))
                (setq g-vol (+ g-vol (nth 4 (nth i datos-procesados))))
                (setq i (1+ i))
              )
              ;; Ultimo acumulado de este grupo
              (setq last-acum (nth 5 (nth (1- g-end) datos-procesados)))
              (setq campos (append campos
                (list nil
                      nil
                      "Suma"
                      (numero-a-string (redondear-2-decimales g-area))
                      (numero-a-string (redondear-2-decimales g-vol))
                      (numero-a-string (redondear-2-decimales last-acum)))))
            )
            ;; Grupo sin datos
            (setq campos (append campos '(nil nil nil nil nil nil)))
          )
          (setq lg (1+ lg))
        )
        (write-line (exr-lista-a-csv campos) archivo)

        ;; ==============================================================
        ;; FILAS SEPARADORAS si hay mas bloques abajo
        ;; ==============================================================
        (if hay-mas-bloques
          (progn
            (write-line "" archivo)
            (write-line "" archivo)
          )
        )

        (setq g (+ g grupos-en-bloque))
      )

      (close archivo)
      T
    )
  )
)

;;; ============================================================================
;;; COMANDO: EXR
;;; ============================================================================
(defun c:EXR (/ ss archivo-salida resultado total-area rect contador
                  nombre-default dir-default)

  (princ "\n")
  (princ "\n+--------------------------------------------------------------+")
  (princ "\n|       EXPORTARECTANGULOS v5.0 - SIN PYTHON                    |")
  (princ "\n+--------------------------------------------------------------+")

  (setq ss (obtener-rectangulos-seleccion))

  (if (not ss)
    (progn
      (princ "\n> No se seleccionaron rectangulos.")
      (princ)
    )
    (progn
      (princ "\nProcesando rectangulos...")
      (reconstruir-lista-desde-seleccion ss)

      (if (not *rectangulos-lista*)
        (progn
          (princ "\n> Los rectangulos no tienen datos validos.")
          (princ "\n  Deben ser creados con el comando RS.")
          (princ)
        )
        (progn
          (setq total-area 0)
          (foreach rect *rectangulos-lista*
            (setq total-area (+ total-area (cadddr rect)))
          )
          (princ (strcat "\n> Baches: " (itoa (length *rectangulos-lista*))
                         "  |  Area total: " (rtos total-area 2 2) " m2"))
          (princ (strcat "\n  Grupos: " 
                         (itoa (/ (+ (length *rectangulos-lista*) 21) 22))
                         " (22 baches c/u, 3 grupos por bloque)"))

          (setq dir-default (getvar "DWGPREFIX"))
          (setq nombre-default (strcat dir-default "Baches_Exportados.csv"))

          (princ "\n")
          (setq archivo-salida (getfiled 
                                 "Guardar archivo CSV" 
                                 nombre-default 
                                 "csv" 
                                 1))

          (if (not archivo-salida)
            (progn
              (princ "\n> Exportacion cancelada.")
              (princ)
            )
            (progn
              (princ "\nGenerando CSV...")
              (setq resultado (exr-generar-csv archivo-salida))

              (if resultado
                (progn
                  (princ "\n")
                  (princ "\n------------------------------------------------------------")
                  (princ "\n> EXPORTACION COMPLETADA")
                  (princ (strcat "\n  * Baches: " (itoa (length *rectangulos-lista*))))
                  (princ (strcat "\n  * Archivo: " archivo-salida))
                  (princ "\n  * Formato: CSV (abrir con Excel)")
                  (princ "\n------------------------------------------------------------")
                )
                (princ "\n> Error al generar el archivo.")
              )
            )
          )
        )
      )
    )
  )
  (princ)
)

;;; ============================================================================
;;; COMANDO: VERLISTA
;;; ============================================================================
(defun c:VERLISTA (/ rect total-area total-perimetro)
  (princ "\n*** LISTA DE RECTANGULOS ***")
  (if (not *rectangulos-lista*)
    (princ "\nNo hay rectangulos en la lista.")
    (progn
      (setq total-area 0)
      (setq total-perimetro 0)
      (princ (strcat "\nTotal: " (itoa (length *rectangulos-lista*))))
      (princ "\n+--------+---------+---------+----------+-----------+")
      (princ "\n| Numero |  Largo  |  Ancho  |   Area   | Perimetro |")
      (princ "\n+--------+---------+---------+----------+-----------+")
      (foreach rect *rectangulos-lista*
        (princ (strcat "\n|  " (itoa (car rect)) 
                      (if (< (car rect) 10) "    " (if (< (car rect) 100) "   " "  "))
                      "| " (rtos (cadr rect) 2 2) "  "
                      "| " (rtos (caddr rect) 2 2) "  "
                      "| " (rtos (cadddr rect) 2 2) "  "
                      "| " (rtos (nth 4 rect) 2 2) "   |"))
        (setq total-area (+ total-area (cadddr rect)))
        (setq total-perimetro (+ total-perimetro (nth 4 rect)))
      )
      (princ "\n+--------+---------+---------+----------+-----------+")
      (princ (strcat "\n| TOTAL  |         |         | " (rtos total-area 2 2) "  | " (rtos total-perimetro 2 2) "   |"))
      (princ "\n+---------------------------------------------------+")
    )
  )
  (princ)
)

;;; ============================================================================
;;; COMANDO: VERXDATA
;;; ============================================================================
(defun c:VERXDATA (/ ss i ent datos)
  (princ "\n*** VER XDATA ***")
  (princ "\nSeleccione rectangulos: ")
  (setq ss (ssget '((8 . "GEOMETRIA_RECTANGULOS"))))
  (if (not ss)
    (princ "\nNo seleccionados.")
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq ent (ssname ss i))
        (setq datos (obtener-datos-rectangulo ent))
        (princ (strcat "\n=== Rectangulo " (itoa (1+ i)) " ==="))
        (if datos
          (progn
            (princ (strcat "\n  Numero:    " (itoa (car datos))))
            (princ (strcat "\n  Largo:     " (rtos (cadr datos) 2 2) " m"))
            (princ (strcat "\n  Ancho:     " (rtos (caddr datos) 2 2) " m"))
            (princ (strcat "\n  Area:      " (rtos (cadddr datos) 2 2) " m2"))
          )
          (princ "\n  > SIN XDATA")
        )
        (setq i (1+ i))
      )
    )
  )
  (princ)
)

;;; ============================================================================
;;; COMANDO: AXD - Asignar XDATA
;;; ============================================================================
(defun c:AXD (/ ss i ent numero largo ancho regapp-name xdata ent-data)
  (princ "\n> Seleccione rectangulos: ")
  (setq ss (ssget '((8 . "GEOMETRIA_RECTANGULOS"))))
  (if (not ss)
    (princ "\nNo seleccionados.")
    (progn
      (setq regapp-name "RECTANGULOS_APP")
      (if (not (tblsearch "APPID" regapp-name)) (regapp regapp-name))
      (setq i 0)
      (repeat (sslength ss)
        (setq ent (ssname ss i))
        (setq ent-data (entget ent))
        (if (not (assoc -3 (entget ent (list regapp-name))))
          (progn
            (princ (strcat "\n--- Rectangulo " (itoa (1+ i)) " ---"))
            (setq numero (getint "\nNumero: "))
            (if numero
              (progn
                (setq largo (getreal "\nLargo (m): "))
                (if largo
                  (progn
                    (setq ancho (getreal "\nAncho (m): "))
                    (if ancho
                      (progn
                        (setq xdata (list -3 
                                          (list regapp-name
                                                (cons 1000 (itoa numero))
                                                (cons 1040 (float largo))
                                                (cons 1040 (float ancho)))))
                        (setq ent-data (entget ent))
                        (setq ent-data (append ent-data (list xdata)))
                        (entmod ent-data)
                        (princ " > OK")
                      )
                    )
                  )
                )
              )
            )
          )
          (princ (strcat "\nRectangulo " (itoa (1+ i)) " ya tiene XDATA."))
        )
        (setq i (1+ i))
      )
      (princ (strcat "\n> " (itoa i) " procesados."))
    )
  )
  (princ)
)

;;; ============================================================================
;;; MENSAJE DE CARGA
;;; ============================================================================
(princ "\n+--------------------------------------------------------------+")
(princ "\n|       EXPORTARECTANGULOS v5.0 - Cargado                      |")
(princ "\n|  EXR      - Exportar baches a CSV (sin Python)                |")
(princ "\n|  VERLISTA - Ver lista en memoria                              |")
(princ "\n|  VERXDATA - Ver XDATA de rectangulos                          |")
(princ "\n|  AXD      - Asignar XDATA a rectangulos                       |")
(princ "\n|  3 grupos por bloque | 22 baches por grupo                   |")
(princ "\n|  Mas de 3 grupos = se agregan abajo                           |")
(princ "\n+--------------------------------------------------------------+")
(princ "\n")
(princ)