;;; MEMO SISTEMA 2.0.0 - archivo generado por construir_bundle.py
;;; Origen: LISP_Textos/Suma Valores Textos ( ST ).lsp

(defun c:ST (/ ss textos num_list suma pt altura_texto ent texto_original str num i h)
  (vl-load-com)
  
  (princ "\n=== SUMAR VALORES DE TEXTOS ===\n")
  (princ "Selecciona textos para sumar sus valores numéricos\n")
  (princ "Puedes seleccionar individualmente o por ventana/cruce\n")
  
  ; Seleccionar textos (individual o por ventana)
  (setq ss (ssget '((0 . "TEXT,MTEXT,ATTRIB"))))
  (if (not ss)
    (progn
      (alert "No se seleccionaron textos.")
      (exit)
    )
  )
  
  ; Procesar todos los textos seleccionados
  (setq textos '())
  (setq num_list '())
  (setq suma 0.0)
  
  (princ "\n--- PROCESANDO TEXTOS ---\n")
  
  (repeat (setq i (sslength ss))
    (setq ent (ssname ss (setq i (1- i))))
    (setq texto_original (cdr (assoc 1 (entget ent))))
    (setq str texto_original)
    
    ; Extraer número del texto
    (setq num (extraer-numero-mejorado str))
    
    (if num
      (progn
        (setq num_list (cons num num_list))
        (princ (strcat "Texto: \"" str "\" -> Valor: " (rtos num 2 3) "\n"))
        (setq suma (+ suma num))
      )
      (princ (strcat "Texto: \"" str "\" -> SIN VALOR NUMÉRICO (omitido)\n"))
    )
  )
  
  ; Verificar que se encontraron números válidos
  (if (not num_list)
    (progn
      (alert "No se pudieron extraer valores numéricos de los textos seleccionados.")
      (exit)
    )
  )
  
  ; Mostrar resumen
  (princ "\n--- RESUMEN DE SUMA ---\n")
  (setq i 1)
  (foreach num (reverse num_list)
    (if (= i 1)
      (princ (strcat (rtos num 2 3)))
      (princ (strcat " + " (rtos num 2 3)))
    )
    (setq i (1+ i))
  )
  (princ (strcat " = " (rtos suma 2 3) "\n"))
  
  ; Obtener altura del primer texto válido para mantener el mismo tamaño
  (setq altura_texto nil)
  (setq i 0)
  (while (and (not altura_texto) (< i (sslength ss)))
    (setq ent (ssname ss i))
    (setq h (cdr (assoc 40 (entget ent))))
    (if h (setq altura_texto h))
    (setq i (1+ i))
  )
  (if (not altura_texto)
    (setq altura_texto (getvar "TEXTSIZE"))
  )
  
  ; Pedir punto de inserción para el texto resultante
  (setq pt (getpoint "\nPunto de inserción para el texto de la suma: "))
  (if (not pt)
    (progn
      (alert "No se seleccionó punto de inserción.")
      (exit)
    )
  )
  
  ; Crear el texto con la suma
  (crear-texto-suma pt suma altura_texto)
  
  (princ (strcat "\n>>> Texto con suma creado: " (rtos suma 2 3) " <<<\n"))
  (princ (strcat ">>> Total de textos procesados: " (itoa (length num_list)) " de " (itoa (sslength ss)) " <<<\n"))
  (princ)
)

; FUNCIÓN MEJORADA PARA EXTRAER NÚMEROS
(defun extraer-numero-mejorado (str / str_limpio num_str char i found_digit found_decimal encontrado_numero)
  ; Primero limpiar el texto de "m2", "m²" y espacios
  (setq str_limpio (vl-string-trim " " (vl-string-translate "m²" "m2" (strcase str))))
  
  ; Si el texto termina con "M2", quitarlo
  (if (and (> (strlen str_limpio) 2)
           (wcmatch (substr str_limpio (- (strlen str_limpio) 1)) "M2"))
    (setq str_limpio (substr str_limpio 1 (- (strlen str_limpio) 2)))
  )
  
  ; También quitar "M2" si está al final con espacio
  (if (and (> (strlen str_limpio) 3)
           (wcmatch (substr str_limpio (- (strlen str_limpio) 2)) " M2"))
    (setq str_limpio (substr str_limpio 1 (- (strlen str_limpio) 3)))
  )
  
  (setq num_str "")
  (setq found_digit nil)
  (setq found_decimal nil)
  (setq encontrado_numero nil)
  
  (setq i 1)
  (while (<= i (strlen str_limpio))
    (setq char (substr str_limpio i 1))
    
    (cond
      ; Si es dígito
      ((wcmatch char "[0-9]")
       (setq num_str (strcat num_str char))
       (setq found_digit T)
       (setq encontrado_numero T)
      )
      
      ; Si es punto decimal y no se ha encontrado otro antes
      ((and (wcmatch char ".")
            found_digit
            (not found_decimal))
       (setq num_str (strcat num_str char))
       (setq found_decimal T)
      )
      
      ; Si es coma (convertir a punto)
      ((and (wcmatch char ",")
            found_digit
            (not found_decimal))
       (setq num_str (strcat num_str "."))
       (setq found_decimal T)
      )
      
      ; Si es signo negativo al inicio
      ((and (wcmatch char "-")
            (= num_str ""))
       (setq num_str (strcat num_str char))
      )
      
      ; Si encontramos un espacio y ya tenemos número, podemos terminar
      ((and (wcmatch char " ")
            encontrado_numero)
       (setq i (strlen str_limpio)) ; Salir del bucle
      )
      
      ; Si encontramos cualquier otro carácter y ya tenemos número, terminar
      ((and encontrado_numero
            (not (wcmatch char "[0-9].,-")))
       (setq i (strlen str_limpio)) ; Salir del bucle
      )
    )
    
    (setq i (1+ i))
  )
  
  ; DEBUG: Mostrar qué se está extrayendo
  (princ (strcat " [DEBUG: Texto limpio: \"" str_limpio "\" -> Extraído: \"" num_str "\"] "))
  
  ; Convertir a número si se encontraron dígitos
  (if (and encontrado_numero (/= num_str ""))
    (progn
      ; Asegurarse de que no termina con punto o coma
      (if (wcmatch (substr num_str (strlen num_str)) "[.,]")
        (setq num_str (substr num_str 1 (1- (strlen num_str))))
      )
      (atof num_str)
    )
    nil
  )
)

; Función alternativa más simple y robusta
(defun extraer-numero-simple-mejorado (str / nums i c decimal)
  (setq nums "")
  (setq i 1)
  (setq decimal nil)
  
  (while (<= i (strlen str))
    (setq c (substr str i 1))
    
    (cond
      ((wcmatch c "[0-9]")
       (setq nums (strcat nums c)))
      
      ((and (or (= c ".") (= c ",")) 
            (not decimal) 
            (/= nums ""))
       (setq nums (strcat nums "."))
       (setq decimal T))
    )
    
    (setq i (1+ i))
  )
  
  (if (and (/= nums "") (> (strlen nums) 0))
    (atof nums)
    nil
  )
)

; Función para crear texto con la suma
(defun crear-texto-suma (pt suma altura / texto_ent)
  ; Formatear el texto de la suma
  (setq texto_suma (rtos suma 2 3)) ; 3 decimales para mejor precisión
  
  ; Crear entidad de texto
  (setq texto_ent (entmakex
    (list
      '(0 . "TEXT")
      '(100 . "AcDbEntity")
      '(100 . "AcDbText")
      (cons 10 pt)
      (cons 1 texto_suma)
      (cons 40 altura)
      '(7 . "Standard")
      '(50 . 0.0)
      '(41 . 1.0)
      '(51 . 0.0)
      '(71 . 0)
      '(72 . 0)
      '(73 . 0)
      (cons 11 pt)
    )
  ))
  
  texto_ent
)

; Versión de prueba con la función simple
(defun c:ST-TEST (/ ss ent str num suma i)
  (princ "\n=== TEST DE EXTRACCIÓN ===\n")
  
  (setq ss (ssget '((0 . "TEXT,MTEXT,ATTRIB"))))
  (if (not ss) (exit))
  
  (setq suma 0.0)
  (repeat (setq i (sslength ss))
    (setq ent (ssname ss (setq i (1- i))))
    (setq str (cdr (assoc 1 (entget ent))))
    
    (setq num (extraer-numero-simple-mejorado str))
    
    (if num
      (progn
        (princ (strcat "Texto: \"" str "\"\n"))
        (princ (strcat "  -> Número extraído: " (rtos num 2 4) "\n"))
        (setq suma (+ suma num))
      )
      (princ (strcat "Texto: \"" str "\" -> NO se pudo extraer número\n"))
    )
  )
  
  (princ (strcat "\nSUMA TOTAL: " (rtos suma 2 4) "\n"))
  (princ)
)

(princ "\nComandos cargados: ST (suma normal) - ST-TEST (modo prueba)")
(princ)