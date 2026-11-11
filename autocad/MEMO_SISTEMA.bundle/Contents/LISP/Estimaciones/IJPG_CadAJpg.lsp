;;; MEMO SISTEMA 2.0.0 - archivo generado por construir_bundle.py
;;; Origen: LISP_Estimaciones/CAD a JPG  ( IJPG ).LSP

;;; ============================================================================
;;; IJPG.LSP v3.8 - Exportar a JPG/PNG y EMF Vectorial (Recorte Perfecto)
;;; ============================================================================
;;; Comandos:
;;;   IJPG      -> Exporta a imagen (JPG/PNG) recortando al area exacta.
;;;   IJPG-EMF  -> Exporta a EMF (Vectorial) del area exacta, sin bordes.
;;;   IJPG-PC3  -> Configura el trazador JPG/PNG.
;;; ============================================================================

(vl-load-com)

;; === CONFIGURACION EDITABLE ===
(setq *IJPG-CTB* "acad.ctb")
;; Trazador por defecto (si creaste el de 600 DPI, cambialo aqui)
(setq *IJPG-PC3* "PublishToWeb JPG.pc3") 
;; PAD = 0.0 para asegurar que no haya margen extra (el recorte lo limpia)
(setq *IJPG-PAD* 0.0) 
(setq *IJPG-OCULTAR-CAPAS* nil)

;; === Constantes ActiveX ===
(if (null acWindow)      (setq acWindow 4))
(if (null acScaleToFit)  (setq acScaleToFit 0))
(if (null ac0degrees)    (setq ac0degrees 0))
(if (null acMillimeters) (setq acMillimeters 1))

;;; ----------------------------------------------------------------------------
(defun ijpg-sanitize (s / i ch res)
  (setq s (strcase (if s s "")))
  (setq res "")
  (setq i 1)
  (while (<= i (strlen s))
    (setq ch (substr s i 1))
    (if (wcmatch ch "[0-9A-Z]")
      (setq res (strcat res ch))
      (setq res (strcat res "_"))
    )
    (setq i (1+ i))
  )
  (if (= res "") (setq res "ESPACIO"))
  res
)

(defun ijpg-getenv (k / r)
  (setq r (vl-catch-all-apply 'getenv (list k)))
  (if (vl-catch-all-error-p r) nil r)
)

(defun ijpg-setenv (k v)
  (vl-catch-all-apply 'setenv (list k v))
  nil
)

(defun ijpg-sysdir (envName / v regKey regKeys)
  (setq v (ijpg-getenv envName))
  (if (and (= (type v) 'STR) (/= v ""))
    v
    (progn
      (setq regKeys
        (list "HKEY_CURRENT_USER\\Volatile Environment"
              "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment"))
      (while (and regKeys (not v))
        (setq regKey (car regKeys))
        (setq regKeys (cdr regKeys))
        (setq v (vl-catch-all-apply 'vl-registry-read (list regKey envName)))
        (if (/= (type v) 'STR) (setq v nil))
      )
      v
    )
  )
)

(defun ijpg-scan-dir (dir pattern depth / out f isDir tmp)
  (setq out nil)
  (setq isDir (vl-catch-all-apply 'vl-file-directory-p (list dir)))
  (if (and (> depth 0) (eq isDir T))
    (progn
      (setq tmp (vl-catch-all-apply 'vl-directory-files (list dir pattern -1)))
      (if (listp tmp)
        (foreach f tmp (setq out (cons (strcat dir "\\" f) out)))
      )
      (setq tmp (vl-catch-all-apply 'vl-directory-files (list dir "*" 1)))
      (if (listp tmp)
        (foreach f tmp
          (if (and (/= f ".") (/= f ".."))
            (setq out (append (ijpg-scan-dir (strcat dir "\\" f) pattern (1- depth)) out))
          )
        )
      )
    )
  )
  out
)

(defun ijpg-scan-files (pattern depth / out envName envVal sub lst p)
  (setq out nil)
  (foreach envName (list "APPDATA" "ProgramData" "ProgramFiles" "ProgramFiles(x86)" "ProgramW6432")
    (setq envVal (ijpg-sysdir envName))
    (if (= (type envVal) 'STR)
      (foreach sub (list "ZWSOFT" "Autodesk")
        (setq lst (ijpg-scan-dir (strcat envVal "\\" sub) pattern depth))
        (foreach p lst (setq out (cons p out)))
      )
    )
  )
  out
)

(defun ijpg-order-by-pattern (lst patterns / res pat f nm)
  (setq res nil)
  (foreach pat patterns
    (foreach f lst
      (if (= (type f) 'STR)
        (progn
          (setq nm (strcase (strcat (vl-filename-base f) (vl-filename-extension f))))
          (if (wcmatch nm pat)
            (setq res (cons f res))
          )
        )
      )
    )
  )
  (reverse res)
)

(defun ijpg-uniq (lst / res f)
  (setq res nil)
  (foreach f lst
    (if (and (= (type f) 'STR)
             (not (member (strcase f) (mapcar 'strcase res))))
      (setq res (cons f res))
    )
  )
  (reverse res)
)

(defun ijpg-find-dir-named (dir name depth / lst f out)
  (setq out nil)
  (if (and (> depth 0) dir (eq (vl-catch-all-apply 'vl-file-directory-p (list dir)) T))
    (progn
      (setq lst (vl-catch-all-apply 'vl-directory-files (list dir "*" 1)))
      (if (listp lst)
        (progn
          (while (and lst (not out))
            (setq f (car lst))
            (setq lst (cdr lst))
            (if (and (/= f ".") (/= f "..") (= (strcase f) (strcase name)))
              (setq out (strcat dir "\\" f))
            )
          )
          (setq lst (vl-catch-all-apply 'vl-directory-files (list dir "*" 1)))
          (if (listp lst)
            (while (and lst (not out))
              (setq f (car lst))
              (setq lst (cdr lst))
              (if (and (/= f ".") (/= f ".."))
                (setq out (ijpg-find-dir-named (strcat dir "\\" f) name (1- depth)))
              )
            )
          )
        )
      )
    )
  )
  out
)

(defun ijpg-pc3-try (layout p / r g)
  (setq r (vl-catch-all-apply 'vla-put-ConfigName (list layout p)))
  (if (vl-catch-all-error-p r)
    (progn
      (princ (strcat "\n  \"" p "\" -> rechazado ("
                     (vl-catch-all-error-message r) ")"))
      nil
    )
    (progn
      (setq g (vl-catch-all-apply 'vla-get-ConfigName (list layout)))
      (cond
        ((vl-catch-all-error-p g) T)
        ((and (= (type g) 'STR) (/= g ""))
         (princ (strcat "\n  \"" p "\" -> aceptado (ConfigName: \"" g "\")"))
         T)
        (t
         (princ (strcat "\n  \"" p "\" -> sin error pero ConfigName quedo vacio"))
         nil)
      )
    )
  )
)

(defun ijpg-plotter-dir (cands / d f dir appd pf lr)
  (setq dir nil)
  (setq d (ijpg-getenv "PrinterConfigDir"))
  (if (and (= (type d) 'STR) (eq (vl-catch-all-apply 'vl-file-directory-p (list d)) T))
    (setq dir d)
  )
  (if (not dir)
    (foreach f cands
      (if (and (not dir) (= (type f) 'STR) (wcmatch (strcase f) "*ZWSOFT*"))
        (setq dir (vl-filename-directory f))
      )
    )
  )
  (if (not dir)
    (progn
      (setq appd (ijpg-sysdir "APPDATA"))
      (if (= (type appd) 'STR)
        (setq dir (ijpg-find-dir-named (strcat appd "\\ZWSOFT") "PLOTTERS" 5))
      )
    )
  )
  (if (not dir)
    (progn
      (setq lr (vl-catch-all-apply 'getvar (list "LOCALROOTPREFIX")))
      (if (= (type lr) 'STR)
        (progn
          (if (= (substr lr (strlen lr) 1) "\\")
            (setq lr (substr lr 1 (1- (strlen lr))))
          )
          (setq dir (ijpg-find-dir-named lr "PLOTTERS" 4))
        )
      )
    )
  )
  (if (not dir)
    (progn
      (setq pf (ijpg-sysdir "ProgramFiles"))
      (if (= (type pf) 'STR)
        (setq dir (ijpg-find-dir-named (strcat pf "\\ZWSOFT") "PLOTTERS" 5))
      )
    )
  )
  dir
)

(defun ijpg-ask-window (oldOsmode / wpt1 wpt2 wOk res x1 y1 x2 y2)
  (setq res nil)
  (setq wOk nil)
  (setvar "OSMODE" (logior (getvar "OSMODE") 1))
  (while (not wOk)
    (setq wpt1 (getpoint "\nPrimera esquina de la ventana (CUALQUIER esquina): "))
    (if (not wpt1)
      (setq wOk T)
      (progn
        (setq wpt2 (getcorner wpt1 "\nEsquina OPUESTA de la ventana: "))
        (if (not wpt2)
          (setq wOk T)
          (progn
            (setq wpt1 (trans wpt1 1 0))
            (setq wpt2 (trans wpt2 1 0))
            (setq x1 (car wpt1) y1 (cadr wpt1) x2 (car wpt2) y2 (cadr wpt2))
            (setq wpt1 (list (min x1 x2) (min y1 y2) 0.0))
            (setq wpt2 (list (max x1 x2) (max y1 y2) 0.0))
            (if (and (> (- (car wpt2) (car wpt1)) 1e-4) (> (- (cadr wpt2) (cadr wpt1)) 1e-4))
              (progn
                (setq res (list wpt1 wpt2))
                (setq wOk T)
              )
              (progn
                (princ "\n*** La ventana NO tiene area (ancho o alto = 0). ***")
                (princ "\n*** Selecciona dos esquinas OPUESTAS. ***")
              )
            )
          )
        )
      )
    )
  )
  (setvar "OSMODE" oldOsmode)
  res
)

;;; ============================================================================
;;; Comando principal: IJPG (Imagen Raster)
;;; ============================================================================
(defun C:IJPG ( / *error* oldCmdecho oldOsmode oldCmddia oldFiledia oldBkg acadObj doc layout lName plotObj result acadOk continue pt1 pt2 pt1Var pt2Var pt1Tr pt2Tr useSaved ans imgPath dwgDir dwgName baseName pt1P pt2P padX padY tolStr winW_mm winH_mm inModel spTag envPfx e1 e2 e3 e4 prodName pc3User pc3Cands pc3CfgDir pc3Name pc3Jpg pc3JpgAll pc3Tgt pc3SrcList pc3Copied ctbDir ctbCands ctbName cand nm p pfx pv q wRes sizeBefore sizeAfter waitT0 wt spin spinCap fProbe plotLied psCmd wshObj execRes capasCong capObj fRes nmC)
  (vl-load-com)

  (setq oldCmdecho (getvar "CMDECHO"))
  (setq oldOsmode  (getvar "OSMODE"))
  (setq oldCmddia  (vl-catch-all-apply 'getvar (list "CMDDIA")))
  (setq oldFiledia (vl-catch-all-apply 'getvar (list "FILEDIA")))
  (setq oldBkg     (vl-catch-all-apply 'getvar (list "BACKGROUNDPLOT")))

  (defun *error* (msg)
    (foreach capObj capasCong
      (vl-catch-all-apply 'vla-put-Freeze (list capObj :vlax-false))
    )
    (if oldCmdecho (setvar "CMDECHO" oldCmdecho))
    (if oldOsmode  (setvar "OSMODE"  oldOsmode))
    (if (and (not (vl-catch-all-error-p oldCmddia)) (numberp oldCmddia))
      (vl-catch-all-apply 'setvar (list "CMDDIA" oldCmddia))
    )
    (if (and (not (vl-catch-all-error-p oldFiledia)) (numberp oldFiledia))
      (vl-catch-all-apply 'setvar (list "FILEDIA" oldFiledia))
    )
    (if (and (not (vl-catch-all-error-p oldBkg)) (numberp oldBkg))
      (vl-catch-all-apply 'setvar (list "BACKGROUNDPLOT" oldBkg))
    )
    (if (and msg (not (wcmatch (strcase msg t) "*break*,*cancel*,*exit*,*end*,*quit*,*interrupcion*,*salida*")))
      (princ (strcat "\n*** Error IJPG: " msg " ***"))
      (princ "\n*** IJPG cancelado. ***")
    )
    (princ)
  )

  (setq continue T)
  (setq acadObj (vlax-get-acad-object))
  (setq doc     (vla-get-ActiveDocument acadObj))
  (setq layout  (vla-get-ActiveLayout doc))
  (setq lName   (vla-get-Name layout))
  (setq inModel (= (getvar "TILEMODE") 1))
  
  (if inModel
    (princ "\nEspacio actual: MODELO")
    (princ (strcat "\nEspacio actual: Layout \"" lName "\""))
  )

  (setq prodName (vl-catch-all-apply 'getvar (list "PROGRAM")))
  (if (and (not (vl-catch-all-error-p prodName)) (= (type prodName) 'STR))
    (princ (strcat "\nPlataforma: " prodName))
  )

  (setq spTag (if inModel "MODEL" (ijpg-sanitize lName)))
  (setq envPfx (strcat "IJPG_" spTag "_"))

  (if continue
    (progn
      (setq useSaved nil)
      (setq e1 (ijpg-getenv (strcat envPfx "PT1_X")))
      (setq e2 (ijpg-getenv (strcat envPfx "PT1_Y")))
      (setq e3 (ijpg-getenv (strcat envPfx "PT2_X")))
      (setq e4 (ijpg-getenv (strcat envPfx "PT2_Y")))
      (if (and e1 e2 e3 e4)
        (progn
          (setq pt1Tr (list (atof e1) (atof e2) 0.0))
          (setq pt2Tr (list (atof e3) (atof e4) 0.0))
        )
        (progn
          (if (not inModel)
            (progn
              (setq e1 (ijpg-getenv "IJPG_PT1_X"))
              (setq e2 (ijpg-getenv "IJPG_PT1_Y"))
              (setq e3 (ijpg-getenv "IJPG_PT2_X"))
              (setq e4 (ijpg-getenv "IJPG_PT2_Y"))
              (if (and e1 e2 e3 e4)
                (progn
                  (setq pt1Tr (list (atof e1) (atof e2) 0.0))
                  (setq pt2Tr (list (atof e3) (atof e4) 0.0))
                )
              )
            )
          )
        )
      )
      (if (and pt1Tr pt2Tr (> (- (car pt2Tr) (car pt1Tr)) 1e-4) (> (- (cadr pt2Tr) (cadr pt1Tr)) 1e-4))
        (progn
          (princ (strcat "\nVentana guardada: (" (rtos (car pt1Tr)  2 2) "," (rtos (cadr pt1Tr) 2 2) ") -> (" (rtos (car pt2Tr)  2 2) "," (rtos (cadr pt2Tr) 2 2) ")"))
          (initget "Usar Nueva")
          (setq ans (getkword "\nUsar ventana guardada? [Usar/Nueva] <Usar>: "))
          (if (= ans "Nueva") (setq useSaved nil) (setq useSaved T))
        )
        (if (and pt1Tr pt2Tr)
          (progn
            (setq pt1Tr nil pt2Tr nil)
            (princ "\n(La ventana guardada no tiene area; se pedira una nueva.)")
          )
        )
      )

      (if (not useSaved)
        (progn
          (princ "\n*** OSNAP Punto Final activado para la seleccion. ***")
          (setq wRes (ijpg-ask-window oldOsmode))
          (if wRes
            (progn
              (setq pt1 (car wRes))
              (setq pt2 (cadr wRes))
              (ijpg-setenv (strcat envPfx "PT1_X") (rtos (car  pt1) 2 6))
              (ijpg-setenv (strcat envPfx "PT1_Y") (rtos (cadr pt1) 2 6))
              (ijpg-setenv (strcat envPfx "PT2_X") (rtos (car  pt2) 2 6))
              (ijpg-setenv (strcat envPfx "PT2_Y") (rtos (cadr pt2) 2 6))
              (princ "\n*** Ventana guardada para futuras exportaciones. ***")
            )
            (setq continue nil)
          )
        )
        (progn
          (setq pt1 pt1Tr)
          (setq pt2 pt2Tr)
        )
      )
    )
  )

  (if continue
    (progn
      (setq dwgDir  (getvar "DWGPREFIX"))
      (setq dwgName (vl-filename-base (getvar "DWGNAME")))
      (setq baseName (strcat dwgName "_" lName))
      (setq imgPath (getfiled "Guardar imagen JPG como..." (strcat dwgDir baseName) "jpg" 1))
      (if (not imgPath) (setq continue nil))
      (if (and continue imgPath (vl-file-size imgPath))
        (progn
          (setq fProbe (open imgPath "a"))
          (if fProbe
            (close fProbe)
            (progn
              (alert (strcat "El archivo destino esta bloqueado o es de solo lectura:\n" imgPath))
              (setq continue nil)
            )
          )
        )
      )
    )
  )

  (if continue
    (progn
      (princ "\n*** Configurando plot... ***")
      (setq acadOk T)

      (setq pc3User (ijpg-getenv "IJPG_PC3"))
      (if (= (type pc3User) 'STR)
        (progn
          (setq *IJPG-PC3* pc3User)
          (princ (strcat "\nPC3 configurado por el usuario (IJPG-PC3): " pc3User))
        )
      )
      
      (if (vl-catch-all-error-p (vl-catch-all-apply 'vla-put-ConfigName (list layout *IJPG-PC3*)))
        (progn
          (princ (strcat "\nNo se pudo asignar \"" *IJPG-PC3* "\"; buscando trazadores JPG en el equipo..."))
          (setq pc3Cands nil)
          (foreach nm (list "PublishToWeb JPG.pc3" "PublishToWeb JPEG.pc3" "JPG.pc3" "JPEG.pc3")
            (setq p (vl-catch-all-apply 'findfile (list nm)))
            (if (= (type p) 'STR) (setq pc3Cands (cons p pc3Cands)))
          )
          (setq pc3CfgDir (ijpg-getenv "PrinterConfigDir"))
          (if (and (= (type pc3CfgDir) 'STR) (eq (vl-catch-all-apply 'vl-file-directory-p (list pc3CfgDir)) T))
            (progn
              (foreach p (ijpg-scan-dir pc3CfgDir "*.pc3" 3)
                (setq pc3Cands (cons p pc3Cands))
              )
            )
          )
          (foreach pv (list "LOCALROOTPREFIX" "ROAMABLEROOTPREFIX")
            (setq pfx (vl-catch-all-apply 'getvar (list pv)))
            (if (= (type pfx) 'STR)
              (progn
                (if (= (substr pfx (strlen pfx) 1) "\\") (setq pfx (substr pfx 1 (1- (strlen pfx)))))
                (if (and (> (strlen pfx) 3) (eq (vl-catch-all-apply 'vl-file-directory-p (list pfx)) T))
                  (progn
                    (foreach q (ijpg-scan-dir pfx "*.pc3" 4)
                      (setq pc3Cands (cons q pc3Cands))
                    )
                  )
                )
              )
            )
          )
          (setq pc3Cands (ijpg-uniq (append pc3Cands (ijpg-scan-files "*.pc3" 6))))
          (setq pc3JpgAll (ijpg-uniq (ijpg-order-by-pattern pc3Cands (list "*PUBLISHTOWEB JPG*" "*JPG*" "*JPEG*"))))
          (setq pc3Jpg pc3JpgAll)
          (setq pc3Name nil)
          (while (and pc3Jpg (not pc3Name))
            (setq cand (car pc3Jpg) pc3Jpg (cdr pc3Jpg))
            (setq nm (strcat (vl-filename-base cand) (vl-filename-extension cand)))
            (if (ijpg-pc3-try layout nm) (setq pc3Name nm)
              (if (ijpg-pc3-try layout cand) (setq pc3Name cand))
            )
          )
          (if (and (not pc3Name) pc3JpgAll)
            (progn
              (setq pc3Tgt (ijpg-plotter-dir pc3Cands))
              (if pc3Tgt
                (progn
                  (setq pc3SrcList pc3JpgAll pc3Copied nil)
                  (while (and pc3SrcList (not pc3Copied))
                    (setq cand (car pc3SrcList) pc3SrcList (cdr pc3SrcList))
                    (setq nm (strcat pc3Tgt "\\PublishToWeb JPG.pc3"))
                    (if (/= (strcase cand) (strcase nm))
                      (setq pc3Copied (vl-catch-all-apply 'vl-file-copy (list cand nm)))
                    )
                  )
                  (if pc3Copied
                    (progn
                      (if (ijpg-pc3-try layout "PublishToWeb JPG.pc3")
                        (setq pc3Name "PublishToWeb JPG.pc3")
                        (if (ijpg-pc3-try layout nm) (setq pc3Name nm))
                      )
                    )
                  )
                )
              )
            )
          )
          (if pc3Name
            (setq *IJPG-PC3* pc3Name)
            (progn
              (alert "No se pudo asignar un trazador JPG.")
              (setq acadOk nil)
            )
          )
        )
      )

      (if acadOk (vl-catch-all-apply 'vla-RefreshPlotDeviceInfo (list layout)))

      (if acadOk
        (if (vl-catch-all-error-p (vl-catch-all-apply 'vla-put-StyleSheet (list layout *IJPG-CTB*)))
          (progn
            (setq ctbCands (ijpg-scan-files "*.ctb" 6))
            (setq ctbDir (ijpg-getenv "PrinterStyleSheetDir"))
            (if (and (= (type ctbDir) 'STR) (eq (vl-catch-all-apply 'vl-file-directory-p (list ctbDir)) T))
              (foreach p (ijpg-scan-dir ctbDir "*.ctb" 2) (setq ctbCands (cons p ctbCands)))
            )
            (setq ctbCands (ijpg-order-by-pattern (ijpg-uniq ctbCands) (list "*ACAD*" "*MONOCHROME*")))
            (setq ctbName nil)
            (while ctbCands
              (if ctbName (setq ctbCands nil)
                (progn
                  (setq cand (car ctbCands) ctbCands (cdr ctbCands))
                  (setq nm (strcat (vl-filename-base cand) (vl-filename-extension cand)))
                  (if (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-put-StyleSheet (list layout nm))))
                    (setq ctbName nm)
                  )
                )
              )
            )
          )
        )
      )

      ;; 3. DEFINIR VENTANA PRIMERO
      (if acadOk
        (progn
          ;; PAD es 0.0 por defecto para evitar bordes extra
          (setq padX *IJPG-PAD* padY *IJPG-PAD*)
          (if inModel
            (progn
              (setq padX (* (abs (- (car pt2) (car pt1))) *IJPG-PAD*))
              (setq padY (* (abs (- (cadr pt2) (cadr pt1))) *IJPG-PAD*))
            )
          )
          (setq pt1P (list (- (car pt1) padX) (- (cadr pt1) padY)))
          (setq pt2P (list (+ (car pt2) padX) (+ (cadr pt2) padY)))
          (setq pt1Var (vlax-make-variant (vlax-safearray-fill (vlax-make-safearray vlax-vbDouble '(0 . 1)) (list (car pt1P) (cadr pt1P)))))
          (setq pt2Var (vlax-make-variant (vlax-safearray-fill (vlax-make-safearray vlax-vbDouble '(0 . 1)) (list (car pt2P) (cadr pt2P)))))
          (setq result (vl-catch-all-apply 'vla-SetWindowToPlot (list layout pt1Var pt2Var)))
          (if (vl-catch-all-error-p result)
            (progn
              (alert (strcat "No se pudo asignar la ventana de plotter.\n\nError: " (vl-catch-all-error-message result)))
              (setq acadOk nil)
            )
          )
        )
      )

      ;; 4. AHORA SI: PlotType = acWindow
      (if acadOk
        (if (vl-catch-all-error-p (vl-catch-all-apply 'vla-put-PlotType (list layout acWindow)))
          (progn
            (alert "No se pudo configurar el tipo de plot (Window).")
            (setq acadOk nil)
          )
        )
      )

      (if acadOk
        (progn
          (vl-catch-all-apply 'vla-put-PlotOrigin        (list layout (vlax-3d-point 0.0 0.0)))
          (vl-catch-all-apply 'vla-put-UseStandardScale  (list layout :vlax-true))
          (vl-catch-all-apply 'vla-put-StandardScale     (list layout acScaleToFit))
          (vl-catch-all-apply 'vla-put-PlotRotation      (list layout ac0degrees))
          (vl-catch-all-apply 'vla-put-PlotWithPlotStyles (list layout :vlax-true))
          (vl-catch-all-apply 'vla-put-PaperUnits        (list layout acMillimeters))
          (vl-catch-all-apply 'vla-put-CenterPlot        (list layout (if inModel :vlax-true :vlax-false)))
        )
      )

      (if acadOk
        (progn
          (setq winW_mm (abs (- (car  pt2) (car  pt1))))
          (setq winH_mm (abs (- (cadr pt2) (cadr pt1))))
          (princ (strcat "\nVentana: " (rtos winW_mm 2 2) " x " (rtos winH_mm 2 2) " mm"))
        )
      )

      (if acadOk
        (vl-catch-all-apply 'vla-put-PlotType (list layout acWindow))
      )

      (setq capasCong nil)
      (if (and acadOk (not inModel) *IJPG-OCULTAR-CAPAS*)
        (foreach nmC *IJPG-OCULTAR-CAPAS*
          (if (and (= (type nmC) 'STR) (/= (strcase nmC) (strcase (getvar "CLAYER"))))
            (progn
              (setq capObj (vl-catch-all-apply 'vla-item (list (vla-get-Layers doc) nmC)))
              (if (not (vl-catch-all-error-p capObj))
                (progn
                  (setq fRes (vl-catch-all-apply 'vla-get-Freeze (list capObj)))
                  (if (eq fRes :vlax-false)
                    (progn
                      (setq fRes (vl-catch-all-apply 'vla-put-Freeze (list capObj :vlax-true)))
                      (if (not (vl-catch-all-error-p fRes))
                        (setq capasCong (cons capObj capasCong))
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
      
      (if acadOk
        (progn
          (princ "\n*** Generando imagen JPG... ***")
          (setq plotObj (vla-get-Plot doc))
          (vl-catch-all-apply 'vla-put-QuietErrorMode (list plotObj :vlax-true))
          (vl-catch-all-apply 'setvar (list "BACKGROUNDPLOT" 0))
          (setq result (vl-catch-all-apply 'vla-PlotToFile (list plotObj imgPath *IJPG-PC3*)))
          (if (vl-catch-all-error-p result)
            (setq result (vl-catch-all-apply 'vla-PlotToFile (list plotObj imgPath)))
          )
          
          (if (and (not (vl-catch-all-error-p result)) (member result (list nil :vlax-false)))
            (progn
              (princ "\n(Plot devolvio False: reintentando...)")
              (vl-catch-all-apply 'vla-RefreshPlotDeviceInfo (list layout))
              (vl-catch-all-apply 'vla-put-ConfigName  (list layout *IJPG-PC3*))
              (vl-catch-all-apply 'vla-SetWindowToPlot (list layout pt1Var pt2Var))
              (vl-catch-all-apply 'vla-put-PlotType    (list layout acWindow))
              (vl-catch-all-apply 'vla-put-PlotOrigin (list layout (vlax-3d-point 0.0 0.0)))
              (vl-catch-all-apply 'vla-put-UseStandardScale (list layout :vlax-true))
              (vl-catch-all-apply 'vla-put-StandardScale (list layout acScaleToFit))
              (vl-catch-all-apply 'vla-put-CenterPlot (list layout (if inModel :vlax-true :vlax-false)))
              (vl-catch-all-apply 'vla-put-QuietErrorMode (list plotObj :vlax-true))
              (vl-catch-all-apply 'setvar (list "BACKGROUNDPLOT" 0))
              (setq result (vl-catch-all-apply 'vla-PlotToFile (list plotObj imgPath *IJPG-PC3*)))
              (if (vl-catch-all-error-p result)
                (setq result (vl-catch-all-apply 'vla-PlotToFile (list plotObj imgPath)))
              )
            )
          )
          (cond
            ((vl-catch-all-error-p result)
             (alert (strcat "Error al generar el JPG:\n\n" (vl-catch-all-error-message result)))
             (setq acadOk nil))
            ((member result (list nil :vlax-false))
             (setq plotLied T))
            (t nil)
          )
        )
      )

      (foreach capObj capasCong
        (vl-catch-all-apply 'vla-put-Freeze (list capObj :vlax-false))
      )
      (setq capasCong nil)

      (if acadOk
        (progn
          (setq sizeBefore (vl-file-size imgPath))
          (if (not sizeBefore)
            (progn
              (setq waitT0 (vl-catch-all-apply 'getvar (list "MILLISECS")))
              (setq spin 0)
              (setq spinCap (if (and (not (vl-catch-all-error-p waitT0)) (numberp waitT0)) 100000000 6000))
              (while (and (not sizeBefore) (< spin spinCap))
                (setq sizeBefore (vl-file-size imgPath))
                (setq spin (1+ spin))
                (if (and (not (vl-catch-all-error-p waitT0)) (numberp waitT0))
                  (progn
                    (setq wt (vl-catch-all-apply 'getvar (list "MILLISECS")))
                    (if (and (not (vl-catch-all-error-p wt)) (numberp wt) (>= (- wt waitT0) 15000))
                      (setq spin spinCap)
                    )
                  )
                )
              )
            )
          )
          (cond
            (sizeBefore
              (princ (strcat "\nTamano antes: " (itoa sizeBefore) " bytes")))
            (plotLied
              (alert "El plot devolvio False y NO se genero el JPG.")
              (setq acadOk nil))
            (t
              (alert "No se encontro el JPG generado.")
              (setq acadOk nil))
          )
        )
      )

      ;; RECORTE AUTOMATICO (Elimina cualquier borde blanco sobrante)
      (if (and acadOk sizeBefore)
        (progn
          (princ "\n*** Recortando margenes blancos para dejar SOLO el dibujo... ***")
          (setq tolStr (if inModel "$tol = 6;" "$tol = 12;"))
          (setq psCmd
            (strcat
              "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "
              "\"Add-Type -AssemblyName System.Drawing;"
              "$img = [System.Drawing.Image]::FromFile('" imgPath "');"
              "$bmp = New-Object System.Drawing.Bitmap($img);"
              "$w = $bmp.Width; $h = $bmp.Height;"
              "$left = $w; $right = 0; $top = $h; $bottom = 0;"
              tolStr
              "for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) {"
              "  $p = $bmp.GetPixel($x, $y);"
              "  $bright = ($p.R + $p.G + $p.B) / 3;"
              "  if ($bright -lt (255 - $tol)) {"
              "    if ($x -lt $left)   { $left = $x }"
              "    if ($x -gt $right)  { $right = $x }"
              "    if ($y -lt $top)    { $top = $y }"
              "    if ($y -gt $bottom) { $bottom = $y } } } }"
              "$img.Dispose();"
              "if ($right -gt $left -and $bottom -gt $top) {"
              "  $newW = $right - $left + 1; $newH = $bottom - $top + 1;"
              "  $crop = New-Object System.Drawing.Bitmap($newW, $newH);"
              "  $g = [System.Drawing.Graphics]::FromImage($crop);"
              "  $g.DrawImage($bmp, (New-Object System.Drawing.Rectangle(0, 0, $newW, $newH)), (New-Object System.Drawing.Rectangle($left, $top, $newW, $newH)), [System.Drawing.GraphicsUnit]::Pixel);"
              "  $g.Dispose(); $bmp.Dispose();"
              "  $crop.Save('" imgPath "', [System.Drawing.Imaging.ImageFormat]::Jpeg);"
              "  $crop.Dispose(); }\""
            )
          )
          (setq wshObj (vlax-create-object "WScript.Shell"))
          (setq execRes (vl-catch-all-apply '(lambda () (vlax-invoke-method wshObj 'Run psCmd 0 :vlax-true))))
          (vlax-release-object wshObj)
          (if (vl-catch-all-error-p execRes)
            (princ (strcat "\n(no se pudo ejecutar recorte automatico: " (vl-catch-all-error-message execRes)))
            (progn
              (setq sizeAfter (vl-file-size imgPath))
              (if sizeAfter (princ (strcat "\nTamano despues: " (itoa sizeAfter) " bytes")))
              (if (and sizeBefore sizeAfter (/= sizeAfter sizeBefore))
                (princ "\n*** Recorte aplicado. Sin bordes blancos. ***")
                (princ "\n*** Aviso: el recorte no modifico el archivo. ***")
              )
            )
          )
        )
      )

      (if acadOk
        (princ (strcat "\n*** Imagen generada con exito: " imgPath " ***"))
      )

      (setvar "CMDECHO" oldCmdecho)
      (setvar "OSMODE"  oldOsmode)
      (if (and (not (vl-catch-all-error-p oldCmddia)) (numberp oldCmddia))
        (vl-catch-all-apply 'setvar (list "CMDDIA" oldCmddia)))
      (if (and (not (vl-catch-all-error-p oldFiledia)) (numberp oldFiledia))
        (vl-catch-all-apply 'setvar (list "FILEDIA" oldFiledia)))
      (if (and (not (vl-catch-all-error-p oldBkg)) (numberp oldBkg))
        (vl-catch-all-apply 'setvar (list "BACKGROUNDPLOT" oldBkg)))
    )
  )
  (princ)
)

;;; ============================================================================
;;; Comando IJPG-EMF: Exportar a Vectorial EXACTAMENTE el area seleccionada
;;; ============================================================================
(defun C:IJPG-EMF (/ filepath base pt1 pt2 pt1W pt2W ss oldFiledia oldCmdecho ok oldOsmode rect oldLayer oldColor)
  (vl-load-com)
  (setq oldFiledia (getvar "FILEDIA"))
  (setq oldCmdecho (getvar "CMDECHO"))
  (setq oldOsmode  (getvar "OSMODE"))
  
  (setvar "FILEDIA" 0)
  (setvar "CMDECHO" 0)
  
  (setvar "OSMODE" (logior (getvar "OSMODE") 1))

  (setq base (strcat (getvar "DWGPREFIX") (vl-filename-base (getvar "DWGNAME"))))
  (setq filepath (getfiled "Guardar imagen EMF para Excel..." base "emf" 1))
  
  (if filepath
    (progn
      (if (not (wcmatch (strcase filepath) "*.EMF"))
        (setq filepath (strcat filepath ".emf"))
      )
        
      (setq pt1 (getpoint "\nPrimera esquina del area a exportar: "))
      (if pt1
        (progn
          (setq pt2 (getcorner pt1 "\nEsquina OPUESTA del area: "))
          (if pt2
            (progn
              (setq pt1W (trans pt1 1 0))
              (setq pt2W (trans pt2 1 0))
              
              (setq ss (ssget "_W" pt1W pt2W))
              (if (not ss) (setq ss (ssget "_C" pt1W pt2W)))
              
              (if ss
                (progn
                  (princ (strcat "\nExportando " (itoa (sslength ss)) " objetos a EMF..."))
                  
                  ;; TRUCO PARA EL TAMAÑO EXACTO: Crear un rectangulo invisible
                  ;; que abarque exactamente el area seleccionada.
                  (setq oldLayer (getvar "CLAYER"))
                  (setq oldColor (getvar "CECOLOR"))
                  
                  ;; Color blanco puro (invisible en Excel con fondo blanco)
                  (command-s "_.-COLOR" "255,255,255" "")
                  ;; Dibujar el rectangulo de la ventana
                  (command-s "_.RECTANG" pt1W pt2W)
                  (setq rect (entlast))
                  ;; Añadir a la seleccion
                  (ssadd rect ss)
                  
                  ;; Exportar
                  (setq ok (vl-catch-all-apply '(lambda () (command-s "_.EXPORT" "_EMF" filepath ss ""))))
                                
                  (if (or (vl-catch-all-error-p ok) (not (vl-file-size filepath)))
                    (progn
                      (princ "\n(EXPORT EMF no soportado. Usando WMFOUT...)")
                      (if (vl-file-size filepath) (vl-file-delete filepath))
                      (command-s "_.WMFOUT" filepath ss "")
                      (princ (strcat "\n*** WMF generado con exito: " filepath " ***"))
                    )
                    (princ (strcat "\n*** EMF generado con exito: " filepath " ***"))
                  )
                  
                  ;; Borrar el rectangulo temporal
                  (if rect (entdel rect))
                  ;; Restaurar color
                  (setvar "CECOLOR" oldColor)
                  (setvar "CLAYER" oldLayer)
                    
                  (princ "\n*** En Excel: Insertar > Imagenes > Desde este dispositivo. ***")
                  (princ "\n*** El area seleccionada ocupa exactamente el borde. ***")
                )
                (princ "\n*** No se encontraron objetos dentro del area seleccionada. ***")
              )
            )
          )
        )
      )
    )
    (princ "\n*** Cancelado. ***")
  )
  
  (setvar "FILEDIA" oldFiledia)
  (setvar "CMDECHO" oldCmdecho)
  (setvar "OSMODE"  oldOsmode)
  (princ)
)

;;; ============================================================================
;;; Comando IJPG-PC3
;;; ============================================================================
(defun C:IJPG-PC3 (/ nm old fnd)
  (setq old (ijpg-getenv "IJPG_PC3"))
  (if (not old) (setq old "PublishToWeb JPG.pc3"))
  (princ (strcat "\nTrazador JPG actual: " old))
  (setq nm (getstring T "\nNombre EXACTO del trazador JPG o ruta completa al .pc3 (Enter=default): "))
  (if (= nm "") (setq nm "PublishToWeb JPG.pc3"))
  (setq fnd (vl-catch-all-apply 'findfile (list nm)))
  (if (= (type fnd) 'STR)
    (princ (strcat "\nEncontrado: " fnd))
    (princ (strcat "\n(Aviso: \"" nm "\" no esta en las rutas de busqueda actual; se guarda de todos modos.)"))
  )
  (ijpg-setenv "IJPG_PC3" nm)
  (setq *IJPG-PC3* nm)
  (princ (strcat "\n*** Guardado. IJPG usara: " nm " ***"))
  (princ)
)

(princ "\n*** IJPG.LSP v3.8 cargado correctamente. ***")
(princ "\n- Comando IJPG: Exportar area exacta a JPG/PNG sin bordes blancos.")
(princ "\n- Comando IJPG-EMF: Exportar area exacta a Vectorial (Ideal para Excel).")
(princ)