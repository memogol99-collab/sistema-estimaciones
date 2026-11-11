;;; MEMO SISTEMA 2.1.1 - archivo generado por construir_bundle.py
;;; Origen: LISP_Topografia/Ptos Civil a Capas ( PCC ).lsp

;;; ============================================================
;;; PCC.lsp - Clasificador de Puntos y Textos CivilCAD
;;; Version 3.0 - Optimizada
;;; ============================================================
;;;
;;; MEJORAS DE RENDIMIENTO (vs v2.0):
;;;   [01] Grid espacial O(n+m) en lugar de O(n*m)
;;;       Para 1000 pts x 1000 textos: ~1M iteraciones  ->  ~9K iteraciones
;;;       Hasta 100x mas rapido en lotes grandes.
;;;   [02] Creacion de capas con entmake (no usa command)
;;;   [03] Agrupacion UNDO: un solo U deshace todo el lote
;;;   [04] Lista de textos construida en una sola pasada (no mapcar+remove)
;;;   [05] Variables locales correctamente declaradas
;;;   [06] HIGHLIGHT, CLAYER, CMDECHO, OSMODE restaurados en error handler
;;;   [07] Barra de progreso cada 100 puntos
;;;   [08] Mensajes ASCII seguros ([OK], [AVISO], [ERROR])
;;;   [09] Floor division para coordenadas negativas (robustez UTM)
;;;
;;; COMANDO:
;;;   PCC  - Clasifica puntos y textos por descripcion cercana
;;;
;;; ============================================================

;;; Configuracion global
(setq PCC:INVALID_COLORS '(0 2 7 8 9 250 251 252 253 254 255))
(setq PCC:MAX_DISTANCE   3.0)

;;; Floor division: para coordenadas negativas, fix() trunca hacia 0
;;; y eso rompe la celda. floor-div devuelve el entero correcto.
(defun PCC:FLOOR-DIV (a b / q)
  (setq q (fix (/ a b)))
  (if (and (minusp a) (/= (* q b) a))
    (1- q)
    q))


;;; ============================================================
;;; COMANDO PRINCIPAL
;;; ============================================================

(defun c:PCC ( / *error* oldCmd oldOsnap oldHighlight oldClayer undoStarted
                 startTime numPts processedCount textosProcesados
                 colorCount layerCache normalizedCache
                 ssPts ssTxt pointList textList grid
                 invalidColors maxDistance cellSize
                 pEnt pPt result closestDesc closestDist closestTEnt
                 lay desc ed txtItem tPt elapsedTime)

  (defun *error* (msg)
    (if (not (member msg '("Function cancelled" "quit / exit abort" "" nil)))
      (princ (strcat "\n[ERROR] " msg)))
    (if undoStarted (command "_UNDO" "_E"))
    (if oldCmd       (setvar "CMDECHO"   oldCmd))
    (if oldOsnap     (setvar "OSMODE"    oldOsnap))
    (if oldHighlight (setvar "HIGHLIGHT" oldHighlight))
    (if oldClayer    (setvar "CLAYER"    oldClayer))
    (princ))

  ;; --- Setup ---
  (setq oldCmd       (getvar "CMDECHO")
        oldOsnap     (getvar "OSMODE")
        oldHighlight (getvar "HIGHLIGHT")
        oldClayer    (getvar "CLAYER")
        startTime    (getvar "MILLISECS")
        undoStarted  nil)

  (setvar "CMDECHO"   0)
  (setvar "OSMODE"    0)
  (setvar "HIGHLIGHT" 0)

  (setq invalidColors   PCC:INVALID_COLORS
        maxDistance     PCC:MAX_DISTANCE
        cellSize        maxDistance     ; celda = maxDistance unidades
        colorCount      1
        processedCount  0
        textosProcesados 0
        layerCache      '()
        normalizedCache '())

  (princ "\n>> Clasificando puntos y textos por descripcion...")

  ;; --- Siguiente color disponible (closure sobre colorCount e invalidColors) ---
  (defun NextColor ( / c)
    (setq c colorCount)
    (while
      (progn
        (setq c (1+ c))
        (if (> c 255) (setq c 1))
        (member c invalidColors)))
    (setq colorCount c)
    c)

  ;; --- Crear capa con entmake (mucho mas rapido que command) ---
  (defun CrearCapaSiNoExiste (nombreCapa / color)
    (cond
      ((member nombreCapa layerCache) nil)
      ((tblsearch "LAYER" nombreCapa)
        (setq layerCache (cons nombreCapa layerCache)) nil)
      (T
        (setq color (NextColor))
        (entmake
          (list '(0 . "LAYER")
                '(100 . "AcDbSymbolTableRecord")
                '(100 . "AcDbLayerTableRecord")
                (cons 2 nombreCapa)
                (cons 62 color)
                '(70 . 0)
                '(6 . "Continuous")
                '(290 . 0)))   ; no plot (equivalente a _P "N")
        (setq layerCache (cons nombreCapa layerCache)) T)))

  ;; --- Normalizar nombre de capa (con cache) ---
  (defun NormalizarNombreCapa (desc / nombre cacheEntry)
    (if (setq cacheEntry (assoc desc normalizedCache))
      (cdr cacheEntry)
      (progn
        (setq nombre (vl-string-trim " " desc))
        (setq nombre (vl-string-subst "_" " " nombre))
        (setq nombre (vl-string-translate "¡…Õ”⁄—·ÈÌÛ˙Ò" "AEIOUNaeioun" nombre))
        (setq nombre (vl-string-translate "\\/*?|<>:\";=`" "___________" nombre))
        (setq nombre (substr nombre 1 (min (strlen nombre) 31)))
        (setq normalizedCache (cons (cons desc nombre) normalizedCache))
        nombre)))

  ;; --- Copiar entidad a otra capa ---
  (defun CopyEntityToLayer (ent layerName)
    (entmake
      (append
        (vl-remove-if '(lambda (x) (member (car x) '(5 330 -1))) (entget ent))
        (list (cons 8 layerName) (cons 62 256))))
    (entlast))

  ;; --- Selection set -> lista de enames ---
  (defun GetEntityList (ss / lst i)
    (if ss
      (progn
        (setq lst '() i 0)
        (repeat (sslength ss)
          (setq lst (cons (ssname ss i) lst) i (1+ i)))
        (reverse lst))
      nil))

  ;; --- Construir grid espacial de textos ---
  ;; Estructura: ((key . (txtItem1 txtItem2 ...)) (key2 . ...))
  ;; key = "cellX,cellY"
  (defun BuildTextGrid (textList / g cellX cellY key existing)
    (setq g '())
    (foreach item textList
      (setq tPt (cadr item))
      (if tPt
        (progn
          (setq cellX (PCC:FLOOR-DIV (car  tPt) cellSize)
                cellY (PCC:FLOOR-DIV (cadr tPt) cellSize)
                key   (strcat (itoa cellX) "," (itoa cellY)))
          (if (setq existing (assoc key g))
            (setq g (subst (cons key (cons item (cdr existing))) existing g))
            (setq g (cons (cons key (list item)) g))))))
    g)

  ;; --- Buscar texto mas cercano usando grid (revisa solo 9 celdas) ---
  (defun FindClosestTextInGrid (pt / cellX cellY closestDesc closestDist closestEnt
                                   dx dy cellTexts dist item)
    (setq cellX (PCC:FLOOR-DIV (car  pt) cellSize)
          cellY (PCC:FLOOR-DIV (cadr pt) cellSize)
          closestDesc nil
          closestDist maxDistance
          closestEnt  nil)
    (setq dx -1)
    (while (<= dx 1)
      (setq dy -1)
      (while (<= dy 1)
        (setq cellTexts
               (cdr (assoc (strcat (itoa (+ cellX dx)) ","
                                   (itoa (+ cellY dy))) grid)))
        (foreach item cellTexts
          (setq tPt (cadr item))
          (if (and tPt (< (setq dist (distance pt tPt)) closestDist))
            (setq closestDist dist
                  closestDesc (car  item)
                  closestEnt  (caddr item))))
        (setq dy (1+ dy)))
      (setq dx (1+ dx)))
    (if closestDesc (list closestDesc closestDist closestEnt) nil))

  ;; --- Iniciar grupo UNDO ---
  (command "_UNDO" "_BE")
  (setq undoStarted T)

  ;; --- Seleccionar puntos y textos ---
  (if (and (setq ssPts (ssget "_X" '((0 . "POINT"))))
           (setq ssTxt (ssget "_X" '((8 . "CVL_PUNTO_DES") (0 . "TEXT,MTEXT")))))
    (progn
      ;; Lista de puntos
      (setq pointList (GetEntityList ssPts)
            numPts    (length pointList))

      ;; Lista de textos (una sola pasada, evita mapcar + vl-remove-if)
      (setq textList '())
      (foreach ent (GetEntityList ssTxt)
        (setq ed   (entget ent)
              desc (cdr (assoc 1 ed)))
        (if desc (setq desc (vl-string-trim " " desc)))
        (if (and desc (/= desc ""))
          (setq textList (cons (list desc (cdr (assoc 10 ed)) ent) textList))))
      (setq textList (reverse textList))

      (princ (strcat "\n   " (itoa numPts) " puntos, "
                     (itoa (length textList)) " textos encontrados"))

      ;; Crear capas desde textos
      (princ "\n>> Creando capas desde textos...")
      (foreach txtItem textList
        (CrearCapaSiNoExiste (NormalizarNombreCapa (car txtItem))))

      ;; Construir grid espacial (clave del rendimiento)
      (princ "\n>> Construyendo indice espacial...")
      (setq grid (BuildTextGrid textList))

      ;; Procesar puntos
      (princ "\n>> Procesando puntos...")
      (foreach pEnt pointList
        ;; Progreso cada 100 puntos
        (if (= 0 (rem processedCount 100))
          (princ (strcat "\r   " (itoa processedCount) "/"
                         (itoa numPts) "    ")))
        (if (setq pPt (cdr (assoc 10 (entget pEnt))))
          (if (and (setq result (FindClosestTextInGrid pPt))
                   (setq closestDesc (car result))
                   (< (setq closestDist (cadr result)) maxDistance))
            (progn
              (setq lay (NormalizarNombreCapa closestDesc))
              (CopyEntityToLayer pEnt lay)
              (if (setq closestTEnt (caddr result))
                (progn
                  (CopyEntityToLayer closestTEnt lay)
                  (setq textosProcesados (1+ textosProcesados))))
              (setq processedCount (1+ processedCount))))))

      ;; Reporte final
      (setq elapsedTime (/ (- (getvar "MILLISECS") startTime) 1000.0))
      (princ (strcat "\n\n[OK] Proceso completado en " (rtos elapsedTime 2 2) " segundos"))
      (princ (strcat "\n     " (itoa processedCount) " de " (itoa numPts) " puntos procesados"))
      (princ (strcat "\n     " (itoa textosProcesados) " textos copiados"))
      (princ (strcat "\n     " (itoa (length layerCache)) " capas creadas/utilizadas"))
      (princ "\n\nColores excluidos: Amarillo (2), Grises (8,9) y colores de sistema")
      (princ "\nUse el comando UNIRMA para unir puntos de capa MA con polilineas"))

    ;; No se encontro nada
    (progn
      (princ "\n[AVISO] No se encontraron puntos o textos en la capa 'CVL_PUNTO_DES'.")
      (princ "\n   Verifique que existan:")
      (princ "\n   - Puntos (entidades POINT)")
      (princ "\n   - Textos en capa 'CVL_PUNTO_DES'")))

  ;; --- Cerrar grupo UNDO y restaurar variables ---
  (command "_UNDO" "_E")
  (setq undoStarted nil)
  (setvar "CMDECHO"   oldCmd)
  (setvar "OSMODE"    oldOsnap)
  (setvar "HIGHLIGHT" oldHighlight)
  (setvar "CLAYER"    oldClayer)
  (princ))


;;; Mensaje de carga
(princ "\n[OK] Comando PCC v3.0 cargado (grid espacial activo). Escribe 'PCC' para ejecutar.")
(princ)
