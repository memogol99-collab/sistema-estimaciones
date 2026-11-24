;;; ========================================================================
;;; ARCHIVO: Procesa-XYZ.lsp
;;; VERSION: 8.5 - Recoger valores dentro de action_tile antes de done_dialog
;;; ========================================================================

(vl-load-com)

;;; Guardar ruta del LSP al cargar
(setq *pz:lsp-dir* nil)
(setq *pz:tmp-ff* (findfile "Procesa-XYZ.lsp"))
(if *pz:tmp-ff*
  (setq *pz:lsp-dir* (vl-filename-directory *pz:tmp-ff*))
  (progn
    (setq *pz:tmp-ff* (findfile "Procesa-XYZ.dcl"))
    (if *pz:tmp-ff*
      (setq *pz:lsp-dir* (vl-filename-directory *pz:tmp-ff*))
    )
  )
)
(setq *pz:tmp-ff* nil)

;; ----------------------------------------------------------------
;; FUNCIONES AUXILIARES
;; ----------------------------------------------------------------

(defun split-campos (cadena / pos lista temporal pos-space pos-tab)
  (setq cadena (vl-string-trim " \t" cadena))
  (if (= cadena "")
    '()
    (progn
      (setq lista '())
      (while (and (> (strlen cadena) 0)
                  (progn
                    (setq pos-space (vl-string-search " " cadena))
                    (setq pos-tab (vl-string-search "\t" cadena))
                    (cond
                      ((and pos-space pos-tab)
                        (setq pos (min pos-space pos-tab)))
                      (pos-space (setq pos pos-space))
                      (pos-tab (setq pos pos-tab))
                      (T nil)
                    )
                  ))
        (if (= pos 0)
          (setq cadena (substr cadena 2))
          (progn
            (setq temporal (vl-string-trim " \t" (substr cadena 1 pos)))
            (if (/= temporal "")
              (setq lista (cons temporal lista))
            )
            (setq cadena (substr cadena (+ pos 1)))
          )
        )
      )
      (reverse lista)
    )
  )
)

(defun unir-campos (lista sep / resultado i)
  (setq resultado "")
  (setq i 0)
  (foreach campo lista
    (if (> i 0)
      (setq resultado (strcat resultado sep))
    )
    (setq resultado (strcat resultado campo))
    (setq i (1+ i))
  )
  resultado
)

(defun cadena-a-real (cadena / val)
  (setq cadena (vl-string-trim " \t" cadena))
  (setq val (distof cadena))
  (if val val nil)
)

(defun reemplazar-indice (lista indice nuevo-val / nueva i)
  (setq nueva '())
  (setq i 0)
  (foreach elem lista
    (if (= i indice)
      (setq nueva (cons nuevo-val nueva))
      (setq nueva (cons elem nueva))
    )
    (setq i (1+ i))
  )
  (reverse nueva)
)

(defun formatear-numero (numero decimales / fmt-str)
  (if (not decimales) (setq decimales 3))
  (if numero
    (rtos numero 2 decimales)
    "0.000"
  )
)

(defun detectar-formato (cadena / pos-punto num-dec)
  (setq pos-punto (vl-string-search "." cadena))
  (if pos-punto
    (progn
      (setq num-dec (- (strlen cadena) pos-punto 1))
      (if (> num-dec 6) (setq num-dec 6))
      (if (< num-dec 0) (setq num-dec 0))
      num-dec
    )
    3
  )
)

(defun calcular-desviacion (suma sum-cuad n / media varianza)
  (if (and n (> n 0))
    (progn
      (setq media (/ suma n))
      (setq varianza (- (/ sum-cuad n) (* media media)))
      (if (< varianza 0.0) (setq varianza 0.0))
      (sqrt varianza)
    )
    0.0
  )
)

(defun pz-split-rangos (cadena / pos lista temp)
  (setq lista '())
  (while (setq pos (vl-string-search ";" cadena))
    (setq temp (vl-string-trim " \t" (substr cadena 1 pos)))
    (if (/= temp "")
      (setq lista (cons temp lista))
    )
    (setq cadena (substr cadena (+ pos 1)))
  )
  (setq temp (vl-string-trim " \t" cadena))
  (if (/= temp "")
    (setq lista (cons temp lista))
  )
  (reverse lista)
)

(defun pz-parse-rango (rango-str / partes zmin zmax ajuste)
  (setq partes (split-campos rango-str))
  (if (>= (length partes) 3)
    (progn
      (setq zmin (distof (nth 0 partes)))
      (setq zmax (distof (nth 1 partes)))
      (setq ajuste (distof (nth 2 partes)))
      (if (and zmin zmax ajuste)
        (list zmin zmax ajuste)
        nil
      )
    )
    nil
  )
)

(defun pz-analizar-archivo (ruta / fh linea datos count min-z max-z sum-z sum-cuad primer-z z-val)
  (setq fh (open ruta "r"))
  (setq count 0 min-z 1E308 max-z -1E308 sum-z 0.0 sum-cuad 0.0 primer-z nil)
  (while (setq linea (read-line fh))
    (setq datos (split-campos linea))
    (if (>= (length datos) 3)
      (progn
        (setq z-val (cadena-a-real (nth 2 datos)))
        (if z-val
          (progn
            (setq count (1+ count))
            (if (< z-val min-z) (setq min-z z-val))
            (if (> z-val max-z) (setq max-z z-val))
            (setq sum-z (+ sum-z z-val))
            (setq sum-cuad (+ sum-cuad (* z-val z-val)))
            (if (not primer-z) (setq primer-z (nth 2 datos)))
          )
        )
      )
    )
  )
  (close fh)
  (list count min-z max-z sum-z sum-cuad primer-z)
)

;; ----------------------------------------------------------------
;; BUSCAR DCL
;; ----------------------------------------------------------------

(defun pz-buscar-dcl ( / ruta-dcl)
  (princ "\n>>> buscando DCL...")
  (setq ruta-dcl nil)
  (if *pz:lsp-dir*
    (progn
      (setq ruta-dcl (strcat *pz:lsp-dir* "Procesa-XYZ.dcl"))
      (if (not (vl-file-size ruta-dcl))
        (setq ruta-dcl nil)
      )
    )
  )
  (if (not ruta-dcl)
    (setq ruta-dcl (findfile "Procesa-XYZ.dcl"))
  )
  (if (not ruta-dcl)
    (progn
      (setq ruta-dcl (strcat (getvar "dwgprefix") "Procesa-XYZ.dcl"))
      (if (not (vl-file-size ruta-dcl))
        (setq ruta-dcl nil)
      )
    )
  )
  (if (not ruta-dcl)
    (setq ruta-dcl (getfiled "Seleccionar Procesa-XYZ.dcl" "" "dcl" 0))
  )
  (if ruta-dcl
    (progn
      (princ (strcat "\n>>> DCL: " ruta-dcl))
      ruta-dcl
    )
    nil
  )
)

;; ----------------------------------------------------------------
;; HABILITAR PARAMETROS
;; ----------------------------------------------------------------

(defun pz-habilitar-parametros (modo-str / modo)
  (setq modo (atoi modo-str))
  (mode_tile "lbl_p1" 1) (mode_tile "p1_desplaz" 1)
  (mode_tile "lbl_p2" 1) (mode_tile "p2_rangos" 1)
  (mode_tile "lbl_p3" 1) (mode_tile "p3_formula" 1)
  (mode_tile "lbl_p4" 1) (mode_tile "p4_nivel" 1)
  (mode_tile "lbl_p5" 1) (mode_tile "p5_offset" 1)
  (mode_tile "lbl_p6" 1) (mode_tile "p6_zmin" 1) (mode_tile "p6_zmax" 1)
  (mode_tile "lbl_p7" 1) (mode_tile "p7_n" 1)
  (cond
    ((= modo 0)
      (mode_tile "lbl_p1" 0) (mode_tile "p1_desplaz" 0))
    ((= modo 1)
      (mode_tile "lbl_p2" 0) (mode_tile "p2_rangos" 0))
    ((= modo 2)
      (mode_tile "lbl_p3" 0) (mode_tile "p3_formula" 0))
    ((= modo 3)
      (mode_tile "lbl_p4" 0) (mode_tile "p4_nivel" 0))
    ((= modo 4)
      (mode_tile "lbl_p5" 0) (mode_tile "p5_offset" 0))
    ((= modo 5)
      (mode_tile "lbl_p6" 0) (mode_tile "p6_zmin" 0) (mode_tile "p6_zmax" 0))
    ((= modo 6)
      (mode_tile "lbl_p7" 0) (mode_tile "p7_n" 0))
  )
)

;; ----------------------------------------------------------------
;; COMANDO PRINCIPAL PZ
;; ----------------------------------------------------------------

(defun c:PZ ( / dcl-ruta dcl-id dlg-ret ruta crear-backup temp-sufijo
              filtro-xmin filtro-xmax filtro-ymin filtro-ymax
              modo modo-str configuracion val lista-rangos rangos-lista
              rango-partes tmp formula-str nivel-deseado offset
              z-elim-min z-elim-max decimar-freq
              stats original-count original-min-z original-max-z
              original-sum-z original-sum-cuad original-primer-z
              formato-decimales ruta-backup nombre-base extension
              ruta-salida archivo-entrada archivo-salida
              total-lineas puntos-procesados puntos-eliminados
              puntos-fuera-filtro min-z max-z sum-z sum-cuad
              decimar-contador preview-lineas sep-campos
              linea datos x-actual y-actual z-str z-actual
              descartar nuevo-z t-inicio t-fin abrir-archivo)

  (setq t-inicio (getvar "MILLISECS"))
  (princ (strcat "\n>>> PZ v8.5"))

  ;; Buscar DCL
  (setq dcl-ruta (pz-buscar-dcl))
  (if (not dcl-ruta)
    (progn
      (alert "No se encontro Procesa-XYZ.dcl.")
      (vl-exit-with-status 0)
    )
  )

  ;; Cargar DCL
  (princ "\n>>> load_dialog...")
  (setq dcl-id (load_dialog dcl-ruta))
  (if (< dcl-id 0)
    (progn
      (alert (strcat "Error al cargar DCL:\n" dcl-ruta))
      (vl-exit-with-status 0)
    )
  )
  (princ (strcat "\n>>> dcl-id=" (itoa dcl-id)))

  ;; Crear dialogo
  (princ "\n>>> new_dialog...")
  (if (not (new_dialog "procesa_xyz" dcl-id))
    (progn
      (alert "Error al crear el dialogo.")
      (unload_dialog dcl-id)
      (vl-exit-with-status 0)
    )
  )
  (princ "\n>>> dialogo creado")

  ;; Inicializar modo
  (setq modo-str "0")
  (pz-habilitar-parametros modo-str)

  ;; Accion: examinar archivo
  (action_tile "examinar"
    "(progn
       (setq tmp-ruta (getfiled \"Seleccionar archivo XYZ\" \"\" \"XYZ;TXT;CSV;*\" 0))
       (if tmp-ruta
         (progn
           (set_tile \"ruta\" tmp-ruta)
           (setq tmp-stats (pz-analizar-archivo tmp-ruta))
           (set_tile \"stats_text\"
             (strcat \"  Puntos: \" (itoa (nth 0 tmp-stats))
                     \"  |  Z min: \" (formatear-numero (nth 1 tmp-stats) 3)
                     \"  |  Z max: \" (formatear-numero (nth 2 tmp-stats) 3)))
         )
       )
     )"
  )

  ;; Accion: filtro on/off
  (action_tile "filtro_on"
    "(progn
       (if (= $value \"1\")
         (progn
           (mode_tile \"fxmin\" 0)
           (mode_tile \"fxmax\" 0)
           (mode_tile \"fymin\" 0)
           (mode_tile \"fymax\" 0)
         )
         (progn
           (mode_tile \"fxmin\" 1)
           (mode_tile \"fxmax\" 1)
           (mode_tile \"fymin\" 1)
           (mode_tile \"fymax\" 1)
         )
       )
     )"
  )

  ;; Accion: cambio de modo
  (action_tile "modos"
    "(progn
       (setq modo-str $value)
       (pz-habilitar-parametros modo-str)
     )"
  )

  ;; **** CLAVE: Recoger TODOS los valores DENTRO del callback
  ;; **** ANTES de llamar done_dialog, mientras el dialogo esta activo
  (action_tile "procesar"
    "(progn
       (setq *pz:d-ruta (get_tile \"ruta\"))
       (setq *pz:d-backup (get_tile \"backup\"))
       (setq *pz:d-sufijo (get_tile \"sufijo\"))
       (setq *pz:d-modo modo-str)
       (setq *pz:d-filtro (get_tile \"filtro_on\"))
       (setq *pz:d-fxmin (get_tile \"fxmin\"))
       (setq *pz:d-fxmax (get_tile \"fxmax\"))
       (setq *pz:d-fymin (get_tile \"fymin\"))
       (setq *pz:d-fymax (get_tile \"fymax\"))
       (setq *pz:d-p1 (get_tile \"p1_desplaz\"))
       (setq *pz:d-p2 (get_tile \"p2_rangos\"))
       (setq *pz:d-p3 (get_tile \"p3_formula\"))
       (setq *pz:d-p4 (get_tile \"p4_nivel\"))
       (setq *pz:d-p5 (get_tile \"p5_offset\"))
       (setq *pz:d-p6a (get_tile \"p6_zmin\"))
       (setq *pz:d-p6b (get_tile \"p6_zmax\"))
       (setq *pz:d-p7 (get_tile \"p7_n\"))
       (done_dialog 1)
     )"
  )

  ;; Accion: cancelar
  (action_tile "cancelar" "(done_dialog 0)")

  ;; Mostrar dialogo
  (princ "\n>>> start_dialog...")
  (setq dlg-ret (start_dialog))

  (if (/= dlg-ret 1)
    (progn
      (unload_dialog dcl-id)
      (princ "\nOperacion cancelada.")
      (vl-exit-with-status 0)
    )
  )

  ;; Descargar dialogo
  (unload_dialog dcl-id)

  ;; ---- LEER VALORES desde variables globales ----
  (princ "\n>>> recogiendo valores...")
  (setq ruta *pz:d-ruta)
  (setq crear-backup (= *pz:d-backup "1"))
  (setq temp-sufijo *pz:d-sufijo)
  (if (or (not temp-sufijo) (= temp-sufijo ""))
    (setq temp-sufijo "_MOD")
  )

  (if (= *pz:d-filtro "1")
    (progn
      (setq filtro-xmin (distof *pz:d-fxmin))
      (setq filtro-xmax (distof *pz:d-fxmax))
      (setq filtro-ymin (distof *pz:d-fymin))
      (setq filtro-ymax (distof *pz:d-fymax))
    )
    (setq filtro-xmin nil)
  )

  (setq modo (atoi *pz:d-modo))

  ;; Construir configuracion
  (setq configuracion nil)
  (cond
    ((= modo 0)
      (setq val (distof *pz:d-p1))
      (if (not val) (setq val 0.0))
      (setq configuracion (list 'CONSTANTE val))
    )
    ((= modo 1)
      (setq lista-rangos '())
      (setq tmp (vl-string-trim " \t" *pz:d-p2))
      (if (/= tmp "")
        (progn
          (setq rangos-lista (pz-split-rangos tmp))
          (foreach r rangos-lista
            (setq rango-partes (pz-parse-rango r))
            (if rango-partes
              (setq lista-rangos (cons rango-partes lista-rangos))
            )
          )
        )
      )
      (if (null lista-rangos)
        (progn
          (alert "Modo 2: Debe ingresar al menos un rango.")
          (vl-exit-with-status 0)
        )
        (setq configuracion (list 'RANGOS (reverse lista-rangos)))
      )
    )
    ((= modo 2)
      (setq formula-str (vl-string-trim " \t" *pz:d-p3))
      (if (= formula-str "") (setq formula-str "z"))
      (setq z 0.0)
      (setq tmp (vl-catch-all-apply 'eval (list (read formula-str))))
      (if (vl-catch-all-error-p tmp)
        (progn
          (alert (strcat "Formula no valida:\n" (vl-catch-all-error-message tmp)))
          (setq formula-str "z")
        )
      )
      (setq configuracion (list 'FORMULA formula-str))
    )
    ((= modo 3)
      (setq nivel-deseado (distof *pz:d-p4))
      (if (not nivel-deseado) (setq nivel-deseado 0.0))
      (setq configuracion (list 'NIVEL nivel-deseado))
    )
    ((= modo 4)
      (setq offset (distof *pz:d-p5))
      (if (not offset) (setq offset 0.0))
      (setq configuracion (list 'INVERTIR offset))
    )
    ((= modo 5)
      (setq z-elim-min (distof *pz:d-p6a))
      (setq z-elim-max (distof *pz:d-p6b))
      (if (or (not z-elim-min) (not z-elim-max))
        (progn
          (alert "Modo 6: Debe ingresar Z min y Z max.")
          (vl-exit-with-status 0)
        )
        (setq configuracion (list 'ELIMINAR z-elim-min z-elim-max))
      )
    )
    ((= modo 6)
      (setq decimar-freq (atoi *pz:d-p7))
      (if (or (not decimar-freq) (< decimar-freq 2))
        (setq decimar-freq 2)
      )
      (setq configuracion (list 'DECIMAR decimar-freq))
    )
  )

  ;; Verificar que hay ruta
  (if (or (not ruta) (= ruta ""))
    (progn
      (alert "No se ha seleccionado ningun archivo XYZ.\nUse el boton Examinar.")
      (vl-exit-with-status 0)
    )
  )

  ;; DIAGNOSTICO: mostrar primeras lineas
  (princ "\n>>> diagnosticos primer linea...")
  (setq tmp (open ruta "r"))
  (if tmp
    (progn
      (setq dbg-linea (read-line tmp))
      (princ (strcat "\n  Linea1 raw=[" dbg-linea "]"))
      (princ (strcat "\n  Linea1 len=" (itoa (strlen dbg-linea))))
      (setq dbg-datos (split-campos dbg-linea))
      (princ (strcat "\n  split-campos=" (itoa (length dbg-datos)) " campos"))
      (if (>= (length dbg-datos) 1)
        (progn
          (princ (strcat "\n  campo0=[" (nth 0 dbg-datos) "] -> " 
                         (if (cadena-a-real (nth 0 dbg-datos)) "OK" "NIL")))
        )
      )
      (if (>= (length dbg-datos) 2)
        (progn
          (princ (strcat "\n  campo1=[" (nth 1 dbg-datos) "] -> "
                         (if (cadena-a-real (nth 1 dbg-datos)) "OK" "NIL")))
        )
      )
      (if (>= (length dbg-datos) 3)
        (progn
          (princ (strcat "\n  campo2=[" (nth 2 dbg-datos) "] -> "
                         (if (cadena-a-real (nth 2 dbg-datos)) "OK" "NIL")))
        )
      )
      (close tmp)
    )
  )
  (princ "\n>>> analizando...")
  (setq stats (pz-analizar-archivo ruta))
  (setq original-count    (nth 0 stats))
  (setq original-min-z    (nth 1 stats))
  (setq original-max-z    (nth 2 stats))
  (setq original-sum-z    (nth 3 stats))
  (setq original-sum-cuad (nth 4 stats))
  (setq original-primer-z (nth 5 stats))
  (if original-primer-z
    (setq formato-decimales (detectar-formato original-primer-z))
  )

  (princ (strcat "\n  Total puntos:     " (itoa original-count)))
  (princ (strcat "\n  Z minimo:         " (formatear-numero original-min-z formato-decimales)))
  (princ (strcat "\n  Z maximo:         " (formatear-numero original-max-z formato-decimales)))
  (if (> original-count 0)
    (progn
      (princ (strcat "\n  Z promedio:       " (formatear-numero (/ original-sum-z original-count) formato-decimales)))
      (princ (strcat "\n  Z desv. estandar:  "
                     (formatear-numero (calcular-desviacion original-sum-z original-sum-cuad original-count)
                                       formato-decimales)))
    )
  )

  (if crear-backup
    (progn
      (setq ruta-backup (strcat (vl-filename-directory ruta) "\\"
                                (vl-filename-base ruta) "_BACKUP"
                                (vl-filename-extension ruta)))
      (vl-file-copy ruta ruta-backup T)
      (princ (strcat "\n  Backup creado: " ruta-backup))
    )
  )

  (setq nombre-base (vl-filename-base ruta))
  (setq extension   (vl-filename-extension ruta))
  (setq ruta-salida (strcat (vl-filename-directory ruta) "\\"
                            nombre-base temp-sufijo extension))

  (princ "\n\nProcesando archivo...")

  (setq archivo-entrada (open ruta "r")
        archivo-salida   (open ruta-salida "w")
        total-lineas          0
        puntos-procesados     0
        puntos-eliminados     0
        puntos-fuera-filtro   0
        min-z                  1E308
        max-z                 -1E308
        sum-z                  0.0
        sum-cuad               0.0
        decimar-contador      0
        preview-lineas        0
        sep-campos            " ")

  (while (setq linea (read-line archivo-entrada))
    (setq total-lineas (1+ total-lineas))
    (if (= (rem total-lineas 10000) 0)
      (princ (strcat "\r  Lineas: " (itoa total-lineas)))
    )
    (setq datos (split-campos linea))
    (if (= sep-campos " ")
      (if (vl-string-search "\t" linea)
        (setq sep-campos "\t")
      )
    )
    (if (>= (length datos) 3)
      (progn
        (setq x-actual (cadena-a-real (nth 0 datos)))
        (setq y-actual (cadena-a-real (nth 1 datos)))
        (setq z-str    (nth 2 datos))
        (setq z-actual (cadena-a-real z-str))
        (if (and z-actual x-actual y-actual)
          (progn
            (setq descartar nil)
            (if filtro-xmin
              (if (or (< x-actual filtro-xmin) (> x-actual filtro-xmax)
                      (< y-actual filtro-ymin) (> y-actual filtro-ymax))
                (setq descartar T)
              )
            )
            (if (eq (car configuracion) 'DECIMAR)
              (progn
                (setq decimar-contador (1+ decimar-contador))
                (if (< (rem decimar-contador (cadr configuracion)) 1)
                  nil
                  (setq descartar T)
                )
              )
            )
            (if (not descartar)
              (progn
                (setq nuevo-z nil)
                (cond
                  ((eq (car configuracion) 'CONSTANTE)
                    (setq nuevo-z (+ z-actual (cadr configuracion)))
                  )
                  ((eq (car configuracion) 'RANGOS)
                    (setq nuevo-z z-actual)
                    (foreach rango (cadr configuracion)
                      (if (and (>= z-actual (car rango)) (<= z-actual (cadr rango)))
                        (setq nuevo-z (+ z-actual (caddr rango)))
                      )
                    )
                  )
                  ((eq (car configuracion) 'FORMULA)
                    (setq z z-actual)
                    (setq nuevo-z (vl-catch-all-apply 'eval
                                    (list (read (cadr configuracion)))))
                    (if (vl-catch-all-error-p nuevo-z)
                      (setq nuevo-z z-actual)
                      (setq nuevo-z (if (numberp nuevo-z) nuevo-z z-actual))
                    )
                  )
                  ((eq (car configuracion) 'NIVEL)
                    (setq nuevo-z (cadr configuracion))
                  )
                  ((eq (car configuracion) 'INVERTIR)
                    (setq nuevo-z (+ (- z-actual) (cadr configuracion)))
                  )
                  ((eq (car configuracion) 'ELIMINAR)
                    (if (and (>= z-actual (cadr configuracion))
                             (<= z-actual (caddr configuracion)))
                      (setq nuevo-z nil)
                      (setq nuevo-z z-actual)
                    )
                  )
                  ((eq (car configuracion) 'DECIMAR)
                    (setq nuevo-z z-actual)
                  )
                )
                (if nuevo-z
                  (progn
                    (setq min-z    (min min-z nuevo-z))
                    (setq max-z    (max max-z nuevo-z))
                    (setq sum-z    (+ sum-z nuevo-z))
                    (setq sum-cuad (+ sum-cuad (* nuevo-z nuevo-z)))
                    (setq datos (reemplazar-indice datos 2
                              (formatear-numero nuevo-z formato-decimales)))
                    (write-line (unir-campos datos sep-campos) archivo-salida)
                    (if (< preview-lineas 5)
                      (progn
                        (princ (strcat "\n  " (itoa (1+ preview-lineas)) ": "
                                       (unir-campos datos sep-campos)))
                        (setq preview-lineas (1+ preview-lineas))
                      )
                    )
                    (setq puntos-procesados (1+ puntos-procesados))
                  )
                  (setq puntos-eliminados (1+ puntos-eliminados))
                )
              )
              (setq puntos-fuera-filtro (1+ puntos-fuera-filtro))
            )
          )
          (write-line linea archivo-salida)
        )
      )
      (write-line linea archivo-salida)
    )
  )

  (close archivo-entrada)
  (close archivo-salida)

  (setq t-fin (getvar "MILLISECS"))

  (princ "\n\n+------------------------------------------+")
  (princ (strcat "\n  PROCESO COMPLETADO ("
                 (rtos (/ (- t-fin t-inicio) 1000.0) 2 1) " seg)"))
  (princ "+------------------------------------------+")
  (princ (strcat "\n  Lineas leidas:      " (itoa total-lineas)))
  (princ (strcat "\n  Puntos resultantes: " (itoa puntos-procesados)))
  (if (> puntos-eliminados 0)
    (princ (strcat "\n  Puntos eliminados:  " (itoa puntos-eliminados)))
  )
  (if (> puntos-fuera-filtro 0)
    (princ (strcat "\n  Fuera de filtro XY: " (itoa puntos-fuera-filtro)))
  )

  (if (> puntos-procesados 0)
    (progn
      (princ "\n  Valores Z resultantes:")
      (princ (strcat "\n    Minimo:   " (formatear-numero min-z formato-decimales)))
      (princ (strcat "\n    Maximo:   " (formatear-numero max-z formato-decimales)))
      (princ (strcat "\n    Promedio: " (formatear-numero (/ sum-z puntos-procesados) formato-decimales)))
      (princ (strcat "\n    Desv.Est.: "
                     (formatear-numero (calcular-desviacion sum-z sum-cuad puntos-procesados)
                                       formato-decimales)))
      (princ (strcat "\n    Rango:    " (formatear-numero (- max-z min-z) formato-decimales)))
    )
  )

  (princ (strcat "\n\n  Archivo: " ruta-salida))

  (princ "\nListo!")
  (princ)
)

(princ (strcat "\n  Procesa-XYZ v8.5 cargado."))
(princ "\nComando: PZ")
(princ)