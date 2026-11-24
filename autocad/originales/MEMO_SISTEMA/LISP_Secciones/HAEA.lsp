;===============================================================
; HAEA - EXPORTADOR + ETIQUETADO TODO-EN-UNO
; Versión 5.2 - DCL SIMPLIFICADO
; Etiqueta por CAPA DEL TIPO + Exporta a CSV
;===============================================================

(vl-load-com)

;===============================================================
; MANEJADOR DE ERRORES GLOBAL
;===============================================================
(defun *error-global* (msg)
  (if (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*EXIT*,*BREAK*"))
    (princ (strcat "\n[Error] " msg))
  )
  (princ)
)
(if (not *old-error*) (setq *old-error* *error*))
(setq *error* *error-global*)

;===============================================================
; CONFIGURACIÓN DE FILTROS
;===============================================================
(if (not *haea_capas_ignorar*)
  (setq *haea_capas_ignorar* 
    '("MEMBRETE" "MEMBRETES" "TITULOS" "TÍTULOS" 
      "ESCALAS" "ESCALA" "NOTAS" "NOTA" 
      "SIMBOLOGIA" "SIMBOLOGÍA" "LEYENDA" 
      "DEFPOINTS")))

(if (not *haea_textos_ignorar*)
  (setq *haea_textos_ignorar*
    '("*ESCALA*" "* : *" "*1:*" "*:1*"
      "*LAMINA*" "*LÁMINA*" "*PLANO*" "*PLANTA*" "*PERFIL*" "*ALZADO*"
      "*SECCION*" "*SECCIÓN*" "*DETALLE*"
      "*PROYECTO*" "*TITULO*" "*TÍTULO*"
      "*FECHA*" "*DIBUJO*" "*DIBUJANTE*" "*REVISO*" "*REVISÓ*"
      "*DISEÑO*" "*ING.*" "*ARQ.*"
      "*NORTE*" "*CROQUIS*"
      "*SIMBOLOGIA*" "*SIMBOLOGÍA*" "*LEYENDA*"
      "*NOTA:*" "*NOTA :*"
      "*NOMENCLATURA*" "*ABREVIATURA*")))

;===============================================================
; VARIABLES GLOBALES
;===============================================================
(if (not *haea_prefijo*) (setq *haea_prefijo* "A="))
(if (not *haea_ultimo_modo*) (setq *haea_ultimo_modo* "Auto"))
(if (not *haea_ultima_accion*) (setq *haea_ultima_accion* "HA"))
(if (not *haea_usar_filtro_capas*) (setq *haea_usar_filtro_capas* T))
(if (not *haea_usar_filtro_textos*) (setq *haea_usar_filtro_textos* T))
(if (not *haea_limite_dist*) (setq *haea_limite_dist* 50.0))
(if (not *haea_cambiar_capa*) (setq *haea_cambiar_capa* T))
(if (not *haea_tipos_activos*) 
  (setq *haea_tipos_activos* 
    '("CARPETA" "CORTE" "EXCAVACION" "BASE" "SUBRASANTE" 
      "ARENA" "NUCLEO" "CORAZA" "RELLENO" "AFINE")))

;===============================================================
; DEFINICIÓN DE TIPOS DE ÁREAS
;===============================================================
(setq *haea_tipos_areas* '(
  ("CARPETA" ("*CARPETA*" "*ACA*" "*ASF*" "*ASFALTO*" "*CARP*"))
  ("CORTE" ("*CORTE*" "*CEPA*" "*ACO*"))
  ("EXCAVACION" ("*EXCAVACION*" "*EXCAV*" "*EXC*"))
  ("BASE" ("*BASE*" "*BAS*" "*AB*"))
  ("SUBRASANTE" ("*SUBRASANTE*" "*ASR*" "*SUBR*"))
  ("ARENA" ("*ARENA*" "*AREN*"))
  ("NUCLEO" ("*NUCLEO*" "*NUC*" "*NUCLE*"))
  ("CORAZA" ("*CORAZA*" "*CORAZ*" "*COR*"))
  ("RELLENO" ("*RELLENO*" "*RELL*" "*TERRAPLEN*"))
  ("AFINE" ("*AFINE*" "*TALUD*" "*ACOMODO*"))
))

;===============================================================
; DCL EMBEBIDO - v5.3 (Layout Vertical)
;===============================================================
(defun escribir-dcl-embebido (/ f ruta)
  (setq ruta (strcat (getenv "TEMP") "\\haea_temp.dcl"))
  (setq f (open ruta "w"))
  (write-line "haea_dialog : dialog {" f)
  (write-line "  label = \"HAEA v5.3\";" f)
  (write-line "  : boxed_radio_column {" f)
  (write-line "    label = \"Accion\";" f)
  (write-line "    key = \"accion\";" f)
  (write-line "    : radio_button { label = \"Exportar a Excel\"; key = \"accion_csv\"; value = \"1\"; }" f)
  (write-line "    : radio_button { label = \"Etiquetar HATCHs\"; key = \"accion_ha\"; }" f)
  (write-line "    : radio_button { label = \"Etiquetar Y Exportar\"; key = \"accion_ambos\"; }" f)
  (write-line "  }" f)
  (write-line "  : boxed_column {" f)
  (write-line "    label = \"Tipo de Areas a Procesar\";" f)
  (write-line "    : row {" f)
  (write-line "      : toggle { label = \"Carpeta\"; key = \"tipo_CARPETA\"; value = \"1\"; }" f)
  (write-line "      : toggle { label = \"Arena\"; key = \"tipo_ARENA\"; value = \"1\"; }" f)
  (write-line "    }" f)
  (write-line "    : row {" f)
  (write-line "      : toggle { label = \"Corte\"; key = \"tipo_CORTE\"; value = \"1\"; }" f)
  (write-line "      : toggle { label = \"Nucleo\"; key = \"tipo_NUCLEO\"; value = \"1\"; }" f)
  (write-line "    }" f)
  (write-line "    : row {" f)
  (write-line "      : toggle { label = \"Excavacion\"; key = \"tipo_EXCAVACION\"; value = \"1\"; }" f)
  (write-line "      : toggle { label = \"Coraza\"; key = \"tipo_CORAZA\"; value = \"1\"; }" f)
  (write-line "    }" f)
  (write-line "    : row {" f)
  (write-line "      : toggle { label = \"Base\"; key = \"tipo_BASE\"; value = \"1\"; }" f)
  (write-line "      : toggle { label = \"Relleno\"; key = \"tipo_RELLENO\"; value = \"1\"; }" f)
  (write-line "    }" f)
  (write-line "    : row {" f)
  (write-line "      : toggle { label = \"Subrasante\"; key = \"tipo_SUBRASANTE\"; value = \"1\"; }" f)
  (write-line "      : toggle { label = \"Afine\"; key = \"tipo_AFINE\"; value = \"1\"; }" f)
  (write-line "    }" f)
  (write-line "  }" f)
  (write-line "  : boxed_column {" f)
  (write-line "    label = \"Estado\";" f)
  (write-line "    : text { key = \"estado\"; label = \"Listo para procesar...\"; width = 50; }" f)
  (write-line "  }" f)
  (write-line "  : row {" f)
  (write-line "    alignment = centered;" f)
  (write-line "    : button { label = \"Procesar\"; key = \"aceptar\"; is_default = true; width = 15; }" f)
  (write-line "    : button { label = \"Cancelar\"; key = \"cancelar\"; is_cancel = true; width = 15; }" f)
  (write-line "  }" f)
  (write-line "}" f)
  (close f)
  ruta
)

;===============================================================
; COMANDO PRINCIPAL
;===============================================================
(defun c:HAEA (/ dcl_file dcl_id resultado datos)
  
  (setq dcl_file (escribir-dcl-embebido))
  (setq dcl_id (load_dialog dcl_file))
  
  (if (< dcl_id 0)
    (progn
      (alert "Error al cargar el DCL embebido.")
      (exit)
    )
  )
  
  (if (not (new_dialog "haea_dialog" dcl_id))
    (progn
      (unload_dialog dcl_id)
      (exit)
    )
  )
  
  (set_tile "estado" "Selecciona accion y tipos de areas...")
  
  (cond
    ((= *haea_ultima_accion* "CSV") (set_tile "accion_csv" "1"))
    ((= *haea_ultima_accion* "HA") (set_tile "accion_ha" "1"))
    ((= *haea_ultima_accion* "AMBOS") (set_tile "accion_ambos" "1"))
  )
  
  (foreach tipo *haea_tipos_activos*
    (set_tile (strcat "tipo_" tipo) "1")
  )
  
  (action_tile "aceptar" 
    "(setq datos (recoger-datos-dcl))
     (if datos 
       (done_dialog 1)
       (set_tile \"estado\" \"ERROR: Selecciona al menos un tipo\"))")
  
  (action_tile "cancelar" "(done_dialog 0)")
  
  (setq resultado (start_dialog))
  (unload_dialog dcl_id)
  (vl-file-delete dcl_file)
  
  (if (= resultado 1)
    (progn
      (setq *haea_tipos_activos* (car datos))
      (setq *haea_ultima_accion* (cadr datos))
      
      ; Modo, distancia y cambiar capa fijos
      (setq *haea_ultimo_modo* "Auto")
      (setq *haea_limite_dist* 50.0)
      (setq *haea_cambiar_capa* T)
      
      (princ "\n\n========================================")
      (princ (strcat "\n  Modo: " *haea_ultimo_modo* " (fijo)"))
      (princ (strcat "\n  Accion: " *haea_ultima_accion*))
      (princ (strcat "\n  Limite: " (rtos *haea_limite_dist* 2 2) " (fijo)"))
      (princ (strcat "\n  Cambiar capa: SI (fijo)"))
      (princ "\n========================================")
      
      (cond
        ((= *haea_ultima_accion* "CSV") 
          (ejecutar-exportacion-csv *haea_prefijo* *haea_ultimo_modo*))
        ((= *haea_ultima_accion* "HA") 
          (ejecutar-etiquetado-ha *haea_prefijo* *haea_ultimo_modo*))
        ((= *haea_ultima_accion* "AMBOS") 
          (progn
            (princ "\n\n>>> PASO 1/2: ETIQUETANDO HATCHs...")
            (ejecutar-etiquetado-ha *haea_prefijo* *haea_ultimo_modo*)
            (princ "\n\n>>> PASO 2/2: EXPORTANDO A CSV...")
            (ejecutar-exportacion-csv *haea_prefijo* *haea_ultimo_modo*)))
      )
    )
    (princ "\nOperación cancelada.")
  )
  
  (princ)
)

;===============================================================
; RECOGER DATOS DEL DIÁLOGO
;===============================================================
(defun recoger-datos-dcl (/ tipos accion resp)
  
  (setq accion "HA")
  (if (= (get_tile "accion_csv") "1") (setq accion "CSV"))
  (if (= (get_tile "accion_ha") "1") (setq accion "HA"))
  (if (= (get_tile "accion_ambos") "1") (setq accion "AMBOS"))
  
  (setq tipos '())
  (foreach tipo '("CARPETA" "CORTE" "EXCAVACION" "BASE" "SUBRASANTE" 
                  "ARENA" "NUCLEO" "CORAZA" "RELLENO" "AFINE")
    (if (= (get_tile (strcat "tipo_" tipo)) "1")
      (setq tipos (cons tipo tipos))
    )
  )
  (setq tipos (reverse tipos))
  
  (if (= tipos nil)
    (setq resp nil)
    (setq resp (list tipos accion))
  )
  
  resp
)

;===============================================================
; OBTENER ÁREA CORRECTA DE UN HATCH
;===============================================================
(defun obtener-area-hatch (ent / obj area area_vla area_cmd resultado)
  
  (setq resultado nil)
  
  (setq obj (vlax-ename->vla-object ent))
  (setq area_vla (vl-catch-all-apply 'vla-get-area (list obj)))
  
  (if (not (vl-catch-all-error-p area_vla))
    (if (> area_vla 0)
      (setq resultado area_vla)
    )
  )
  
  (if (or (not resultado) (<= resultado 0))
    (progn
      (setq area_cmd (obtener-area-con-comando ent))
      (if (and area_cmd (> area_cmd 0))
        (setq resultado area_cmd)
      )
    )
  )
  
  (if (or (not resultado) (<= resultado 0))
    (progn
      (setq resultado (obtener-area-por-contorno ent))
    )
  )
  
  (if resultado resultado 0.0)
)

;===============================================================
; MÉTODO 2: Usar el comando AREA de AutoCAD
;===============================================================
(defun obtener-area-con-comando (ent / old_cmdecho old_osmode area_val)
  (setq old_cmdecho (getvar "CMDECHO"))
  (setq old_osmode (getvar "OSMODE"))
  (setvar "CMDECHO" 0)
  (setvar "OSMODE" 0)
  
  (setq area_val nil)
  
  (vl-catch-all-apply
    '(lambda ()
       (command "_.AREA" "_O" ent)
       (setq area_val (getvar "AREA"))
     )
  )
  
  (setvar "CMDECHO" old_cmdecho)
  (setvar "OSMODE" old_osmode)
  
  (if (and area_val (> area_val 0))
    area_val
    nil
  )
)

;===============================================================
; MÉTODO 3: Calcular área desde las coordenadas del contorno
;===============================================================
(defun obtener-area-por-contorno (ent / obj coords pts area i n
                                        x1 y1 x2 y2 suma p1 p2)
  (setq obj (vlax-ename->vla-object ent))
  (setq area 0.0)
  
  (setq coords (vl-catch-all-apply
                 '(lambda ()
                    (vlax-safearray->list
                      (vlax-variant-value
                        (vla-get-coordinates obj)))
                  )
               ))
  
  (if (not (vl-catch-all-error-p coords))
    (if coords
      (progn
        (setq pts '()
              i 0)
        (while (< i (length coords))
          (setq pts (cons (list (nth i coords) (nth (1+ i) coords)) pts))
          (setq i (+ i 2))
        )
        (setq pts (reverse pts))
        
        (setq n (length pts)
              suma 0.0
              i 0)
        (while (< i n)
          (setq p1 (nth i pts)
                p2 (nth (if (= i (1- n)) 0 (1+ i)) pts))
          (setq x1 (car p1)
                y1 (cadr p1)
                x2 (car p2)
                y2 (cadr p2))
          (setq suma (+ suma (- (* x1 y2) (* x2 y1))))
          (setq i (1+ i))
        )
        (setq area (abs (/ suma 2.0)))
      )
    )
  )
  
  area
)

;===============================================================
; EXTRAER TIPO DE UN TEXTO DE ÁREA
;===============================================================
(defun extraer-tipo-de-texto (texto / txt_upper resultado)
  (setq txt_upper (strcase texto)
        resultado nil)
  
  (cond
    ((wcmatch txt_upper "*CARPETA*") (setq resultado "CARPETA"))
    ((wcmatch txt_upper "*EXCAVACION*") (setq resultado "EXCAVACION"))
    ((wcmatch txt_upper "*EXCAVACIÓN*") (setq resultado "EXCAVACION"))
    ((wcmatch txt_upper "*SUBRASANTE*") (setq resultado "SUBRASANTE"))
    ((wcmatch txt_upper "*TERRAPLEN*") (setq resultado "TERRAPLEN"))
    ((wcmatch txt_upper "*RELLENO*") (setq resultado "RELLENO"))
    ((wcmatch txt_upper "*CORAZA*") (setq resultado "CORAZA"))
    ((wcmatch txt_upper "*NUCLEO*") (setq resultado "NUCLEO"))
    ((wcmatch txt_upper "*ARENA*") (setq resultado "ARENA"))
    ((wcmatch txt_upper "*CORTE*") (setq resultado "CORTE"))
    ((wcmatch txt_upper "*AFINE*") (setq resultado "AFINE"))
    ((wcmatch txt_upper "*DESMONTE*") (setq resultado "DESMONTE"))
    ((wcmatch txt_upper "*BASE*") (setq resultado "BASE"))
  )
  
  resultado
)

;===============================================================
; ETIQUETADO HA - BUSCA HATCH POR CAPA DEL TIPO (v5.2)
;===============================================================
(defun ejecutar-etiquetado-ha (prefijo modo / ss_textos i j 
                                hatch_ent hatch_obj area_val 
                                texto_datos nuevo_texto texto_original
                                texto_capa capa_hatch hatch_capa hatch_capa_upper
                                contador pos_texto 
                                mejor_dist dist
                                ss_hatch pos_hatch coord ent datos pos item
                                ignorados ok capa_texto
                                ent_texto contenido_texto
                                sin_match limite_dist minpt maxpt
                                tipo_texto area_hatch)
  
  (princ "\n\n=== ETIQUETADO POR TIPO (v5.2) ===")
  (princ "\nBusca el HATCH mas cercano EN LA CAPA del tipo")
  
  (setq ok T)
  
  (if (not *haea_limite_dist*) (setq *haea_limite_dist* 50.0))
  (setq limite_dist *haea_limite_dist*)
  (princ (strcat "\nDistancia maxima permitida: " (rtos limite_dist 2 2)))
  
  ; === PASO 1: Seleccionar TEXTOS ===
  (if (= modo "Auto")
    (progn
      (princ "\nSeleccionando textos automaticamente...")
      (setq ss_textos (ssget "_X" '((0 . "TEXT,MTEXT"))))
    )
    (progn
      (princ "\nSeleccione los TEXTOS a etiquetar: ")
      (setq ss_textos (ssget '((0 . "TEXT,MTEXT"))))
    )
  )
  
  (if (not ss_textos)
    (progn
      (princ "\n[!] No se seleccionaron textos.")
      (setq ok nil)
    )
  )
  
  ; === PASO 2: Filtrar SOLO textos con "AREA" ===
  (if ok
    (progn
      (setq lista_textos '()
            i 0
            ignorados 0)
      (repeat (sslength ss_textos)
        (setq ent (ssname ss_textos i)
              datos (entget ent)
              pos (cdr (assoc 10 datos))
              contenido (cdr (assoc 1 datos))
              capa (cdr (assoc 8 datos)))
        
        (if (and pos contenido)
          (progn
            (if (wcmatch (strcase contenido) "*AREA*")
              (setq lista_textos 
                    (cons (list ent pos contenido capa) lista_textos))
              (setq ignorados (1+ ignorados))
            )
          )
        )
        (setq i (1+ i))
      )
      
      (princ (strcat "\n[OK] Textos de area validos: " (itoa (length lista_textos))))
      (if (> ignorados 0)
        (princ (strcat "\n[--] Textos ignorados: " (itoa ignorados)))
      )
      
      (if (= lista_textos nil)
        (progn
          (princ "\n[!] No se encontraron textos de area validos.")
          (setq ok nil)
        )
      )
    )
  )
  
  ; === PASO 3: Seleccionar HATCHs ===
  (if ok
    (progn
      (princ "\n\nSeleccione los HATCHs a etiquetar: ")
      (setq ss_hatch (ssget '((0 . "HATCH"))))
      
      (if (not ss_hatch)
        (progn
          (princ "\n[!] No se seleccionaron HATCHs.")
          (setq ok nil)
        )
      )
    )
  )
  
  ; === PASO 4: Etiquetar POR TIPO ===
  (if ok
    (progn
      (princ (strcat "\n[OK] HATCHs seleccionados: " (itoa (sslength ss_hatch))))
      (princ "\n\nProcesando...")
      
      (setq contador 0
            sin_match 0)
      
      ; Para cada TEXTO
      (foreach texto_item lista_textos
        (setq ent_texto (car texto_item)
              pos_texto (cadr texto_item)
              contenido_texto (caddr texto_item)
              texto_capa (nth 3 texto_item))
        
        ; Extraer el TIPO del contenido del texto
        (setq tipo_texto (extraer-tipo-de-texto contenido_texto))
        
        ; Buscar el HATCH más cercano EN LA CAPA del tipo
        (setq mejor_dist 1e308
              capa_hatch nil
              area_hatch nil)
        
        (setq j 0)
        (repeat (sslength ss_hatch)
          (setq hatch_ent (ssname ss_hatch j))
          (setq hatch_capa (cdr (assoc 8 (entget hatch_ent))))
          (setq hatch_capa_upper (strcase hatch_capa))
          
          ; Verificar si la capa del HATCH coincide con el tipo del texto
          (if (and tipo_texto
                   (wcmatch hatch_capa_upper (strcat "*" tipo_texto "*")))
            (progn
              ; Obtener centro del HATCH
              (setq hatch_obj (vlax-ename->vla-object hatch_ent))
              (setq pos_hatch nil)
              (setq coord (vl-catch-all-apply
                            'vla-getboundingbox
                            (list hatch_obj 'minpt 'maxpt)))
              (if (not (vl-catch-all-error-p coord))
                (progn
                  (setq minpt (vlax-safearray->list minpt))
                  (setq maxpt (vlax-safearray->list maxpt))
                  (setq pos_hatch (list 
                                    (/ (+ (car minpt) (car maxpt)) 2.0)
                                    (/ (+ (cadr minpt) (cadr maxpt)) 2.0)
                                    0.0))
                )
              )
              
              (if (not pos_hatch)
                (setq pos_hatch (cdr (assoc 10 (entget hatch_ent))))
              )
              
              ; Calcular distancia
              (if (and pos_hatch pos_texto)
                (progn
                  (setq dist (distance pos_texto pos_hatch))
                  (if (< dist mejor_dist)
                    (setq mejor_dist dist
                          capa_hatch hatch_capa
                          area_hatch (obtener-area-hatch hatch_ent))
                  )
                )
              )
            )
          )
          
          (setq j (1+ j))
        )
        
        ; Actualizar el texto si encontramos HATCH
        (if (and area_hatch (<= mejor_dist limite_dist))
          (progn
            (setq texto_datos (entget ent_texto))
            (setq texto_original (cdr (assoc 1 texto_datos)))
            (setq area_val (rtos area_hatch 2 2))
            
            (setq nuevo_texto (reemplazar-solo-numero texto_original area_val))
            
            (entmod (subst (cons 1 nuevo_texto) (assoc 1 texto_datos) texto_datos))
            
            ; Cambiar capa del texto
            (if (and *haea_cambiar_capa*
                     (not (equal (strcase texto_capa) (strcase capa_hatch)))
                     (tblsearch "LAYER" capa_hatch))
              (progn
                (setq texto_datos (entget ent_texto))
                (entmod (subst (cons 8 capa_hatch) 
                               (assoc 8 texto_datos) 
                               texto_datos))
              )
            )
            
            (entupd ent_texto)
            
            (setq contador (1+ contador))
            (princ (strcat "\n   [" (itoa contador) "] OK | Tipo:" tipo_texto
                           " | HATCH capa:" capa_hatch
                           " | Area:" area_val))
            (princ (strcat "\n        Dist texto-HATCH: " (rtos mejor_dist 2 2)))
            (if (and *haea_cambiar_capa*
                     (not (equal (strcase texto_capa) (strcase capa_hatch))))
              (princ (strcat "\n        Capa: [" texto_capa "] -> [" capa_hatch "]"))
            )
            (princ (strcat "\n        '" texto_original "' -> '" nuevo_texto "'"))
          )
          (progn
            (setq sin_match (1+ sin_match))
            (princ (strcat "\n   [!] SIN HATCH | Tipo:" 
                           (if tipo_texto tipo_texto "DESCONOCIDO")
                           " | Texto: " contenido_texto))
            (if mejor_dist
              (princ (strcat "\n        Mejor dist: " (rtos mejor_dist 2 2)
                             " > limite " (rtos limite_dist 2 2)))
            )
          )
        )
      )
      
      (princ "\n\n========================================")
      (princ (strcat "\n[OK] Etiquetados: " (itoa contador) " de " 
                     (itoa (length lista_textos))))
      (if (> sin_match 0)
        (princ (strcat "\n[!] Sin HATCH: " (itoa sin_match)))
      )
      (princ "\n========================================")
    )
  )
  
  (princ)
)

;===============================================================
; REEMPLAZA SOLO EL VALOR NUMÉRICO EN EL TEXTO
;===============================================================
(defun reemplazar-solo-numero (texto_original nuevo_valor / 
                                i char resultado 
                                pos_igual pos_inicio pos_fin
                                longitud encontrado)
  
  (setq resultado ""
        i 1
        pos_igual nil
        pos_inicio nil
        pos_fin nil
        encontrado nil
        longitud (strlen texto_original))
  
  (while (<= i longitud)
    (setq char (substr texto_original i 1))
    (if (and (not pos_igual)
             (or (= char "=") (= char ":")))
      (setq pos_igual i)
    )
    (setq i (1+ i))
  )
  
  (setq i (if pos_igual (1+ pos_igual) 1))
  
  (while (<= i longitud)
    (setq char (substr texto_original i 1))
    
    (if (and (not encontrado)
             (wcmatch char "[0-9]"))
      (progn
        (setq pos_inicio i
              encontrado T)
      )
    )
    
    (if (and encontrado (not pos_fin) (> i pos_inicio))
      (progn
        (if (not (or (wcmatch char "[0-9]") (= char ".")))
          (setq pos_fin (1- i))
        )
      )
    )
    
    (setq i (1+ i))
  )
  
  (if (and encontrado (not pos_fin))
    (setq pos_fin longitud)
  )
  
  (if (and pos_inicio pos_fin)
    (progn
      (setq resultado (substr texto_original 1 (1- pos_inicio)))
      (setq resultado (strcat resultado nuevo_valor))
      (if (< pos_fin longitud)
        (setq resultado (strcat resultado (substr texto_original (1+ pos_fin))))
      )
    )
    (setq resultado texto_original)
  )
  
  resultado
)

;===============================================================
; EXPORTACIÓN CSV
;===============================================================
(defun ejecutar-exportacion-csv (prefijo modo / ss textos lista_estaciones 
                                   archivo file old_cmdecho contador_exportados 
                                   datos_emparejados i registro linea cabecera_csv 
                                   capas_encontradas tipos_encontrados 
                                   indices_tipos estadisticas ok)

  (setq old_cmdecho (getvar "CMDECHO"))
  (setvar "CMDECHO" 0)
  (setq ok T)
  
  (princ "\n\n=== EXPORTANDO A CSV ===")
  
  (if (= modo "Auto")
    (progn
      (princ "\nSeleccionando todos los textos...")
      (setq ss (ssget "_X" '((0 . "TEXT,MTEXT"))))
    )
    (progn
      (princ "\nSeleccione textos: ")
      (setq ss (ssget '((0 . "TEXT,MTEXT"))))
    )
  )
  
  (if (not ss)
    (progn
      (princ "\nNo se seleccionaron textos.")
      (setq ok nil)
    )
  )
  
  (if ok
    (progn
      (setq capas_encontradas (detectar-capas-y-contenidos ss))
      (setq archivo (getfiled "Guardar archivo CSV" "" "csv" 1))
      (if (not archivo)
        (progn
          (princ "\nOperación cancelada.")
          (setq ok nil)
        )
      )
    )
  )
  
  (if ok
    (progn
      (setq textos (procesar-seleccion-con-capas ss)
            lista_estaciones '())
      
      (foreach tipo *haea_tipos_activos*
        (set (read (strcat "lista_areas_" tipo)) '())
      )
      
      (setq estadisticas (clasificar-textos-inteligente textos))
      (setq lista_estaciones (car estadisticas))
      
      (setq tipos_encontrados '())
      (foreach tipo *haea_tipos_activos*
        (setq cantidad (length (eval (read (strcat "lista_areas_" tipo)))))
        (if (> cantidad 0)
          (setq tipos_encontrados (cons tipo tipos_encontrados))
        )
      )
      (setq tipos_encontrados (reverse tipos_encontrados))
      
      (setq indices_tipos '()
            indice 1)
      (foreach tipo tipos_encontrados
        (setq indices_tipos (cons (cons tipo indice) indices_tipos))
        (setq indice (1+ indice))
      )
      
      (princ (strcat "\n\nEstaciones: " (itoa (length lista_estaciones))))
      (princ (strcat "\nTipos detectados: " (itoa (length tipos_encontrados))))
      
      (foreach tipo tipos_encontrados
        (princ (strcat "\n   " tipo ": " 
                       (itoa (length (eval (read (strcat "lista_areas_" tipo)))))
                       " areas"))
      )
      
      (setq datos_emparejados (emparejar-por-proximidad-dinamico 
                                lista_estaciones tipos_encontrados indices_tipos))
      
      (setq cabecera_csv "ESTACION")
      (foreach tipo tipos_encontrados
        (setq cabecera_csv (strcat cabecera_csv "," (strcase tipo)))
      )
      
      (setq file (open archivo "w"))
      (write-line cabecera_csv file)
      
      (setq contador_exportados 0)
      (foreach registro datos_emparejados
        (write-line (formatear-linea-csv-dinamico registro) file)
        (setq contador_exportados (1+ contador_exportados))
      )
      (close file)
      
      (princ (strcat "\n\n[OK] Exportados " (itoa contador_exportados) " registros"))
      (princ (strcat "\n[OK] Archivo: " archivo))
      
      (if (findfile "EXCEL.EXE")
        (startapp "EXCEL" archivo)
        (startapp "notepad" archivo)
      )
    )
  )
  
  (setvar "CMDECHO" old_cmdecho)
  (princ)
)

;===============================================================
; FUNCIONES AUXILIARES
;===============================================================

(defun detectar-capas-y-contenidos (ss / capas i ent datos capa texto)
  (setq capas '() i 0)
  (repeat (sslength ss)
    (setq ent (ssname ss i)
          datos (entget ent)
          capa (cdr (assoc 8 datos))
          texto (cdr (assoc 1 datos)))
    (if (and (not (member capa capas)) (/= texto ""))
      (setq capas (cons capa capas))
    )
    (setq i (1+ i))
  )
  (reverse capas)
)

(defun procesar-seleccion-con-capas (ss / i ent datos texto posicion capa resultados)
  (setq resultados '() i 0)
  (repeat (sslength ss)
    (setq ent (ssname ss i)
          datos (entget ent)
          texto (cdr (assoc 1 datos))
          posicion (cdr (assoc 10 datos))
          capa (cdr (assoc 8 datos)))
    (if (and texto (/= texto ""))
      (setq resultados (cons (list texto posicion capa) resultados))
    )
    (setq i (1+ i))
  )
  resultados
)

(defun clasificar-textos-inteligente (textos / lista_estaciones tipos_detectados
                                              contenido contenido_upper capa
                                              valor_estacion valor_area tipo_encontrado
                                              nombre_tipo patrones contador_ignorados)
  (setq lista_estaciones '() 
        tipos_detectados '()
        contador_ignorados 0)
  
  (foreach texto textos
    (setq contenido (car texto)
          posicion (cadr texto)
          capa (caddr texto)
          contenido_upper (strcase contenido))
    
    (if (debe-ignorar-texto? contenido capa)
      (setq contador_ignorados (1+ contador_ignorados))
      (progn
        (if (es-estacion? contenido)
          (progn
            (setq valor_estacion (extraer-numero-estacion-avanzado contenido))
            (if valor_estacion
              (progn
                (setq lista_estaciones (cons (list valor_estacion posicion) lista_estaciones))
                (princ (strcat "\n   * Estacion: " (rtos valor_estacion 2 3) " [" capa "]"))
              )
            )
          )
        )
        
        (setq tipo_encontrado nil)
        (foreach tipo *haea_tipos_areas*
          (setq nombre_tipo (car tipo)
                patrones (cadr tipo))
          
          (if (and (not tipo_encontrado) (member nombre_tipo *haea_tipos_activos*))
            (progn
              (foreach patron patrones
                (if (and (not tipo_encontrado) (wcmatch contenido_upper patron))
                  (progn
                    (setq valor_area (extraer-numero contenido))
                    (if valor_area
                      (progn
                        (set (read (strcat "lista_areas_" nombre_tipo)) 
                             (cons (list valor_area posicion) 
                                   (eval (read (strcat "lista_areas_" nombre_tipo)))))
                        (setq tipo_encontrado T)
                        (if (not (member nombre_tipo tipos_detectados))
                          (setq tipos_detectados (cons nombre_tipo tipos_detectados))
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
  
  (if (> contador_ignorados 0)
    (princ (strcat "\n\n   Total textos ignorados: " (itoa contador_ignorados)))
  )
  
  (list lista_estaciones tipos_detectados)
)

(defun emparejar-por-proximidad-dinamico (estaciones tipos_encontrados indices_tipos / resultados i mejor_dist mejor_indice mejor_estacion nuevo_resultado valor_est valor_area pos_area pos_est dist lista_areas indice_tipo)
  (setq resultados '())
  
  (foreach estacion estaciones
    (setq valor_est (car estacion)
          registro (list valor_est))
    (foreach tipo tipos_encontrados
      (setq registro (append registro (list 0.0)))
    )
    (setq resultados (cons registro resultados))
  )
  
  (setq resultados (vl-sort resultados '(lambda (x y) (< (car x) (car y)))))
  
  (foreach tipo tipos_encontrados
    (setq lista_areas (eval (read (strcat "lista_areas_" tipo)))
          indice_tipo (cdr (assoc tipo indices_tipos)))
    
    (foreach area lista_areas
      (setq valor_area (car area)
            pos_area (cadr area)
            mejor_dist 1e308
            mejor_indice nil)
      
      (setq i 0)
      (foreach resultado resultados
        (setq valor_est (car resultado)
              pos_est (buscar-posicion-estacion valor_est estaciones)
              dist (distance pos_area pos_est))
        (if (< dist mejor_dist)
          (setq mejor_dist dist
                mejor_indice i)
        )
        (setq i (1+ i))
      )
      
      (if mejor_indice
        (progn
          (setq mejor_estacion (nth mejor_indice resultados))
          (setq nuevo_resultado (reemplazar-elemento mejor_estacion indice_tipo valor_area))
          (setq resultados (reemplazar-en-lista resultados mejor_indice nuevo_resultado))
        )
      )
    )
  )
  
  resultados
)

(defun buscar-posicion-estacion (valor_est lista_estaciones / resultado)
  (setq resultado nil)
  (foreach estacion lista_estaciones
    (if (equal (car estacion) valor_est 0.001)
      (setq resultado (cadr estacion))
    )
  )
  resultado
)

(defun formatear-linea-csv-dinamico (registro / linea i valor)
  (setq linea (rtos (car registro) 2 3)
        i 1)
  (repeat (1- (length registro))
    (setq valor (nth i registro))
    (setq linea (strcat linea "," (rtos valor 2 3)))
    (setq i (1+ i))
  )
  linea
)

(defun reemplazar-elemento (lista indice nuevo_valor / resultado i)
  (setq resultado '() i 0)
  (foreach elemento lista
    (if (= i indice)
      (setq resultado (cons nuevo_valor resultado))
      (setq resultado (cons elemento resultado))
    )
    (setq i (1+ i))
  )
  (reverse resultado)
)

(defun reemplazar-en-lista (lista indice nuevo_elemento / resultado i)
  (setq resultado '() i 0)
  (foreach elemento lista
    (if (= i indice)
      (setq resultado (cons nuevo_elemento resultado))
      (setq resultado (cons elemento resultado))
    )
    (setq i (1+ i))
  )
  (reverse resultado)
)

(defun extraer-numero-estacion-avanzado (str / i char encontrado_numero 
                                               bandera_despues_del_mas antes_del_mas 
                                               despues_del_mas parte_antes parte_despues
                                               txt_upper)
  (setq txt_upper (strcase str))
  
  (if (not (wcmatch txt_upper "*+*"))
    (progn
      (if (or (wcmatch txt_upper "*ESTACION*")
              (wcmatch txt_upper "*ESTACIÓN*")
              (wcmatch txt_upper "*PROGRESIVA*")
              (wcmatch txt_upper "*STA*"))
        (extraer-numero-estacion-alternativo str)
        nil
      )
    )
    (progn
      (setq encontrado_numero nil
            bandera_despues_del_mas nil
            antes_del_mas ""
            despues_del_mas ""
            i 1)
      
      (while (<= i (strlen str))
        (setq char (substr str i 1))
        (cond
          ((= char "+") (setq bandera_despues_del_mas T))
          ((and (not bandera_despues_del_mas) (wcmatch char "[0-9]"))
           (setq antes_del_mas (strcat antes_del_mas char)))
          ((and bandera_despues_del_mas (wcmatch char "[0-9.]"))
           (setq despues_del_mas (strcat despues_del_mas char))
           (setq encontrado_numero T))
          ((and bandera_despues_del_mas (wcmatch char "[A-Za-z]"))
           (setq i (strlen str)))
        )
        (setq i (1+ i))
      )
      
      (if encontrado_numero
        (progn
          (if (/= antes_del_mas "")
            (setq parte_antes (* (atof antes_del_mas) 1000.0))
            (setq parte_antes 0.0)
          )
          (setq parte_despues (atof (vl-string-translate "," "." despues_del_mas)))
          (+ parte_antes parte_despues)
        )
        nil
      )
    )
  )
)

(defun extraer-numero-estacion-alternativo (str / num_str i char encontrado_numero)
  (setq num_str "" encontrado_numero nil i 1)
  (while (<= i (strlen str))
    (setq char (substr str i 1))
    (cond
      ((wcmatch char "[0-9]")
       (setq num_str (strcat num_str char))
       (setq encontrado_numero T))
      ((and (wcmatch char "[.,]") encontrado_numero)
       (setq num_str (strcat num_str char)))
    )
    (setq i (1+ i))
  )
  (if (and encontrado_numero (/= num_str ""))
    (atof (vl-string-translate "," "." num_str))
    nil
  )
)

(defun es-estacion? (texto / txt_upper)
  (setq txt_upper (strcase texto))
  
  (if (or
        (wcmatch txt_upper "*ESCALA*")
        (wcmatch txt_upper "*ESCAL*")
        (wcmatch txt_upper "* : *")
        (wcmatch txt_upper "*1:*")
        (wcmatch txt_upper "*:1*")
        (wcmatch txt_upper "*LAMINA*")
        (wcmatch txt_upper "*LÁMINA*")
        (wcmatch txt_upper "*PLANO*")
        (wcmatch txt_upper "*TITULO*")
        (wcmatch txt_upper "*TÍTULO*")
        (wcmatch txt_upper "*PROYECTO*")
        (wcmatch txt_upper "*FECHA*")
        (wcmatch txt_upper "*DIBUJO*")
        (wcmatch txt_upper "*DIBUJANTE*")
        (wcmatch txt_upper "*REVISO*")
        (wcmatch txt_upper "*DISEÑO*")
        (wcmatch txt_upper "*ING.*")
        (wcmatch txt_upper "*ARQ.*")
        (wcmatch txt_upper "*NORTE*")
        (wcmatch txt_upper "*CROQUIS*")
        (wcmatch txt_upper "*SIMBOLOGIA*")
        (wcmatch txt_upper "*SIMBOLOGÍA*")
        (wcmatch txt_upper "*LEYENDA*")
        (wcmatch txt_upper "*NOTA:*")
      )
    nil
    (progn
      (or
        (wcmatch txt_upper "*ESTACION*")
        (wcmatch txt_upper "*ESTACIÓN*")
        (wcmatch txt_upper "*PROGRESIVA*")
        (wcmatch txt_upper "*STA*")
        (wcmatch txt_upper "*STATION*")
        (wcmatch txt_upper "*[0-9]+[0-9]*")
        (wcmatch txt_upper "*[0-9]+[0-9].[0-9]*")
        (wcmatch txt_upper "K[0-9]+[0-9]*")
      )
    )
  )
)

(defun extraer-numero (str / num_str char i encontrado_numero 
                            punto_decimal encontrado_letra txt_upper)
  (setq txt_upper (strcase str))
  
  (if (or
        (wcmatch txt_upper "*ESCALA*")
        (wcmatch txt_upper "* : *")
        (wcmatch txt_upper "*1:*")
        (wcmatch txt_upper "*:1*")
      )
    nil
    (progn
      (setq num_str "" 
            encontrado_numero nil 
            punto_decimal nil 
            encontrado_letra nil 
            i 1)
      
      (while (<= i (strlen str))
        (setq char (substr str i 1))
        
        (if (and encontrado_numero (wcmatch char "[a-zA-Z]"))
          (setq encontrado_letra T)
        )
        
        (cond
          (encontrado_letra 
            (setq i (strlen str)))
          ((wcmatch char "[0-9]")
           (setq num_str (strcat num_str char))
           (setq encontrado_numero T))
          ((and (wcmatch char ".") encontrado_numero (not punto_decimal))
           (setq num_str (strcat num_str char))
           (setq punto_decimal T))
          ((and (wcmatch char ",") encontrado_numero (not punto_decimal))
           (setq num_str (strcat num_str "."))
           (setq punto_decimal T))
          ((and (wcmatch char "-") (= num_str ""))
           (setq num_str (strcat num_str char)))
        )
        (setq i (1+ i))
      )
      
      (if (and encontrado_numero (/= num_str ""))
        (atof num_str)
        nil
      )
    )
  )
)

(defun debe-ignorar-texto? (contenido capa / contenido_upper capa_upper resultado)
  (setq contenido_upper (strcase contenido)
        capa_upper (strcase capa)
        resultado nil)
  
  (if *haea_usar_filtro_capas*
    (progn
      (foreach capa_ignorar *haea_capas_ignorar*
        (if (and (not resultado) 
                 (= capa_upper (strcase capa_ignorar)))
          (setq resultado T)
        )
      )
    )
  )
  
  (if (and (not resultado) *haea_usar_filtro_textos*)
    (progn
      (foreach patron *haea_textos_ignorar*
        (if (and (not resultado) 
                 (wcmatch contenido_upper (strcase patron)))
          (setq resultado T)
        )
      )
    )
  )
  
  resultado
)

;===============================================================
; COMANDO HA (versión rápida - manual)
;===============================================================
(defun c:HA (/ hatch_ent text_ent hatch_obj area_val texto_datos 
               nuevo_texto texto_original capa_hatch capa_texto)
  (vl-load-com)
  
  (princ "\n=== HA RAPIDO - Manual ===")
  
  (setq hatch_ent (car (entsel "\nSelecciona HATCH: ")))
  (if (and hatch_ent (= (cdr (assoc 0 (entget hatch_ent))) "HATCH"))
    (progn
      (setq hatch_obj (vlax-ename->vla-object hatch_ent))
      (setq area_val (rtos (obtener-area-hatch hatch_ent) 2 2))
      (setq capa_hatch (cdr (assoc 8 (entget hatch_ent))))
      
      (princ (strcat "\n  CAPA del HATCH: " capa_hatch))
      (princ (strcat "\n  Area calculada: " area_val " m2"))
      
      (setq text_ent (car (entsel "\nSelecciona TEXT: ")))
      (if (and text_ent (wcmatch (cdr (assoc 0 (entget text_ent))) "TEXT,MTEXT"))
        (progn
          (setq texto_datos (entget text_ent))
          (setq texto_original (cdr (assoc 1 texto_datos)))
          (setq capa_texto (cdr (assoc 8 texto_datos)))
          (setq nuevo_texto (reemplazar-solo-numero texto_original area_val))
          
          (entmod (subst (cons 1 nuevo_texto) (assoc 1 texto_datos) texto_datos))
          
          (if (and *haea_cambiar_capa*
                   (not (equal (strcase capa_texto) (strcase capa_hatch)))
                   (tblsearch "LAYER" capa_hatch))
            (progn
              (setq texto_datos (entget text_ent))
              (entmod (subst (cons 8 capa_hatch) (assoc 8 texto_datos) texto_datos))
              (princ (strcat "\n  Capa: [" capa_texto "] -> [" capa_hatch "]"))
            )
          )
          
          (entupd text_ent)
          (princ (strcat "\n  '" texto_original "' -> '" nuevo_texto "'"))
        )
        (princ "\n! Texto no válido")
      )
    )
    (princ "\n! Hatch no válido")
  )
  (princ)
)

;===============================================================
; COMANDO EA
;===============================================================
(defun c:EA ()
  (if (not *haea_usar_filtro_capas*) (setq *haea_usar_filtro_capas* T))
  (if (not *haea_usar_filtro_textos*) (setq *haea_usar_filtro_textos* T))
  (ejecutar-exportacion-csv *haea_prefijo* "Auto")
)

;===============================================================
; MENSAJE DE CARGA
;===============================================================
(princ "\n==========================================")
(princ "\n  HAEA v5.2 - DCL SIMPLIFICADO")
(princ "\n  Etiqueta por CAPA DEL TIPO + Exporta")
(princ "\n==========================================")
(princ "\n  HAEA         -> Interfaz completa")
(princ "\n  HA           -> Etiquetado rapido manual")
(princ "\n  EA           -> Exportacion a Excel")
(princ "\n==========================================")
(princ "\nModo Auto, Distancia 50, Cambiar capa SI")
(princ)