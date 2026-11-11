;;; MEMO SISTEMA 2.0.0 - archivo generado por construir_bundle.py
;;; Origen: LISP_Secciones/Area_Secc 3P( AS ).lsp

; Parámetros del estilo de texto:
; "text-Secc" - Nombre del estilo
; "romans" - Fuente
; "0.15" - Altura fija
; "0.85" - Relación anchura/altura
; "0" - Ángulo de inclinación (0 = texto horizontal)
; "N" - No texto hacia atrás
; "N" - No texto volteado
; "N" - No texto vertical

(defun c:As (/ poli1 poli2 poli3 poli4 sublista1 lista1 altura1 sublista2 lista2 altura2 
              distancia origen inicio dif A1 A2)
  
  ; Crear capa "Area de Secciones" y establecerla como actual
  (if (not (tblsearch "layer" "Area de Secciones"))
    (command "_.layer" "_m" "Area de Secciones" "_c" "7" "" "")
    (command "_.layer" "_s" "Area de Secciones" "")
  )
  
  ; Crear estilo de texto text-Secc y ponerlo como actual
  (if (not (tblsearch "style" "text-Secc"))
    (command "_.style" "text-Secc" "romans" "0.15" "0.85" "0" "N" "N" "N")
  )
  ; Establecer text-Secc como estilo de texto actual
  (setvar "TEXTSTYLE" "text-Secc")
  
 (setq poli1 (entget(car(entsel "\nSelecciona la Seccion de Terreno")))) 
(setq poli2 (entget(car(entsel "\nSelecciona la Seccion de Corte")))) 
(setq poli3 poli1 poli4 poli2) 
(setq sublista1 nil lista1 nil altura1 nil sublista2 nil lista2 nil altura2 nil distancia nil origen nil inicio nil dif nil) 

(while 
(setq sublista2 (assoc 10 poli4)) 
(setq lista2 (cons(cdr sublista2) lista2)) 
(setq altura2 (cons (caddr sublista2) altura2)) 
(setq poli4(cdr (member sublista2 poli4))) 
) 
(if (= 2 (length altura2)) (setq altura2 (cons (car altura2) altura2))) 
(if (> (caar lista2) (caadr lista2)) (setq lista2 (reverse lista2))) 

(while 
(setq sublista1 (assoc 10 poli3)) 
(setq lista1 (cons(cdr sublista1) lista1)) 
(setq altura1 (cons (caddr sublista1) altura1)) 
(setq poli3(cdr (member sublista1 poli3))) 
) 


(if (> (caar lista1) (caadr lista1)) (progn (setq lista1 (reverse lista1)) (setq altura1 (reverse altura1)))) 
(if (> (caar lista2) (caadr lista2)) (progn (setq lista2 (reverse lista2)) (setq altura2 (reverse altura2)))) 
(setq distancia (list (- (caadr lista1) (caar lista1)) (- (caaddr lista1) (caadr lista1)))) 
(setq dif (mapcar '- altura1 altura2)) 


(setq origen (car lista2)) 
(setq inicio (polar origen (- (/ pi 6)) 1.2)) 
(command "_text" inicio "0" (strcat "A1=("(rtos (car dif)2 2)"+"(rtos (cadr dif)2 2)")/2x"(rtos (car distancia) 2 2))) 
(command "_text" (polar inicio (- (/ pi 2)) 0.22) "0" (strcat "A1="(rtos(/ (+ (car dif) (cadr dif)) 2) 2 2)"x"(rtos (car distancia) 2 2))) 
(command "_text" (polar inicio (- (/ pi 2)) 0.44) "0" (strcat "A1="(rtos (setq A1(* (car distancia) (/ (+ (car dif) (cadr dif)) 2))) 2 2))) 

(setq inicio (polar inicio 0 3.5)) 
(command "_text" inicio "0" (strcat "A2=("(rtos (cadr dif)2 2)"+"(rtos (caddr dif)2 2)")/2x"(rtos (cadr distancia) 2 2))) 
(command "_text" (polar inicio (- (/ pi 2)) 0.22) "0" (strcat "A2="(rtos(/ (+ (cadr dif) (caddr dif)) 2) 2 2)"x"(rtos (cadr distancia) 2 2))) 
(command "_text" (polar inicio (- (/ pi 2)) 0.44) "0" (strcat "A2="(rtos (setq A2(* (cadr distancia) (/ (+ (cadr dif) (caddr dif)) 2))) 2 2))) 

(setq inicio (polar (setq inicio (polar inicio (- pi) 1.5)) (- (/ pi 2)) 0.5)) 
(command "_text" inicio "0" "At=A1+A2") 
(command "_text" (polar inicio (- (/ pi 2)) 0.22) "0" (strcat "At="(rtos (+ A1 A2) 2 2)" m2")) 

) 
