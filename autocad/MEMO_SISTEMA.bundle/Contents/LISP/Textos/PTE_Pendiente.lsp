;;; MEMO SISTEMA 2.1.0 - archivo generado por construir_bundle.py
;;; Origen: LISP_Textos/Pendiente ( PTE ).lsp

; PENDIENTE.LSP 1.6
;
; Julio Pablo. Enero, 2000
;
; Rotula la pendiente entre dos puntos, insertando el texto automaticamente
; en el punto medio, tomando como "horizonte" el eje X, es decir, la anotacion
; es inteligente. Nunca aparecera rotulada una pendiente de mas de 90 grados.
;
; Mas ordenes como esta en
;       http://web.jet.es/juliopablo
;
;       Version 1.1 (febrero, 2000): Desfasa el rotulo un pelin para que no
;                                    coincida con la linea de pendiente.
;       Version 1.2: Altura del texto automatica segun distancia entre puntos.
;       Version 1.3: Tres mejoras:
;         1) La referencia a objetos PUNTO FINAL se activa automaticamente al
;            ejecutar la orden y se restaura la configuracion previa al salir
;            (tambien si se cancela con Esc).
;         2) Menu de formato de la pendiente: [Porcentaje/Grados/Millar/Ambos].
;            Se recuerda el ultimo formato usado en la sesion (Enter = repetir).
;         3) Seleccion con UN SOLO CLIC: basta hacer clic sobre una LINEA o
;            POLILINEA y la orden toma los dos extremos del tramo clicado;
;            la etiqueta sigue saliendo en el CENTRO del tramo. Si se pulsa
;            Enter (o no se acierta a clicar una entidad valida), la orden
;            pide dos puntos como en la version anterior, ahora con la
;            referencia Punto Final activada durante los clics.
;       Version 1.4: El formato Millar sale asi: 'PTE.: 1.50/mill', con dos
;                    decimales, y es el formato inicial por defecto.
;       Version 1.5: El valor al millar sale con UN decimal: 'PTE.: 1.5/mill'.
;       Version 1.6: El rotulo ya no queda encima de la linea: el desplazamiento
;                    perpendicular se calcula con el SENTIDO DE LECTURA del
;                    texto (antes, en lineas dibujadas de derecha a izquierda,
;                    el rotulo cruzaba la linea) y la separacion aumenta al
;                    doble (media altura de texto).
;
; USO: cargar con APPLOAD (o arrastrando el archivo al dibujo) y escribir PTE.
;      Ejemplo de etiqueta en formato Millar:  PTE.: 1.5/mill

(vl-load-com)

; ******** funciones auxiliares **********
; funcion para redondear a cierto valor
(defun redondear (cualo cuanto)
 (if (> (- cualo (* cuanto (fix (/ cualo cuanto)))) (/ cuanto 2))
  (+ cualo (- cuanto (- cualo (* cuanto (fix (/ cualo cuanto))))))
  (- cualo (- cualo (* cuanto (fix (/ cualo cuanto)))))
 )
)

; Convertir valor en radianes a grados
(defun RTD (r)
  (* 180.0 (/ r pi))
)

; Funcion para calcular distancia 2D entre dos puntos
(defun distancia (p1 p2)
  (sqrt (+ (expt (- (car p2) (car p1)) 2)
           (expt (- (cadr p2) (cadr p1)) 2)))
)

; Proyectar un punto a 2D (solo X e Y)
(defun pto2d (p)
  (list (car p) (cadr p))
)

; Devuelve (p1 p2) en WCS con los extremos del tramo clicado.
; ENT: nombre de entidad; TIPO: valor DXF 0; PCLIC: punto de clic en WCS.
; Para LINE devuelve sus dos extremos; para LWPOLYLINE/POLYLINE localiza el
; tramo entre dos vertices consecutivos mas cercano al punto de clic.
; Los tramos con curva se tratan como cuerda recta entre vertices.
; Devuelve nil si no se puede determinar.
(defun par-segmento (ent tipo pclic / res tmp param endp i p1 p2)
 (setq res nil)
 (cond
  ((= tipo "LINE")
   (setq p1 (vl-catch-all-apply 'vlax-curve-getStartPoint (list ent)))
   (setq p2 (vl-catch-all-apply 'vlax-curve-getEndPoint (list ent)))
   (if (and (not (vl-catch-all-error-p p1))
            (not (vl-catch-all-error-p p2))
       )
    (setq res (list p1 p2))
   )
  )
  ((member tipo '("LWPOLYLINE" "POLYLINE"))
   (setq tmp (vl-catch-all-apply 'vlax-curve-getClosestPointTo (list ent pclic)))
   (if (not (vl-catch-all-error-p tmp))
    (progn
     (setq param (vl-catch-all-apply 'vlax-curve-getParamAtPoint (list ent tmp)))
     (setq endp (vl-catch-all-apply 'vlax-curve-getEndParam (list ent)))
     (if (and (not (vl-catch-all-error-p param))
              (not (vl-catch-all-error-p endp))
              (>= (fix (+ endp 0.000001)) 1)
         )
      (progn
       (setq i (fix param))
       ; si el clic cayo justo en el ultimo vertice, retrocede un tramo
       (if (>= i endp) (setq i (1- (fix (+ endp 0.000001)))))
       (if (>= i 0)
        (progn
         (setq p1 (vl-catch-all-apply 'vlax-curve-getPointAtParam (list ent i)))
         (setq p2 (vl-catch-all-apply 'vlax-curve-getPointAtParam (list ent (1+ i))))
         (if (and (not (vl-catch-all-error-p p1))
                  (not (vl-catch-all-error-p p2))
                  p1 p2
             )
          (setq res (list p1 p2))
         )
        )
       )
      )
     )
    )
   )
  )
 )
 res
)

; ********* funcion-meollo ***********
; Cargando la orden y dando la bienvenida
(princ "\nPENDIENTE.LSP 1.6. (Julio Pablo, enero/2000 - Modificado). Orden PTE cargada: un clic sobre una linea y formatos porcentaje, grados o millar.\n")

(defun c:pte (/ *error* redondeo prefijo desfase osnap_viejo textsize_viejo cmd_viejo
                formato sel ent tipo pclic par_ptos pto1 pto2 altura1 altura2
                x_pto1 x_pto2 angulo angulo_txt anchura_pto h_pto porcentaje millar
                valor_ang valor_pct valor_mil texto_pte texto_consola
                med_dist_x med_dist_y punto_texto punto_texto_desfasado dist_pts
                altura_texto)

 ; gestor de errores: restaura referencias y variables aunque se cancele
 (defun *error* (msg)
  (if osnap_viejo (setvar "osmode" osnap_viejo))
  (if textsize_viejo (setvar "TEXTSIZE" textsize_viejo))
  (if cmd_viejo (setvar "cmdecho" cmd_viejo))
  (if (and msg (/= msg "Function cancelled") (/= msg "quit / exit abort"))
   (princ (strcat "\nError: " msg))
  )
  (princ)
 )

 (princ "\nRotula la pendiente con UN CLIC sobre una linea o polilinea (o entre dos puntos), con respecto al eje X")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Estableciendo el valor del redondeo y el prefijo. Introduce
;         aqui----! el que mas te interese
 (setq redondeo 0.10)
 (setq prefijo "PTE.: ")
; el desfase es la separacion entre el rotulo y la linea de pendiente; la
; separacion real es la altura del texto dividida entre este valor, asi que
; a menor desfase, mas separacion (2 = media altura de texto)
 (setq desfase 2)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; --- 1) formato del rotulo: se recuerda el ultimo usado en la sesion ---
 (if (null *pte:formato*) (setq *pte:formato* "Millar"))
 (initget "Porcentaje Grados Millar Ambos")
 (setq formato
  (getkword
   (strcat "\nFormato de la pendiente [Porcentaje/Grados/Millar/Ambos] <"
           *pte:formato* ">: "
   )
  )
 )
 (if formato (setq *pte:formato* formato))
 (setq formato *pte:formato*)

; --- 2) activando la referencia a objetos PUNTO FINAL durante la orden ---
 (setq osnap_viejo (getvar "osmode"))
 (setvar "osmode" (logior osnap_viejo 1))

; --- 3) UN CLIC: senalar la linea o polilinea a rotular ---
 (setq sel (entsel "\nHaga clic sobre la linea o polilinea a rotular (Enter = indicar dos puntos): "))
 (cond
  ; caso A: entidad valida clicada -> se toman los extremos de ese tramo
  ((and sel
        (setq ent (car sel))
        (setq tipo (cdr (assoc 0 (entget ent))))
        (member tipo '("LINE" "LWPOLYLINE" "POLYLINE"))
        (setq pclic (trans (cadr sel) 1 0))
        (setq par_ptos (par-segmento ent tipo pclic))
   )
   (setq pto1 (trans (car par_ptos) 0 1))
   (setq pto2 (trans (cadr par_ptos) 0 1))
  )
  ; caso B: modo clasico de dos puntos, con Punto Final activo
  (T
   (if sel
    (princ "\nEsa entidad no sirve para medir pendiente (use LINEA o POLILINEA). Indique dos puntos:")
    (princ "\nModo dos puntos, con la referencia Punto Final activada:")
   )
   (setq pto1 (getpoint "\nIntroduce el primer punto: "))
   (setq pto2 (getpoint "\nIntroduce el segundo punto: "))
  )
 )

 (if (and pto1 pto2)
  (progn

   ; trabajando en 2D (alzado respecto al eje X)
   (setq pto1 (pto2d pto1))
   (setq pto2 (pto2d pto2))

   ; Calcular distancia entre puntos para determinar altura del texto
   (setq dist_pts (distancia pto1 pto2))

   (if (<= dist_pts 0.0000001)
    (princ "\nPuntos coincidentes: nada que rotular.")
    (progn

     ; Calcular altura del texto en funcion de la distancia
     ; Para 10 metros = 0.20 de altura (proporcion 1:50)
     (setq altura_texto (/ dist_pts 50.0))

     ; Establecer limites minimos y maximos para la altura del texto
     (if (< altura_texto 0.10)
       (setq altura_texto 0.10)
     )
     (if (> altura_texto 2.0)
       (setq altura_texto 2.0)
     )

     (princ (strcat "\nDistancia entre puntos: " (rtos dist_pts 2 2)
                    " - Altura texto: " (rtos altura_texto 2 2)))

     ; Obtiene las coordenadas Y de cada punto
     (setq altura1 (cadr pto1))
     (setq altura2 (cadr pto2))

     ; Obtiene las coordenadas X
     (setq x_pto1 (car pto1))
     (setq x_pto2 (car pto2))

     ; Obtiene el angulo y lo amolda a nuestros intereses
     (setq angulo (RTD (angle pto1 pto2)))
     (setq angulo_txt angulo)
     (if (> x_pto1 x_pto2)
      (setq angulo_txt (+ 180 angulo_txt))
     )
     (if (and (>= 180 angulo) (>= angulo 90)) (setq angulo (- 180 angulo)))
     (if (and (>= 270 angulo) (>= angulo 180)) (setq angulo (- angulo 180)))
     (if (and (>= 360 angulo) (>= angulo 170)) (setq angulo (- 360 angulo)))

     (setq anchura_pto (abs (- x_pto1 x_pto2)))
     (setq h_pto (abs (- altura1 altura2)))

     (if (= anchura_pto 0)
      (setq porcentaje 0)
      (setq porcentaje (/ (* 100 h_pto) anchura_pto))
     )
     ; el valor al millar (por mil) es diez veces el porcentaje
     (setq millar (* 10.0 porcentaje))

     ; Componiendo el texto de salida segun el formato elegido
     (setq valor_ang (rtos (redondear angulo redondeo) 2 1))
     (setq valor_pct (rtos (redondear porcentaje redondeo) 2 1))
     ; valor al millar con un decimal, p. ej. 1.5
     (setq valor_mil (rtos (redondear millar redondeo) 2 1))
     (cond
      ((= formato "Porcentaje")
       (setq texto_pte (strcat prefijo valor_pct "%"))
       (setq texto_consola texto_pte)
      )
      ((= formato "Grados")
       (setq texto_pte (strcat prefijo valor_ang "%%d"))
       (setq texto_consola (strcat prefijo valor_ang (chr 176)))
      )
      ((= formato "Millar")
       (setq texto_pte (strcat prefijo valor_mil "/mill"))
       (setq texto_consola texto_pte)
      )
      (T
       (setq texto_pte (strcat prefijo valor_ang "%%d = " valor_pct "%"))
       (setq texto_consola (strcat prefijo valor_ang (chr 176) " = " valor_pct "%"))
      )
     )

     ; calculando el punto medio e insertando el texto
     (setq med_dist_x (+ x_pto1 (/ (- x_pto2 x_pto1) 2)))
     (setq med_dist_y (+ altura1 (/ (- altura2 altura1) 2)))
     (setq punto_texto (list med_dist_x med_dist_y))
        ;separando el rotulo de la linea de pendiente: se desplaza perpendicular
        ;al SENTIDO DE LECTURA del texto (angulo_txt), de modo que el rotulo
        ;siempre queda a un costado de la linea y nunca encima de ella
     (setq punto_texto_desfasado
      (polar punto_texto
             (+ (* angulo_txt (/ pi 180.0)) (/ pi 2.0))
             (/ altura_texto desfase)
      )
     )

     ; desactivando referencias y dibujando el texto centrado con altura automatica
     (setq textsize_viejo (getvar "TEXTSIZE"))
     (setq cmd_viejo (getvar "cmdecho"))
     (setvar "cmdecho" 0)
     (setvar "osmode" 0)
     (setvar "TEXTSIZE" altura_texto)

     (command "_text" "c" punto_texto_desfasado "" angulo_txt texto_pte)

     (setvar "TEXTSIZE" textsize_viejo)
     (setvar "osmode" osnap_viejo)
     (setvar "cmdecho" cmd_viejo)

     ; Mostrando resultados
     (princ "\n")
     (princ texto_consola)
    )
   )
  )
  (princ "\nOrden cancelada.")
 )

; restaurando las referencias a objetos del usuario
 (setvar "osmode" osnap_viejo)

 ; El autor! El autor!
 (princ "\nOrden perpetrada por Julio Pablo. Enero, 2000. Gracias por utilizarla\n")
 (prin1)
)
