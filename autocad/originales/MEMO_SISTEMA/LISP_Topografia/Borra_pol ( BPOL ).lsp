;|Este es un lisp en formato original, se puede ver el código fuente, la intención, es de que el código fuente
; pueda ser modificado y adaptado a la necesidad de cada usuario, lo único que siempre se solicita en estos
; casos es de que siempre se haga referencia al autor del mismo (es decir que no se modifique la autoría del lisp),
; salvo que este se modifique ampliamente, si se construye un nuevo programa tomando como partes un lisp publicado,
; se debería de hacer el comentario de que parte del nuevo programa esta basado en el autor original.|;

; -- Orden PolErase MEJORADA
 ; Borra objetos por ventana/captura interior/exterior,
 ;   o borra y recorta interior/exterior, a partir de una polílinea existente.
 ;   ©2004/09/10 scaner, Spain
 ;   Mejoras implementadas: 2024

 ; Notas:
 ;   Las 2D/3D polilíleas, polilíneas optimizadas, círculos y elipses que sirvan de borde
 ;     de designación, se consideran cerradas y proyectadas sobre el plano z=0
 ;   Para recortar se utiliza la función etrim de la orden extrim, de las Express Tools.
 
 ; Descargado desde:
 ; http://www.construcgeek.com
 ; Fuente | www.hispacad.com
 ; 2009 - Con mejoras 2024

(defun c:BPol (/ pol typ vrt lyr pto ssx ssv ssc n ent ky1 ky2 old_error old_cmdecho old_highlight old_ucsfollow)
  
  ; Función auxiliar para obtener código DXF
  (defun dxf (ass ent) (cdr (assoc ass (entget ent))))
  
  ; Guardar estado original
  (setq old_error *error*)
  (setq old_cmdecho   (getvar "cmdecho")
        old_highlight (getvar "highlight")
        old_ucsfollow (getvar "ucsfollow")
  )
  
  ; Configurar entorno
  (setvar "cmdecho" 0)
  (setvar "ucsfollow" 0)
  (command "_undo" "_begin")
  (command "_ucs" "_world")
  
  ; Selección y validación de objeto borde
  (princ "\n*** BPOL - Borrado/Recorte por Polilínea ***")
  (while (not (and (setq pol (car (entsel "\nSeleccione el objeto de borde (Polilínea/Círculo/Elipse): ")))
                   (member (dxf 0 pol) '("LWPOLYLINE" "POLYLINE" "CIRCLE" "ELLIPSE"))
              )
         )
    (princ "\n? Error: Debe seleccionar una Polilínea, Círculo o Elipse.")
  )
  
  ; Validar que el objeto esté cerrado
  (cond
    ((member (dxf 0 pol) '("LWPOLYLINE" "POLYLINE"))
     (if (not (or (= (dxf 70 pol) 1)    ; LWPOLYLINE cerrada
                  (= (dxf 70 pol) 129))) ; POLYLINE 3D cerrada
       (progn
         (princ "\n? Error: La polilínea debe estar cerrada.")
         (exit)
       )
     )
    )
    ((= (dxf 0 pol) "CIRCLE") T) ; Los círculos siempre están cerrados
    ((= (dxf 0 pol) "ELLIPSE")
     (if (not (dxf 41 pol)) ; El parámetro 41 indica si la elipse está cerrada
       (progn
         (princ "\n? Error: La elipse debe estar cerrada.")
         (exit)
       )
     )
    )
  )
  
  ; Extraer vértices según el tipo de objeto
  (cond
    ((= (dxf 0 pol) "LWPOLYLINE") (setq vrt (LstVrt2LWPol pol)))
    ((= (dxf 0 pol) "POLYLINE") (setq vrt (LstVrt2Pol pol)))
    ((= (dxf 0 pol) "CIRCLE") (setq vrt (LstVrt2Circle pol)))
    ((= (dxf 0 pol) "ELLIPSE") (setq vrt (LstVrt2Ellipse pol)))
  )
  
  ; Obtener capas utilizadas
  (setq lyr (append '((-4 . "<or"))
                    (mapcar (function (lambda (n) (cons 8 n))) (LstLyrUtlAct))
                    '((-4 . "or>"))
            )
  )
  
  ; Selección de método
  (initget "Ventana Captura Recortar")
  (if (not (setq ky1 (getkword "\nSeleccione método [Ventana/Captura/Recortar] <Recortar>: ")))
    (setq ky1 "Recortar")
  )
  
  ; Abreviar para lógica interna
  (setq ky1 (cond 
              ((= ky1 "Ventana") "V")
              ((= ky1 "Captura") "C") 
              ((= ky1 "Recortar") "R")
              (t "R")
            )
  )
  
  ; Punto para definir el lado
  (initget 1)
  (command "_point"
           (setq pto (getpoint "\nIndique punto en el lado a borrar/recortar: "))
  )
  
  ; Seleccionar objetos
  (setq ssx (ssdel pol (ssget "_x" lyr))
        ssv (ssget "_wp" vrt)
        ssc (ssdel pol (ssget "_cp" vrt))
        n   -1
        ky2 nil
  )
  
  ; Detectar si el punto está en el interior
  (while (setq ent (ssname ssc (setq n (1+ n))))
    (if (= (dxf 5 (entlast)) (dxf 5 ent))
      (setq ky2 T) ; interior
    )
  )
  
  ; Ejecutar según método seleccionado
  (princ "\n?? Procesando objetos...")
  (cond 
    ((and (or (= ky1 "V") (= ky1 "R")) ky2) 
     (command "_erase" ssv "")
     (princ (strcat "\n? Borrados " (itoa (sslength ssv)) " objetos del interior."))
    )
    ((or (= ky1 "V") (= ky1 "R")) 
     (command "_erase" ssx "_remove" ssc "")
     (princ (strcat "\n? Borrados objetos del exterior."))
    )
    ((and (= ky1 "C") ky2) 
     (command "_erase" ssc "")
     (princ (strcat "\n? Borrados " (itoa (sslength ssc)) " objetos del interior (captura)."))
    )
    ((= ky1 "C")
     (command "_erase" ssx)
     (if ssv
       (command "_remove" ssv "")
       (command "")
     )
     (princ "\n? Borrados objetos del exterior (captura).")
    )
  )
  
  ; Recortar si se seleccionó esa opción
  (cond 
    ((= ky1 "R") 
     (if (not (load "extrim"))
       (princ "\n??  Advertencia: Express Tools no disponibles para recorte.")
       (progn
         (etrim pol pto)
         (princ "\n? Recorte completado con Express Tools.")
       )
     )
    )
  )
  
  ; Restaurar entorno
  (command "_ucs" "_prev")
  (command "_undo" "_end")
  (setvar "ucsfollow" old_ucsfollow)
  (setvar "highlight" old_highlight)
  (setvar "cmdecho" old_cmdecho)
  (setq *error* old_error)
  
  (princ "\n? Operación BPOL completada exitosamente.")
  (princ)
)

; -- Función *error* MEJORADA
(defun *error* (msg)
  (if (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*EXIT*"))
    (princ (strcat "\n? Error: " msg))
    (princ "\n??  Operación cancelada por el usuario.")
  )
  (command "_ucs" "_prev")
  (command "_undo" "_end")
  (setvar "ucsfollow" old_ucsfollow)
  (setvar "highlight" old_highlight)
  (setvar "cmdecho" old_cmdecho)
  (setq *error* old_error)
  (princ)
)

; -- Función LstVrt2LWPol (ORIGINAL)
(defun LstVrt2LWPol (pol / ass lst)
  (foreach ass (entget pol)
    (if (= (car ass) 10)
      (setq lst (cons (cdr ass) lst))
    )
  )
  (reverse lst)
)

; -- Función LstVrt2Pol (ORIGINAL)
(defun LstVrt2Pol (pol / nxt lst)
  (setq nxt (entnext pol))
  (while (/= (cdr (assoc 0 (entget nxt))) "SEQEND")
    (setq lst (cons (reverse (cdr (reverse (cdr (assoc 10 (entget nxt)))))) lst)
          nxt (entnext nxt)
    )
  )
  (reverse lst)
)

; -- NUEVA Función LstVrt2Circle
(defun LstVrt2Circle (cir / cen rad ang pts)
  (setq cen (dxf 10 cir)
        rad (dxf 40 cir)
        ang 0.0
        pts '()
  )
  (repeat 36 ; Crear 36 puntos para aproximar el círculo
    (setq pts (cons (list (+ (car cen) (* rad (cos ang))) 
                         (+ (cadr cen) (* rad (sin ang)))) 
                    pts))
    (setq ang (+ ang (/ (* 2 pi) 36)))
  )
  (reverse pts)
)

; -- NUEVA Función LstVrt2Ellipse
(defun LstVrt2Ellipse (ell / cen maj min ratio ang pts)
  (setq cen (dxf 10 ell)
        maj (dxf 11 ell)
        min (dxf 12 ell)
        ratio (dxf 40 ell)
        ang 0.0
        pts '()
  )
  (repeat 36 ; Crear 36 puntos para aproximar la elipse
    (setq pts (cons (list (+ (car cen) 
                            (* (car maj) (cos ang)) 
                            (* (car min) (sin ang))) 
                         (+ (cadr cen) 
                            (* (cadr maj) (cos ang)) 
                            (* (cadr min) (sin ang)))) 
                    pts))
    (setq ang (+ ang (/ (* 2 pi) 36)))
  )
  (reverse pts)
)

; -- Función LstLyrUtlAct (ORIGINAL)
(defun LstLyrUtlAct (/ lyr lst)
  (setq lyr (tblnext "layer" T))
  (while lyr
    (if (and (= (logand (cdr (assoc 70 lyr)) 1) 0) (> (cdr (assoc 62 lyr)) 0))
      (setq lst (cons (cdr (assoc 2 lyr)) lst))
    )
    (setq lyr (tblnext "layer"))
  )
  (acad_strlsort lst)
)

; Mensaje de carga
(prompt "\n*** Comando BPOL cargado - Versión Mejorada 2024 ***")
(prompt "\nComando: BPOL - Borrado/Recorte por objeto cerrado")
(princ)