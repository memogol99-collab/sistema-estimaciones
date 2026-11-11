;;; =====================================================================
;;;  MEMO_Unificados.lsp  -  Comandos que agrupan familias de rutinas
;;;
;;;   MTABLA      Una sola entrada para las tablas COP / ASI / CSSA.
;;;               Lee el portapapeles y propone el formato según el
;;;               número de columnas copiadas (5, 7 o 4).
;;;   MAREA       Una sola entrada para los 9 comandos de áreas.
;;;   MBACHEO     Flujo de bacheo paso a paso: dibujar, numerar, cotar,
;;;               hatch, exportar.
;;;   MEMO_CONFIG Edita los valores configurables del sistema.
;;;
;;;  Estos comandos NO reescriben las rutinas originales: las llaman,
;;;  así el resultado en el dibujo es exactamente el mismo de siempre.
;;; =====================================================================
(vl-load-com)

;;; ---------------------------------------------------------------------
;;; MTABLA
;;; ---------------------------------------------------------------------
(defun c:MTABLA (/ *error* txt cols def fmt)
  (defun *error* (msg)
    (setq memo:*tabla-sin-preguntar* nil)
    (if (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*EXIT*"))
      (princ (strcat "\nError: " msg)))
    (princ)
  )
  (princ "\n=== MTABLA - Tablas de conceptos ===")
  (setq txt (memo:portapapeles))
  (if txt (setq txt (memo:tsv-normalizar txt)))
  (setq cols (if txt (length (memo:split (car (memo:split txt "\n")) "\t")) 0))
  (if txt
    (princ (strcat "\nPortapapeles: " (itoa (memo:contar-lineas txt)) " fila(s) de "
                   (itoa cols) " columna(s)."))
    (princ "\nEl portapapeles está vacío: después podrás pegar los datos a mano.")
  )
  (setq def
    (cond
      ((= cols 5) "Obras")
      ((= cols 7) "Asipona")
      ((= cols 4) "Ssa")
      ((member (memo:cfg "TABLA_ULTIMO") '("Obras" "Asipona" "Ssa")) (memo:cfg "TABLA_ULTIMO"))
      (T "Obras")
    )
  )
  (princ "\n  Obras         = 5 col. (No.|Código|Concepto|Unidad|Precio)")
  (princ "\n  Asipona       = 7 col. (No.|Código|Descripción|Unidad|P.U.|Cantidad|Importe)")
  (princ "\n  Ssa           = 4 col. (No.|Concepto|Unidad|Cantidad)")
  (setq fmt (memo:opcion "\nFormato de tabla" "Obras Asipona Ssa" def))
  (memo:cfg-set "TABLA_ULTIMO" fmt)
  ;; El usuario ya vio lo que hay en el portapapeles: no volver a preguntar
  (setq memo:*tabla-sin-preguntar* (if txt T nil))
  (memo:llamar (cdr (assoc fmt '(("Obras" . "COP") ("Asipona" . "ASI") ("Ssa" . "CSSA")))))
  (setq memo:*tabla-sin-preguntar* nil)
  (princ)
)

;;; ---------------------------------------------------------------------
;;; MAREA
;;; ---------------------------------------------------------------------
(setq memo:*areas*
  '(("Prefijo"  "HA2"  "Área de un hatch a un texto, preguntando prefijo")
    ("Rapido"   "HA"   "Igual que Prefijo, con el último prefijo usado")
    ("M2"       "AM2"  "Actualiza el área en m² del texto de un hatch")
    ("Hatch"    "AH"   "Varios hatches: 'AREA DE [TIPO]=[VALOR]M2'")
    ("Contorno" "AC"   "Áreas de secciones a partir de contornos")
    ("Tres"     "AS"   "Área de sección por 3 puntos")
    ("Detalle"  "CAS"  "Cálculo con fórmulas (triángulos, trapecios, círculos)")
    ("Valores"  "QA"   "Cálculo rápido con valores sustituidos")
    ("Exportar" "EA"   "Etiquetar por capa y exportar a CSV/Excel"))
)

(defun c:MAREA (/ def op e)
  (princ "\n=== MAREA - Áreas ===")
  (foreach e memo:*areas*
    (princ (strcat "\n  " (car e) (substr "          " 1 (- 10 (strlen (car e))))
                   "(" (cadr e) ")  " (caddr e)))
  )
  (setq def (memo:cfg "AREA_ULTIMO"))
  (if (not (assoc def memo:*areas*)) (setq def "Prefijo"))
  (setq op (memo:opcion "\nTipo de área"
                        "Prefijo Rapido M2 Hatch Contorno Tres Detalle Valores Exportar" def))
  (memo:cfg-set "AREA_ULTIMO" op)
  (memo:llamar (cadr (assoc op memo:*areas*)))
  (princ)
)

;;; ---------------------------------------------------------------------
;;; MBACHEO
;;; ---------------------------------------------------------------------
(setq memo:*bacheo*
  '(("Dibujar"  "RS"        "Dibujar rectángulos con cotas y hatch")
    ("Numerar"  "RNB"       "Renumerar por vecino más cercano")
    ("Cotar"    "COTB"      "Anotar largo y ancho")
    ("Hatch"    "HR"        "Hatch a los rectángulos")
    ("Exportar" "EXR"       "Exportar a CSV (área, volumen, acumulado)")
    ("Limpiar"  "BTR"       "Borrar textos dentro de rectángulos")
    ("Config"   "RS-CONFIG" "Configurar el hatch de RS"))
)

(defun c:MBACHEO (/ op sig paso)
  (princ "\n=== MBACHEO - Flujo de bacheo ===")
  (princ (strcat "\nEspesor para el volumen: " (memo:cfg "BACHEO_ESPESOR")
                 " m (se cambia con MEMO_CONFIG)"))
  (setq sig "Dibujar")
  (while
    (/= "Salir"
        (setq op (memo:opcion "\nPaso" "Dibujar Numerar Cotar Hatch Exportar Limpiar Config Salir" sig)))
    (setq paso (assoc op memo:*bacheo*))
    (princ (strcat "\n--- " (caddr paso) " (" (cadr paso) ") ---"))
    (memo:llamar (cadr paso))
    ;; Proponer el siguiente paso lógico
    (setq sig
      (cond
        ((= op "Dibujar") "Numerar")
        ((= op "Numerar") "Cotar")
        ((= op "Cotar") "Exportar")
        ((= op "Hatch") "Exportar")
        ((= op "Exportar") "Salir")
        (T "Dibujar")
      )
    )
  )
  (princ)
)

;;; ---------------------------------------------------------------------
;;; MEMO_CONFIG
;;; memo:*cfg-def* = lista de (CLAVE "defecto" "descripción" tipo opciones)
;;;   tipo: "NUM" o "TXT"; opciones: "" o "SI,NO,PREGUNTAR"
;;; ---------------------------------------------------------------------
(defun memo:cfg-valido (e v)
  (cond
    ((= (nth 3 e) "NUM") (distof v 2))
    ((/= (nth 4 e) "") (member (strcase v) (memo:split (nth 4 e) ",")))
    (T T)
  )
)

(defun memo:cfg-listar (/ i e v)
  (princ "\n\n===== MEMO_CONFIG - valores configurables =====")
  (setq i 1)
  (foreach e memo:*cfg-def*
    (setq v (memo:cfg (car e)))
    (princ (strcat "\n" (if (< i 10) " " "") (itoa i) ". " (caddr e) ": " v
                   (if (/= v (cadr e)) (strcat "   (defecto " (cadr e) ")") "")))
    (setq i (1+ i))
  )
  (princ "\n===============================================")
)

(defun c:MEMO_CONFIG (/ op i e nuevo)
  (while
    (progn
      (memo:cfg-listar)
      (setq op (getstring "\nNúmero a cambiar, R = restablecer todo, Enter = salir: "))
      (/= op "")
    )
    (cond
      ((= (strcase op) "R")
       (initget "Si No")
       (if (= (getkword "\n¿Restablecer todos los valores por defecto? [Si/No] <No>: ") "Si")
         (progn
           (foreach e memo:*cfg-def* (memo:cfg-set (car e) ""))
           (princ "\nValores restablecidos.")
         )
       )
      )
      ((and (> (setq i (atoi op)) 0) (setq e (nth (1- i) memo:*cfg-def*)))
       (if (/= (nth 4 e) "") (princ (strcat "\nOpciones: " (nth 4 e))))
       (setq nuevo (getstring T (strcat "\n" (caddr e) " <" (memo:cfg (car e)) ">: ")))
       (cond
         ((= nuevo ""))
         ((memo:cfg-valido e nuevo)
          (memo:cfg-set (car e) (if (/= (nth 4 e) "") (strcase nuevo) nuevo))
          (princ "\nGuardado."))
         (T (princ "\nValor no válido; no se cambió."))
       )
      )
      (T (princ "\nOpción no válida."))
    )
  )
  (princ "\nLos cambios se aplican la próxima vez que ejecutes cada comando.")
  (princ)
)

(princ)
