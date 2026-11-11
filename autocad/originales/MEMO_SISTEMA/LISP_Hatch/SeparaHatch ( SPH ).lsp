;===========================================================================
;  Comando: SEPARAHATCH o SH
;  Inverso de FUSIONHATCH / FH
;
;  Descripcion:
;  1. Seleccionar un hatch compuesto (varias fronteras)
;  2. La rutina crea un hatch individual por cada ruta de frontera
;  3. Elimina el hatch original
;
;  Notas importantes:
;  - Funciona con hatches asociativos y no asociativos.
;  - Si el hatch tiene islas (agujeros dentro de una frontera exterior),
;    cada isla se convierte en un hatch separado. Si desea mantener las
;    islas con su frontera exterior, vuelva a usar FUSIONHATCH para
;    reagruparlas.
;  - Conserva: patron, escala, angulo, capa, color, color de fondo,
;    relleno solido/gradiente y asociatividad (cuando es posible).
;
;  Logica de parseo DXF:
;  La estructura DXF de un hatch con N fronteras es:
;
;    (91 . N)                  <- numero de rutas de frontera
;    (92 . flags) (93 . nEdges) ... bordes ... (97 . nObj) (330 . handle)
;    (98 . nSeeds) (10 pt)     <- RUTA 1 completa
;    (92 . flags) (93 . nEdges) ... bordes ... (97 . nObj) (330 . handle)
;    (98 . nSeeds) (10 pt)     <- RUTA 2 completa
;    ...
;    (75 . estilo)             <- inicio de la seccion de patron/estilo
;    (52 . angulo) (41 . escala) (77 . doble) (78 . nLineas)
;    ... definicion de lineas de patron ...
;    (450 ...)                 <- datos de gradiente (si aplica)
;
;  La rutina extrae la seccion entre 91 y 75, la divide en cada
;  grupo 92 (inicio de ruta), y recrea un hatch individual con
;  cada ruta + la seccion de patron/estilo compartida.
;
;  By Juan Villarreal (extension)
;  Comando inverso a FUSIONHATCH
;===========================================================================

(vl-load-com)

;---------------------------------------------------------------------------
; Funcion auxiliar: obtener todas las parejas con una clave dada
(defun massoc (key alst / )
  (vl-remove-if '(lambda (pair) (/= (car pair) key)) alst)
)

;---------------------------------------------------------------------------
; Extrae la seccion de datos de fronteras.
; Retorna la sublista DXF entre el grupo 91 (numero de fronteras)
; y el grupo 75 (estilo de hatch), sin incluirlos.
;
; Estrategia:
;   1. Obtener todo lo que esta despues de (91 . N)
;   2. Invertir la lista y buscar (75 ...)
;   3. Tomar todo lo que esta antes de 75 en la lista invertida
;   4. Invertir de nuevo para obtener el orden correcto
;---------------------------------------------------------------------------
(defun getBoundarySection (hatchData / after91 revData from75)
  (setq after91 (cdr (member (assoc 91 hatchData) hatchData)))
  (if after91
    (progn
      (setq revData (reverse after91))
      (setq from75 (member (assoc 75 hatchData) revData))
      (if from75
        (reverse (cdr from75))
        after91  ; si no hay 75, devolver todo despues de 91 (caso raro)
      )
    )
    nil
  )
)

;---------------------------------------------------------------------------
; Divide la seccion de fronteras en rutas individuales.
; Cada ruta comienza con un grupo 92 (tipo de ruta de frontera).
;
; Entrada: lista DXF de la seccion de fronteras
; Salida:  lista de listas, cada sublista es una ruta de frontera completa
;          incluyendo bordes, objetos asociativos (97/330) y semillas (98/10)
;---------------------------------------------------------------------------
(defun splitPaths (boundarySection / paths currentPath rest pair)
  (setq paths nil
        currentPath nil
        rest boundarySection)
  (while rest
    (setq pair (car rest))
    (if (and (= (car pair) 92) currentPath)
      ;; Inicio de una nueva ruta: guardar la anterior y comenzar la nueva
      (progn
        (setq paths (append paths (list currentPath)))
        (setq currentPath (list pair))
      )
      ;; Agregar al currentPath
      (setq currentPath (append currentPath (list pair)))
    )
    (setq rest (cdr rest))
  )
  ;; No olvidar la ultima ruta
  (if currentPath
    (setq paths (append paths (list currentPath)))
  )
  paths
)

;---------------------------------------------------------------------------
; Comando principal: SEPARAHATCH
;---------------------------------------------------------------------------
(defun c:SeparaHatch ( / ent hatchData hatchObj bgCol paths nPaths i pathData
                           newHatch tailSection newEntList turnoff headerList
                           newEnt isAssociative boundarySection)

  (vl-load-com)

  ;; ---------------------------------------------------------------
  ;; PASO 1: Seleccionar el hatch a separar
  ;; ---------------------------------------------------------------
  (setq ent nil)
  (while (not ent)
    (setq ent (car (entsel "\nSeleccionar hatch a separar: ")))
    (cond
      ((not ent)
       (princ "\nNo selecciono nada. Intente de nuevo."))
      ((/= (cdr (assoc 0 (entget ent))) "HATCH")
       (princ "\nEl objeto seleccionado no es un HATCH. Intente de nuevo.")
       (setq ent nil))
    )
  )

  (setq hatchData  (entget ent)
        hatchObj   (vlax-ename->vla-object ent)
        bgCol      (vla-get-backgroundcolor hatchObj)
  )

  ;; ---------------------------------------------------------------
  ;; PASO 2: Analizar las rutas de frontera
  ;; ---------------------------------------------------------------
  (setq boundarySection (getBoundarySection hatchData))

  (if (not boundarySection)
    (progn (princ "\nError: no se pudieron extraer las fronteras del hatch.")
           (princ)
    )
  )

  (setq paths  (splitPaths boundarySection)
        nPaths (length paths)
  )

  (if (< nPaths 2)
    (progn
      (princ "\nEl hatch solo tiene una frontera. No hay nada que separar.")
      (princ)
    )
  )

  (princ (strcat "\nSeparando hatch en " (itoa nPaths) " hatches individuales..."))

  ;; ---------------------------------------------------------------
  ;; PASO 3: Obtener la seccion de estilo/patron (desde grupo 75)
  ;; Esta seccion se comparte por todos los hatches nuevos.
  ;; Incluye: estilo (75), angulo (52), escala (41), doble (77),
  ;;          lineas de patron (78...), y datos de gradiente (450...)
  ;; ---------------------------------------------------------------
  (setq tailSection    (member (assoc 75 hatchData) hatchData)
        newEntList     nil
        turnoff        nil
        isAssociative  (= (cdr (assoc 71 hatchData)) 1)
        i              0
  )

  ;; ---------------------------------------------------------------
  ;; PASO 4: Crear un hatch individual por cada ruta de frontera
  ;; ---------------------------------------------------------------
  (repeat nPaths
    (setq pathData (nth i paths))

    ;; --- Construir el encabezado de la entidad ---
    (setq headerList
      (list
        (cons 0 "HATCH")
        (cons 100 "AcDbEntity")
        (assoc 8 hatchData)    ; capa
      )
    )
    ;; Agregar color si existe (color explicito)
    (if (assoc 62 hatchData)
      (setq headerList (append headerList (list (assoc 62 hatchData))))
    )

    ;; --- Construir la lista DXF completa del hatch nuevo ---
    ;; Estructura: encabezado + encabezado hatch + (91 . 1) + ruta + cola
    (setq newHatch
      (append headerList
        (list
          (cons 100 "AcDbHatch")
          (assoc 10  hatchData)   ; punto de elevacion
          (assoc 210 hatchData)   ; direccion de extrusion
          (assoc 2   hatchData)   ; nombre del patron
          (assoc 70  hatchData)   ; tipo de relleno (0=patron, 1=solido)
          (assoc 71  hatchData)   ; bandera de asociatividad
          (cons 91 1)             ; 1 sola ruta de frontera
        )
        pathData                  ; datos completos de esta frontera
        tailSection               ; estilo, patron, gradiente, etc.
      )
    )

    ;; --- Verificar si esta ruta conserva asociatividad ---
    ;; Una ruta sin objetos fuente (sin grupo 330) pierde asociatividad
    (if isAssociative
      (if (not (assoc 330 pathData))
        (setq turnoff T)
      )
    )

    ;; --- Crear el hatch con entmake ---
    (entmake newHatch)
    (setq newEnt (entlast))
    (setq newEntList (cons newEnt newEntList))

    ;; --- Restaurar asociatividad con los objetos de frontera ---
    ;; Cada grupo 330 en la ruta es el handle de un objeto frontera.
    ;; Actualizamos ese objeto para que apunte al nuevo hatch.
    (if (and isAssociative (not turnoff))
      (mapcar
        '(lambda (x / objData)
           (setq objData (entget (cdr x)))
           (entmod (subst (cons 330 newEnt) (assoc 330 objData) objData))
         )
        (massoc 330 pathData)
      )
    )

    ;; --- Restaurar el color de fondo ---
    (vl-catch-all-apply
      '(lambda () (vla-put-backgroundcolor (vlax-ename->vla-object newEnt) bgCol))
    )

    (setq i (1+ i))
  )

  ;; ---------------------------------------------------------------
  ;; PASO 5: Eliminar el hatch original
  ;; ---------------------------------------------------------------
  (entdel ent)

  ;; ---------------------------------------------------------------
  ;; PASO 6: Mensajes finales
  ;; ---------------------------------------------------------------
  (if turnoff
    (princ "\nAdvertencia: la asociatividad se elimino en algunos hatches nuevos.")
  )
  (princ (strcat "\nListo. Se crearon " (itoa nPaths) " hatches individuales."))

  (princ)
)

;---------------------------------------------------------------------------
; Alias corto
;---------------------------------------------------------------------------
(defun c:SPH () (c:SeparaHatch))


;===========================================================================
;  COMANDO ORIGINAL: FUSIONHATCH / FH
;  (incluido para tener todo en un solo archivo)
;
;  1. Seleccionar hatch de referencia (patron a copiar)
;  2. Seleccionar TODOS los hatches a fusionar
;  3. La rutina crea un solo hatch combinado
;  4. Elimina los hatches originales
;
;  By Juan Villarreal
;===========================================================================

;;---------------------------------------------------------------------------
(defun c:FusionHatch ( / hentinfo ss i ent ent# seedpt# entinfo entinfo2 seedpts
                           MergedHatchList Turnoff BGColor)
  (vl-load-com)
  (while (/= (cdr (assoc 0 hentinfo)) "HATCH")
    (setq hentinfo (car (entsel "\nSelect Hatch Pattern to MATCH: ")))
    (If hentinfo
      (setq BGColor (vla-get-backgroundcolor (vlax-ename->vla-object hentinfo))
            hentinfo (entget hentinfo))
      (princ "\nMissed. Try again.")
    )
  )
  (while (not ss)
    (princ "\nSelect ALL hatch entities to merge: ")
    (setq ss (ssget '((0 . "HATCH"))))
  )
  (setq MergedHatchList
        (list (cons 0 "HATCH")
              (cons 100 "AcDbEntity")
              (assoc 8 hentinfo)
        )
  )
  (if (assoc 62 hentinfo)
    (setq MergedHatchList (append MergedHatchList (list (assoc 62 hentinfo))))
  )
  (setq MergedHatchList
    (append MergedHatchList (list
      (cons 100 "AcDbHatch")
      (assoc 10 hentinfo)
      (assoc 210 hentinfo)
      (assoc 2 hentinfo)
      (assoc 70 hentinfo)
      (assoc 71 hentinfo)
      (cons 91 (sslength ss))))
    i -1 seedpt# 0 ent# 0
  )
  (setvar 'cmdecho 0)
  (repeat (sslength ss)
    (setq entinfo  (entget (ssname ss (setq i (1+ i))))
          entinfo2 (member (assoc 92 entinfo) entinfo)
          entinfo2 (reverse (cdr (member (assoc 75 entinfo2) (reverse entinfo2))))
          ent#     (+ ent# (cdr (assoc 91 entinfo)))
          seedpt#  (+ seedpt# (cdr (assoc 98 entinfo)))
          seedpts  (append seedpts (massoc 10 (member (assoc 98 entinfo) entinfo)))
          MergedHatchList (append MergedHatchList entinfo2)
    )
    (if (zerop (cdr (assoc 71 entinfo)))
      (setq turnoff T)
    )
    (entdel (ssname ss i))
  )
  (setq MergedHatchList
    (subst (cons 91 ent#) (assoc 91 MergedHatchList) MergedHatchList)
  )
  (setq MergedHatchList
    (append MergedHatchList
      (append
        (reverse (cdr (member (assoc 98 hentinfo) (reverse (member (assoc 75 hentinfo) hentinfo)))))
        (cons (cons 98 seedpt#) seedpts)
      )
    )
  )
  (if (= (cdr (assoc 70 hentinfo)) 1)
    (setq MergedHatchList
      (append MergedHatchList (member (assoc 450 hentinfo) hentinfo))
    )
  )
  (entmake MergedHatchList)
  (setq ent (entlast))
  (if (and (= (cdr (assoc 71 hentinfo)) 1) (not turnoff))
    (mapcar
      '(lambda (x / entlist)
         (setq entlist (entget (cdr x)))
         (entmod (subst (cons 330 ent) (assoc 330 entlist) entlist))
       )
      (massoc 330 MergedHatchList)
    )
    (princ "\nAll Hatch Associativity has been removed.")
  )
  (vla-put-backgroundcolor (vlax-ename->vla-object ent) BGColor)
  (princ)
)

(defun c:FH () (c:FusionHatch))