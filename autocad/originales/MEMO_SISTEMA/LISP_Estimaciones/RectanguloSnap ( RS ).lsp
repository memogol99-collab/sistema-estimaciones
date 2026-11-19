;;; ============================================================================
;;; RUTINA LISP MEJORADA PARA AUTOCAD
;;; COMANDO: RECTANGLOSNAP (RS)
;;; Cotas por FUERA - 2 decimales SIN suprimir ceros - Texto alineado
;;; Version 2.13 - Hatch individual por rectangulo en capa Hatch_Bache
;;; ============================================================================

;;; Cargar extensiones Visual LISP (necesarias para vl-catch-all-apply, etc.)
(vl-load-com)

;;; ============================================================================
;;; VARIABLES GLOBALES
;;; ============================================================================
(setq *rectangulos-lista* nil)
(setq *rs-old-cmdecho* nil)
(setq *rs-old-osmode* nil)
(setq *rs-old-snapunit* nil)
(setq *rs-old-clayer* nil)
(setq *rs-old-dimstyle* nil)
(setq *rs-old-error* nil)

;;; Configuracion del hatch (editable)
;;; IMPORTANTE: la escala del patron ANSI31 determina la separacion entre
;;; lineas. Con escala 1.0 las lineas quedan a ~1.4 unidades y en baches
;;; pequenos (<2m) se ven SOLIDAS. Usar escala 5-10 para baches de 0.5-5m.
(setq RS:HATCH_LAYER   "Hatch_Bache")     ; nombre de la capa para hatch
(setq RS:HATCH_PATTERN "ANSI31")          ; patron (ANSI31, SOLID, EARTH, AR-CONC...)
(setq RS:HATCH_SCALE   8.0)               ; escala del patron (separacion visible)
(setq RS:HATCH_ANGLE   0.0)               ; angulo adicional en grados
(setq RS:HATCH_COLOR   8)                 ; color de la capa Hatch_Bache (8 = gris)


;;; ============================================================================
;;; FUNCIONES AUXILIARES
;;; ============================================================================

;;; Funcion para crear una capa de forma segura (con entmake)
(defun rs-crear-capa (nombre color)
  (if (not (tblsearch "LAYER" nombre))
    (entmake
      (list '(0 . "LAYER")
            '(100 . "AcDbSymbolTableRecord")
            '(100 . "AcDbLayerTableRecord")
            (cons 2 nombre)
            (cons 62 color)
            '(70 . 0)
            '(6 . "Continuous"))))
  T)

;;; Funcion para redondear a 2 decimales
(defun rs-redondear (num)
  (/ (fix (+ (* num 100) 0.5)) 100.0))

;;; Funcion para obtener el ultimo numero usado
(defun rs-obtener-ultimo-numero (/ archivo linea num maximo)
  (setq maximo 0)
  (if (setq archivo (open "rectangulos_contador.txt" "r"))
    (progn
      (while (setq linea (read-line archivo))
        (setq num (atoi linea))
        (if (> num maximo) (setq maximo num)))
      (close archivo)))
  maximo)

;;; Funcion para guardar el ultimo numero
(defun rs-guardar-ultimo-numero (num / archivo)
  (if (setq archivo (open "rectangulos_contador.txt" "w"))
    (progn
      (write-line (itoa num) archivo)
      (close archivo))))

;;; Funcion para almacenar datos en archivo
(defun rs-almacenar-datos-archivo (ent numero largo ancho / archivo)
  (if (setq archivo (open "rectangulos_datos.txt" "a"))
    (progn
      (write-line (strcat (itoa numero) "," (rtos largo 2 2) "," (rtos ancho 2 2)) archivo)
      (close archivo))))

;;; Funcion para almacenar datos XDATA en la entidad
(defun rs-almacenar-datos-xdata (ent numero largo ancho / regapp-name xdata ent-data)
  (setq regapp-name "RECTANGULOS_APP")
  (if (not (tblsearch "APPID" regapp-name))
    (regapp regapp-name))
  (setq xdata (list -3
                    (list regapp-name
                          (cons 1000 (itoa numero))
                          (cons 1040 (float largo))
                          (cons 1040 (float ancho)))))
  (setq ent-data (entget ent))
  (setq ent-data (append ent-data (list xdata)))
  (entmod ent-data))

;;; Funcion para restaurar variables (segura - usa vl-catch-all-apply en todo)
;;; IMPORTANTE: DIMSTYLE no se puede restaurar con setvar. Usamos command-s
;;; (version segura de command que SI funciona dentro de *error*).
;;; Si command-s no existe (AutoCAD < 2016), se omite la restauracion del DIMSTYLE.
(defun rs-restaurar-variables (/ old-cmdecho cmd-s-available)
  (vl-catch-all-apply 'setvar (list "CMDECHO"  (or *rs-old-cmdecho*  1)))
  (vl-catch-all-apply 'setvar (list "OSMODE"   (or *rs-old-osmode*   0)))
  (vl-catch-all-apply 'setvar (list "SNAPUNIT" (or *rs-old-snapunit* '(1.0 1.0))))
  (vl-catch-all-apply 'setvar (list "CLAYER"   (or *rs-old-clayer*   "0")))
  ;; Verificar si command-s esta disponible (atoms-family es AutoLISP nativo)
  (setq cmd-s-available (car (atoms-family 0 '("COMMAND-S"))))
  (if (and *rs-old-dimstyle* cmd-s-available)
    (progn
      (setq old-cmdecho (getvar "CMDECHO"))
      (setvar "CMDECHO" 0)
      (vl-catch-all-apply
        '(lambda ()
           (command-s "._-DIMSTYLE" "_R" *rs-old-dimstyle*)))
      (setvar "CMDECHO" old-cmdecho)))
  (princ))


;;; ============================================================================
;;; CREAR ESTILOS DE TEXTO (con entmake - mas robusto que command)
;;; ============================================================================

(defun rs-crear-estilo-texto ()
  (if (not (tblsearch "STYLE" "MONOTXT4"))
    (entmake
      (list '(0 . "STYLE")
            '(100 . "AcDbSymbolTableRecord")
            '(100 . "AcDbTextStyleTableRecord")
            (cons 2 "MONOTXT4")
            '(70 . 0)
            (cons 40 0.0)
            (cons 41 1.0)
            (cons 50 0.0)
            (cons 71 0)
            (cons 42 0.2)
            (cons 3 "monotxt.ttf")
            (cons 4 ""))))
  T)

(defun rs-crear-estilo-texto-arial ()
  (if (not (tblsearch "STYLE" "ARIAL"))
    (entmake
      (list '(0 . "STYLE")
            '(100 . "AcDbSymbolTableRecord")
            '(100 . "AcDbTextStyleTableRecord")
            (cons 2 "ARIAL")
            '(70 . 0)
            (cons 40 0.0)
            (cons 41 1.0)
            (cons 50 0.0)
            (cons 71 0)
            (cons 42 0.2)
            (cons 3 "arial.ttf")
            (cons 4 ""))))
  T)


;;; ============================================================================
;;; CREAR BLOQUE OBLIQUE (flecha oblicua)
;;; ============================================================================
(defun rs-crear-bloque-oblique ()
  (if (not (tblsearch "BLOCK" "_OBLIQUE"))
    (progn
      (entmake (list '(0 . "BLOCK") '(2 . "_OBLIQUE") '(70 . 0) '(10 0.0 0.0 0.0)))
      (entmake (list '(0 . "LINE") '(8 . "0") '(10 0.0 0.0 0.0) '(11 -0.5 0.15 0.0)))
      (entmake (list '(0 . "LINE") '(8 . "0") '(10 0.0 0.0 0.0) '(11 -0.5 -0.15 0.0)))
      (entmake '((0 . "ENDBLK")))))
  (if (not (tblsearch "BLOCK" "OBLIQUE"))
    (progn
      (entmake (list '(0 . "BLOCK") '(2 . "OBLIQUE") '(70 . 0) '(10 0.0 0.0 0.0)))
      (entmake (list '(0 . "LINE") '(8 . "0") '(10 0.0 0.0 0.0) '(11 -0.5 0.15 0.0)))
      (entmake (list '(0 . "LINE") '(8 . "0") '(10 0.0 0.0 0.0) '(11 -0.5 -0.15 0.0)))
      (entmake '((0 . "ENDBLK")))))
  T)


;;; ============================================================================
;;; HATCH INDIVIDUAL POR RECTANGULO
;;; ============================================================================
;;; Crea un hatch separado para cada rectangulo en la capa Hatch_Bache.
;;; Cada hatch es una entidad independiente con su propio boundary.

(defun rs-crear-hatch-rectangulo (ent-plinea contorno-puntos / old-clayer old-osmode hatch-ent)
  ;; Asegurar que la capa Hatch_Bache exista
  (rs-crear-capa RS:HATCH_LAYER RS:HATCH_COLOR)

  (setq old-clayer (getvar "CLAYER")
        old-osmode (getvar "OSMODE"))
  (setvar "CLAYER" RS:HATCH_LAYER)
  (setvar "OSMODE" 0)

  ;; Metodo: usar -HATCH con seleccion directa de la polilinea recien creada.
  ;; Cada llamada genera un hatch independiente asociado a esa polilinea.
  (vl-catch-all-apply
    '(lambda ()
       (command "._-HATCH"
                "_P" RS:HATCH_PATTERN RS:HATCH_SCALE RS:HATCH_ANGLE
                "_S" ent-plinea "" "")))

  (setq hatch-ent (entlast))

  (setvar "CLAYER" old-clayer)
  (setvar "OSMODE" old-osmode)

  ;; Verificar que se haya creado un HATCH (no la polilinea)
  (if (and hatch-ent (= (cdr (assoc 0 (entget hatch-ent))) "HATCH"))
    hatch-ent
    nil))


;;; ============================================================================
;;; CONFIGURAR VARIABLES DE COTA
;;; ============================================================================
(defun rs-configurar-cotas ()
  (rs-crear-bloque-oblique)

  (vl-catch-all-apply 'setvar (list "DIMBLK" "OBLIQUE"))
  (vl-catch-all-apply 'setvar (list "DIMASZ" 0.1000))

  (vl-catch-all-apply 'setvar (list "DIMCLRD" 256))
  (vl-catch-all-apply 'setvar (list "DIMLWD" -1))
  (vl-catch-all-apply 'setvar (list "DIMSD1" 0))
  (vl-catch-all-apply 'setvar (list "DIMSD2" 0))
  (vl-catch-all-apply 'setvar (list "DIMDLE" 0.0))

  (vl-catch-all-apply 'setvar (list "DIMCLRE" 252))
  (vl-catch-all-apply 'setvar (list "DIMLWE" -1))
  (vl-catch-all-apply 'setvar (list "DIMSE1" 0))
  (vl-catch-all-apply 'setvar (list "DIMSE2" 0))
  (vl-catch-all-apply 'setvar (list "DIMEXE" 0.0500))
  (vl-catch-all-apply 'setvar (list "DIMEXO" 0.0500))

  (vl-catch-all-apply 'setvar (list "DIMCLRT" 256))
  (vl-catch-all-apply 'setvar (list "DIMTXT" 0.2000))
  (vl-catch-all-apply 'setvar (list "DIMTAD" 0))
  (vl-catch-all-apply 'setvar (list "DIMTIH" 0))
  (vl-catch-all-apply 'setvar (list "DIMTOH" 0))
  (vl-catch-all-apply 'setvar (list "DIMJUST" 0))
  (vl-catch-all-apply 'setvar (list "DIMGAP" 0.1000))
  (vl-catch-all-apply 'setvar (list "DIMTXSTY" "MONOTXT4"))

  (vl-catch-all-apply 'setvar (list "DIMLUNIT" 2))
  (vl-catch-all-apply 'setvar (list "DIMDEC" 2))
  (vl-catch-all-apply 'setvar (list "DIMLFAC" 1.0))
  (vl-catch-all-apply 'setvar (list "DIMDSEP" 46))
  (vl-catch-all-apply 'setvar (list "DIMRND" 0.0))
  (vl-catch-all-apply 'setvar (list "DIMZIN" 0))
  (vl-catch-all-apply 'setvar (list "DIMPOST" ""))

  (vl-catch-all-apply 'setvar (list "DIMSCALE" 1.0))

  (if (tblsearch "DIMSTYLE" "Cota alineada")
    (command "._-DIMSTYLE" "_SA" "Cota alineada" "_Y")
    (command "._-DIMSTYLE" "_SA" "Cota alineada"))

  (princ "\nEstilo de cota configurado.")
  (princ "\n  - Texto alineado con lineas de cota")
  (princ "\n  - 2 decimales SIN suprimir ceros (ej: 0.50)"))


;;; ============================================================================
;;; MODIFICAR TEXTO DE COTA A 2 DECIMALES (sin suprimir ceros)
;;; ============================================================================
(defun rs-modificar-cota-2decimales (ent / ent-data medida texto-nuevo)
  (if ent
    (progn
      (setq ent-data (entget ent))
      (if (setq medida (cdr (assoc 42 ent-data)))
        (progn
          (setq medida (rs-redondear medida))
          (setq texto-nuevo (rs-formato-2decimales medida))
          (setq ent-data (subst (cons 1 texto-nuevo) (assoc 1 ent-data) ent-data))
          (if (not (assoc 1 ent-data))
            (setq ent-data (append ent-data (list (cons 1 texto-nuevo)))))
          (entmod ent-data)
          (entupd ent))))))

(defun rs-formato-2decimales (num / entero decimal)
  (setq entero (fix num))
  (setq decimal (fix (* (+ (- num entero) 0.0001) 100)))
  (if (< decimal 0) (setq decimal 0))
  (if (> decimal 99) (setq decimal 99))
  (strcat (itoa entero) "."
          (if (< decimal 10)
            (strcat "0" (itoa decimal))
            (itoa decimal))))


;;; ============================================================================
;;; COMANDO PRINCIPAL: RS (RECTANGLOSNAP)
;;; ============================================================================
(defun c:RS (/ pt1 pt2 pt2-snap largo ancho angulo p2 p4 p3-calc
              centro ent contador ultimo-numero largo-redondo ancho-redondo
              offset-cota pos-cota-largo pos-cota-ancho cota-ent hatch-ent)

  ;; Guarda el handler *error* previo (sin usar functionp - *error* es nil o funcion)
  ;; NO usamos *push-error-using-command* porque causa INTERNAL error en algunas versiones.
  ;; El handler solo usa setvar (que SI funciona en cualquier contexto) y vl-catch-all-apply.
  (setq *rs-old-error* *error*)
  (defun *error* (msg)
    (vl-catch-all-apply 'setvar (list "CMDECHO"  (or *rs-old-cmdecho*  1)))
    (vl-catch-all-apply 'setvar (list "OSMODE"   (or *rs-old-osmode*   0)))
    (vl-catch-all-apply 'setvar (list "SNAPUNIT" (or *rs-old-snapunit* '(1.0 1.0))))
    (vl-catch-all-apply 'setvar (list "CLAYER"   (or *rs-old-clayer*   "0")))
    (vl-catch-all-apply 'setvar (list "SNAPMODE" 0))
    (setq *error* *rs-old-error*)
    (if (not (member msg '("Function cancelled" "quit / exit abort" "" nil)))
      (princ (strcat "\n[ERROR] " msg)))
    (princ))

  (setq *rs-old-cmdecho*  (getvar "CMDECHO")
        *rs-old-osmode*   (getvar "OSMODE")
        *rs-old-snapunit* (getvar "SNAPUNIT")
        *rs-old-clayer*   (getvar "CLAYER")
        *rs-old-dimstyle* (getvar "DIMSTYLE"))

  (setvar "CMDECHO" 0)
  (setvar "SNAPUNIT" '(0.1 0.1))
  (setvar "OSMODE" 0)

  ;; Crear capas, estilos y estilo de cota (idempotentes)
  (rs-crear-capa "GEOMETRIA_RECTANGULOS" 14)
  (rs-crear-capa "COTAS_RECTANGULOS" 2)
  (rs-crear-capa "NUMEROS_RECTANGULOS" 7)
  (rs-crear-capa RS:HATCH_LAYER RS:HATCH_COLOR)         ; Hatch_Bache
  (rs-crear-estilo-texto)
  (rs-crear-estilo-texto-arial)
  (rs-configurar-cotas)
  (command "._-DIMSTYLE" "_R" "Cota alineada")

  (setq ultimo-numero (rs-obtener-ultimo-numero))
  (princ (strcat "\nUltimo numero usado: " (itoa ultimo-numero)))

  (initget 4)
  (setq contador (getint (strcat "\nNumero de figura inicial <" (itoa (1+ ultimo-numero)) ">: ")))
  (if (not contador) (setq contador (1+ ultimo-numero)))

  (princ "\n*** RECTANGLOSNAP - Dibujo de rectangulos ***")
  (princ (strcat "\nNumero inicial: " (itoa contador)))
  (princ (strcat "\nHatch: patron " RS:HATCH_PATTERN
                 " esc " (rtos RS:HATCH_SCALE 2 2)
                 " en capa '" RS:HATCH_LAYER "'"))

  (while (setq pt1 (getpoint "\nPrimer punto (Enter para terminar): "))
    (setq pt2 (getpoint pt1 "\nPunto opuesto: "))
    (if pt2
      (progn
        (setq pt2-snap (list (* (fix (/ (+ (car pt2) 0.05) 0.1)) 0.1)
                             (* (fix (/ (+ (cadr pt2) 0.05) 0.1)) 0.1)
                             0.0))
        (setq angulo (angle pt1 pt2-snap))
        (setq largo (distance pt1 pt2-snap))
        (setq largo-redondo (rs-redondear largo))

        (princ (strcat "\nLargo: " (rs-formato-2decimales largo-redondo) "m"))
        (setq ancho (getreal "\nAncho (m): "))

        (if (and ancho (> ancho 0.09))
          (progn
            (setq ancho (* (fix (/ (+ ancho 0.05) 0.1)) 0.1))
            (setq ancho-redondo (rs-redondear ancho))

            (setq p2 (polar pt1 (+ angulo (/ pi 2)) ancho-redondo))
            (setq p4 (polar pt1 angulo largo-redondo))
            (setq p3-calc (polar p2 angulo largo-redondo))
            (setq centro (list (/ (+ (car pt1) (car p3-calc)) 2)
                               (/ (+ (cadr pt1) (cadr p3-calc)) 2)
                               0.0))

            ;; Dibujar polilinea (rectangulo)
            (setvar "CLAYER" "GEOMETRIA_RECTANGULOS")
            (command "._PLINE" pt1 p2 p3-calc p4 "C")
            (setq ent (entlast))

            (rs-almacenar-datos-archivo ent contador largo-redondo ancho-redondo)
            (rs-almacenar-datos-xdata ent contador largo-redondo ancho-redondo)
            (princ " (Datos guardados OK)")

            ;; CREAR HATCH INDIVIDUAL para este rectangulo
            (rs-crear-hatch-rectangulo ent (list pt1 p2 p3-calc p4))

            ;; COTAS FUERA DEL RECTANGULO
            (setvar "CLAYER" "COTAS_RECTANGULOS")
            (setq offset-cota 0.3)

            (setq pos-cota-largo (polar pt1 (- angulo (/ pi 2)) offset-cota))
            (command "._DIMALIGNED" pt1 p4 pos-cota-largo)
            (rs-modificar-cota-2decimales (entlast))

            (setq pos-cota-ancho (polar pt1 (- angulo pi) offset-cota))
            (command "._DIMALIGNED" pt1 p2 pos-cota-ancho)
            (rs-modificar-cota-2decimales (entlast))

            ;; Numero central con estilo ARIAL
            (setvar "CLAYER" "NUMEROS_RECTANGULOS")
            (command "._TEXT" "_S" "ARIAL" "_J" "_MC" centro 0.6 "0" (itoa contador))

            (setq *rectangulos-lista*
                  (append *rectangulos-lista*
                         (list (list contador largo-redondo ancho-redondo))))

            (princ (strcat "\nRectangulo " (itoa contador) " creado."))
            (princ (strcat " Largo: " (rs-formato-2decimales largo-redondo)
                           "m, Ancho: " (rs-formato-2decimales ancho-redondo) "m"))
            (setq contador (1+ contador)))
          (princ "\nAncho invalido (debe ser > 0.1m).")))))
  (rs-guardar-ultimo-numero (1- contador))
  (rs-restaurar-variables)
  (setvar "SNAPMODE" 0)
  ;; Restaurar handler *error* previo
  (setq *error* *rs-old-error*)
  (princ "\nComando RS finalizado.")
  (princ))


;;; ============================================================================
;;; COMANDO: CC - Crear Cotas con 2 decimales
;;; ============================================================================
(defun c:CC (/ pt1 pt2 pt3 cota-ent)
  (setq *rs-old-error* *error*)
  (defun *error* (msg)
    (vl-catch-all-apply 'setvar (list "CMDECHO"  (or *rs-old-cmdecho*  1)))
    (vl-catch-all-apply 'setvar (list "OSMODE"   (or *rs-old-osmode*   0)))
    (vl-catch-all-apply 'setvar (list "CLAYER"   (or *rs-old-clayer*   "0")))
    (setq *error* *rs-old-error*)
    (if (not (member msg '("Function cancelled" "quit / exit abort" "" nil)))
      (princ (strcat "\n[ERROR] " msg)))
    (princ))
  (setq *rs-old-dimstyle* (getvar "DIMSTYLE")
        *rs-old-clayer*   (getvar "CLAYER")
        *rs-old-cmdecho*  (getvar "CMDECHO")
        *rs-old-osmode*   (getvar "OSMODE"))
  (setvar "CMDECHO" 0)
  (setvar "OSMODE" 0)
  (rs-crear-estilo-texto)
  (rs-configurar-cotas)
  (command "._-DIMSTYLE" "_R" "Cota alineada")

  (princ "\n*** CREAR COTAS (2 decimales, texto alineado) ***")

  (while (setq pt1 (getpoint "\nPrimer punto (Enter para terminar): "))
    (setq pt2 (getpoint pt1 "\nSegundo punto: "))
    (if pt2
      (progn
        (setq pt3 (getpoint "\nPosicion linea de cota: "))
        (if pt3
          (progn
            (command "._DIMALIGNED" pt1 pt2 pt3)
            (rs-modificar-cota-2decimales (entlast)))))))
  (rs-restaurar-variables)
  (setq *error* *rs-old-error*)
  (princ "\nFinalizado.")
  (princ))


;;; ============================================================================
;;; COMANDO: AEC - Actualizar Estilo de Cota
;;; ============================================================================
(defun c:AEC ()
  (rs-crear-estilo-texto)
  (rs-configurar-cotas)
  (princ "\nEstilo de cota actualizado.")
  (princ))


;;; ============================================================================
;;; COMANDO: RC2 - Redondear Cotas existentes a 2 decimales
;;; ============================================================================
(defun c:RC2 (/ ss i ent)
  (princ "\nSeleccione cotas para redondear a 2 decimales: ")
  (setq ss (ssget '((0 . "DIMENSION"))))
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq ent (ssname ss i))
        (rs-modificar-cota-2decimales ent)
        (setq i (1+ i)))
      (princ (strcat "\n" (itoa (sslength ss)) " cotas redondeadas a 2 decimales.")))
    (princ "\nNo se seleccionaron cotas."))
  (princ))


;;; ============================================================================
;;; COMANDO: RSHATCH - Re-aplicar hatch a rectangulos existentes
;;; ============================================================================
;;; Selecciona polilineas cerradas y crea un hatch individual en Hatch_Bache.
;;; Util cuando ya tienes rectangulos dibujados sin hatch.

(defun c:RSHATCH (/ ss i ent old-clayer)
  (princ "\nSeleccione polilineas rectangulares para hatchear: ")
  (setq ss (ssget '((0 . "LWPOLYLINE") (-4 . "&") (70 . 1))))  ; solo cerradas
  (if ss
    (progn
      (rs-crear-capa RS:HATCH_LAYER RS:HATCH_COLOR)
      (setq old-clayer (getvar "CLAYER")
            i 0)
      (setvar "CLAYER" RS:HATCH_LAYER)
      (while (< i (sslength ss))
        (setq ent (ssname ss i))
        (vl-catch-all-apply
          '(lambda ()
             (command "._-HATCH"
                      "_P" RS:HATCH_PATTERN RS:HATCH_SCALE RS:HATCH_ANGLE
                      "_S" ent "" "")))
        (setq i (1+ i)))
      (setvar "CLAYER" old-clayer)
      (princ (strcat "\n[OK] " (itoa i) " hatches individuales creados en '" RS:HATCH_LAYER "'.")))
    (princ "\nNo se seleccionaron polilineas."))
  (princ))


;;; ============================================================================
;;; COMANDO: RS-CONFIG - Configurar hatch interactivamente
;;; ============================================================================
;;; Evita tener que escribir expresiones LISP. Pide cada valor por separado
;;; y permite saltar con Enter para mantener el actual.

(defun c:RS-CONFIG (/ opt patron escala angulo color capa input val)
  (princ "\n=== CONFIGURACION DE HATCH (RS) ===")
  (princ (strcat "\n  Patron actual: " RS:HATCH_PATTERN))
  (princ (strcat "\n  Escala actual: " (rtos RS:HATCH_SCALE 2 2)))
  (princ (strcat "\n  Angulo actual: " (rtos RS:HATCH_ANGLE 2 1) " deg"))
  (princ (strcat "\n  Capa actual  : " RS:HATCH_LAYER))
  (princ (strcat "\n  Color capa   : " (itoa RS:HATCH_COLOR)))
  (princ "\n\nQue deseas cambiar? [Patron/Escala/Angulo/Capa/Color/Todo] <Todo>: ")
  (initget "Patron Escala Angulo Capa Color Todo")
  (setq opt (getkword))
  (if (null opt) (setq opt "Todo"))

  (if (member opt '("Patron" "Todo"))
    (progn
      (princ (strcat "\nPatrones comunes: ANSI31, ANSI32, ANSI37, ANSI38, SOLID,"))
      (princ (strcat "\n                  EARTH, AR-CONC, AR-SAND, GRASS, MUDST"))
      (princ (strcat "\nPatron actual <" RS:HATCH_PATTERN ">: "))
      (setq patron (getstring T))
      (if (and patron (/= patron ""))
        (setq RS:HATCH_PATTERN (vl-string-trim " " patron)))))

  (if (member opt '("Escala" "Todo"))
    (progn
      (princ (strcat "\nEscala actual <" (rtos RS:HATCH_SCALE 2 2) ">: "))
      (setq escala (getreal))
      (if escala (setq RS:HATCH_SCALE escala))))

  (if (member opt '("Angulo" "Todo"))
    (progn
      (princ (strcat "\nAngulo actual en grados <" (rtos RS:HATCH_ANGLE 2 1) ">: "))
      (setq angulo (getreal))
      (if angulo (setq RS:HATCH_ANGLE angulo))))

  (if (member opt '("Capa" "Todo"))
    (progn
      (princ (strcat "\nNombre de capa <" RS:HATCH_LAYER ">: "))
      (setq capa (getstring T))
      (if (and capa (/= capa ""))
        (setq RS:HATCH_LAYER (vl-string-trim " " capa)))))

  (if (member opt '("Color" "Todo"))
    (progn
      (princ (strcat "\nColor de capa (1-255) <" (itoa RS:HATCH_COLOR) ">: "))
      (setq color (getint))
      (if (and color (> color 0) (<= color 255))
        (setq RS:HATCH_COLOR color))))

  (princ "\n--- Configuracion final ---")
  (princ (strcat "\n  Patron: " RS:HATCH_PATTERN))
  (princ (strcat "\n  Escala: " (rtos RS:HATCH_SCALE 2 2)))
  (princ (strcat "\n  Angulo: " (rtos RS:HATCH_ANGLE 2 1) " deg"))
  (princ (strcat "\n  Capa  : " RS:HATCH_LAYER))
  (princ (strcat "\n  Color : " (itoa RS:HATCH_COLOR)))
  (princ "\n\nLos cambios aplican a los proximos rectangulos que dibujes con RS.")
  (princ "\nPara re-hatchear rectangulos ya existentes usa RSHATCH.")
  (princ))


;;; ============================================================================
;;; INICIALIZACION AL CARGAR EL ARCHIVO
;;; ============================================================================
(rs-crear-estilo-texto)        ; MONOTXT4
(rs-crear-estilo-texto-arial)  ; ARIAL


;;; ============================================================================
;;; MENSAJE DE CARGA
;;; ============================================================================
(princ "\n")
(princ "\n+--------------------------------------------------------------+")
(princ "\n|          RECTANGLOSNAP v2.13 - Cargado                       |")
(princ "\n+--------------------------------------------------------------+")
(princ "\n|  RS       - Dibujar rectangulos con cotas + hatch            |")
(princ "\n|  CC       - Crear cotas (2 decimales)                        |")
(princ "\n|  AEC      - Actualizar estilo de cota                        |")
(princ "\n|  RC2      - Redondear cotas existentes a 2 decimales         |")
(princ "\n|  RSHATCH  - Re-aplicar hatch a polilineas existentes         |")
(princ "\n|  RS-CONFIG- Configurar hatch interactivamente                |")
(princ "\n+--------------------------------------------------------------+")
(princ "\n|  * Estilos creados al cargar: ARIAL, MONOTXT4                |")
(princ "\n|  * Capa de hatch: Hatch_Bache (hatch individual por figura)  |")
(princ "\n|  * Cota LARGO: lado inferior - ABAJO                         |")
(princ "\n|  * Cota ANCHO: lado izquierdo - IZQUIERDA                    |")
(princ "\n|  * Texto ALINEADO con linea de cota                          |")
(princ "\n|  * 2 decimales SIN suprimir ceros (ej: 0.50)                 |")
(princ "\n|  * Numeros con estilo ARIAL                                  |")
(princ "\n|  * Guarda XDATA para exportacion con EXREC                   |")
(princ "\n+--------------------------------------------------------------+")
(princ "\n")
(princ)
