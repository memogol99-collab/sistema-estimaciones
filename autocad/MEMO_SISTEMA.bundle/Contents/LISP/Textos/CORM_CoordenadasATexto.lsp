;;; MEMO SISTEMA 2.1.1 - archivo generado por construir_bundle.py
;;; Origen: LISP_Textos/Coordenadas_a_texto ( CORM ).lsp
;;; Parches aplicados: corm-princ

;;
;; ACTUALIZAR COORDENADAS EN TEXTOS - VERSIÓN MEJORADA
;; Programa desarrollado por Mario Torres Pejerrey
;; http://www.construcgeek.com/
;; Mejoras implementadas: 2024
;;

(vl-load-com)

(defun c:COR (/ *error* old_cmdecho PuntoCoordenada decimales con_prefijo
                Este Norte Cota entSupE entSupN entSupZ)
  
  ;; Función de manejo de errores
  (defun *error* (msg)
    (if (not (wcmatch (strcase msg) "*CANCEL*,*EXIT*"))
      (princ (strcat "\n*** Error: " msg " ***"))
    )
    (if old_cmdecho (setvar "CMDECHO" old_cmdecho))
    (princ)
  )
  
  ;; Función para seleccionar texto con validación
  (defun seleccionar-texto (mensaje / ent)
    (while
      (progn
        (setq ent (car (entsel mensaje)))
        (cond
          ((null ent) nil) ; Usuario presiona Enter - salir
          ((not (wcmatch (cdr (assoc 0 (entget ent))) "TEXT,MTEXT"))
           (princ "\n*** Error: El objeto seleccionado no es texto. ***")
           t) ; Continuar bucle
          (t nil) ; Texto válido - salir del bucle
        )
      )
    )
    ent
  )
  
  ;; Función para formatear coordenada
  (defun formatear-coordenada (valor prefijo con_prefijo)
    (if con_prefijo
      (strcat prefijo "=" valor)
      valor
    )
  )
  
  ;; --- INICIO DEL PROGRAMA PRINCIPAL ---
  
  ; Guardar variables de AutoCAD
  (setq old_cmdecho (getvar "CMDECHO"))
  (setvar "CMDECHO" 0)
  
  (princ "\n*** ACTUALIZAR COORDENADAS EN TEXTOS ***")
  
  ; Configurar formato de coordenadas con valor por defecto
  (initget "2 3 4")
  (setq decimales (getint "\nNúmero de decimales [2/3/4] <3>: "))
  (if (not decimales) (setq decimales 3))
  
  ; Opción de prefijo con valor por defecto
  (initget "Sí No")
  (setq con_prefijo (getkword "\n¿Agregar prefijo (X=, Y=, Z=)? [Sí/No] <Sí>: "))
  (setq con_prefijo (if (or (null con_prefijo) (= con_prefijo "Sí")) T nil))
  
  ; Obtener punto de coordenadas
  (if (setq PuntoCoordenada (getpoint "\nIndique el punto donde obtener la coordenada: "))
    (progn
      ; Formatear coordenadas
      (setq Este (rtos (car PuntoCoordenada) 2 decimales))
      (setq Norte (rtos (cadr PuntoCoordenada) 2 decimales))
      (setq Cota (rtos (caddr PuntoCoordenada) 2 decimales))
      
      (princ (strcat "\n? Coordenadas obtenidas: X=" Este " Y=" Norte " Z=" Cota))
      
      ; Actualizar texto de Este (X)
      (princ "\n\n--- COORDENADA ESTE (X) ---")
      (if (setq entSupE (seleccionar-texto "\nSeleccione el texto para Este (X) <Enter para omitir>: "))
        (progn
          (vla-put-TextString (vlax-ename->vla-object entSupE)
            (formatear-coordenada Este "X" con_prefijo))
          (princ " ? Texto Este actualizado.")
        )
        (princ " ?  Este omitido.")
      )
      
      ; Actualizar texto de Norte (Y)
      (princ "\n\n--- COORDENADA NORTE (Y) ---")
      (if (setq entSupN (seleccionar-texto "\nSeleccione el texto para Norte (Y) <Enter para omitir>: "))
        (progn
          (vla-put-TextString (vlax-ename->vla-object entSupN)
            (formatear-coordenada Norte "Y" con_prefijo))
          (princ " ? Texto Norte actualizado.")
        )
        (princ " ?  Norte omitido.")
      )
      
      ; Actualizar texto de Cota (Z)
      (princ "\n\n--- COORDENADA COTA (Z) ---")
      (if (setq entSupZ (seleccionar-texto "\nSeleccione el texto para Cota (Z) <Enter para omitir>: "))
        (progn
          (vla-put-TextString (vlax-ename->vla-object entSupZ)
            (formatear-coordenada Cota "Z" con_prefijo))
          (princ " ? Texto Cota actualizado.")
        )
        (princ " ?  Cota omitida.")
      )
      
      ; Resumen final
      (princ "\n\n?? RESUMEN DE ACTUALIZACIONES:")
      (princ (strcat "\n   Este (X): " (formatear-coordenada Este "X" con_prefijo)))
      (princ (strcat "\n   Norte (Y): " (formatear-coordenada Norte "Y" con_prefijo)))
      (princ (strcat "\n   Cota (Z): " (formatear-coordenada Cota "Z" con_prefijo)))
      (princ "\n? Proceso completado exitosamente.")
    )
    (princ "\n? Operación cancelada: No se seleccionó punto.")
  )
  
  ; Restaurar variable
  (setvar "CMDECHO" old_cmdecho)
  (princ)
)

;; Versión rápida mejorada
(defun c:COR2 (/ *error* pt x y z txt)
  (vl-load-com)
  
  (defun *error* (msg)
    (if (not (wcmatch (strcase msg) "*CANCEL*,*EXIT*"))
      (princ (strcat "\n? Error: " msg))
    )
    (princ)
  )
  
  (defun seleccionar-texto-rapido (mensaje / ent)
    (while
      (progn
        (setq ent (car (entsel mensaje)))
        (cond
          ((null ent) nil)
          ((not (wcmatch (cdr (assoc 0 (entget ent))) "TEXT,MTEXT"))
           (princ "\n? Error: Seleccione un texto.")
           t)
          (t nil)
        )
      )
    )
    ent
  )
  
  (princ "\n? ACTUALIZAR COORDENADAS - VERSIÓN RÁPIDA")
  
  (if (setq pt (getpoint "\nSeleccione punto para obtener coordenadas: "))
    (progn
      (setq x (rtos (car pt) 2 3))
      (setq y (rtos (cadr pt) 2 3))
      (setq z (rtos (caddr pt) 2 3))
      
      (princ (strcat "\n?? Coordenadas: X=" x " Y=" y " Z=" z))
      
      ; Actualizar textos en secuencia rápida
      (if (setq txt (seleccionar-texto-rapido "\nSeleccione texto para X: "))
        (vla-put-TextString (vlax-ename->vla-object txt) (strcat "X=" x)))
      
      (if (setq txt (seleccionar-texto-rapido "\nSeleccione texto para Y: "))
        (vla-put-TextString (vlax-ename->vla-object txt) (strcat "Y=" y)))
      
      (if (setq txt (seleccionar-texto-rapido "\nSeleccione texto para Z: "))
        (vla-put-TextString (vlax-ename->vla-object txt) (strcat "Z=" z)))
      
      (princ "\n? Coordenadas actualizadas exitosamente.")
    )
    (princ "\n? Operación cancelada.")
  )
  (princ)
)

;; Nueva versión para múltiples puntos
(defun c:CORM (/ *error* old_cmdecho pts i pt x y z txtE txtN txtZ)
  (vl-load-com)
  
  (defun *error* (msg)
    (if old_cmdecho (setvar "CMDECHO" old_cmdecho))
    (princ)
  )
  
  (princ "\n?? ACTUALIZAR MÚLTIPLES COORDENADAS")
  (princ "\nSeleccione puntos y textos en secuencia...")
  
  (setq old_cmdecho (getvar "CMDECHO"))
  (setvar "CMDECHO" 0)
  
  (while (setq pt (getpoint "\nSeleccione punto de coordenadas <Enter para terminar>: "))
    (setq x (rtos (car pt) 2 3)
          y (rtos (cadr pt) 2 3)
          z (rtos (caddr pt) 2 3))
    
    (princ (strcat "\nCoordenadas: X=" x " Y=" y " Z=" z))
    
    (if (setq txtE (car (entsel "\nTexto para X: ")))
      (vla-put-TextString (vlax-ename->vla-object txtE) (strcat "X=" x)))
    
    (if (setq txtN (car (entsel "\nTexto para Y: ")))
      (vla-put-TextString (vlax-ename->vla-object txtN) (strcat "Y=" y)))
    
    (if (setq txtZ (car (entsel "\nTexto para Z: ")))
      (vla-put-TextString (vlax-ename->vla-object txtZ) (strcat "Z=" z)))
    
    (princ "\n? Coordenadas actualizadas. Seleccione siguiente punto...")
  )
  
  (setvar "CMDECHO" old_cmdecho)
  (princ "\n? Proceso de múltiples coordenadas finalizado.")
  (princ)
)

; Mensaje de carga mejorado
(princ (strcat "\n"
  "\n?? COMANDOS DE COORDENADAS CARGADOS:" 
  "\n------------------------------------"
  "\nCOR  - Versión completa con opciones"
  "\nCOR2 - Versión rápida predeterminada" 
  "\nCORM - Múltiples coordenadas en secuencia"
  "\n------------------------------------"
))
(princ)