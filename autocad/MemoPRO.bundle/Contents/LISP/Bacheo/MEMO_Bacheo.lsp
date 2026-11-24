;;; MemoPRO 3.1.0 - archivo generado por construir_bundle.py
;;; Origen: @combinar
;;; Parches aplicados: combinado de 6 archivos

;;; ==================================================================
;;; PARTE: LISP_Estimaciones/RectanguloSnap ( RS ).lsp
;;; ==================================================================
;;; MemoPRO: ancho de RS con UN solo punto o el valor tecleado.
;;; Con un punto: el ancho es la distancia PERPENDICULAR del punto a la línea
;;; del largo, y el rectángulo se dibuja hacia ese lado (rs:lado = 1 izquierda,
;;; -1 derecha). Con un valor tecleado se dibuja hacia la izquierda, como antes.
(setq rs:lado 1)
(defun rs:pedir-ancho (a b / r cruz largo)
  (setq rs:lado 1)
  (initget 128)
  (setq r (getpoint "\nAncho (m) <teclea el valor o señala un punto del lado del bache>: "))
  (cond
    ((= (type r) 'STR) (distof r 2))
    ((= (type r) 'LIST)
     (setq largo (distance (list (car a) (cadr a)) (list (car b) (cadr b)))
           cruz (- (* (- (car b) (car a)) (- (cadr r) (cadr a)))
                   (* (- (cadr b) (cadr a)) (- (car r) (car a)))))
     (if (< cruz 0.0) (setq rs:lado -1))
     (if (> largo 0.0) (/ (abs cruz) largo)))))

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
  ;; MemoPRO: ya no se fuerza la rejilla de 0.1 m
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
        (setq pt2-snap (list (car pt2) (cadr pt2) 0.0))   ; MemoPRO: punto exacto
        (setq angulo (angle pt1 pt2-snap))
        (setq largo (distance pt1 pt2-snap))
        (setq largo-redondo (rs-redondear largo))

        (princ (strcat "\nLargo: " (rs-formato-2decimales largo-redondo) "m"))
        (setq ancho (rs:pedir-ancho pt1 pt2-snap))

        (if (and ancho (> ancho 0.0001))
          (progn
            ;; MemoPRO: el ancho ya no se redondea a 0.1 m
            (setq ancho-redondo (rs-redondear ancho))

            (setq p2 (polar pt1 (+ angulo (* rs:lado (/ pi 2))) ancho-redondo))
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

            (setq pos-cota-largo (polar pt1 (- angulo (* rs:lado (/ pi 2))) offset-cota))
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
          (princ "\nAncho invalido (debe ser mayor que 0).")))))
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
(defun c:RSC (/ pt1 pt2 pt3 cota-ent)
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
























;;; ==================================================================
;;; PARTE: LISP_Estimaciones/RenumerarRectangulos ( RV ).lsp
;;; ==================================================================
;;; ============================================================================
;;; RENUMERARVECINO.LSP - Versión MEJORADA v3.1
;;; Renumeración por vecino más cercano
;;; SOLO elimina números de los rectángulos SELECCIONADOS
;;; Números CENTRADOS y ALINEADOS con el LADO LARGO (usando vértices reales)
;;; ============================================================================

;;; Variable global
(setq *rectangulos-lista* '())

;;; ============================================================================
;;; FUNCIÓN: obtener-vertices-rectangulo
;;; Devuelve la lista de vértices del rectángulo
;;; ============================================================================
(defun obtener-vertices-rectangulo (ent / elist vertices x y)
  (setq elist (entget ent))
  (setq vertices '())
  
  (foreach item elist
    (if (= (car item) 10)
      (progn
        (setq x (cadr item))
        (setq y (caddr item))
        (setq vertices (append vertices (list (list x y 0.0))))
      )
    )
  )
  
  vertices
)

;;; ============================================================================
;;; FUNCIÓN: obtener-centro-rapido
;;; ============================================================================
(defun obtener-centro-rapido (ent / elist minx miny maxx maxy x y)
  (setq minx 1e308 miny 1e308 maxx -1e308 maxy -1e308)
  (setq elist (entget ent))
  
  (foreach item elist
    (if (= (car item) 10)
      (progn
        (setq x (cadr item))
        (setq y (caddr item))
        (if (< x minx) (setq minx x))
        (if (< y miny) (setq miny y))
        (if (> x maxx) (setq maxx x))
        (if (> y maxy) (setq maxy y))
      )
    )
  )
  
  (list (/ (+ minx maxx) 2) (/ (+ miny maxy) 2) 0.0)
)

;;; ============================================================================
;;; FUNCIÓN: distancia-2d
;;; Calcula la distancia entre dos puntos 2D
;;; ============================================================================
(defun distancia-2d (p1 p2)
  (sqrt (+ (expt (- (car p1) (car p2)) 2)
           (expt (- (cadr p1) (cadr p2)) 2)))
)

;;; ============================================================================
;;; FUNCIÓN: angulo-entre-puntos
;;; Calcula el ángulo entre dos puntos (en radianes)
;;; ============================================================================
(defun angulo-entre-puntos (p1 p2)
  (angle p1 p2)
)

;;; ============================================================================
;;; FUNCIÓN: obtener-datos-lado-largo-v2
;;; Analiza los vértices para encontrar el lado más largo y su ángulo
;;; Devuelve el ángulo del lado largo (ajustado para texto legible)
;;; ============================================================================
(defun obtener-datos-lado-largo-v2 (ent / vertices n i p1 p2 dist1 dist2 
                                       angulo-lado1 angulo-lado2 longitud-lado1 longitud-lado2)
  (setq vertices (obtener-vertices-rectangulo ent))
  (setq n (length vertices))
  
  (if (< n 4)
    ;; Si no hay suficientes vértices, usar método anterior
    (progn
      (setq angulo-lado1 0.0)
      (setq longitud-lado1 1.0)
      (setq longitud-lado2 1.0)
    )
    (progn
      ;; Calcular distancia del lado 0-1 y lado 1-2
      (setq p1 (nth 0 vertices))
      (setq p2 (nth 1 vertices))
      (setq longitud-lado1 (distancia-2d p1 p2))
      (setq angulo-lado1 (angulo-entre-puntos p1 p2))
      
      (setq p1 (nth 1 vertices))
      (setq p2 (nth 2 vertices))
      (setq longitud-lado2 (distancia-2d p1 p2))
      (setq angulo-lado2 (angulo-entre-puntos p1 p2))
      
      ;; Determinar cuál es el lado largo y devolver su ángulo
      ;; El texto va PARALELO al lado largo (no perpendicular)
      (if (> longitud-lado1 longitud-lado2)
        ;; Lado 1 es el largo - el texto va paralelo a este lado
        (setq angulo-lado1 angulo-lado1)
        ;; Lado 2 es el largo - el texto va paralelo a este lado
        (setq angulo-lado1 angulo-lado2)
      )
    )
  )
  
  ;; Normalizar el ángulo entre 0 y 2*pi
  (while (> angulo-lado1 (* 2 pi))
    (setq angulo-lado1 (- angulo-lado1 (* 2 pi)))
  )
  (while (< angulo-lado1 0)
    (setq angulo-lado1 (+ angulo-lado1 (* 2 pi)))
  )
  
  ;; Si el ángulo está entre 90° y 270° (pi/2 y 3*pi/2), 
  ;; el texto quedaría de cabeza, así que giramos 180°
  (if (and (> angulo-lado1 (/ pi 2))
           (< angulo-lado1 (* 1.5 pi)))
    (setq angulo-lado1 (+ angulo-lado1 pi))
  )
  
  ;; Normalizar nuevamente
  (while (> angulo-lado1 (* 2 pi))
    (setq angulo-lado1 (- angulo-lado1 (* 2 pi)))
  )
  (while (< angulo-lado1 0)
    (setq angulo-lado1 (+ angulo-lado1 (* 2 pi)))
  )
  
  ;; Devolver el ángulo
  angulo-lado1
)

;;; ============================================================================
;;; FUNCIÓN: distancia-entre-puntos
;;; ============================================================================
(defun distancia-entre-puntos (p1 p2)
  (sqrt (+ (expt (- (car p1) (car p2)) 2)
           (expt (- (cadr p1) (cadr p2)) 2)))
)

;;; ============================================================================
;;; FUNCIÓN: encontrar-vecino-mas-cercano
;;; ============================================================================
(defun encontrar-vecino-mas-cercano (punto lista-rectangulos visitados / 
                                      menor-distancia rect-cercano distancia ent)
  (setq menor-distancia 1e308)
  (setq rect-cercano nil)
  
  (foreach rect lista-rectangulos
    (setq ent (nth 0 rect))
    (if (not (member ent visitados))
      (progn
        (setq distancia (distancia-entre-puntos punto (nth 4 rect)))
        (if (< distancia menor-distancia)
          (progn
            (setq menor-distancia distancia)
            (setq rect-cercano rect)
          )
        )
      )
    )
  )
  
  rect-cercano
)

;;; ============================================================================
;;; FUNCIÓN: entidad-igual
;;; ============================================================================
(defun entidad-igual (ent1 ent2)
  (= (cdr (assoc 5 (entget ent1))) (cdr (assoc 5 (entget ent2))))
)

;;; ============================================================================
;;; FUNCIÓN: crear-estilo-texto-arial
;;; ============================================================================
(defun crear-estilo-texto-arial ()
  (if (not (tblsearch "STYLE" "ARIAL"))
    (command "._-STYLE" "ARIAL" "arial.ttf" "0" "1" "0" "N" "N" "N")
  )
)

;;; ============================================================================
;;; FUNCIÓN: punto-dentro-de-lista-centros
;;; Verifica si un punto está cerca de algún centro de la lista de rectángulos
;;; ============================================================================
(defun punto-dentro-de-lista-centros (punto lista-rects tolerancia / 
                                       centro dist encontrado)
  (setq encontrado nil)
  (foreach rect lista-rects
    (setq centro (nth 4 rect))
    (if centro
      (progn
        (setq dist (distancia-entre-puntos punto centro))
        (if (< dist tolerancia)
          (setq encontrado T)
        )
      )
    )
  )
  encontrado
)

;;; ============================================================================
;;; FUNCIÓN: borrar-textos-solo-seleccionados
;;; Elimina SOLO los textos que están cerca del centro de los rectángulos 
;;; que fueron SELECCIONADOS por el usuario
;;; ============================================================================
(defun borrar-textos-solo-seleccionados (lista-rects / contador-elim ent ent-data
                                          insert-point pt10 pt11 dist tolerancia
                                          lista-a-borrar)
  (setq contador-elim 0)
  (setq lista-a-borrar '())
  (setq tolerancia 2.0)  ; Tolerancia de distancia
  
  ;; PASO 1: Recorrer TODAS las entidades de texto en la capa
  (setq ent (entnext))
  
  (while ent
    (setq ent-data (entget ent))
    
    ;; Verificar si es TEXT y está en la capa NUMEROS_RECTANGULOS
    (if (and (= (cdr (assoc 0 ent-data)) "TEXT")
             (= (strcase (cdr (assoc 8 ent-data))) "NUMEROS_RECTANGULOS"))
      (progn
        ;; Obtener punto de inserción del texto
        (setq pt10 (cdr (assoc 10 ent-data)))
        (setq pt11 (cdr (assoc 11 ent-data)))
        
        ;; Usar pt11 si existe (texto justificado), sino pt10
        (if (and pt11 (/= (car pt11) 0.0) (/= (cadr pt11) 0.0))
          (setq insert-point pt11)
          (setq insert-point pt10)
        )
        
        ;; Verificar si el texto está cerca del centro de los rectángulos SELECCIONADOS
        (if (and insert-point 
                 (punto-dentro-de-lista-centros insert-point lista-rects tolerancia))
          (setq lista-a-borrar (cons ent lista-a-borrar))
        )
      )
    )
    
    (setq ent (entnext ent))
  )
  
  ;; PASO 2: Eliminar los textos encontrados
  (foreach ent-borrar lista-a-borrar
    (entdel ent-borrar)
    (setq contador-elim (1+ contador-elim))
  )
  
  ;; Retornar cantidad eliminada
  contador-elim
)

;;; ============================================================================
;;; FUNCIÓN: crear-texto-numero-alineado
;;; Crea el texto CENTRADO en el rectángulo y ALINEADO con el lado largo
;;; Usa ENTMAKE con códigos DXF correctos
;;; ============================================================================
(defun crear-texto-numero-alineado (ent-rect numero / altura centro angulo texto-str ent-texto ent-data)
  (setq altura 0.6)
  
  ;; Obtener centro del rectángulo
  (setq centro (obtener-centro-rapido ent-rect))
  
  ;; Obtener ángulo del lado largo (analizando vértices reales)
  (setq angulo (obtener-datos-lado-largo-v2 ent-rect))
  
  ;; Crear el texto como string
  (setq texto-str (itoa numero))
  
  ;; Crear texto usando ENTMAKE
  (entmake
    (list
      (cons 0 "TEXT")                    ; Tipo de entidad
      (cons 100 "AcDbEntity")            ; Subclase
      (cons 8 "NUMEROS_RECTANGULOS")     ; Capa
      (cons 100 "AcDbText")              ; Subclase
      (cons 10 centro)                   ; Punto de inserción
      (cons 40 altura)                   ; Altura del texto
      (cons 1 texto-str)                 ; Contenido del texto
      (cons 7 "ARIAL")                   ; Estilo de texto
      (cons 50 angulo)                   ; Rotación en radianes
      (cons 100 "AcDbText")              ; Subclase
    )
  )
  
  ;; Obtener la entidad creada
  (setq ent-texto (entlast))
  (setq ent-data (entget ent-texto))
  
  ;; Agregar justificación Middle Center
  (setq ent-data 
    (append ent-data
      (list
        (cons 72 4)      ; Alineación horizontal: 4 = Centro
        (cons 11 centro) ; Punto de alineación
      )
    )
  )
  (entmod ent-data)
  
  ;; Agregar alineación vertical
  (setq ent-data (entget ent-texto))
  (setq ent-data 
    (append ent-data
      (list
        (cons 73 2)      ; Alineación vertical: 2 = Medio
      )
    )
  )
  (entmod ent-data)
)

;;; ============================================================================
;;; FUNCIÓN: actualizar-xdata-rectangulo
;;; ============================================================================
(defun actualizar-xdata-rectangulo (ent nuevo-numero largo ancho / xdata app-name nueva-xdata)
  ;; Obtener XDATA actual
  (setq xdata (entget ent '("RECTANGULOS_APP")))
  
  (if (assoc -3 xdata)
    (progn
      ;; Obtener nombre de la aplicación
      (setq app-name (car (cdr (assoc -3 xdata))))
      (setq app-name (car app-name))
      
      ;; Crear nueva XDATA
      (setq nueva-xdata (list -3 
                              (list app-name
                                    (cons 1000 (itoa nuevo-numero))
                                    (cons 1040 largo)
                                    (cons 1040 ancho))))
      
      ;; Actualizar entidad
      (entmod (subst nueva-xdata (assoc -3 xdata) xdata))
    )
  )
)

;;; ============================================================================
;;; FUNCIÓN: reconstruir-lista-desde-dibujo
;;; ============================================================================
(defun reconstruir-lista-desde-dibujo (/ ss i ent xdata datos num largo ancho)
  (setq ss (ssget "X" '((8 . "GEOMETRIA_RECTANGULOS"))))
  (setq *rectangulos-lista* '())
  
  (if ss
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq ent (ssname ss i))
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
            
            (setq *rectangulos-lista* 
                  (append *rectangulos-lista* 
                         (list (list num largo ancho))))
          )
        )
        (setq i (1+ i))
      )
    )
  )
)

;;; ============================================================================
;;; COMANDO: RENUMERARVECINO (RV)
;;; ============================================================================
(defun c:RENUMERARVECINO (/ old-cmdecho old-clayer ss i ent 
                            xdata lista-rectangulos nuevo-numero contador
                            rectangulo datos num-viejo largo ancho
                            punto-inicial rect-actual visitados centro
                            ent-inicial opcion num-buscar encontrado ent-lista
                            textos-eliminados)
  
  ;; Guardar variables
  (setq old-cmdecho (getvar "CMDECHO"))
  (setq old-clayer (getvar "CLAYER"))
  (setvar "CMDECHO" 0)
  
  (princ "\n")
  (princ "\n+--------------------------------------------------------------+")
  (princ "\n¦       RENUMERARVECINO v3.1                                   ¦")
  (princ "\n¦       Renumeración por vecino más cercano                    ¦")
  (princ "\n+--------------------------------------------------------------+")
  
  ;; Crear estilo ARIAL si no existe
  (crear-estilo-texto-arial)
  
  ;; Seleccionar rectángulos a renumerar
  (princ "\nSeleccione los rectángulos a renumerar (o Enter para todos): ")
  (setq ss (ssget '((8 . "GEOMETRIA_RECTANGULOS"))))
  
  (if (not ss)
    (princ "\nNo se seleccionaron rectángulos.")
    (progn
      (princ (strcat "\nRectángulos seleccionados: " (itoa (sslength ss))))
      
      ;; Crear lista con los rectángulos seleccionados y sus datos
      (setq lista-rectangulos '())
      (setq i 0)
      
      (repeat (sslength ss)
        (setq ent (ssname ss i))
        (setq xdata (entget ent '("RECTANGULOS_APP")))
        
        (if (assoc -3 xdata)
          (progn
            (setq datos (cdr (assoc -3 xdata)))
            (setq datos (car datos))
            (setq datos (cdr datos))
            
            (setq num-viejo (atoi (cdr (assoc 1000 datos))))
            (setq largo (cdr (assoc 1040 datos)))
            (setq datos (cdr (member (assoc 1040 datos) datos)))
            (setq ancho (cdr (assoc 1040 datos)))
            (setq centro (obtener-centro-rapido ent))
            
            (setq lista-rectangulos 
                  (append lista-rectangulos 
                         (list (list ent num-viejo largo ancho centro))))
          )
        )
        (setq i (1+ i))
      )
      
      (princ (strcat "\nRectángulos con datos XDATA: " (itoa (length lista-rectangulos))))
      
      (if (= (length lista-rectangulos) 0)
        (princ "\nNingún rectángulo seleccionado tiene datos XDATA.")
        (progn
          ;; Preguntar número inicial
          (initget 4)
          (setq nuevo-numero (getint "\nNúmero inicial para la renumeración: "))
          (if (not nuevo-numero)
            (setq nuevo-numero 1)
          )
          
          ;; Preguntar método de selección del rectángulo inicial
          (initget "Seleccionar Numero")
          (setq opcion (getkword "\n¿Seleccionar rectángulo inicial por [Seleccionar/Numero]? <Seleccionar>: "))
          
          (if (or (not opcion) (= opcion "Seleccionar"))
            (progn
              ;; SELECCIÓN GRÁFICA
              (setq ent-inicial (car (entsel "\nSeleccione el rectángulo inicial: ")))
              
              (if (not ent-inicial)
                (princ "\nNo se seleccionó rectángulo inicial.")
                (progn
                  ;; Buscar el rectángulo seleccionado en la lista
                  (setq rect-actual nil)
                  (setq encontrado nil)
                  (foreach rect lista-rectangulos
                    (setq ent-lista (car rect))
                    (if (entidad-igual ent-lista ent-inicial)
                      (progn
                        (setq rect-actual rect)
                        (setq encontrado T)
                      )
                    )
                  )
                  
                  (if (not encontrado)
                    (princ "\nEl rectángulo seleccionado no tiene datos XDATA válidos.")
                  )
                )
              )
            )
            (progn
              ;; SELECCIÓN POR NÚMERO
              (princ "\nRectángulos disponibles:")
              (foreach rect lista-rectangulos
                (princ (strcat "\n  Número " (itoa (cadr rect)) " - Ubicación: " 
                       (rtos (car (nth 4 rect)) 2 2) "," 
                       (rtos (cadr (nth 4 rect)) 2 2)))
              )
              
              (setq num-buscar (getint "\nIngrese el NÚMERO del rectángulo inicial: "))
              
              ;; Buscar el rectángulo con ese número
              (setq rect-actual nil)
              (foreach rect lista-rectangulos
                (if (= (cadr rect) num-buscar)
                  (setq rect-actual rect)
                )
              )
              
              (if (not rect-actual)
                (princ "\nNo se encontró un rectángulo con ese número.")
              )
            )
          )
          
          ;; Si se encontró el rectángulo inicial, proceder con la renumeración
          (if rect-actual
            (progn
              (setvar "CLAYER" "NUMEROS_RECTANGULOS")
              
              ;; ============================================================
              ;; ELIMINAR SOLO LOS NÚMEROS DE LOS RECTÁNGULOS SELECCIONADOS
              ;; ============================================================
              (princ "\n")
              (princ "\nEliminando números anteriores de la selección...")
              (setq textos-eliminados (borrar-textos-solo-seleccionados lista-rectangulos))
              (princ (strcat "\n? " (itoa textos-eliminados) " números eliminados de la selección."))
              (princ "\n")
              
              ;; ============================================================
              ;; INICIAR RENUMERACIÓN
              ;; ============================================================
              (setq contador nuevo-numero)
              (setq visitados (list (car rect-actual)))
              
              ;; Renumerar el primer rectángulo
              (setq ent (car rect-actual))
              (setq num-viejo (cadr rect-actual))
              (setq largo (caddr rect-actual))
              (setq ancho (cadddr rect-actual))
              (setq centro (nth 4 rect-actual))
              
              ;; Actualizar XDATA
              (actualizar-xdata-rectangulo ent contador largo ancho)
              
              ;; Crear nuevo texto centrado y alineado al lado largo
              (crear-texto-numero-alineado ent contador)
              
              (princ (strcat "\nRectángulo " (itoa num-viejo) " ? " (itoa contador)))
              (setq contador (1+ contador))
              (setq punto-inicial centro)
              
              ;; Renumerar el resto por vecino más cercano
              (while (< (length visitados) (length lista-rectangulos))
                (setq rect-actual (encontrar-vecino-mas-cercano 
                                    punto-inicial lista-rectangulos visitados))
                
                (if rect-actual
                  (progn
                    (setq ent (car rect-actual))
                    (setq num-viejo (cadr rect-actual))
                    (setq largo (caddr rect-actual))
                    (setq ancho (cadddr rect-actual))
                    (setq centro (nth 4 rect-actual))
                    
                    ;; Actualizar XDATA
                    (actualizar-xdata-rectangulo ent contador largo ancho)
                    
                    ;; Crear nuevo texto centrado y alineado al lado largo
                    (crear-texto-numero-alineado ent contador)
                    
                    (princ (strcat "\nRectángulo " (itoa num-viejo) " ? " (itoa contador)))
                    
                    (setq visitados (append visitados (list ent)))
                    (setq punto-inicial centro)
                    (setq contador (1+ contador))
                  )
                )
              )
              
              (princ "\n")
              (princ "\n------------------------------------------------------------")
              (princ (strcat "\n? Renumeración completada. Último número: " (itoa (1- contador))))
              (princ "\n------------------------------------------------------------")
              
              ;; Reconstruir la lista global
              (reconstruir-lista-desde-dibujo)
            )
          )
        )
      )
    )
  )
  
  ;; Restaurar variables
  (setvar "CMDECHO" old-cmdecho)
  (setvar "CLAYER" old-clayer)
  (princ)
)

;;; ============================================================================
;;; COMANDO CORTO: RV
;;; ============================================================================
(defun c:BNUM ()
  (c:RENUMERARVECINO)
)

;;; ============================================================================
;;; MENSAJE DE CARGA
;;; ============================================================================

















;;; ==================================================================
;;; PARTE: LISP_Estimaciones/COTAR_BACHES  (COTB ).lsp
;;; ==================================================================
(vl-load-com)
;; ===================================================================
;; COTAR_BACHES v2.1
;; ===================================================================
;; Rutina que anota el LARGO y ANCHO de cada rectángulo (bache)
;; en la capa "GEOMETRIA_RECTANGULOS", colocando un SOLO texto
;; de largo y un SOLO texto de ancho por rectángulo.
;;
;; CONFIGURACIÓN:
;;   - Capa origen:    GEOMETRIA_RECTANGULOS  (donde están los rects)
;;   - Capa destino:   COTAS_RECTANGULOS      (donde se crean los textos)
;;   - Estilo texto:   MONOTXT
;;   - Altura texto:   0.45
;;   - Relación A/H:   0.70
;;   - Precisión:      2 decimales (sin suprimir ceros)
;;
;; COMANDO: COTAR_BACHES
;;
;; NOTA: Cada vez que se ejecuta, elimina los textos existentes
;;       en la capa COTAS_RECTANGULOS y los recrea.
;;
;; v2.0: Correccion de justificacion vertical dinamica.
;;       Elige Superior/Inferior automaticamente para que el
;;       cuerpo del texto SIEMPRE quede fuera del rectangulo.
;; v2.1: Rotacion > 90 grados -> suma 180 para evitar texto volteado.
;; ===================================================================

(defun c:COTB ( /
  ;; -- Configuración ------------------------------------------
  layer_src layer_dst style_name text_h width_f offset_dist
  round_dec tol
  ;; -- Selección ----------------------------------------------
  ss ss_old j
  ;; -- Entidad ------------------------------------------------
  ent data pts z pt closed_flag
  ;; -- Geometría ----------------------------------------------
  d01 d12 d23 d30 lado_a lado_b
  largo ancho es_cuadrado
  p_l1 p_l2 p_a1 p_a2
  mid_l mid_a ang_l ang_a
  norm_l norm_a pos_l pos_a
  cx cy centroid
  ;; -- Texto --------------------------------------------------
  text_l text_a vjust_l vjust_a
  ;; -- Contadores ---------------------------------------------
  i n_rect n_skip
  ;; -- Temporales ---------------------------------------------
  old_cmdecho old_dimzin
  norm_ang top_body_dot
)

  ;; --------------------------------------------------------------
  ;;                    CONFIGURACIÓN
  ;; --------------------------------------------------------------
  (setq layer_src   "GEOMETRIA_RECTANGULOS")
  (setq layer_dst   "COTAS_RECTANGULOS")
  (setq style_name  "MONOTXT")
  (setq text_h      0.45)
  (setq width_f     0.70)
  (setq offset_dist 0.25)   ;; Separación del texto al borde
  (setq round_dec   2)       ;; Decimales
  (setq tol         0.01)    ;; Tolerancia para igualdad de lados

  ;; Guardar estado
  (setq old_cmdecho (getvar "CMDECHO"))
  (setq old_dimzin  (getvar "DIMZIN"))
  (setvar "CMDECHO" 0)
  (setvar "DIMZIN"  0)    ;; No suprimir ceros: "1.00" en vez de "1"

  (prompt "\n")
  (prompt "+----------------------------------------------------+")
  (prompt "\n¦       COTAR_BACHES v2.1 - Cotar Baches          ¦")
  (prompt "\n+----------------------------------------------------+")

  ;; --------------------------------------------------------------
  ;;         PASO 1: ELIMINAR TEXTOS EXISTENTES EN CAPA DESTINO
  ;; --------------------------------------------------------------
  (prompt (strcat "\nLimpiando textos previos en capa '" layer_dst "'..."))
  (setq ss_old (ssget "_X" (list '(0 . "*TEXT") (cons 8 layer_dst))))
  (if ss_old
    (progn
      (setq j 0)
      (while (< j (sslength ss_old))
        (entdel (ssname ss_old j))
        (setq j (1+ j))
      )
      (prompt (strcat "\n  Eliminados " (itoa (sslength ss_old)) " texto(s) anterior(es)."))
    )
    (prompt "\n  No hay textos previos que limpiar.")
  )

  ;; --------------------------------------------------------------
  ;;         PASO 2: CREAR CAPA DESTINO SI NO EXISTE
  ;; --------------------------------------------------------------
  (if (not (tblsearch "LAYER" layer_dst))
    (progn
      (entmake
        (list '(0 . "LAYER")
              '(100 . "AcDbSymbolTableRecord")
              '(100 . "AcDbLayerTableRecord")
              (cons 2 layer_dst)
              '(70 . 0)              ;; No congelada, no bloqueada
              '(62 . 7)              ;; Color blanco (7)
              '(6 . "CONTINUOUS")))  ;; Tipo de línea
      (prompt (strcat "\n  Creada capa '" layer_dst "'."))
    )
  )

  ;; --------------------------------------------------------------
  ;;         PASO 3: VERIFICAR ESTILO DE TEXTO
  ;; --------------------------------------------------------------
  (if (not (tblsearch "STYLE" style_name))
    (progn
      (prompt (strcat "\n  El estilo '" style_name "' no existe."))
      (prompt "\n  Intentando crear estilo con fuente simplex.shx...")
      (entmake
        (list '(0 . "STYLE")
              '(100 . "AcDbSymbolTableRecord")
              '(100 . "AcDbTextStyleTableRecord")
              (cons 2 style_name)
              '(70 . 0)          ;; No backward, no vertical
              '(40 . 0.0)        ;; Altura variable (se define al crear)
              '(41 . 1.0)        ;; Width factor default del estilo
              '(50 . 0.0)        ;; Angulo oblicuo
              '(71 . 0)          ;; Generation flags
              '(42 . 0.2)        ;; Ultima altura usada
              '(3 . "simplex.shx")  ;; Fuente
              '(4 . "")))        ;; Big font (ninguno)
      (if (tblsearch "STYLE" style_name)
        (prompt (strcat "\n  Creado estilo '" style_name "' con simplex.shx."))
        (prompt "\n  ERROR: No se pudo crear el estilo. Verifique permisos.")
      )
    )
  )

  ;; --------------------------------------------------------------
  ;;         PASO 4: SELECCIONAR RECTÁNGULOS
  ;; --------------------------------------------------------------
  (setq ss (ssget "_X" (list '(0 . "LWPOLYLINE") (cons 8 layer_src))))

  (if (not ss)
    (progn
      (prompt (strcat "\n\n  No se encontraron polilineas en la capa '"
                      layer_src "'."))
      (prompt (strcat "\n  Verifique que la capa exista y tenga objetos."))
      (setvar "CMDECHO" old_cmdecho)
      (setvar "DIMZIN"  old_dimzin)
      (princ)
      (exit)
    )
  )

  (prompt (strcat "\n  Encontrados " (itoa (sslength ss))
                  " objeto(s) en '" layer_src "'."))

  ;; --------------------------------------------------------------
  ;;         PASO 5: PROCESAR CADA RECTÁNGULO
  ;; --------------------------------------------------------------
  (setq i 0)
  (setq n_rect 0)
  (setq n_skip 0)

  (while (< i (sslength ss))
    (setq ent  (ssname ss i))
    (setq data (entget ent))

    ;; 5a. Verificar que sea polilinea CERRADA
    (setq closed_flag (cdr (assoc 70 data)))
    (if (/= (logand closed_flag 1) 1)
      (progn
        (prompt "\n  Advertencia: Polilinea no cerrada. Saltando.")
        (setq n_skip (1+ n_skip))
        (setq i (1+ i))
      ) ;; fin progn skip
      (progn ;; polilinea CERRADA -> procesar

        ;; 5b. Obtener elevación Z
        (setq z (cdr (assoc 38 data)))
        (if (null z) (setq z 0.0))

        ;; 5c. Extraer vértices y convertir de OCS a WCS
        (setq pts nil)
        (foreach item data
          (if (= (car item) 10)
            (progn
              (setq pt (list (cadr item) (caddr item) z))
              (setq pt (trans pt ent 0))   ;; OCS -> WCS
              (setq pts (cons pt pts))
            )
          )
        )
        (setq pts (reverse pts))

        ;; 5d. Procesar solo si tiene exactamente 4 vértices
        (if (/= (length pts) 4)
          (progn
            (setq n_skip (1+ n_skip))
          )
          (progn
            ;; --------------------------------------------------
            ;;  CALCULAR LADOS Y CENTROIDE
            ;; --------------------------------------------------
            (setq d01 (distance (nth 0 pts) (nth 1 pts)))
            (setq d12 (distance (nth 1 pts) (nth 2 pts)))
            (setq d23 (distance (nth 2 pts) (nth 3 pts)))
            (setq d30 (distance (nth 3 pts) (nth 0 pts)))

            (setq lado_a (/ (+ d01 d23) 2.0))
            (setq lado_b (/ (+ d12 d30) 2.0))

            (setq cx (/ (+ (car (nth 0 pts)) (car (nth 1 pts))
                           (car (nth 2 pts)) (car (nth 3 pts))) 4.0))
            (setq cy (/ (+ (cadr (nth 0 pts)) (cadr (nth 1 pts))
                           (cadr (nth 2 pts)) (cadr (nth 3 pts))) 4.0))
            (setq centroid (list cx cy))

            ;; --------------------------------------------------
            ;;  IDENTIFICAR LARGO vs ANCHO
            ;; --------------------------------------------------
            (if (< (abs (- lado_a lado_b)) tol)
              (progn
                (setq es_cuadrado T)
                (setq largo lado_a)
                (setq p_l1 (nth 0 pts) p_l2 (nth 1 pts))
              )
              (if (> lado_a lado_b)
                (progn
                  (setq es_cuadrado nil)
                  (setq largo lado_a  ancho lado_b)
                  (setq p_l1 (nth 0 pts) p_l2 (nth 1 pts))
                  (setq p_a1 (nth 1 pts) p_a2 (nth 2 pts))
                )
                (progn
                  (setq es_cuadrado nil)
                  (setq largo lado_b  ancho lado_a)
                  (setq p_l1 (nth 1 pts) p_l2 (nth 2 pts))
                  (setq p_a1 (nth 0 pts) p_a2 (nth 1 pts))
                )
              )
            )

            ;; --------------------------------------------------
            ;;  CREAR TEXTO DEL LARGO
            ;; --------------------------------------------------
            (setq mid_l (list (/ (+ (car p_l1) (car p_l2)) 2.0)
                              (/ (+ (cadr p_l1) (cadr p_l2)) 2.0)))
            (setq ang_l (angle p_l1 p_l2))
            ;; Corregir rotacion para que nunca quede boca abajo:
            ;; Normalizar a [0, 2*pi) y voltear si esta entre 90 y 270
            (while (< ang_l 0.0) (setq ang_l (+ ang_l (* 2.0 pi))))
            (while (>= ang_l (* 2.0 pi)) (setq ang_l (- ang_l (* 2.0 pi))))
            (if (and (>= ang_l (* 0.5 pi)) (< ang_l (* 1.5 pi)))
              (setq ang_l (+ ang_l pi))
            )
            ;; Normal apuntando hacia afuera
            (setq norm_l (CB:get-outward-normal p_l1 p_l2 centroid))
            ;; Posición del texto
            (setq pos_l (list (+ (car mid_l) (* (car norm_l) offset_dist))
                              (+ (cadr mid_l) (* (cadr norm_l) offset_dist))
                              0.0))
            ;; -- Justificación vertical DINÁMICA -------------
            ;; Verificar si el cuerpo del texto se extiende hacia
            ;; afuera o hacia adentro con justificación Superior (73=3).
            ;; Si se mete adentro, usar Inferior (73=0).
            (setq norm_ang (atan (cadr norm_l) (car norm_l)))
            (setq top_body_dot
              (+ (* (cos (- ang_l (/ pi 2.0))) (cos norm_ang))
                 (* (sin (- ang_l (/ pi 2.0))) (sin norm_ang))))
            (if (> top_body_dot 0.0)
              (setq vjust_l 3)   ;; Superior: cuerpo va hacia afuera
              (setq vjust_l 0)   ;; Inferior: cuerpo va hacia afuera
            )
            ;; Valor del texto (2 decimales, sin suprimir ceros)
            (setq text_l (rtos largo 2 round_dec))

            ;; Crear la entidad TEXT
            (entmake
              (list '(0 . "TEXT")
                    (cons 10 pos_l)
                    (cons 11 pos_l)
                    (cons 40 text_h)
                    (cons 41 width_f)
                    (cons 1  text_l)
                    (cons 50 ang_l)
                    (cons 7  style_name)
                    (cons 8  layer_dst)
                    '(72 . 1)              ;; Horizontal: Centro
                    (cons 73 vjust_l)))    ;; Vertical: dinámica

            ;; --------------------------------------------------
            ;;  CREAR TEXTO DEL ANCHO (solo si NO es cuadrado)
            ;; --------------------------------------------------
            (if (not es_cuadrado)
              (progn
                (setq mid_a (list (/ (+ (car p_a1) (car p_a2)) 2.0)
                                  (/ (+ (cadr p_a1) (cadr p_a2)) 2.0)))
                (setq ang_a (angle p_a1 p_a2))
                ;; Corregir rotacion para que nunca quede boca abajo:
                ;; Normalizar a [0, 2*pi) y voltear si esta entre 90 y 270
                (while (< ang_a 0.0) (setq ang_a (+ ang_a (* 2.0 pi))))
                (while (>= ang_a (* 2.0 pi)) (setq ang_a (- ang_a (* 2.0 pi))))
                (if (and (>= ang_a (* 0.5 pi)) (< ang_a (* 1.5 pi)))
                  (setq ang_a (+ ang_a pi))
                )
                (setq norm_a (CB:get-outward-normal p_a1 p_a2 centroid))
                (setq pos_a (list (+ (car mid_a) (* (car norm_a) offset_dist))
                                  (+ (cadr mid_a) (* (cadr norm_a) offset_dist))
                                  0.0))
                ;; -- Justificación vertical DINÁMICA ---------
                (setq norm_ang (atan (cadr norm_a) (car norm_a)))
                (setq top_body_dot
                  (+ (* (cos (- ang_a (/ pi 2.0))) (cos norm_ang))
                     (* (sin (- ang_a (/ pi 2.0))) (sin norm_ang))))
                (if (> top_body_dot 0.0)
                  (setq vjust_a 3)
                  (setq vjust_a 0)
                )
                ;; Valor del texto
                (setq text_a (rtos ancho 2 round_dec))

                ;; Crear la entidad TEXT
                (entmake
                  (list '(0 . "TEXT")
                        (cons 10 pos_a)
                        (cons 11 pos_a)
                        (cons 40 text_h)
                        (cons 41 width_f)
                        (cons 1  text_a)
                        (cons 50 ang_a)
                        (cons 7  style_name)
                        (cons 8  layer_dst)
                        '(72 . 1)
                        (cons 73 vjust_a)))
              )
            ) ;; fin if not cuadrado

            (setq n_rect (1+ n_rect))

          ) ;; fin progn 4 vértices
        ) ;; fin if 4 vértices

      ) ;; fin progn cerrada
    ) ;; fin if cerrada

    (setq i (1+ i))
  ) ;; fin while

  ;; --------------------------------------------------------------
  ;;                    RESULTADO FINAL
  ;; --------------------------------------------------------------
  (prompt "\n")
  (prompt (strcat "\n  Resultado: " (itoa n_rect) " rectangulo(s) cotado(s)."))
  (if (> n_skip 0)
    (prompt (strcat "\n  Omitidos: " (itoa n_skip)
                    " objeto(s) (no cerrados o sin 4 vertices)."))
  (prompt "\n")
  )

  ;; Restaurar estado
  (setvar "CMDECHO" old_cmdecho)
  (setvar "DIMZIN"  old_dimzin)
  (princ)
)


;; ===================================================================
;; FUNCIÓN AUXILIAR: CB:get-outward-normal
;; ===================================================================
;; Calcula la normal unitaria (2D) de un lado de polígono que apunta
;; HACIA AFUERA (alejada del centroide).
;; ===================================================================
(defun CB:get-outward-normal (p1 p2 centroid /
                               dx dy len nx1 ny1 nx2 ny2
                               mx my d1 d2)

  (setq dx (- (car p2) (car p1)))
  (setq dy (- (cadr p2) (cadr p1)))
  (setq len (sqrt (+ (* dx dx) (* dy dy))))
  (if (< len 1e-10) (setq len 1e-10))

  (setq nx1  (/  dy len))
  (setq ny1  (- (/ dx len)))
  (setq nx2  (- (/ dy len)))
  (setq ny2  (/  dx len))

  (setq mx (/ (+ (car p1) (car p2)) 2.0))
  (setq my (/ (+ (cadr p1) (cadr p2)) 2.0))

  (setq d1 (+ (* (- (+ mx nx1) (car centroid))
                 (- (+ mx nx1) (car centroid)))
              (* (- (+ my ny1) (cadr centroid))
                 (- (+ my ny1) (cadr centroid)))))
  (setq d2 (+ (* (- (+ mx nx2) (car centroid))
                 (- (+ mx nx2) (car centroid)))
              (* (- (+ my ny2) (cadr centroid))
                 (- (+ my ny2) (cadr centroid)))))

  (if (> d1 d2)
    (list nx1 ny1)
    (list nx2 ny2)
  )
)


;; ===================================================================
;; CARGA DE LA RUTINA
;; ===================================================================















;;; ==================================================================
;;; PARTE: LISP_Estimaciones/ExportaRectangulos ( EXR ).lsp
;;; ==================================================================
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
    (setq volumen (redondear-2-decimales (* area (memo:cfg-num "BACHEO_ESPESOR"))))
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












;;; ==================================================================
;;; PARTE: @fuente/BACHEO_HR.lsp
;;; ==================================================================
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


;;; ==================================================================
;;; PARTE: LISP_Estimaciones/BorrarTextoEnRect.lsp
;;; ==================================================================
(defun c:BTR (/ ss_rect i ent_rect ent_data pts pt z j ent_text del_list)
  (vl-load-com)
  
  (prompt "\nSeleccione los rectángulos (polilíneas) para procesar: ")
  ; Seleccionamos solo LWPOLYLINE
  (if (setq ss_rect (ssget '((0 . "LWPOLYLINE"))))
    (progn
      (setq i 0)
      (setq del_list nil)
      
      (prompt "\nAnalizando geometría y buscando textos...")
      
      (while (< i (sslength ss_rect))
        (setq ent_rect (ssname ss_rect i))
        (setq ent_data (entget ent_rect))
        
        ; 1. Obtener elevación (Z)
        (setq z (cdr (assoc 38 ent_data)))
        (if (null z) (setq z 0.0))
        
        ; 2. Construir lista de puntos para el polígono
        (setq pts nil)
        (foreach item ent_data
          (if (= (car item) 10)
            (progn
              ; Construir punto 3D en OCS
              (setq pt (list (cadr item) (caddr item) z))
              ; Convertir a UCS actual (Donde trabaja ssget)
              (setq pt (trans pt ent_rect 1))
              ; IMPORTANTE: ssget "WP" prefiere puntos 2D proyectados en el plano actual
              ; Extraemos solo X e Y para evitar errores de "cadena de modo"
              (setq pts (cons (list (car pt) (cadr pt)) pts))
            )
          )
        )
        
        ; 3. Seleccionar textos con "_WP" (Window Polygon)
        ; El guion bajo _ asegura compatibilidad de idioma
        (if pts
          ; Intentamos seleccionar textos. Ignoramos errores si la vista no es válida para WP
          (setq ss_text (ssget "_WP" pts '((0 . "*TEXT"))))
        )
        
        ; 4. Agregar a la lista de eliminación
        (if ss_text
          (progn
            (setq j 0)
            (while (< j (sslength ss_text))
              (setq ent_text (ssname ss_text j))
              (if (not (member ent_text del_list))
                (setq del_list (cons ent_text del_list))
              )
              (setq j (1+ j))
            )
          )
        )
        (setq i (1+ i))
      )
      
      ; 5. Eliminar
      (if del_list
        (progn
          (foreach txt del_list (entdel txt))
          (prompt (strcat "\nListo. Se eliminaron " (itoa (length del_list)) " textos."))
        )
        (prompt "\nNo se encontraron textos dentro de los rectángulos.")
      )
    )
    (prompt "\nNo se seleccionaron objetos.")
  )
  (princ)
)
(princ "\nMEMO_Bacheo cargado: RS, BNUM, COTB, EXR, HR, BTR, RSC, AEC, RC2, RSHATCH, RS-CONFIG, VERLISTA, VERXDATA, AXD (MBACHEO = flujo guiado)")
(princ)
