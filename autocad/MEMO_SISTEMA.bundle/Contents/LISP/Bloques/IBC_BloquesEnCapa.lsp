;;; MEMO SISTEMA 2.0.0 - archivo generado por construir_bundle.py
;;; Origen: LISP_Bloques/Insertar Bloques en Capa ( IBC ).lsp

;;; ============================================================================
;;; RUTINA: IBC - Insertar Bloques con detección automática de escala
;;; ============================================================================
;;; DESCRIPCIÓN:
;;;   Inserta bloques en los puntos de capas específicas (AR-Punto, RAP-Punto,
;;;   DES-Punto, PV-Punto, TM-Punto, CF-Punto), asignándolos a su capa final.
;;;   Detecta automáticamente la escala del primer bloque existente en el dibujo
;;;   y ajusta temporalmente las unidades a milímetros para que la escala sea
;;;   consistente entre diferentes dibujos.
;;;
;;; COMANDO: IBC
;;;
;;; USO:
;;;   1. Cargar el archivo con APPLOAD
;;;   2. Escribir IBC en la línea de comandos
;;;   3. La rutina insertará todos los bloques automáticamente
;;; ============================================================================


;;; ============================================================================
;;; FUNCIÓN PRINCIPAL: c:IBC
;;; ============================================================================
(defun c:IBC ( / *error* old_cmd old_osmode old_insunits blk_list blk_name 
               layer_filter final_layer escala_x escala_y angulo ss pt_count i 
               pt_ent pt found current_layer ss_blk blk_ref blk_data hubo_cambio)
  
  ;; --------------------------------------------------------------------------
  ;; FUNCIÓN DE MANEJO DE ERRORES
  ;; --------------------------------------------------------------------------
  ;; Esta función se ejecuta automáticamente si ocurre un error durante la rutina.
  ;; Restaura todas las variables del sistema a sus valores originales y muestra
  ;; el mensaje de error (excepto si fue cancelado por el usuario con ESC).
  ;; --------------------------------------------------------------------------
  (defun *error* (msg)
    (if old_cmd (setvar "CMDECHO" old_cmd))         ; Restaurar eco de comandos
    (if old_osmode (setvar "OSMODE" old_osmode))    ; Restaurar referencias a objetos
    (if old_insunits (setvar "INSUNITS" old_insunits)) ; Restaurar unidades del dibujo
    (if (not (member msg '("Function cancelled" "quit / exit abort")))
      (princ (strcat "\nError: " msg))              ; Mostrar error (si no es cancelación)
    )
    (princ)
  )
  
  ;; --------------------------------------------------------------------------
  ;; GUARDAR VALORES ACTUALES DE VARIABLES DEL SISTEMA
  ;; --------------------------------------------------------------------------
  ;; Guardamos los valores para poder restaurarlos al final de la rutina
  ;; --------------------------------------------------------------------------
  (setq old_cmd (getvar "CMDECHO")       ; Eco de comandos
        old_osmode (getvar "OSMODE")     ; Referencias a objetos (OSNAP)
        old_insunits (getvar "INSUNITS")) ; Unidades de inserción del dibujo
  
  ;; --------------------------------------------------------------------------
  ;; CONFIGURAR VARIABLES PARA EJECUCIÓN SILENCIOSA
  ;; --------------------------------------------------------------------------
  ;; Desactivamos el eco de comandos y las referencias a objetos para que
  ;; la rutina se ejecute sin mostrar todo el proceso en pantalla
  ;; --------------------------------------------------------------------------
  (setvar "CMDECHO" 0)
  (setvar "OSMODE" 0)
  
  ;; --------------------------------------------------------------------------
  ;; MENSAJE INICIAL
  ;; --------------------------------------------------------------------------
  (princ "\n=== IBC: Insertando bloques con detección de escala ===")
  (princ (strcat "\nUnidades actuales: " (itoa old_insunits)))
  
  ;; --------------------------------------------------------------------------
  ;; CAMBIO TEMPORAL DE UNIDADES A MILÍMETROS
  ;; --------------------------------------------------------------------------
  ;; Las unidades INSUNITS tienen estos códigos:
  ;;   0 = Sin unidades    1 = Pulgadas        2 = Pies
  ;;   3 = Millas          4 = Milímetros      5 = Centímetros    6 = Metros
  ;;
  ;; Si el dibujo NO está en milímetros (4), lo cambiamos temporalmente para
  ;; que AutoCAD no haga conversión de unidades al insertar los bloques.
  ;; Al final de la rutina se restaura el valor original.
  ;; --------------------------------------------------------------------------
  (setq hubo_cambio nil)                  ; Bandera para saber si cambiamos unidades
  (if (/= old_insunits 4)                 ; Si NO está en milímetros...
    (progn
      (setvar "INSUNITS" 4)               ; Cambiar a milímetros
      (setq hubo_cambio T)                ; Marcar que hubo cambio
      (princ "\n? Cambiando temporalmente a MILÍMETROS (4)")
    )
    (princ "\n? Ya está en MILÍMETROS")   ; Si ya está en mm, no hacer nada
  )
  
  ;; --------------------------------------------------------------------------
  ;; LISTA DE BLOQUES A INSERTAR
  ;; --------------------------------------------------------------------------
  ;; Formato: (NombreBloque "PrefijoCapaPuntos" "CapaFinal")
  ;;
  ;;   - NombreBloque:      Nombre EXACTO del bloque definido en el dibujo
  ;;   - PrefijoCapaPuntos: Prefijo de la capa donde están los PUNTOS
  ;;                        (se le agrega "*" como comodín)
  ;;   - CapaFinal:         Capa donde se insertarán los bloques finales
  ;; --------------------------------------------------------------------------
  (setq blk_list '(
    ("Arbol"         "AR"  "V-ARBOL")              ; Árboles
    ("RAP"           "RAP" "AP-Registro de AP")    ; Registros de Agua Potable
    ("Descarga"      "DES" "DS-Reg Alb Existente") ; Descargas / Reg. Albañal
    ("PV Existente"  "PV"  "DS-PV Existente")      ; Pozos de Visita
    ("Poste de TM"   "TM"  "T-Poste TM")           ; Postes de Teléfonos
    ("Poste de CFE"  "CF"  "L-Poste CFE")          ; Postes de CFE
  ))
  
  (setq found nil)   ; Bandera: se pondrá en T si insertamos al menos un bloque
  
  ;; --------------------------------------------------------------------------
  ;; BUCLE PRINCIPAL: PROCESAR CADA BLOQUE DE LA LISTA
  ;; --------------------------------------------------------------------------
  (foreach blk_pair blk_list
    
    ;; Extraer datos del par actual
    (setq blk_name (car blk_pair))                              ; Nombre del bloque
    (setq layer_filter (strcat (cadr blk_pair) "*"))            ; Filtro capa (ej: "AR*")
    (setq final_layer (caddr blk_pair))                         ; Capa final destino
    
    (princ (strcat "\n\n--- " blk_name " ---"))
    
    ;; ------------------------------------------------------------------------
    ;; VERIFICAR SI EL BLOQUE EXISTE EN EL DIBUJO
    ;; ------------------------------------------------------------------------
    (if (tblsearch "BLOCK" blk_name)
      (progn
        
        ;; --------------------------------------------------------------------
        ;; DETECCIÓN AUTOMÁTICA DE ESCALA
        ;; --------------------------------------------------------------------
        ;; Buscamos todas las inserciones existentes del bloque en el dibujo
        ;; y tomamos la escala de la primera que encontremos.
        ;; Esto garantiza que los nuevos bloques tengan la misma escala que
        ;; los ya existentes en el dibujo.
        ;; --------------------------------------------------------------------
        (setq ss_blk (ssget "_X" (list (cons 0 "INSERT") (cons 2 blk_name))))
        
        (if ss_blk
          (progn
            ;; Tomar la primera inserción encontrada
            (setq blk_ref (ssname ss_blk 0))
            (setq blk_data (entget blk_ref))
            
            ;; Leer escala X (código 41), escala Y (código 42) y ángulo (código 50)
            (setq escala_x (cdr (assoc 41 blk_data)))
            (setq escala_y (cdr (assoc 42 blk_data)))
            (setq angulo (cdr (assoc 50 blk_data)))
            
            ;; Valores por defecto si no se detectaron
            (if (null escala_x) (setq escala_x 1.0))
            (if (null escala_y) (setq escala_y escala_x))
            (if (null angulo) (setq angulo 0.0))
            
            (princ (strcat "\n  ? Escala detectada: " (rtos escala_x 2 6)))
          )
          (progn
            ;; No hay inserciones previas: usar escala 1.0 por defecto
            (setq escala_x 1.0) (setq escala_y 1.0) (setq angulo 0.0)
            (princ "\n  ? Sin inserciones previas, usando escala 1.0")
          )
        )
        
        ;; --------------------------------------------------------------------
        ;; CREAR CAPA FINAL SI NO EXISTE
        ;; --------------------------------------------------------------------
        (if (not (tblsearch "LAYER" final_layer))
          (command "_-LAYER" "_M" final_layer "")
        )
        
        ;; --------------------------------------------------------------------
        ;; BUSCAR PUNTOS EN LA CAPA CORRESPONDIENTE
        ;; --------------------------------------------------------------------
        ;; Busca todos los objetos POINT en capas que coincidan con el filtro
        ;; Ejemplo: para "AR" busca en "AR*" ? "AR-Punto", "AR-001", etc.
        ;; "_X" significa buscar en todo el dibujo (no solo lo visible)
        ;; --------------------------------------------------------------------
        (setq ss (ssget "_X" (list (cons 0 "POINT") (cons 8 layer_filter))))
        
        (if ss
          (progn
            (setq pt_count 0)   ; Contador de bloques insertados
            (setq i 0)          ; Índice del bucle
            (setq found T)      ; Marcar que encontramos puntos
            
            ;; ----------------------------------------------------------------
            ;; BUCLE: INSERTAR BLOQUE EN CADA PUNTO ENCONTRADO
            ;; ----------------------------------------------------------------
            (while (< i (sslength ss))
              ;; Obtener la entidad del punto actual
              (setq pt_ent (ssname ss i))
              
              ;; Extraer las coordenadas del punto (código 10)
              (setq pt (cdr (assoc 10 (entget pt_ent))))
              
              ;; Guardar la capa actual antes de cambiarla
              (setq current_layer (getvar "CLAYER"))
              
              ;; Cambiar a la capa final para que el bloque se inserte ahí
              (setvar "CLAYER" final_layer)
              
              ;; ----------------------------------------------------------
              ;; COMANDO INSERT
              ;; ----------------------------------------------------------
              ;; Sintaxis: -INSERT nombre punto escala_x escala_y rotación
              ;; El guion bajo "_" fuerza el uso de la versión en inglés
              ;; del comando, para que funcione en cualquier idioma de AutoCAD
              ;; ----------------------------------------------------------
              (command "_-INSERT" blk_name pt escala_x escala_y angulo)
              
              ;; Restaurar la capa original
              (setvar "CLAYER" current_layer)
              
              ;; Incrementar contadores
              (setq pt_count (1+ pt_count))
              (setq i (1+ i))
            )
            
            (princ (strcat "\n  » " (itoa pt_count) " bloques insertados (Escala: " 
                          (rtos escala_x 2 6) ")"))
          )
          (princ (strcat "\n  ? No hay puntos en capas '" layer_filter "'"))
        )
      )
      ;; El bloque no existe
      (princ (strcat "\n  ? Bloque '" blk_name "' NO EXISTE"))
    )
  )
  
  ;; --------------------------------------------------------------------------
  ;; RESTAURAR UNIDADES ORIGINALES
  ;; --------------------------------------------------------------------------
  ;; Si habíamos cambiado las unidades a milímetros, las restauramos ahora
  ;; --------------------------------------------------------------------------
  (if hubo_cambio
    (progn
      (setvar "INSUNITS" old_insunits)
      (princ (strcat "\n\n? Unidades restauradas a " (itoa old_insunits)))
    )
  )
  
  ;; --------------------------------------------------------------------------
  ;; RESTAURAR VARIABLES DEL SISTEMA
  ;; --------------------------------------------------------------------------
  (setvar "CMDECHO" old_cmd)
  (setvar "OSMODE" old_osmode)
  
  ;; --------------------------------------------------------------------------
  ;; MENSAJE FINAL
  ;; --------------------------------------------------------------------------
  (if found
    (princ "\n[OK] ¡Proceso completado!")
    (princ "\n[!] No se insertó nada.")
  )
  (princ)   ; Salir silenciosamente
)


;;; ============================================================================
;;; MENSAJE DE CARGA
;;; ============================================================================
;;; Este mensaje se muestra al cargar el archivo con APPLOAD
;;; ============================================================================
(princ "\n+-----------------------------------------------+")
(princ "\n¦  RUTINA IBC CARGADA CORRECTAMENTE             ¦")
(princ "\n¦                                               ¦")
(princ "\n¦  Comando disponible:                          ¦")
(princ "\n¦    IBC  - Inserta todos los bloques           ¦")
(princ "\n¦                                               ¦")
(princ "\n¦  Bloques que inserta:                         ¦")
(princ "\n¦    Arbol, RAP, Descarga, PV Existente,        ¦")
(princ "\n¦    Poste de TM, Poste de CFE                  ¦")
(princ "\n+-----------------------------------------------+")
(princ)