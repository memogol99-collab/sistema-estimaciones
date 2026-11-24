;;; =====================================================================
;;;  MEMO_Lib.lsp  -  Biblioteca común del MemoPRO
;;;  Se carga al abrir cada dibujo (es pequeña). Todas las funciones
;;;  llevan el prefijo memo: para no chocar con ningún otro LISP.
;;;
;;;   Configuración : memo:cfg  memo:cfg-num  memo:cfg-set
;;;   Portapapeles  : memo:portapapeles
;;;   Tablas Excel  : memo:tsv-normalizar  memo:leer-datos-tabla  memo:pedir-texto
;;;   Ejecución     : memo:ejecutar  memo:envolver (Deshacer agrupado y ESC seguro)
;;;   Utilidades    : memo:split  memo:recortar  memo:contar-lineas
;;;                   memo:llamar  memo:opcion
;;; =====================================================================
(vl-load-com)

;;; ---------------------------------------------------------------------
;;; CONFIGURACIÓN
;;; Los valores por defecto (memo:*cfg-def*) los define MEMO_Cargador.lsp
;;; a partir de catalogo.py. Lo que el usuario cambia con MEMO_CONFIG se
;;; guarda con setenv (registro de Windows, perfil de AutoCAD), así que
;;; sobrevive a reinstalar o actualizar el sistema.
;;; ---------------------------------------------------------------------
(defun memo:cfg (clave / v d)
  (setq v (getenv (strcat "MEMO_" clave)))
  (if (and v (/= v ""))
    v
    (if (setq d (assoc clave memo:*cfg-def*)) (cadr d) "")
  )
)

(defun memo:cfg-num (clave / v)
  (setq v (distof (memo:cfg clave) 2))
  (if v v 0.0)
)

(defun memo:cfg-set (clave valor)
  (setenv (strcat "MEMO_" clave) valor)
)

;;; ---------------------------------------------------------------------
;;; UTILIDADES
;;; ---------------------------------------------------------------------
(defun memo:split (txt sep / pos res)
  (while (setq pos (vl-string-search sep txt))
    (setq res (cons (substr txt 1 pos) res)
          txt (substr txt (+ pos 1 (strlen sep))))
  )
  (reverse (cons txt res))
)

(defun memo:recortar (txt n)
  (if (> (strlen txt) n) (strcat (substr txt 1 (- n 3)) "...") txt)
)

(defun memo:contar-lineas (txt)
  (length (vl-remove "" (memo:split txt "\n")))
)

;; Ejecuta un comando MEMO (aunque todavía no esté cargado)
(defun memo:llamar (cmd)
  (eval (list (read (strcat "C:" cmd))))
)

;; Pregunta una opción con valor por defecto. kws = "Uno Dos Tres"
(defun memo:opcion (msg kws def / r)
  (initget kws)
  (setq r (getkword (strcat msg " [" (vl-string-translate " " "/" kws) "] <" def ">: ")))
  (if r r def)
)

;;; ---------------------------------------------------------------------
;;; PORTAPAPELES
;;; 1) Objeto COM "htmlfile" (rápido, sin ventanas).
;;; 2) Si no existe en el equipo: PowerShell Get-Clipboard (más lento).
;;; Devuelve el texto copiado o nil.
;;; ---------------------------------------------------------------------
(defun memo:portapapeles-html (/ html res)
  (setq res
    (vl-catch-all-apply
      '(lambda ()
         (setq html (vlax-create-object "htmlfile"))
         (vlax-invoke
           (vlax-get (vlax-get html 'ParentWindow) 'ClipboardData)
           'GetData "Text")
       )
    )
  )
  (if html (vl-catch-all-apply 'vlax-release-object (list html)))
  (if (and (not (vl-catch-all-error-p res)) (= (type res) 'STR) (/= res ""))
    res
  )
)

(defun memo:portapapeles-ps (/ tmp wsh f lin txt)
  (setq tmp (vl-filename-mktemp "memo_pp" nil ".txt"))
  (vl-catch-all-apply
    '(lambda ()
       (setq wsh (vlax-create-object "WScript.Shell"))
       (vlax-invoke-method wsh 'Run
         (strcat "powershell -NoProfile -ExecutionPolicy Bypass -Command "
                 "\"Get-Clipboard -Raw | Set-Content -Encoding Default -LiteralPath '"
                 tmp "'\"")
         0 :vlax-true)
     )
  )
  (if wsh (vl-catch-all-apply 'vlax-release-object (list wsh)))
  (if (and (findfile tmp) (setq f (open tmp "r")))
    (progn
      (while (setq lin (read-line f))
        (setq txt (if txt (strcat txt "\n" lin) lin))
      )
      (close f)
      (vl-file-delete tmp)
    )
  )
  (if (and txt (/= txt "")) txt)
)

(defun memo:portapapeles ()
  (cond ((memo:portapapeles-html)) ((memo:portapapeles-ps)))
)

;;; ---------------------------------------------------------------------
;;; TEXTO COPIADO DE EXCEL (columnas separadas por TAB)
;;; - Quita los retornos de carro (\r).
;;; - Las celdas con salto de línea interno vienen "entre comillas":
;;;   se unen en una sola línea y se quitan las comillas.
;;; - Elimina líneas vacías.
;;; Devuelve las filas separadas por \n (con \n final, igual que cuando
;;; se pegaban a mano), o nil si no hay datos.
;;; ---------------------------------------------------------------------
(defun memo:tsv-normalizar (txt / cs acc dentro c res)
  (setq cs (vl-string->list txt))
  (while cs
    (setq c (car cs) cs (cdr cs))
    (cond
      ((= c 13))                                        ; \r
      ((= c 34)                                         ; comilla
       (cond
         ((and dentro (= (car cs) 34))                  ; "" escapada
          (setq acc (cons 34 acc) cs (cdr cs)))
         (dentro (setq dentro nil))
         ((or (null acc) (member (car acc) '(9 10)))    ; inicio de celda
          (setq dentro T))
         (T (setq acc (cons c acc)))))
      ((and dentro (= c 10)) (setq acc (cons 32 acc)))  ; salto dentro de celda
      (T (setq acc (cons c acc)))
    )
  )
  (foreach lin (memo:split (vl-list->string (reverse acc)) "\n")
    (if (/= (vl-string-trim " \t" lin) "")
      (setq res (cons lin res))
    )
  )
  (if res
    (apply 'strcat (mapcar '(lambda (l) (strcat l "\n")) (reverse res)))
  )
)

;;; ---------------------------------------------------------------------
;;; DATOS PARA TABLAS (COP, ASI, CSSA y MTABLA)
;;; ncols = columnas que espera la tabla (5 COP, 7 ASI, 4 CSSA).
;;; Según TABLA_PORTAPAPELES:
;;;   SI        -> usa lo copiado directamente (sólo pregunta si el número
;;;                de columnas no coincide con lo que espera la tabla)
;;;   PREGUNTAR -> muestra lo copiado y pregunta antes de usarlo
;;;   NO        -> como antes: pegar con Ctrl+V y Enter 2 veces
;;; Si no hay nada copiado, también se pega a mano.
;;; ---------------------------------------------------------------------
(defun memo:leer-datos-tabla (ncols / modo txt n c resp entrada linea)
  (setq modo (strcase (memo:cfg "TABLA_PORTAPAPELES")))
  (if (/= modo "NO")
    (progn
      (setq txt (memo:portapapeles))
      (if txt (setq txt (memo:tsv-normalizar txt)))
    )
  )
  (if txt
    (progn
      (setq n (memo:contar-lineas txt)
            c (length (memo:split (car (memo:split txt "\n")) "\t")))
      (princ (strcat "\nDatos del portapapeles: " (itoa n) " fila(s), " (itoa c) " columna(s)."))
      (princ (strcat "\n  1a fila: " (memo:recortar (vl-string-translate "\t" "|" (car (memo:split txt "\n"))) 75)))
      (cond
        ((and ncols (/= c ncols))
         (princ (strcat "\n  ATENCIÓN: esta tabla espera " (itoa ncols) " columnas."))
         (if (= (memo:opcion "\n¿Usar de todas formas los datos del portapapeles?" "Si No" "No") "No")
           (setq txt nil)))
        ((and (= modo "PREGUNTAR") (not memo:*tabla-sin-preguntar*))
         (if (= (memo:opcion "\n¿Usar los datos del portapapeles?" "Si No" "Si") "No")
           (setq txt nil)))
      )
    )
  )
  (setq memo:*tabla-sin-preguntar* nil)
  (if (not txt)
    (progn
      (princ "\nPega los datos (Ctrl+V) y presiona Enter 2 veces:")
      (setq entrada "" linea (getstring T "\n>>> "))
      (while (and linea (/= linea ""))
        (setq entrada (strcat entrada linea "\n")
              linea (getstring T ">>> "))
      )
      (setq txt entrada)
    )
  )
  txt
)

;;; ---------------------------------------------------------------------
;;; TEXTO CON EL PORTAPAPELES COMO VALOR POR DEFECTO (CTX y otros)
;;; Si lo copiado es una sola línea corta, Enter la usa.
;;; ---------------------------------------------------------------------
(defun memo:pedir-texto (msg / clip r)
  (setq clip (memo:portapapeles))
  (if clip (setq clip (vl-string-trim " \t\r\n" clip)))
  (if (and clip (/= clip "") (<= (strlen clip) 250)
           (not (vl-string-search "\n" clip)) (not (vl-string-search "\t" clip)))
    (progn
      (setq r (getstring T (strcat msg " <" (memo:recortar clip 40) ">: ")))
      (if (= r "") clip r))
    (getstring T (strcat msg ": "))
  )
)

;;; ---------------------------------------------------------------------
;;; EJECUCIÓN SEGURA DE TODOS LOS COMANDOS MEMO
;;; Cuando se carga un archivo, cada comando se "envuelve" para que:
;;;  1) todo lo que hace quede en UN solo paso de Deshacer (U);
;;;  2) si se cancela con ESC o hay un error, se restauren las variables
;;;     (OSMODE, capa, estilo de texto, CMDECHO, REGENMODE, etc.).
;;; Si el comando termina bien, no se toca nada: queda como lo dejó.
;;; Se desactiva con MEMO_CONFIG -> DESHACER_AGRUPADO = NO.
;;; ---------------------------------------------------------------------
(setq memo:*vars-guardar*
  '("CMDECHO" "OSMODE" "CLAYER" "TEXTSTYLE" "SNAPMODE" "SNAPUNIT" "ORTHOMODE"
    "REGENMODE" "CECOLOR" "FILEDIA" "CMDDIA" "DIMZIN" "HIGHLIGHT" "UCSFOLLOW"
    "PDMODE" "PDSIZE" "HPNAME" "HPSCALE" "HPANG"))

(defun memo:doc () (vla-get-ActiveDocument (vlax-get-acad-object)))

(defun memo:guardar-vars ()
  (vl-remove nil
    (mapcar '(lambda (v / x)
               (setq x (vl-catch-all-apply 'getvar (list v)))
               (if (not (vl-catch-all-error-p x)) (cons v x)))
            memo:*vars-guardar*))
)

(defun memo:restaurar-vars (lst)
  (foreach par lst
    (if (not (equal (getvar (car par)) (cdr par)))
      (vl-catch-all-apply 'setvar (list (car par) (cdr par))))
  )
)

;; Llama a la versión original del comando
(defun memo:llamar-orig (cmd)
  (eval (list (read (strcat "MEMO:ORIG-" cmd))))
)

;; memo:dentro es una variable LOCAL de memo:ejecutar-externo: por el
;; alcance dinámico de AutoLISP, un comando llamado desde otro (MTABLA ->
;; COP, FH -> FUSIONHATCH) la ve en T y no abre un segundo grupo. Al
;; terminar o cancelar, AutoLISP la devuelve sola a nil.
(defun memo:ejecutar (cmd)
  (if memo:dentro
    (memo:llamar-orig cmd)
    (memo:ejecutar-externo cmd)
  )
)

(defun memo:ejecutar-externo (cmd / *error* memo:dentro vars doc res)
  (setq memo:dentro T
        doc (memo:doc)
        vars (memo:guardar-vars))
  ;; Si la vez anterior el comando terminó por su propio manejador de
  ;; errores, el grupo de Deshacer quedó abierto: cerrarlo ahora.
  (if memo:*marca-abierta*
    (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
  (defun *error* (msg)
    (memo:restaurar-vars vars)
    (vl-catch-all-apply 'vla-EndUndoMark (list doc))
    (setq memo:*marca-abierta* nil)
    (if (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*EXIT*,*BREAK*,*SALIR*,*ABORT*,*QUITAR*"))
      (princ (strcat "\nError en " cmd ": " msg)))
    (princ)
  )
  (vl-catch-all-apply 'vla-StartUndoMark (list doc))
  (setq memo:*marca-abierta* T)
  (setq res (memo:llamar-orig cmd))
  (vl-catch-all-apply 'vla-EndUndoMark (list doc))
  (setq memo:*marca-abierta* nil)
  res
)

;; Envuelve los comandos de un archivo recién cargado (una sola vez)
(defun memo:envolver (cmds / sym)
  (if (/= (strcase (memo:cfg "DESHACER_AGRUPADO")) "NO")
    (foreach cmd cmds
      (setq sym (read (strcat "C:" cmd)))
      (if (and (eval sym)
               (not (member cmd memo:*envueltos*))
               (not (and memo:es-stub-p (memo:es-stub-p cmd))))
        (progn
          (set (read (strcat "MEMO:ORIG-" cmd)) (eval sym))
          (eval (list 'defun sym nil (list 'memo:ejecutar cmd)))
          (setq memo:*envueltos* (cons cmd memo:*envueltos*))
        )
      )
    )
  )
)
;;; ---------------------------------------------------------------------
;;; TEXTOS DE ÁREA Y TIPOS (compartido por EA y las herramientas de áreas)
;;;   memo:limpiar-mtext  memo:pos-igual  memo:buscar-numero
;;;   memo:tipo-de  memo:cargar-patrones  memo:nombre-tipo  memo:cfg-txt
;;; ---------------------------------------------------------------------

;; Quita los códigos de formato de un MTEXT: \H0.25x; \fArial|b0; {} \P ...
(defun memo:limpiar-mtext (txt / i n c c2 res)
  (setq i 1 n (strlen txt) res "")
  (while (<= i n)
    (setq c (substr txt i 1))
    (cond
      ((and (= c "\\") (< i n))
       (setq c2 (substr txt (1+ i) 1))
       (cond
         ((wcmatch c2 "[ACcFfHQTWpS]")        ; códigos con parámetro hasta ";"
          (while (and (<= i n) (/= (substr txt i 1) ";")) (setq i (1+ i))))
         ((member c2 '("P" "~")) (setq res (strcat res " ")) (setq i (1+ i)))
         ((member c2 '("\\" "{" "}")) (setq res (strcat res c2)) (setq i (1+ i)))
         (T (setq i (1+ i)))))                 ; \L \l \O \o \K \k
      ((member c '("{" "}")))
      (T (setq res (strcat res c))))
    (setq i (1+ i)))
  res)

;; Posición (1..n) del último "=" o ":" del texto, o nil
(defun memo:pos-igual (txt / i pos c)
  (setq i 1)
  (while (<= i (strlen txt))
    (setq c (substr txt i 1))
    (if (or (= c "=") (= c ":")) (setq pos i))
    (setq i (1+ i)))
  pos)

;; Primer número del texto a partir de la posición ini (1..n), saltando
;; códigos de MTEXT. Devuelve (inicio fin valor) o nil.
;;   "1234.56" -> 1234.56   "1,234.56" -> 1234.56 (coma de miles = 3 dígitos)
;;   "15,5"    -> 15.5      (coma decimal)
(defun memo:buscar-numero (txt ini / i n c ini_num fin str dec sig)
  (setq n (strlen txt) i ini)
  (while (and (<= i n) (not ini_num))
    (setq c (substr txt i 1))
    (cond
      ((and (= c "\\") (< i n) (wcmatch (substr txt (1+ i) 1) "[ACcFfHQTWpS]"))
       (while (and (<= i n) (/= (substr txt i 1) ";")) (setq i (1+ i))))
      ((and (= c "\\") (< i n)) (setq i (1+ i)))
      ((wcmatch c "#") (setq ini_num i)))
    (setq i (1+ i)))
  (if ini_num
    (progn
      (setq i ini_num str "" dec nil)
      (while (and (<= i n) (not fin))
        (setq c (substr txt i 1) sig (substr txt (1+ i) 1))
        (cond
          ((wcmatch c "#") (setq str (strcat str c)))
          ((and (= c ",") (not dec)
                (wcmatch (substr txt (1+ i) 3) "###")
                (not (wcmatch (substr txt (+ i 4) 1) "#")))
           nil)                                       ; coma de miles: se omite
          ((and (member c '("." ",")) (not dec) (wcmatch sig "#"))
           (setq str (strcat str ".") dec T))         ; punto o coma decimal
          (T (setq fin (1- i))))
        (if (not fin) (setq i (1+ i))))
      (if (not fin) (setq fin n))
      (list ini_num fin (atof str)))))

;; ---------------------------------------------------------------
;; TIPOS DE ÁREA (7.2)
;; Orden = prioridad: los más específicos primero (SUBBASE antes que
;; BASE). Cada tipo se reconoce en el TEXTO y en la CAPA del hatch con
;; el mismo patrón, configurable con MEMO_CONFIG (EA_TIPO_<TIPO>).
;; ---------------------------------------------------------------
(setq memo:*tipos-def* '(
  ("SUBBASE"    "*SUBBASE*,*SUB-BASE*,*SUB BASE*")
  ("SUBRASANTE" "*SUBRASANTE*,*SUB-RASANTE*")
  ("CARPETA"    "*CARPETA*")
  ("EXCAVACION" "*EXCAVACION*,*EXCAVACIÓN*")
  ("DESMONTE"   "*DESMONTE*")
  ("TERRAPLEN"  "*TERRAPLEN*,*TERRAPLÉN*")
  ("RELLENO"    "*RELLENO*")
  ("CORAZA"     "*CORAZA*")
  ("NUCLEO"     "*NUCLEO*,*NÚCLEO*")
  ("ARENA"      "*ARENA*")
  ("CORTE"      "*CORTE*")
  ("AFINE"      "*AFINE*")
  ("BASE"       "*BASE*")))
(setq memo:*tipos* (mapcar 'car memo:*tipos-def*))

;; Texto de MEMO_CONFIG (o el valor por defecto)
(defun memo:cfg-txt (clave defecto / v)
  (if (and memo:cfg (setq v (memo:cfg clave)) (/= v "")) v defecto))

;; Lee los patrones una vez por comando (getenv es lento en bucles)
(defun memo:cargar-patrones ()
  (setq memo:*patrones*
    (mapcar '(lambda (e) (list (car e) (strcase (memo:cfg-txt (strcat "EA_TIPO_" (car e)) (cadr e)))))
            memo:*tipos-def*)))

;; Tipo de un texto o de un nombre de capa, o nil
(defun memo:tipo-de (cadena / txt res)
  (if (not memo:*patrones*) (memo:cargar-patrones))
  (setq txt (strcase (memo:limpiar-mtext cadena)))
  (foreach e memo:*patrones*
    (if (and (not res) (wcmatch txt (cadr e))) (setq res (car e))))
  res)

;; Nombre para mostrar: "SUBBASE" -> "Subbase"
(defun memo:nombre-tipo (tipo)
  (strcat (substr tipo 1 1) (strcase (substr tipo 2) T)))

;; Número con decimales fijos, sin depender de DIMZIN
(defun memo:fmt-dec (v dec / dz txt)
  (setq dz (getvar "DIMZIN"))
  (setvar "DIMZIN" 0)
  (setq txt (rtos v 2 dec))
  (setvar "DIMZIN" dz)
  txt)

;; ---------------------------------------------------------------------
;; ESCRIBIR UN ÁREA EN UN TEXTO (HA, AH, EA, MAREA)
;; Según MEMO_CONFIG:
;;   AREA_ESCRITURA = NUMERO   -> cambia sólo el número y conserva el resto
;;                                ("AREA DE CORTE=12.50 M2" -> "...=13.10 M2");
;;                                si no hay número pero sí "=", lo agrega
;;                  = COMPLETO -> escribe Prefijo + área + Sufijo
;;   AREA_PREFIJO ("A="), AREA_SUFIJO ("m2"), AREA_MAYUSCULAS (SI/NO),
;;   AREA_PREF_TIPO (SI: prefijo "AREA DE <TIPO>=" si se conoce el tipo)
;; ---------------------------------------------------------------------
(defun memo:si-p (clave defecto)
  (= (strcase (memo:cfg-txt clave defecto)) "SI"))

(defun memo:decimales-area ()
  (fix (cond ((distof (memo:cfg-txt "AREA_DECIMALES" "2") 2)) (2))))

(defun memo:sufijo-area (/ s)
  (setq s (memo:cfg-txt "AREA_SUFIJO" "m2"))
  (if (= (strcase s) "NINGUNO") "" s))

(defun memo:texto-area (original valor tipo / pos completo txt)
  (setq pos (if original (memo:pos-igual original)))
  (cond
    ((and original (= (strcase (memo:cfg-txt "AREA_ESCRITURA" "NUMERO")) "NUMERO")
          (if pos (memo:numero-tras original (1+ pos)) (memo:buscar-numero original 1)))
     (memo:reemplazar-numero original valor))
    ((and original pos (= (strcase (memo:cfg-txt "AREA_ESCRITURA" "NUMERO")) "NUMERO"))
     ;; si después del "=" ya hay algo (p. ej. " M2") sólo se inserta el número
     (strcat (substr original 1 pos) valor
             (if (= (vl-string-trim " " (substr original (1+ pos))) "") (memo:sufijo-area) "")
             (substr original (1+ pos))))
    (T
     (setq txt (strcat (if (and tipo (memo:si-p "AREA_PREF_TIPO" "SI"))
                         (strcat "AREA DE " tipo "=")
                         (memo:cfg-txt "AREA_PREFIJO" "A="))
                       valor (memo:sufijo-area)))
     (if (memo:si-p "AREA_MAYUSCULAS" "NO") (strcase txt) txt))))

;; Número que empieza JUSTO en la posición ini (saltando espacios), o nil.
;; Evita tomar el "2" de "M2" cuando después del "=" no hay número.
(defun memo:numero-tras (txt ini / i r)
  (setq i ini)
  (while (and (<= i (strlen txt)) (= (substr txt i 1) " ")) (setq i (1+ i)))
  (if (and (setq r (memo:buscar-numero txt i)) (= (car r) i)) r))

;; Reemplaza el número que va después del último "=" o ":" (o el primero)
(defun memo:reemplazar-numero (txt nuevo / pos r)
  (setq pos (memo:pos-igual txt))
  (setq r (if pos (memo:numero-tras txt (1+ pos)) (memo:buscar-numero txt 1)))
  (if r
    (strcat (substr txt 1 (1- (car r))) nuevo (substr txt (1+ (cadr r))))
    txt))

(princ)
