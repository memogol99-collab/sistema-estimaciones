;;; MEMO SISTEMA 2.0.0 - archivo generado por construir_bundle.py
;;; Origen: LISP_Textos/Texto_Alto_Ancho.lsp

(defun c:CTAF ( / *error* oldcmdecho oldregen altura factor ss i ent data starttime endtime segundos)
  ; Función de error
  (defun *error* (msg)
    (if oldcmdecho (setvar "CMDECHO" oldcmdecho))
    (if oldregen (setvar "REGENMODE" oldregen))
    (princ)
  )
  
  ; Desactivar características que ralentizan
  (setq oldcmdecho (getvar "CMDECHO"))
  (setq oldregen (getvar "REGENMODE"))
  (setvar "CMDECHO" 0)
  (setvar "REGENMODE" 0)
  
  ; Solicitar parámetros
  (initget 7)
  (setq altura (getdist "\nNueva altura de texto: "))
  
  (initget 7)
  (setq factor (getreal "\nNuevo factor de anchura: "))
  
  ; Contador de tiempo
  (setq starttime (getvar "MILLISECS"))
  
  ; Seleccionar textos por VENTANA/CRUCE (cambiar aquí)
  (princ "\nSeleccione textos [Ventana/Cruce/Todos/Ayuda] <Ventana>: ")
  (setq ss (ssget '((0 . "TEXT,MTEXT")))) ; Selección interactiva
  
  (if ss
    (progn
      (princ (strcat "\nEncontrados " (itoa (sslength ss)) " textos. Procesando..."))
      
      ; Procesar usando entmod
      (repeat (setq i (sslength ss))
        (setq ent (ssname ss (setq i (1- i))))
        (setq data (entget ent))
        
        ; Modificar altura (código 40 para TEXT, 43 para MTEXT)
        (setq data (subst (cons 40 altura) (assoc 40 data) data))
        
        ; Para TEXT: factor de anchura (código 41)
        (if (= (cdr (assoc 0 data)) "TEXT")
          (setq data (subst (cons 41 factor) (assoc 41 data) data))
          ; Para MTEXT: ancho (código 41) = altura * factor
          (setq data (subst (cons 41 (* altura factor)) (assoc 41 data) data))
        )
        
        ; Aplicar cambios
        (entmod data)
        
        ; Mostrar progreso cada 1000 textos
        (if (= (rem (1+ i) 1000) 0)
          (princ (strcat "\rProcesados " (itoa (- (sslength ss) i)) " textos..."))
        )
      )
      
      ; Calcular tiempo transcurrido
      (setq endtime (getvar "MILLISECS"))
      (setq segundos (/ (- endtime starttime) 1000.0))
      
      ; Mostrar resultados
      (princ (strcat "\r? Modificados " (itoa (sslength ss)) " textos en " 
                     (rtos segundos 2 2) " segundos"))
      (princ (strcat "\n  Velocidad: " 
                     (rtos (/ (sslength ss) segundos) 2 0) " textos/segundo"))
      (princ (strcat "\n  - Altura: " (rtos altura 2 2)))
      (princ (strcat "\n  - Factor anchura: " (rtos factor 2 2)))
    )
    (princ "\n? No se seleccionaron textos.")
  )
  
  ; Restaurar variables
  (setvar "CMDECHO" oldcmdecho)
  (setvar "REGENMODE" oldregen)
  
  ; Forzar regeneración final
  (command "_.REGEN")
  
  (princ)
)

; Versión ULTRA-RÁPIDA con valores predefinidos
(defun c:CTF ( / ss i ent data starttime segundos)
  (setvar "CMDECHO" 0)
  (setvar "REGENMODE" 0)
  
  (setq starttime (getvar "MILLISECS"))
  
  ; Seleccionar por ventana/cruce en lugar de todos
  (princ "\nSeleccione textos [Altura=0.35, Factor=0.60]: ")
  (setq ss (ssget '((0 . "TEXT,MTEXT"))))
  
  (if ss
    (progn
      (princ (strcat "\nModificando " (itoa (sslength ss)) " textos a Altura=0.35, Factor=0.60..."))
      
      (repeat (setq i (sslength ss))
        (setq ent (ssname ss (setq i (1- i))))
        (setq data (entget ent))
        
        ; Valores predefinidos
        (setq data (subst (cons 40 0.35) (assoc 40 data) data))
        
        (if (= (cdr (assoc 0 data)) "TEXT")
          (setq data (subst (cons 41 0.60) (assoc 41 data) data))
          (setq data (subst (cons 41 (* 0.35 0.60)) (assoc 41 data) data))
        )
        
        (entmod data)
      )
      
      (setq segundos (/ (- (getvar "MILLISECS") starttime) 1000.0))
      (princ (strcat "\n? Listo! " (itoa (sslength ss)) " textos en " 
                     (rtos segundos 2 2) " segundos"))
    )
    (princ "\n? No se seleccionaron textos.")
  )
  
  (setvar "CMDECHO" 1)
  (setvar "REGENMODE" 1)
  (command "_.REGEN")
  (princ)
)

; VERSIÓN MEJORADA con opción "Todos" incluida
(defun c:CTAF2 ( / *error* oldcmdecho oldregen altura factor ss i ent data starttime endtime segundos opcion)
  (defun *error* (msg)
    (if oldcmdecho (setvar "CMDECHO" oldcmdecho))
    (if oldregen (setvar "REGENMODE" oldregen))
    (princ)
  )
  
  (setq oldcmdecho (getvar "CMDECHO"))
  (setq oldregen (getvar "REGENMODE"))
  (setvar "CMDECHO" 0)
  (setvar "REGENMODE" 0)
  
  ; Solicitar parámetros
  (initget 7)
  (setq altura (getdist "\nNueva altura de texto: "))
  
  (initget 7)
  (setq factor (getreal "\nNuevo factor de anchura: "))
  
  ; Preguntar método de selección
  (initget "Todos Ventana")
  (setq opcion (getkword "\nSeleccionar por [Todos/Ventana] <Ventana>: "))
  (if (not opcion) (setq opcion "Ventana"))
  
  (setq starttime (getvar "MILLISECS"))
  
  ; Selección según opción
  (cond
    ((= opcion "Todos")
     (princ "\nBuscando TODOS los textos del dibujo...")
     (setq ss (ssget "_X" '((0 . "TEXT,MTEXT"))))
    )
    ((= opcion "Ventana")
     (princ "\nSeleccione textos por ventana/cruce: ")
     (setq ss (ssget '((0 . "TEXT,MTEXT"))))
    )
  )
  
  (if ss
    (progn
      (princ (strcat "\nEncontrados " (itoa (sslength ss)) " textos. Procesando..."))
      
      (repeat (setq i (sslength ss))
        (setq ent (ssname ss (setq i (1- i))))
        (setq data (entget ent))
        
        (setq data (subst (cons 40 altura) (assoc 40 data) data))
        
        (if (= (cdr (assoc 0 data)) "TEXT")
          (setq data (subst (cons 41 factor) (assoc 41 data) data))
          (setq data (subst (cons 41 (* altura factor)) (assoc 41 data) data))
        )
        
        (entmod data)
        
        (if (= (rem (1+ i) 1000) 0)
          (princ (strcat "\rProcesados " (itoa (- (sslength ss) i)) " textos..."))
        )
      )
      
      (setq endtime (getvar "MILLISECS"))
      (setq segundos (/ (- endtime starttime) 1000.0))
      
      (princ (strcat "\r? Modificados " (itoa (sslength ss)) " textos en " 
                     (rtos segundos 2 2) " segundos"))
      (princ (strcat "\n  Velocidad: " 
                     (rtos (/ (sslength ss) segundos) 2 0) " textos/segundo"))
    )
    (princ "\n? No se encontraron textos.")
  )
  
  (setvar "CMDECHO" oldcmdecho)
  (setvar "REGENMODE" oldregen)
  (command "_.REGEN")
  (princ)
)