;;; =====================================================================
;;;  MEMO_Lib.lsp  -  Biblioteca común del MEMO SISTEMA
;;;  Se carga al abrir cada dibujo (es pequeña). Todas las funciones
;;;  llevan el prefijo memo: para no chocar con ningún otro LISP.
;;;
;;;   Configuración : memo:cfg  memo:cfg-num  memo:cfg-set
;;;   Portapapeles  : memo:portapapeles
;;;   Tablas Excel  : memo:tsv-normalizar  memo:leer-datos-tabla
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
;;; Lee el portapapeles según TABLA_PORTAPAPELES (PREGUNTAR / SI / NO).
;;; Si no hay nada copiado o el usuario dice No, vuelve al método de
;;; siempre: pegar con Ctrl+V y Enter 2 veces.
;;; ---------------------------------------------------------------------
(defun memo:leer-datos-tabla (/ modo txt n resp entrada linea)
  (setq modo (strcase (memo:cfg "TABLA_PORTAPAPELES")))
  (if (/= modo "NO")
    (progn
      (setq txt (memo:portapapeles))
      (if txt (setq txt (memo:tsv-normalizar txt)))
    )
  )
  (if txt
    (progn
      (setq n (memo:contar-lineas txt))
      (princ (strcat "\nPortapapeles: " (itoa n) " fila(s), "
                     (itoa (length (memo:split (car (memo:split txt "\n")) "\t")))
                     " columna(s)."))
      (princ (strcat "\n  1a fila: " (memo:recortar (vl-string-translate "\t" "|" (car (memo:split txt "\n"))) 75)))
      (if (and (= modo "PREGUNTAR") (not memo:*tabla-sin-preguntar*))
        (if (= (memo:opcion "\n¿Usar los datos del portapapeles?" "Si No" "Si") "No")
          (setq txt nil)
        )
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

(princ)
