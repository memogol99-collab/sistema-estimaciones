;;; ======================================================================
;;;  CT-Toolbox.lsp
;;;  ------------------------------------------------------------------
;;;  Copiar Texto - 6 herramientas unidas en un solo archivo con DCL
;;;
;;;  COMANDO PRINCIPAL:
;;;     CT   -> Abre el cuadro de dialogo (CT seleccionado por defecto)
;;;
;;;  ATAJOS DIRECTOS (sin dialogo, compatibles con los originales):
;;;     CTE  -> Copia Texto con opcion de estilo (pregunta S/N)
;;;     CTP  -> Copia Texto con propiedades (texto / todo / solo rotacion)
;;;     IPT  -> Igualar propiedades de texto
;;;     CTN  -> Copiar texto con numeracion automatica (V-1, V-2, V-3...)
;;;     STV  -> Sumar o restar un valor a textos numericos
;;;
;;;  El cuadro DCL se genera temporalmente desde este mismo archivo,
;;;  NO requiere un archivo .dcl separado ni instalacion adicional.
;;; ======================================================================

(vl-load-com)

;;; ------------------------------------------------------------------
;;; Devuelve T si la entidad es TEXT o MTEXT
;;; ------------------------------------------------------------------
(defun ct:es-texto (ent / tipo)
  (and ent
       (setq tipo (cdr (assoc 0 (entget ent))))
       (member tipo '("TEXT" "MTEXT"))
  )
)

;;; ------------------------------------------------------------------
;;; Crea el archivo DCL temporal y devuelve su ruta
;;; ------------------------------------------------------------------
(defun ct:crear-dcl ( / ruta f)
  (setq ruta (vl-filename-mktemp "ct_toolbox" nil ".dcl"))
  (setq f (open ruta "w"))
  (foreach l
    (list
      "ct_toolbox : dialog {"
      "  label = \"Copiar Texto - 6 herramientas en 1\";"
      ""
      "  : column {"
      "    : boxed_radio_column {"
      "      label = \"Selecciona el modo\";"
      ""
      "      : radio_button {"
      "        key = \"rb_ct\";"
      "        label = \"CT   -  Copia Texto Simple (solo contenido)\";"
      "      }"
      ""
      "      : radio_button {"
      "        key = \"rb_cte\";"
      "        label = \"CTE  -  Copia Texto + Estilo (pregunta S/N)\";"
      "      }"
      ""
      "      : radio_button {"
      "        key = \"rb_ctp\";"
      "        label = \"CTP  -  Copia Texto + Propiedades (con rotación)\";"
      "      }"
      ""
      "      : radio_button {"
      "        key = \"rb_ipt\";"
      "        label = \"IPT  -  Igualar Propiedades (sin tocar el texto)\";"
      "      }"
      ""
      "      : radio_button {"
      "        key = \"rb_ctn\";"
      "        label = \"CTN  -  Copiar con Numeración automática\";"
      "      }"
      ""
      "      : radio_button {"
      "        key = \"rb_stv\";"
      "        label = \"STV  -  Sumar / Restar valor a textos numéricos\";"
      "      }"
      "    }"
      ""
      "    : boxed_column {"
      "      label = \"Descripcion\";"
      ""
      "      : text {"
      "        key = \"tx_desc\";"
      "        label = \"\";"
      "        width = 66;"
      "        alignment = left;"
      "        is_bold = true;"
      "      }"
      "    }"
      "  }"
      ""
      "  spacer;"
      ""
      "  : row {"
      "    alignment = centered;"
      "    fixed_width = true;"
      ""
      "    : button {"
      "      key = \"accept\";"
      "      label = \"Continuar\";"
      "      is_default = true;"
      "      width = 14;"
      "    }"
      ""
      "    : button {"
      "      key = \"cancel\";"
      "      label = \"Cancelar\";"
      "      is_default = false;"
      "      width = 14;"
      "    }"
      "  }"
      "}"
    )
    (write-line l f)
  )
  (close f)
  ruta
)

;;; ------------------------------------------------------------------
;;; Muestra la descripcion del modo seleccionado dentro del dialogo
;;; ------------------------------------------------------------------
(defun ct:desc (modo)
  (set_tile "tx_desc"
    (cond
      ((= modo "CT")  "Copia solo el contenido en cada texto donde hagas clic.")
      ((= modo "CTE") "Copia el contenido y pregunta si también copia el estilo.")
      ((= modo "CTP") "Texto, todo (con altura y rotación) o solo rotar como el origen.")
      ((= modo "IPT") "Iguala estilo, altura, capa y color; conserva texto y rotación.")
      ((= modo "CTN") "Pega el texto y autoincrementa el número final en cada clic.")
      ((= modo "STV") "Suma o resta un valor a los textos numéricos seleccionados.")
      (t "")
    )
  )
)

;;; ------------------------------------------------------------------
;;; Muestra el cuadro de dialogo. Devuelve "CT" "CTE" "CTP" "IPT" o nil
;;; ------------------------------------------------------------------
(defun ct:dialogo ( / ruta id modo res)
  (setq modo nil)
  (setq ruta (ct:crear-dcl))
  (if (and ruta (findfile ruta))
    (progn
      (setq res (vl-catch-all-apply 'load_dialog (list ruta)))
      (if (vl-catch-all-error-p res)
        (princ (strcat "\nERROR al cargar el DCL: " (vl-catch-all-error-message res)))
        (progn
          (setq id res)
          (if (new_dialog "ct_toolbox" id)
            (progn
              (set_tile "rb_ct" "1")            ; CT seleccionado por defecto
              (ct:desc "CT")
              (action_tile "rb_ct"  "(ct:desc \"CT\")")
              (action_tile "rb_cte" "(ct:desc \"CTE\")")
              (action_tile "rb_ctp" "(ct:desc \"CTP\")")
              (action_tile "rb_ipt" "(ct:desc \"IPT\")")
              (action_tile "rb_ctn" "(ct:desc \"CTN\")")
              (action_tile "rb_stv" "(ct:desc \"STV\")")
              (action_tile
                "accept"
                (strcat
                  "(setq modo (cond ((= (get_tile \"rb_ct\") \"1\") \"CT\")"
                  " ((= (get_tile \"rb_cte\") \"1\") \"CTE\")"
                  " ((= (get_tile \"rb_ctp\") \"1\") \"CTP\")"
                  " ((= (get_tile \"rb_ipt\") \"1\") \"IPT\")"
                  " ((= (get_tile \"rb_ctn\") \"1\") \"CTN\")"
                  " ((= (get_tile \"rb_stv\") \"1\") \"STV\")"
                  " (t \"CT\")))(done_dialog 1)"
                )
              )
              (action_tile "cancel" "(setq modo nil) (done_dialog 0)")
              (start_dialog)
            )
            (princ "\nERROR: no se pudo mostrar el cuadro de diálogo.")
          )
          (unload_dialog id)
        )
      )
    )
    (princ "\nERROR: no se pudo crear el archivo DCL temporal.")
  )
  (if (and ruta (findfile ruta)) (vl-file-delete ruta))
  modo
)

;;; ==================================================================
;;;  MODO CT - Copia Texto Simple (solo contenido, directo)
;;; ==================================================================
(defun ct:r-simple ( / ent_base obj_base texto_base ent obj contador)
  (setq ent_base (car (entsel "\nSelecciona el texto con el contenido a copiar: ")))
  (if (ct:es-texto ent_base)
    (progn
      (setq obj_base (vlax-ename->vla-object ent_base))
      (setq texto_base (vlax-get-property obj_base 'TextString))
      (princ (strcat "\nTexto a copiar: \"" texto_base "\""))
      (princ "\nHaz clic en cada texto a cambiar (Enter para terminar).")
      (setq contador 0)
      (while (setq ent (car (entsel "\nClic en el texto a cambiar [Enter=terminar]: ")))
        (if (ct:es-texto ent)
          (progn
            (setq obj (vlax-ename->vla-object ent))
            (vlax-put-property obj 'TextString texto_base)
            (setq contador (1+ contador))
            (princ (strcat "\nTexto cambiado. Total: " (itoa contador)))
          )
          (princ "\nEl objeto no es un texto. Selecciona otro.")
        )
      )
      (princ (strcat "\nProceso terminado. Textos cambiados: " (itoa contador)))
    )
    (princ "\nNo se seleccionó un texto válido.")
  )
  (princ)
)

;;; ==================================================================
;;;  MODO CTE - Copia Texto con opcion de estilo (pregunta S/N)
;;; ==================================================================
(defun ct:r-estilo ( / ent_base obj_base texto_base estilo_base resp cambiar_estilo ent obj contador)
  (setq ent_base (car (entsel "\nSelecciona el texto con las propiedades a copiar: ")))
  (if (ct:es-texto ent_base)
    (progn
      (setq obj_base (vlax-ename->vla-object ent_base))
      (setq texto_base  (vlax-get-property obj_base 'TextString))
      (setq estilo_base (vlax-get-property obj_base 'StyleName))
      (initget "Si No")
      (setq resp (getkword "\n¿Cambiar también el estilo de texto? [Si/No] <No>: "))
      (setq cambiar_estilo (and resp (= (strcase resp) "SI")))
      (princ (strcat "\nTexto a copiar: \"" texto_base "\""))
      (if cambiar_estilo
        (princ (strcat "\nEstilo a copiar: " estilo_base))
      )
      (princ "\nHaz clic en cada texto a cambiar (Enter para terminar).")
      (setq contador 0)
      (while (setq ent (car (entsel "\nClic en el texto a cambiar [Enter=terminar]: ")))
        (if (ct:es-texto ent)
          (progn
            (setq obj (vlax-ename->vla-object ent))
            (vlax-put-property obj 'TextString texto_base)
            (if cambiar_estilo
              (vlax-put-property obj 'StyleName estilo_base)
            )
            (setq contador (1+ contador))
            (princ (strcat "\nTexto cambiado. Total: " (itoa contador)))
          )
          (princ "\nEl objeto no es un texto. Selecciona otro.")
        )
      )
      (princ (strcat "\nProceso terminado. Textos cambiados: " (itoa contador)))
    )
    (princ "\nNo se seleccionó un texto válido.")
  )
  (princ)
)

;;; ==================================================================
;;;  MODO CTP - Copia Texto con propiedades
;;;  Opciones: Texto (solo contenido) / Todo (contenido + estilo +
;;;  altura + rotación) / Rotacion (solo rotar como el origen)
;;; ==================================================================
(defun ct:r-props ( / ent_base obj_base texto_base estilo_base altura_base rot_base resp cambiar_todo solo_rotar ent obj contador)
  (setq ent_base (car (entsel "\nSelecciona el texto con las propiedades a copiar: ")))
  (if (ct:es-texto ent_base)
    (progn
      (setq obj_base (vlax-ename->vla-object ent_base))
      (setq texto_base  (vlax-get-property obj_base 'TextString))
      (setq estilo_base (vlax-get-property obj_base 'StyleName))
      (setq altura_base (vlax-get-property obj_base 'Height))
      (setq rot_base    (vlax-get-property obj_base 'Rotation))
      (initget "Texto Todo Rotacion")
      (setq resp (getkword "\n¿Qué copiar? [Texto/Todo/Rotacion] <Texto>: "))
      (setq cambiar_todo (and resp (= (strcase resp) "TODO"))
            solo_rotar   (and resp (= (strcase resp) "ROTACION"))
      )
      (princ (strcat "\nTexto a copiar: \"" texto_base "\""))
      (if cambiar_todo
        (princ (strcat "\nEstilo: " estilo_base
                       "  |  Altura: " (rtos altura_base 2 2)
                       "  |  Rotación: " (angtos rot_base 0 2)
                )
        )
      )
      (princ "\nHaz clic en cada texto a cambiar (Enter para terminar).")
      (setq contador 0)
      (while (setq ent (car (entsel "\nClic en el texto a cambiar [Enter=terminar]: ")))
        (if (ct:es-texto ent)
          (progn
            (setq obj (vlax-ename->vla-object ent))
            (if solo_rotar
              (vlax-put-property obj 'Rotation rot_base)
              (progn
                (vlax-put-property obj 'TextString texto_base)
                (if cambiar_todo
                  (progn
                    (vlax-put-property obj 'StyleName estilo_base)
                    (vlax-put-property obj 'Height altura_base)
                    (vlax-put-property obj 'Rotation rot_base)
                  )
                )
              )
            )
            (setq contador (1+ contador))
            (princ (strcat "\nTexto cambiado. Total: " (itoa contador)))
          )
          (princ "\nEl objeto no es un texto. Selecciona otro.")
        )
      )
      (princ (strcat "\nProceso terminado. Textos cambiados: " (itoa contador)))
    )
    (princ "\nNo se seleccionó un texto válido.")
  )
  (princ)
)

;;; ==================================================================
;;;  MODO IPT - Igualar propiedades de texto (seleccion multiple)
;;;  Copia estilo, altura, capa y color; conserva texto y rotacion.
;;; ==================================================================
(defun ct:r-igualar ( / src obj_src st ly cl ht ss n i ent obj rot)
  (princ "\nIgualar propiedades de texto.")
  (setq src (car (entsel "\nSelecciona el texto FUENTE: ")))
  (if (ct:es-texto src)
    (progn
      (setq obj_src (vlax-ename->vla-object src))
      (setq st (vlax-get-property obj_src 'StyleName))
      (setq ly (vlax-get-property obj_src 'Layer))
      (setq cl (vlax-get-property obj_src 'Color))
      (setq ht (vlax-get-property obj_src 'Height))
      (princ (strcat "\nFuente -> Estilo: " st "  |  Altura: " (rtos ht 2 2) "  |  Capa: " ly))
      (princ "\nSelecciona los textos DESTINO (ventana o individual): ")
      (setq ss (ssget '((0 . "TEXT,MTEXT"))))
      (if ss
        (progn
          (setq n (sslength ss))
          (setq i 0)
          (repeat n
            (setq ent (ssname ss i)
                  obj (vlax-ename->vla-object ent)
                  rot (vlax-get-property obj 'Rotation)
            )
            (vlax-put-property obj 'StyleName st)
            (vlax-put-property obj 'Layer    ly)
            (vlax-put-property obj 'Color    cl)
            (vlax-put-property obj 'Height   ht)
            (vlax-put-property obj 'Rotation rot)   ; conservar rotacion original
            (setq i (1+ i))
          )
          (princ (strcat "\n" (itoa n) " textos actualizados."))
        )
        (princ "\nNo se seleccionaron textos destino.")
      )
    )
    (princ "\nNo se seleccionó un texto fuente válido.")
  )
  (princ)
)

;;; ==================================================================
;;;  MODO CTN - Copiar texto con numeración automática
;;;  Pega el texto origen incrementando su número final en cada clic
;;;  Ejemplo: origen "V-1"  ->  clics: "V-2", "V-3", "V-4"...
;;;  Conserva ceros a la izquierda: "P-05" -> "P-06", "P-07"...
;;;  Solo cambia el contenido; no modifica el estilo de cada texto.
;;; ==================================================================

;; Separa un texto en (prefijo numero anchura).
;; Si no termina en número devuelve (texto nil 0)
(defun ct:partir-num (str / n i asc)
  (setq n (strlen str)
        i n
  )
  (while (and (> i 0)
              (>= (setq asc (ascii (substr str i 1))) 48)
              (<= asc 57)
        )
    (setq i (1- i))
  )
  (if (= i n)
    (list str nil 0)
    (list (substr str 1 i) (atoi (substr str (1+ i))) (- n i))
  )
)

;; Convierte un número en texto con ceros a la izquierda (anchura fija)
(defun ct:relleno (num anchura / s)
  (setq s (itoa num))
  (while (< (strlen s) anchura)
    (setq s (strcat "0" s))
  )
  s
)

(defun ct:r-numerar ( / ent_base obj_base partes prefijo num_base anchura inicio contador nuevo ent obj)
  (setq ent_base (car (entsel "\nSelecciona el texto ORIGEN (con el número a incrementar): ")))
  (if (ct:es-texto ent_base)
    (progn
      (setq obj_base    (vlax-ename->vla-object ent_base))
      (setq partes      (ct:partir-num (vlax-get-property obj_base 'TextString)))
      (setq prefijo     (car partes)
            num_base    (cadr partes)
            anchura     (caddr partes)
      )
      (if num_base
        (progn
          (princ (strcat "\nEl texto termina en el número " (itoa num_base) "."))
          (setq inicio (getint (strcat "\n¿Número para el primer clic? <" (itoa (1+ num_base)) ">: ")))
          (if (not inicio) (setq inicio (1+ num_base)))
        )
        (progn
          (setq inicio (getint "\nEl texto no termina en número. ¿Número para el primer clic? <1>: "))
          (if (not inicio) (setq inicio 1))
        )
      )
      (princ "\nHaz clic en cada texto a numerar (Enter para terminar).")
      (setq contador inicio)
      (while (setq ent (car (entsel "\nClic en el texto a numerar [Enter=terminar]: ")))
        (if (ct:es-texto ent)
          (progn
            (setq nuevo (strcat prefijo (ct:relleno contador anchura)))
            (setq obj (vlax-ename->vla-object ent))
            (vlax-put-property obj 'TextString nuevo)
            (princ (strcat "\nColocado: \"" nuevo "\"  |  Siguiente: " (itoa (1+ contador))))
            (setq contador (1+ contador))
          )
          (princ "\nEl objeto no es un texto. Selecciona otro.")
        )
      )
      (princ (strcat "\nProceso terminado. Último número usado: " (itoa (1- contador))))
    )
    (princ "\nNo se seleccionó un texto válido.")
  )
  (princ)
)

;;; ==================================================================
;;;  MODO STV - Sumar / Restar un valor a textos numéricos
;;;  Útil por ejemplo para cambiar de nivel (datum) en cotas:
;;;  valor +1.5 suma 1.5 a todos; valor -0.35 resta 0.35 a todos.
;;;  Respeta los decimales de cada texto (y del valor escrito).
;;; ==================================================================

;; Cuenta los decimales de un texto tipo "1250.30" -> 2
(defun ct:decimales (str / pos)
  (setq pos (vl-string-search "." str))
  (if pos
    (- (strlen str) (1+ pos))
    0
  )
)

(defun ct:r-sumar ( / sval val dec_val ss n i ent obj s v dec nuevo hechos saltados dim_old)
  (setq sval (vl-string-translate "," "." (getstring T "\nValor a SUMAR a los textos (negativo = restar, ej. -0.35): ")))
  (setq val (distof sval))
  (if val
    (progn
      (setq dec_val (ct:decimales sval))
      (princ "\nSelecciona los textos numéricos a modificar: ")
      (setq ss (ssget '((0 . "TEXT,MTEXT"))))
      (if ss
        (progn
          (setq dim_old (getvar "DIMZIN"))
          (setvar "DIMZIN" 0)          ; conservar ceros (1250.30 sigue siendo 1250.30)
          (setq n (sslength ss)
                i 0
                hechos 0
                saltados 0
          )
          (repeat n
            (setq ent (ssname ss i)
                  obj (vlax-ename->vla-object ent)
                  s   (vlax-get-property obj 'TextString)
                  v   (distof s)
            )
            (if v
              (progn
                (setq dec   (max (ct:decimales s) dec_val)
                      nuevo (rtos (+ v val) 2 dec)
                )
                (vlax-put-property obj 'TextString nuevo)
                (setq hechos (1+ hechos))
              )
              (setq saltados (1+ saltados))
            )
            (setq i (1+ i))
          )
          (setvar "DIMZIN" dim_old)
          (princ (strcat "\nListo: " (itoa hechos) " textos actualizados"
                         (if (> saltados 0)
                           (strcat " (" (itoa saltados) " no numéricos, se dejaron igual).")
                           "."
                         )
                  )
          )
        )
        (princ "\nNo se seleccionaron textos.")
      )
    )
    (princ "\nValor no válido. Escribe un número (ej. 1.5 o -0.35).")
  )
  (princ)
)

;;; ==================================================================
;;;  COMANDOS
;;; ==================================================================

;;; Comando principal: abre el cuadro de dialogo (CT por defecto)
(defun c:CT ( / modo)
  (setq modo (ct:dialogo))
  (cond
    ((not modo)     (princ "\nOperación cancelada."))
    ((= modo "CT")  (princ "\nModo: CT - Copia Texto Simple.") (ct:r-simple))
    ((= modo "CTE") (princ "\nModo: CTE - Copia Texto + Estilo.") (ct:r-estilo))
    ((= modo "CTP") (princ "\nModo: CTP - Copia Texto + Propiedades.") (ct:r-props))
    ((= modo "IPT") (princ "\nModo: IPT - Igualar Propiedades.") (ct:r-igualar))
    ((= modo "CTN") (princ "\nModo: CTN - Copiar con Numeración.") (ct:r-numerar))
    ((= modo "STV") (princ "\nModo: STV - Sumar/Restar valor.") (ct:r-sumar))
  )
  (princ)
)

;;; Atajos directos sin dialogo (mismos nombres que los comandos originales)
(defun c:CTE () (ct:r-estilo)  (princ))
(defun c:CTP () (ct:r-props)   (princ))
(defun c:IPT () (ct:r-igualar) (princ))
(defun c:CTN () (ct:r-numerar) (princ))
(defun c:STV () (ct:r-sumar)   (princ))

(princ "\nCT-Toolbox cargado.  Comando: CT (diálogo, CT por defecto)  |  Atajos: CTE, CTP, IPT, CTN, STV.")
(princ)
