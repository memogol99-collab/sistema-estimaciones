;; Modificado por Bier@es para este formato
;; v2.3k: Opciones de capas activadas por defecto al iniciar.
;; v2.3j: Soporte agregado para archivos .XYZ (X,Y,Z,Desc) sin numero de punto.
;; v2.3i: Soporte mejorado para archivos TXT
;; v2.3h: Reescritura de logica de capas para mayor robustez.
;; v2.3l: Añadido ZOOM EXTENTS al final de la importacion.

; Diseño y Programación:
; Mario Torres Pejerrey
; http://www.construcgeek.com/

(vl-load-com)
(setq AcadObj (vlax-get-acad-object))
(setq AcadDocument (vla-get-activedocument AcadObj))
(setq mspace (vla-get-modelspace AcadDocument))

(defun c:iCe()
    (setq version "v2.3l")
    (setq OLDERR *error*  *error* tberror)
      (setq TEMPCMD (getvar "CMDECHO"))  
    (setvar "CMDECHO" 0)
    (Crear_CuadroDialogo_iCe)
    (setq ind (LOAD_DIALOG fnameiCe))
    (if (not (new_dialog "dlg_iCe" ind))(exit))
    (CargarNombreConfiguracionDefecto)
    (Defecto)
    (valores)
    (acciones)
    (if (= 1 (START_DIALOG))(EjecutarComando))
    (UNLOAD_DIALOG ind)
    (vl-file-delete fnameiCe)
    (princ)
)

(defun CargarNombreConfiguracionDefecto()
    (setq Clave_Ice "HKEY_CURRENT_USER\\Software\\construcgeek.com\\iCe.lsp")
    (setq NombreConfiguracionxDefectoDef (vl-registry-read Clave_Ice "Configuracion por defecto"))
    (if (null NombreConfiguracionxDefectoDef)(setq NombreConfiguracionxDefectoDef ""))
    (setq RutaArchivoImportarDef (vl-registry-read Clave_Ice "Ruta de archivo a importar"))
    (if (null RutaArchivoImportarDef)(setq RutaArchivoImportarDef "*")
        (progn (if (null (findfile RutaArchivoImportarDef))(setq RutaArchivoImportarDef "*")))
    )
    ;; CAMBIADO A "1" PARA ACTIVAR POR DEFECTO
    (setq InsertarPuntosEnCapasDef (vl-registry-read Clave_Ice "Insertar puntos en capas de descripcion"))
    (if (null InsertarPuntosEnCapasDef)(setq InsertarPuntosEnCapasDef "1"))
    
    ;; CAMBIADO A "1" PARA ACTIVAR POR DEFECTO
    (setq PuntosyEtiquetasEnCapasDef (vl-registry-read Clave_Ice "Puntos y etiquetas en capas separadas"))
    (if (null PuntosyEtiquetasEnCapasDef)(setq PuntosyEtiquetasEnCapasDef "1"))
    
    ;; CAMBIADO A "1" PARA ACTIVAR POR DEFECTO
    (setq EtiquetasUnaCapaDef (vl-registry-read Clave_Ice "Etiquetas en una sola capa"))
    (if (null EtiquetasUnaCapaDef)(setq EtiquetasUnaCapaDef "1"))
)

(Defun Defecto()
    (setq Clave_Ice "HKEY_CURRENT_USER\\Software\\construcgeek.com\\iCe.lsp")
    (setq RutaArchivoBloqueDef (vl-registry-read (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Ruta de archivo de bloque importar"))
    (if (null RutaArchivoBloqueDef)(setq RutaArchivoBloqueDef "*")
        (progn (if (null (findfile RutaArchivoBloqueDef))(setq RutaArchivoBloqueDef "*")))
    )
    (setq EstiloPuntoDef (vl-registry-read (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Estilo del punto"))
    (if (null EstiloPuntoDef)(setq EstiloPuntoDef "Punto"))
    (setq NombreBloqueDef (vl-registry-read (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Nombre del bloque"))
    (if (null NombreBloqueDef)(setq NombreBloqueDef "cg-point")) 
    (setq EscalaBloqueDef (vl-registry-read (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Escala del bloque"))
    (if (null EscalaBloqueDef)(setq EscalaBloqueDef "1.00"))
    (setq AnguloBloqueDef (vl-registry-read (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Angulo del bloque"))
    (if (null AnguloBloqueDef)(setq AnguloBloqueDef "0"))
    (setq InsertarNumeroPuntoDef (vl-registry-read (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Insertar numero de punto"))
    (if (null InsertarNumeroPuntoDef)(setq InsertarNumeroPuntoDef "1"))
    (setq InsertarCotaDef (vl-registry-read (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Insertar cota"))
    (if (null InsertarCotaDef)(setq InsertarCotaDef "1"))
    (setq InsertarDescripcionDef (vl-registry-read (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Insertar descripcion"))
    (if (null InsertarDescripcionDef)(setq InsertarDescripcionDef "1"))
    (setq EscalaEtiquetaDef (vl-registry-read (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Escala de la etiqueta"))
    (if (null EscalaEtiquetaDef)(setq EscalaEtiquetaDef "1"))
    (setq NumeroDecimalesDef (vl-registry-read (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Numero de decimales"))
    (if (null NumeroDecimalesDef)(setq NumeroDecimalesDef "3"))
    (setq RotacionEtiquetaDef (vl-registry-read (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Rotacion de la etiqueta"))
    (if (null RotacionEtiquetaDef)(setq RotacionEtiquetaDef "0"))
    (setq SeparacionXEtiquetaDef (vl-registry-read (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Separacion de la etiqueta"))
    (if (null SeparacionXEtiquetaDef)(setq SeparacionXEtiquetaDef "0.20"))
)

(defun valores ()
    (SET_TILE "lblRuta" RutaArchivoImportarDef)
    (SET_TILE "chkImPuntoCapas" InsertarPuntosEnCapasDef)
    (SET_TILE "chkImPuntoDesCapas" PuntosyEtiquetasEnCapasDef)
    (SET_TILE "chkEtiquetasUnaCapa" EtiquetasUnaCapaDef)
    (cond
        ((= EstiloPuntoDef "Punto")(SET_TILE "rbPCAD" "1")(MODE_TILE "dspNBloque" 1)(MODE_TILE "cmdBlk" 1)(MODE_TILE "lblRutaB" 1)(MODE_TILE "txtEscBlk" 1)(MODE_TILE "txtAngBlk" 1))
        ((= EstiloPuntoDef "Seleccionar")(SET_TILE "rbSeleccionarBloque" "1")(MODE_TILE "cmdBlk" 1)(MODE_TILE "lblRutaB" 1)(MODE_TILE "dspNBloque" 0)(MODE_TILE "txtEscBlk" 0)(MODE_TILE "txtAngBlk" 0))
        ((= EstiloPuntoDef "Importar")(SET_TILE "rbImporBq" "1")(MODE_TILE "cmdBlk" 0)(MODE_TILE "lblRutaB" 0)(MODE_TILE "dspNBloque" 1)(MODE_TILE "txtEscBlk" 0)(MODE_TILE "txtAngBlk" 0))
    )
    (SET_TILE "lblRutaB" RutaArchivoBloqueDef)
    (CrearBloquePredeterminado)
    (ObtenerBloques)
    (START_LIST "dspNBloque")(MAPCAR 'ADD_LIST ListaBloques)(END_LIST)(SET_TILE "dspNBloque" BloqueIndiCe)
    (SET_TILE "txtEscBlk" EscalaBloqueDef)
    (SET_TILE "txtAngBlk" AnguloBloqueDef)
    (ObtenerListaConfiguracion)
    (START_LIST "dspNConfiguracion")(MAPCAR 'ADD_LIST ListaConfiguracion)(END_LIST)(SET_TILE "dspNConfiguracion" IndiceConfiguracion)
    (if (= contIndiceLista 0)(MODE_TILE "cmdEliminarConfig" 1))
    (SET_TILE "chkInsPunto" InsertarNumeroPuntoDef)
    (SET_TILE "chkInsCota" InsertarCotaDef)
    (SET_TILE "chkInsDes" InsertarDescripcionDef)
    (SET_TILE "txtEscEtiq" EscalaEtiquetaDef)
    (SET_TILE "txtNumDec" NumeroDecimalesDef)
    (SET_TILE "txtRotEtiq" RotacionEtiquetaDef)
    (SET_TILE "txtDesX" SeparacionXEtiquetaDef)
)
 
(defun Acciones()
    (ACTION_TILE "cmdArchivo" "(Seleccionar-Archivo)")
    (ACTION_TILE "dspNConfiguracion" "(setq NombreConfiguracionxDefectoDef (nth (atoi $Value) ListaConfiguracion))(Defecto)(valores)")
    (ACTION_TILE "cmdGuardarConfig" "(GuardarNombreConfiguracion)")
    (ACTION_TILE "cmdEliminarConfig" "(EliminarConfiguracion)")
    (ACTION_TILE "rbPCAD" "(MODE_TILE \"dspNBloque\" 1)(MODE_TILE \"cmdBlk\" 1)(MODE_TILE \"lblRutaB\" 1)(MODE_TILE \"txtEscBlk\" 1)(MODE_TILE \"txtAngBlk\" 1)")
    (ACTION_TILE "rbSeleccionarBloque" "(MODE_TILE \"dspNBloque\" 0)(MODE_TILE \"cmdBlk\" 1)(MODE_TILE \"lblRutaB\" 1)(MODE_TILE \"txtEscBlk\" 0)(MODE_TILE \"txtAngBlk\" 0)")
    (ACTION_TILE "dspNBloque" "(SeleccionarBloque)")
    (ACTION_TILE "rbImporBq" "(MODE_TILE \"dspNBloque\" 1)(MODE_TILE \"cmdBlk\" 0)(MODE_TILE \"lblRutaB\" 0)(MODE_TILE \"txtEscBlk\" 0)(MODE_TILE \"txtAngBlk\" 0)")
    (ACTION_TILE "cmdBlk" "(Importar-Bloque)")
    (ACTION_TILE "chkInsPunto" "(if (and (= $Value \"0\") (= (GET_TILE \"chkInsCota\")\"0\") (= (GET_TILE \"chkInsDes\")\"0\") )(progn (MODE_TILE \"txtNumDec\" 1)(MODE_TILE \"txtEscEtiq\" 1)(MODE_TILE \"txtRotEtiq\" 1)(MODE_TILE \"txtDesX\" 1))(progn (MODE_TILE \"txtNumDec\" 0)(MODE_TILE \"txtEscEtiq\" 0)(MODE_TILE \"txtRotEtiq\" 0)(MODE_TILE \"txtDesX\" 0)))")
    (ACTION_TILE "chkInsCota" "(if (and (= $Value \"0\") (= (GET_TILE \"chkInsPunto\")\"0\") (= (GET_TILE \"chkInsDes\")\"0\") )(progn (MODE_TILE \"txtNumDec\" 1)(MODE_TILE \"txtEscEtiq\" 1)(MODE_TILE \"txtRotEtiq\" 1)(MODE_TILE \"txtDesX\" 1))(progn (MODE_TILE \"txtNumDec\" 0)(MODE_TILE \"txtEscEtiq\" 0)(MODE_TILE \"txtRotEtiq\" 0)(MODE_TILE \"txtDesX\" 0)))")
    (ACTION_TILE "chkInsDes" "(if (and (= $Value \"0\") (= (GET_TILE \"chkInsCota\")\"0\") (= (GET_TILE \"chkInsPunto\")\"0\") )(progn (MODE_TILE \"txtNumDec\" 1)(MODE_TILE \"txtEscEtiq\" 1)(MODE_TILE \"txtRotEtiq\" 1)(MODE_TILE \"txtDesX\" 1))(progn (MODE_TILE \"txtNumDec\" 0)(MODE_TILE \"txtEscEtiq\" 0)(MODE_TILE \"txtRotEtiq\" 0)(MODE_TILE \"txtDesX\" 0)))")
    (ACTION_TILE "accept" "(Aceptar)")
    (ACTION_TILE "cancel" "(DONE_DIALOG)")
    (ACTION_TILE "Acerca" "(acercade)")
)

(defun Aceptar()
    (GuardarConfiguracion)
    (if (= grexi T)(DONE_DIALOG 1))
)

(defun Seleccionar-Archivo()
    (if (or (EQ (SUBSTR (GETVAR "acadver") 1 4) "15.0")(EQ (SUBSTR (GETVAR "acadver") 1 4) "16.0")(EQ (SUBSTR (GETVAR "acadver") 1 4) "16.1"))
        (setq RutaArchivoImportar (acet-ui-getfile "Elija el archivo de puntos a importar" RutaArchivoImportarDef "xls;xlsx;csv;txt;xyz" 1664))
        (setq RutaArchivoImportar (acet-ui-getfile "Elija el archivo de puntos a importar" RutaArchivoImportarDef "xls;xlsx;csv;txt;xyz" "xls;xlsx;csv;txt;xyz" 1664))
    )
    (if (not (null RutaArchivoImportar))
        (progn
            (SET_TILE "lblRuta" RutaArchivoImportar)
            (setq RutaArchivoImportarDef (GET_TILE "lblRuta"))
        )
    )
)

(defun EjecutarComando()
    (setq isExcel (or (wcmatch (strcase RutaArchivoImportarDef) "*.XLS") (wcmatch (strcase RutaArchivoImportarDef) "*.XLSX")))
    (if isExcel
        (progn (conectar-excel)(CrearEtiqueta)(ImportarPuntos)(desconectar-excel))
        (progn (CrearEtiqueta)(ImportarPuntosTXT_CSV))
    )
    ;; NUEVO: Ejecutar ZOOM EXTENTS al finalizar la importacion
    (ZoomExtents)
)

;; NUEVA FUNCION: Zoom Extents
(defun ZoomExtents ()
    (command "_.ZOOM" "_E")
    (princ)
)

;; --- Funciones TXT/CSV/XYZ mejoradas ---
(defun CleanString (str) 
    (if str
        (vl-string-trim " \t\r\n" str)
        ""
    )
)

(defun DetectDelimiter (linea)
    (cond
        ((vl-string-search "," linea) ",")
        ((vl-string-search ";" linea) ";")
        ((vl-string-search "\t" linea) "\t")
        ((vl-string-search " " linea) " ")
        (t ",")
    )
)

(defun ImportarPuntosTXT_CSV ()
    (setq NombreCapaActual (getvar "Clayer"))
    (setq mm (getvar "modemacro"))
    (setq fp (open RutaArchivoImportarDef "r"))
    
    (if fp
        (progn
            (setq Fila 1)
            (setq contPuntos 0)
            (setq delimiter nil)
            
            ;; --- NUEVO: Detectar si es formato XYZ (sin numero de punto) ---
            (setq isXYZFormat (wcmatch (strcase RutaArchivoImportarDef) "*.XYZ"))
            (if isXYZFormat 
                (setq varPuntoAuto 1) ;; Iniciar contador automatico
            )
            ;; -------------------------------------------------------------
            
            (while (setq linea (read-line fp))
                (if (and (null delimiter) (> (strlen (CleanString linea)) 0))
                    (setq delimiter (DetectDelimiter linea))
                )
                
                (if (null delimiter) (setq delimiter ","))
                
                (setq lstValores (StrParse linea delimiter))
                (setq numCols (length lstValores))
                (setq lstValores (mapcar 'CleanString lstValores))
                
                ;; --- LOGICA DE LECTURA MODIFICADA ---
                (if isXYZFormat
                    (progn
                        ;; Formato XYZ / XYZD: X, Y, Z, [Descripcion]
                        ;; El numero de punto es automatico
                        (setq varPunto varPuntoAuto)
                        (setq varx (atof (nth 0 lstValores))) 
                        (setq vary (atof (nth 1 lstValores)))
                        
                        (cond
                            ((>= numCols 4)
                                ;; X, Y, Z, Desc
                                (setq varz (atof (nth 2 lstValores)))
                                (setq varDescripcion (nth 3 lstValores))
                            )
                            ((= numCols 3)
                                ;; X, Y, Z (sin descripcion)
                                (setq varz (atof (nth 2 lstValores)))
                                (setq varDescripcion "")
                            )
                            (t
                                ;; Datos insuficientes
                                (setq varz 0.0)
                                (setq varDescripcion "")
                            )
                        )
                        ;; Incrementar contador automatico
                        (setq varPuntoAuto (1+ varPuntoAuto))
                    )
                    (progn
                        ;; Formato Original: P, X, Y, [Z], [Descripcion]
                        (setq varPunto (atof (nth 0 lstValores)))
                        (setq varx (atof (nth 1 lstValores))) 
                        (setq vary (atof (nth 2 lstValores)))
                        
                        (cond
                            ((= numCols 4)
                                (setq varz 0.0)
                                (setq varDescripcion (nth 3 lstValores))
                            )
                            ((>= numCols 5)
                                (setq varz (atof (nth 3 lstValores)))
                                (setq varDescripcion (nth 4 lstValores))
                            )
                            (t
                                (setq varz 0.0)
                                (setq varDescripcion "")
                            )
                        )
                    )
                )
                ;; ------------------------------------
                
                (if (null varDescripcion)(setq varDescripcion ""))
                
                (if (not (equal varPunto 0.0))
                    (progn
                        (EstablecerCapaActual "Punto" varDescripcion)
                        (cond 
                            ((= EstiloPunto "Punto")(vla-addPoint mspace (vlax-3d-point (list varx vary varz))))
                            ((= EstiloPunto "Seleccionar")(vla-insertblock mspace (vlax-3d-point (list varx vary varz)) NombreBloqueDef (atof EscalaBloque) (atof EscalaBloque) (atof EscalaBloque) (/ (atof AnguloBloque) 57.2957794)))
                            ((= EstiloPunto "Importar")(vla-insertblock mspace (vlax-3d-point (list varx vary varz)) RutaArchivoBloqueDef (atof EscalaBloque) (atof EscalaBloque) (atof EscalaBloque) (/ (atof AnguloBloque) 57.2957794)))
                        )
                        (EstablecerCapaActual "Etiqueta" varDescripcion)
                        (if (/= vchk 0) (setq BRefObj (vla-insertblock mspace (vlax-3d-point (list varx vary varz)) NombreBloque (atof EscalaEtiqueta) (atof EscalaEtiqueta) (atof EscalaEtiqueta) (/ (atof RotacionEtiqueta) 57.2957794) )))
                        (cond
                            ((= vchk 1) (vla-Put-TextString (nth 0 (vlax-Invoke BRefObj 'GetAttributes))(itoa (fix varPunto))))
                            ((= vchk 2) (vla-Put-TextString (nth 0 (vlax-Invoke BRefObj 'GetAttributes))(rtos varz 2 (atoi NumeroDecimales))))
                            ((= vchk 3) (vla-Put-TextString (nth 0 (vlax-Invoke BRefObj 'GetAttributes))(itoa (fix varPunto))) (vla-Put-TextString (nth 1 (vlax-Invoke BRefObj 'GetAttributes))(rtos varz 2 (atoi NumeroDecimales))) )
                            ((= vchk 4) (vla-Put-TextString (nth 0 (vlax-Invoke BRefObj 'GetAttributes)) varDescripcion))
                            ((= vchk 5) (vla-Put-TextString (nth 0 (vlax-Invoke BRefObj 'GetAttributes))(itoa (fix varPunto))) (vla-Put-TextString (nth 1 (vlax-Invoke BRefObj 'GetAttributes)) varDescripcion) )
                            ((= vchk 6) (vla-Put-TextString (nth 0 (vlax-Invoke BRefObj 'GetAttributes))(rtos varz 2 (atoi NumeroDecimales))) (vla-Put-TextString (nth 1 (vlax-Invoke BRefObj 'GetAttributes)) varDescripcion) )
                            ((= vchk 7) (vla-Put-TextString (nth 0 (vlax-Invoke BRefObj 'GetAttributes))(itoa (fix varPunto))) (vla-Put-TextString (nth 1 (vlax-Invoke BRefObj 'GetAttributes))(rtos varz 2 (atoi NumeroDecimales))) (vla-Put-TextString (nth 2 (vlax-Invoke BRefObj 'GetAttributes)) varDescripcion) )
                        )
                        (setq contPuntos (+ contPuntos 1))
                    )
                )
                (setq Fila (+ Fila 1))
                (setvar "modemacro" (strcat "Importando: " (itoa contPuntos) " punto(s)"))
            )
            (close fp)
            (vla-put-ActiveLayer AcadDocument (vla-Item (vla-get-Layers AcadDocument) NombreCapaActual))
            (setq msg (strcat "\nListo, se importaron " (itoa contPuntos) " puntos desde " (strcase (vl-filename-base RutaArchivoImportarDef)) "."))
            (Alert msg) 
            (setvar "modemacro" mm)
        )
        (alert "No se pudo abrir el archivo.")
    )
)

(defun StrParse (str delim / pos lst)
  (while (setq pos (vl-string-search delim str))
    (setq lst (cons (substr str 1 pos) lst))
    (setq str (substr str (+ pos 2)))
  )
  (setq lst (cons str lst))
  (reverse lst)
)
; ------------------------

(defun conectar-excel() 
  (setq apl-excel  (vlax-create-object "excel.application") 
   col-libros (vlax-get-property apl-excel "workbooks")
   libro  (vlax-invoke-method col-libros "open" RutaArchivoImportarDef)
   col-hojas  (vlax-get-property libro "sheets") 
   hoja-1     (vlax-get-property col-hojas "item" 1) 
   col-celdas (vlax-get-property hoja-1 "cells")
  ) 
  (vla-put-visible apl-excel :vlax-false)
) 

(defun CrearBloquePredeterminado()
    (if (= (tblsearch "BLOCK" "cg-point") nil) 
        (progn 
            (entmake (list '(0 . "BLOCK") '(2 . "cg-point")'(70 . 2)'(10 0.0 0.0 0.0) '(8 . "0")))
            (entmake '((0 . "LINE")(8 . "0")(10 0.0 0.13 0.0)(11 0.0 -0.13 0.0)(210 0.0 0.0 1.0)))
            (entmake '((0 . "LINE")(8 . "0")(10 -0.13 0.0 0.0)(11 0.13 0.0 0.0)(210 0.0 0.0 1.0)))
            (entmake '((0 . "CIRCLE")(8 . "0")(10 0.0 0.0 0.0)(40 . 0.1)(210 0.0 0.0 1.0)))
            (entmake '((0 . "ENDBLK"))) 
        ) 
    )
)

(defun CrearEtiqueta () 
    (setq EstiloTextoActual (getvar "TEXTSTYLE"))
    (if (= InsertarNumeroPunto "1")(setq vchkIP 1)(setq vchkIP 0))
    (if (= InsertarCota "1")(setq vchkIC 2)(setq vchkIC 0))
    (if (= InsertarDescripcion "1")(setq vchkID 4)(setq vchkID 0))
    (setq vchk (+ vchkIP vchkIC vchkID))
    (cond
        ((or (= vchk 1) (= vchk 2)(= vchk 4))(setq y1 -0.10 y2 -0.10 y3 -0.10))
        ((= vchk 3) (setq y1 0.04 y2 -0.24 y3 0))
        ((= vchk 5) (setq y1 0.04 y2 0 y3 -0.24))
        ((= vchk 6) (setq y1 0 y2 0.04 y3 -0.24))
        ((= vchk 7) (setq y1 0.18 y2 -0.10 y3 -0.38))
    )
    (setq PIP (list (atof SeparacionXEtiqueta) y1 0.0))
    (setq PIC (list (atof SeparacionXEtiqueta) y2 0.0))
    (setq PID (list (atof SeparacionXEtiqueta) y3 0.0))
    (setq indbloque 1)
    (setq NombreInicialBloque "e-cg-point")
    (setq NombreBloque NombreInicialBloque)
    (while (/= (tblsearch "BLOCK" NombreBloque) nil)
        (setq NombreBloque (strcat NombreInicialBloque (itoa indbloque)))
        (setq indbloque (+ indbloque 1))
    )
    (if (/= vchk 0)
        (progn
            (entmake (list '(0 . "BLOCK") (cons 2 NombreBloque)'(70 . 2)'(10 0.0 0.0 0.0) '(8 . "0")))
            (if (= InsertarNumeroPunto "1")
                (entmake (list '(0 . "ATTDEF") (CONS 7 EstiloTextoActual) '(8 . "0") (cons 10 PIP) '(11 0.0 0.0 0.0) '(1 . "1") '(2 . "Punto") '(3 . "P") '(40 . 0.2) '(41 . 1.0) '(50 . 0.0) '(51 . 0.0) '(70 . 0) '(71 . 0) '(72 . 0) '(73 . 0) '(74 . 0)))
            )
            (if (= InsertarCota "1")
                (entmake (list '(0 . "ATTDEF") (CONS 7 EstiloTextoActual) '(8 . "0") (cons 10 PIC) '(11 0.0 0.0 0.0) '(1 . "0.00") '(2 . "Cota") '(3 . "C") '(40 . 0.2) '(41 . 1.0) '(50 . 0.0) '(51 . 0.0) '(70 . 0) '(71 . 0) '(72 . 0) '(73 . 0)'(74 . 0)))
            )
            (if (= InsertarDescripcion "1")
                (entmake (list '(0 . "ATTDEF") (CONS 7 EstiloTextoActual) '(8 . "0") (cons 10 PID) '(11 0.0 0.0 0.0) '(1 . "ConstrucGeek") '(2 . "Descripción") '(3 . "D") '(40 . 0.2) '(41 . 1.0) '(50 . 0.0) '(51 . 0.0) '(70 . 0) '(71 . 0) '(72 . 0) '(73 . 0)'(74 . 0)))
            )
            (entmake '((0 . "ENDBLK"))) 
        ) 
    )
) 

(defun EstablecerCapaActual(EstablecerPara ValorDescripcion)
    (setq NombreCapaAVerificar NombreCapaActual)
    (if (= (type ValorDescripcion) 'STR)
        (setq ValorDescripcion (vl-string-trim " \t" ValorDescripcion))
    )
    (cond
        ((and (= EstablecerPara "Etiqueta") (= EtiquetasUnaCapa "1"))
            (setq NombreCapaAVerificar "-Etiquetas")
        )
        ((and (= InsertarPuntosEnCapas "1") ValorDescripcion (/= ValorDescripcion ""))
            (if (not (wcmatch ValorDescripcion "*<*,*>*,*/*,*\\*,*:*"))
                (if (= PuntosyEtiquetasEnCapas "1")
                    (setq NombreCapaAVerificar (strcat ValorDescripcion (if (= EstablecerPara "Punto") "-Punto" "-Etiqueta")))
                    (setq NombreCapaAVerificar ValorDescripcion)
                )
            )
        )
        ((= PuntosyEtiquetasEnCapas "1")
            (setq NombreCapaAVerificar (strcat NombreCapaActual (if (= EstablecerPara "Punto") "-Punto" "-Etiqueta")))
        )
    )
    (if NombreCapaAVerificar
        (progn
            (setq CapaNombreDescripcion (tblsearch "LAYER" NombreCapaAVerificar T))
            (if (null CapaNombreDescripcion) 
                (vla-add (vla-get-layers AcadDocument) NombreCapaAVerificar)
            )
            (vla-put-ActiveLayer AcadDocument (vla-Item(vla-get-Layers AcadDocument) NombreCapaAVerificar))
        )
    )
)

(defun ImportarPuntos()
    (setq NombreCapaActual (getvar "Clayer"))
    (setq mm (getvar "modemacro"))
    (setq Fila 1)
    (setq varPunto 1)

    (while (not (equal varPunto 0.0))
        (setq varPunto (vlax-variant-value (vlax-variant-change-type (vlax-get-property col-celdas "item" Fila 1)vlax-vbInteger)))
        (setq vary (vlax-variant-value (vlax-variant-change-type (vlax-get-property col-celdas "item" Fila 3)vlax-vbDouble)))
        (setq varx (vlax-variant-value (vlax-variant-change-type (vlax-get-property col-celdas "item" Fila 2)vlax-vbDouble)))
        
        (setq valCol5 (vl-catch-all-apply 'vlax-variant-value 
            (list (vlax-variant-change-type (vlax-get-property col-celdas "item" Fila 5) vlax-vbString))))
        
        (if (and (not (vl-catch-all-error-p valCol5)) (/= valCol5 ""))
            (progn
                (setq varz (vlax-variant-value (vlax-variant-change-type (vlax-get-property col-celdas "item" Fila 4)vlax-vbDouble)))
                (setq varDescripcion valCol5)
            )
            (progn
                (setq varz 0.0)
                (setq varDescripcion (vlax-variant-value (vlax-variant-change-type (vlax-get-property col-celdas "item" Fila 4) vlax-vbString)))
            )
        )
        
        (if (null varDescripcion)(setq varDescripcion ""))

        (if (not (equal varPunto 0.0))
            (progn
                (EstablecerCapaActual "Punto" varDescripcion)
                (cond 
                    ((= EstiloPunto "Punto")(vla-addPoint mspace (vlax-3d-point (list varx vary varz))))
                    ((= EstiloPunto "Seleccionar")(vla-insertblock mspace (vlax-3d-point (list varx vary varz)) NombreBloqueDef (atof EscalaBloque) (atof EscalaBloque) (atof EscalaBloque) (/ (atof AnguloBloque) 57.2957794)))
                    ((= EstiloPunto "Importar")(vla-insertblock mspace (vlax-3d-point (list varx vary varz)) RutaArchivoBloqueDef (atof EscalaBloque) (atof EscalaBloque) (atof EscalaBloque) (/ (atof AnguloBloque) 57.2957794)))
                )
                
                (EstablecerCapaActual "Etiqueta" varDescripcion)
                (if (/= vchk 0) (setq BRefObj (vla-insertblock mspace (vlax-3d-point (list varx vary varz)) NombreBloque (atof EscalaEtiqueta) (atof EscalaEtiqueta) (atof EscalaEtiqueta) (/ (atof RotacionEtiqueta) 57.2957794) )))

                (cond
                    ((= vchk 1) (vla-Put-TextString (nth 0 (vlax-Invoke BRefObj 'GetAttributes))(itoa varPunto)))
                    ((= vchk 2) (vla-Put-TextString (nth 0 (vlax-Invoke BRefObj 'GetAttributes))(rtos varz 2 (atoi NumeroDecimales))))
                    ((= vchk 3) (vla-Put-TextString (nth 0 (vlax-Invoke BRefObj 'GetAttributes))(itoa varPunto)) (vla-Put-TextString (nth 1 (vlax-Invoke BRefObj 'GetAttributes))(rtos varz 2 (atoi NumeroDecimales))) )
                    ((= vchk 4) (vla-Put-TextString (nth 0 (vlax-Invoke BRefObj 'GetAttributes)) varDescripcion))
                    ((= vchk 5) (vla-Put-TextString (nth 0 (vlax-Invoke BRefObj 'GetAttributes))(itoa varPunto)) (vla-Put-TextString (nth 1 (vlax-Invoke BRefObj 'GetAttributes)) varDescripcion) )
                    ((= vchk 6) (vla-Put-TextString (nth 0 (vlax-Invoke BRefObj 'GetAttributes))(rtos varz 2 (atoi NumeroDecimales))) (vla-Put-TextString (nth 1 (vlax-Invoke BRefObj 'GetAttributes)) varDescripcion) )
                    ((= vchk 7) (vla-Put-TextString (nth 0 (vlax-Invoke BRefObj 'GetAttributes))(itoa varPunto)) (vla-Put-TextString (nth 1 (vlax-Invoke BRefObj 'GetAttributes))(rtos varz 2 (atoi NumeroDecimales))) (vla-Put-TextString (nth 2 (vlax-Invoke BRefObj 'GetAttributes)) varDescripcion) )
                )
            )
        )
        (setq Fila (+ Fila 1))
        (setvar "modemacro" (strcat "Importando: " (itoa (- Fila 2)) " punto(s)"))
    )
    
    (vla-put-ActiveLayer AcadDocument (vla-Item (vla-get-Layers AcadDocument) NombreCapaActual))
    (setq msg (strcat "\nListo, se importaron " (itoa (- Fila 2)) " puntos."))
    (Alert msg)
    (setvar "modemacro" mm)
)

(defun desconectar-excel() 
  (vlax-release-object col-celdas) 
  (vlax-release-object hoja-1) 
  (vlax-release-object col-hojas) 
  (vlax-release-object col-libros)
  (vlax-invoke-method apl-excel 'QUIT) 
  (vlax-release-object apl-excel) 
  (gc) 
)

(defun ObtenerListaConfiguracion()
    (setq IndiceConfiguracion "0")
    (setq contIndiceLista 0)
    (if (vl-registry-descendents Clave_Ice)
        (progn
            (setq ListaConfiguracion (vl-registry-descendents Clave_Ice))
            (setq longLista (vl-list-length ListaConfiguracion))
            (repeat longLista
                (setq CofigNombOntenida (nth contIndiceLista ListaConfiguracion))
                (if (= CofigNombOntenida NombreConfiguracionxDefectoDef)(setq IndiceConfiguracion (itoa contIndiceLista)))
                (setq contIndiceLista (+ contIndiceLista 1))
            )
        )
        (setq ListaConfiguracion (list "Sin nombre"))
    )
)

(defun ObtenerBloques (/ b bn tl)
(setq cont 0)
(setq BloqueIndiCe 0)
  (vlax-for b (vla-get-blocks AcadDocument)
    (if (= (vla-get-islayout b) :vlax-false)
        (progn
          (setq tl (cons (vla-get-name b) tl))
          (if  (= (vla-get-name b)  NombreBloqueDef)(setq BloqueIndiCe (itoa cont)))
          (setq cont (+ cont 1))
      )
    )
  )
  (setq ListaBloques (reverse tl))
)

(defun SeleccionarBloque()
    (setq ValorSeleccionado (GET_TILE "dspNBloque"))
    (setq NombreBloqueDef (nth (atoi ValorSeleccionado) ListaBloques))
)

(defun Importar-Bloque()
    (setq RutaArchivoBloque (acet-ui-getfile "Elija el bloque a insertar en el dibujo" RutaArchivoBloqueDef "dwg" "dwg" 1664))
    (if (not (null RutaArchivoBloque))
        (progn
            (SET_TILE "lblRutaB" RutaArchivoBloque)
            (Setq RutaArchivoBloqueDef RutaArchivoBloque)
        )
    )
)

(defun GuardarNombreConfiguracion()
    (setq NombreConfiguracionAGuardar (acet-ui-txted "" ta "Guardar configuración actual de estilos de punto y etiqueta como:"))
    (if (not (null NombreConfiguracionAGuardar))
        (progn
            (setq NombreConfiguracionxDefectoDef NombreConfiguracionAGuardar)
            (GuardarConfiguracion)
            (ObtenerListaConfiguracion)
            (START_LIST "dspNConfiguracion")(MAPCAR 'ADD_LIST ListaConfiguracion)(END_LIST)(SET_TILE "dspNConfiguracion" IndiceConfiguracion)
            (if (> contIndiceLista 0)(MODE_TILE "cmdEliminarConfig" 0)(MODE_TILE "cmdEliminarConfig" 1))
        )
    )
)

(defun EliminarConfiguracion()
    (setq IndiceActualEliminar (atoi (GET_TILE "dspNConfiguracion")))
    (setq NombreConfiguracionAEliminar (nth IndiceActualEliminar ListaConfiguracion))
    (setq Respuesta (acet-ui-message  (strcat "¿Estás seguro que deseas eliminar la configuración: " NombreConfiguracionAEliminar "?" "\nEsta acción no se puede deshacer.") ta (+ (+ 4 32) 256)))
    (if (= Respuesta 6)
        (progn
            (vl-registry-delete (strcat Clave_Ice "\\" NombreConfiguracionAEliminar))
            (if (> IndiceActualEliminar 0)
                (setq NombreConfiguracionxDefectoDef (nth (- IndiceActualEliminar 1) ListaConfiguracion))
                (setq NombreConfiguracionxDefectoDef (nth IndiceActualEliminar ListaConfiguracion))
            )
            (ObtenerListaConfiguracion)
            (START_LIST "dspNConfiguracion")(MAPCAR 'ADD_LIST ListaConfiguracion)(END_LIST)(SET_TILE "dspNConfiguracion" IndiceConfiguracion)
            (if (= contIndiceLista 0)(MODE_TILE "cmdEliminarConfig" 1)(MODE_TILE "cmdEliminarConfig" 0))
        )
    )
)

(defun GuardarConfiguracion()
    (setq grexi nil)
    (cond
        ((= (GET_TILE "lblRuta") "*")(acet-ui-message "Debe de seleccionar un archivo con coordenadas de puntos a importar antes de continuar." ta (+ (+ 0 48) 0)))
        ((And (Or (= (GET_TILE "rbSeleccionarBloque") "1") (= (GET_TILE "rbImporBq") "1") ) (= (GET_TILE "txtEscBlk") ""))
            (MODE_TILE "txtEscBlk" 2)(acet-ui-message "Debe de ingresar la escala para el bloque." ta (+ (+ 0 48) 0))
        )
        ((And (Or (= (GET_TILE "rbSeleccionarBloque") "1") (= (GET_TILE "rbImporBq") "1") ) (= (GET_TILE "txtAngBlk") ""))
            (MODE_TILE "txtAngBlk" 2)(acet-ui-message "Debe de ingresar un ángulo de inserción del bloque." ta (+ (+ 0 48) 0))
        )
        ((And (Or (= (GET_TILE "rbSeleccionarBloque") "1") (= (GET_TILE "rbImporBq") "1") ) (<= (Atof (GET_TILE "txtEscBlk")) 0))
            (MODE_TILE "txtEscBlk" 2)(acet-ui-message "Debe de ingresar una escala válida para el bloque." ta (+ (+ 0 48) 0))
        )
        ((And (Or (= (GET_TILE "rbSeleccionarBloque") "1") (= (GET_TILE "rbImporBq") "1") )(< (Atof (GET_TILE "txtAngBlk")) 0))
            (MODE_TILE "txtAngBlk" 2)(acet-ui-message "Debe de ingresar un ángulo válido para la inserción del bloque." ta (+ (+ 0 48) 0))
        )
        ((And (= (GET_TILE "rbImporBq") "1") (= (GET_TILE "lblRutaB") "*"))
            (MODE_TILE "cmdBlk" 2)(acet-ui-message "Debe de indicar una ruta para el bloque a importar." ta (+ (+ 0 48) 0))
        )
        ((And (Or (= (GET_TILE "chkInsPunto") "1") (= (GET_TILE "chkInsCota") "1") (= (GET_TILE "chkInsDes") "1")) (= (GET_TILE "txtEscEtiq") ""))
            (MODE_TILE "txtEscEtiq" 2)(acet-ui-message "Debe de ingresar la escala para la etiqueta del punto." ta (+ (+ 0 48) 0))
        )
        ((And (Or (= (GET_TILE "chkInsPunto") "1") (= (GET_TILE "chkInsCota") "1") (= (GET_TILE "chkInsDes") "1")) (= (GET_TILE "txtNumDec") ""))
            (MODE_TILE "txtNumDec" 2)(acet-ui-message "Debe de ingresar el número de decimales para cota de la etiqueta del punto." ta (+ (+ 0 48) 0))
        )
        ((And (Or (= (GET_TILE "chkInsPunto") "1") (= (GET_TILE "chkInsCota") "1") (= (GET_TILE "chkInsDes") "1")) (= (GET_TILE "txtRotEtiq") ""))
            (MODE_TILE "txtRotEtiq" 2)(acet-ui-message "Debe de ingresar el ángulo de rotación para la etiqueta del punto." ta (+ (+ 0 48) 0))
        )
        ((And (Or (= (GET_TILE "chkInsPunto") "1") (= (GET_TILE "chkInsCota") "1") (= (GET_TILE "chkInsDes") "1")) (= (GET_TILE "txtDesX") ""))
            (MODE_TILE "txtDesX" 2)(acet-ui-message "Debe de ingresar la separación entre el punto y los textos de etiqueta del punto." ta (+ (+ 0 48) 0))
        )
        ((And (Or (= (GET_TILE "chkInsPunto") "1") (= (GET_TILE "chkInsCota") "1") (= (GET_TILE "chkInsDes") "1")) (<= (Atof (GET_TILE "txtEscEtiq")) 0))
            (MODE_TILE "txtEscEtiq" 2)(acet-ui-message "Debe de ingresar una altura válida para la etiqueta del punto." ta (+ (+ 0 48) 0))
        )
        ((And (Or (= (GET_TILE "chkInsPunto") "1") (= (GET_TILE "chkInsCota") "1") (= (GET_TILE "chkInsDes") "1")) (<= (Atoi (GET_TILE "txtNumDec")) 0))
            (MODE_TILE "txtNumDec" 2)(acet-ui-message "Debe de ingresar un número válido de decimales para cota de la etiqueta del punto." ta (+ (+ 0 48) 0))
        )
        ((And (Or (= (GET_TILE "chkInsPunto") "1") (= (GET_TILE "chkInsCota") "1") (= (GET_TILE "chkInsDes") "1")) (< (Atof (GET_TILE "txtRotEtiq")) 0))
            (MODE_TILE "txtRotEtiq" 2)(acet-ui-message "Debe de ingresar un valor de rotación válido para la etiqueta del punto." ta (+ (+ 0 48) 0))
        )
        ((And (Or (= (GET_TILE "chkInsPunto") "1") (= (GET_TILE "chkInsCota") "1") (= (GET_TILE "chkInsDes") "1")) (< (Atof (GET_TILE "txtDesX")) 0))
            (MODE_TILE "txtDesX" 2)(acet-ui-message "Debe de ingresar un valor de desplazamiento entre el punto y su etiqueta válido." ta (+ (+ 0 48) 0))
        )
        (T 
            (if (/= NombreConfiguracionxDefectoDef "Sin nombre")(VL-REGISTRY-WRITE Clave_Ice "Configuracion por defecto" NombreConfiguracionxDefectoDef))
            (VL-REGISTRY-WRITE Clave_Ice "Ruta de archivo a importar" RutaArchivoImportarDef)
            (setq InsertarPuntosEnCapas (GET_TILE "chkImPuntoCapas"))
            (VL-REGISTRY-WRITE Clave_Ice "Insertar puntos en capas de descripcion" InsertarPuntosEnCapas)
            (setq PuntosyEtiquetasEnCapas (GET_TILE "chkImPuntoDesCapas"))
            (VL-REGISTRY-WRITE Clave_Ice "Puntos y etiquetas en capas separadas" PuntosyEtiquetasEnCapas)
            (setq EtiquetasUnaCapa (GET_TILE "chkEtiquetasUnaCapa"))
            (VL-REGISTRY-WRITE Clave_Ice "Etiquetas en una sola capa" EtiquetasUnaCapa)
            (If (= (GET_TILE "rbPCAD") "1")(setq EstiloPunto "Punto"))
            (If (= (GET_TILE "rbSeleccionarBloque") "1")(setq EstiloPunto "Seleccionar"))
            (If (= (GET_TILE "rbImporBq") "1")(setq EstiloPunto "Importar"))
            (VL-REGISTRY-WRITE (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Estilo del punto" EstiloPunto)
            (VL-REGISTRY-WRITE (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Nombre del bloque" NombreBloqueDef)
            (VL-REGISTRY-WRITE (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Ruta de archivo de bloque importar" RutaArchivoBloqueDef)
            (setq EscalaBloque(GET_TILE "txtEscBlk"))(VL-REGISTRY-WRITE (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Escala del bloque" EscalaBloque)
            (setq AnguloBloque(GET_TILE "txtAngBlk"))(VL-REGISTRY-WRITE (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Angulo del bloque" AnguloBloque)
            (setq InsertarNumeroPunto (GET_TILE "chkInsPunto"))(VL-REGISTRY-WRITE (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Insertar numero de punto" InsertarNumeroPunto)
            (setq InsertarCota(GET_TILE "chkInsCota"))(VL-REGISTRY-WRITE (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Insertar cota" InsertarCota)
            (setq InsertarDescripcion (GET_TILE "chkInsDes"))(VL-REGISTRY-WRITE (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Insertar descripcion" InsertarDescripcion)
            (setq EscalaEtiqueta (GET_TILE "txtEscEtiq"))(VL-REGISTRY-WRITE (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Escala de la etiqueta" EscalaEtiqueta)
            (setq NumeroDecimales (GET_TILE "txtNumDec"))(VL-REGISTRY-WRITE (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Numero de decimales" NumeroDecimales)
            (setq RotacionEtiqueta (GET_TILE "txtRotEtiq"))(VL-REGISTRY-WRITE (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Rotacion de la etiqueta" RotacionEtiqueta)
            (setq SeparacionXEtiqueta (GET_TILE "txtDesX"))(VL-REGISTRY-WRITE (strcat Clave_Ice "\\" NombreConfiguracionxDefectoDef) "Separacion de la etiqueta" SeparacionXEtiqueta)
            (setq grexi T)
        )
    )
)

(defun acercade()
(acet-ui-message (strcat "Programa: Importar Coordenadas desde Excel, Comando: iCe"
     "\nLisp Desarrollado por Mario Torres Pejerrey."
     "\nImporta puntos de coordenadas a partir de archivos Excel, CSV, TXT o XYZ."
     "\nhttp://www.construcgeek.com/"
     ) ta (+ (+ 0 64) 0))
)
 
(defun tberror (S)
    (if (= S "Function cancelled")(princ (strcat "\nSe ha producido el error: " S))(princ S))
    (setvar "CMDECHO" TEMPCMD)
    (if (not (null apl-excel))(desconectar-excel))
    (if (not (null fnameiCe))
        (progn (close fnIPC)(vl-file-delete fnameiCe))
    )
    (setq *error* OLDERR)
    (princ)
)

(defun Crear_CuadroDialogo_iCe()
(setq fnameiCe (vl-filename-mktemp "iCe.dcl"))
(setq fnIPC (open fnameiCe "w"))
(setq ta (strcat "Construcgeek iCe " version))
(setq Form-parte-a (strcat "dlg_iCe : dialog {
  label=\"" ta "\";
  : boxed_column {
    label=\"Archivo de datos \";
    :row {fixed_width=true; : text {key=\"txtTexto\"; label=\"Archivo de puntos a importar  \";} :button {key=\"cmdArchivo\"; width=3; label=\"...\";} }
    : text {key=\"lblRuta\"; alignment=left; fixed_height=false; label=\"*\";}
  }
  : boxed_column {
       label=\"Opciones de importación de puntos\";
    : toggle {key=\"chkImPuntoCapas\"; alignment=left;label=\"En capas según su &descripción\"; alignment=left; fixed_width=false;}
    : toggle {key=\"chkImPuntoDesCapas\"; label=\"Puntos &y etiquetas en capas separadas\"; alignment=left; fixed_width=false;}
    : toggle {key=\"chkEtiquetasUnaCapa\"; label=\"Etiquetas en una sola capa (-Etiquetas)\"; alignment=left; fixed_width=false;}
    spacer;
  }
  : boxed_column {
       label=\"Configuraciones guardadas\";
    :column {
        : popup_list {key=\"dspNConfiguracion\"; label=\"\"; width=18;} 
        :row {
            :button {fixed_width=true; key=\"cmdGuardarConfig\"; width=3; label=\"Gua&rdar como...\"; fixed_width=true;} 
            :button {key=\"cmdEliminarConfig\"; width=2; label=\"E&liminar...\"; fixed_width=true;}
        }
    }
    spacer;
  }
   "))
(setq Form-parte-b ": boxed_radio_column {
    label=\"Estilo de punto \";
    : row {
    : radio_column {:radio_button {key=\"rbPCAD\"; label=\"&Punto de AutoCAD\";} : radio_button {key=\"rbSeleccionarBloque\"; label=\"&Seleccionar bloque\";} :radio_button {key=\"rbImporBq\"; label=\"Importar &bloque\";}}
    : column {:text {key=\"lbl\"; alignment=left; label=\"\";} : popup_list {key=\"dspNBloque\"; label=\"\"; alignment=left;} :button {key=\"cmdBlk\"; width=3; fixed_width=true; alignment=right; label=\"...\";}}
    }
    :column {alignment=left; fixed_width=true;
    :text {key=\"lblRutaB\"; label=\"*\";}
    :edit_box {key=\"txtEscBlk\"; edit_width=5; edit_limit=5; label=\"      &Escala del bloque                    \";}   
    :edit_box {key=\"txtAngBlk\"; edit_width=5; edit_limit=5; label=\"      An&gulo de rotación                    \";} 
    }
  spacer;
  }")
(setq Form-parte-c ": boxed_column {
    label=\"Estilo de etiqueta \";
    : toggle {key=\"chkInsPunto\"; label=\"Inser&tar número de punto\"; fixed_width=true;}
    : toggle {key=\"chkInsCota\"; label=\"Insertar c&ota\"; fixed_width=true;}
    : toggle {key=\"chkInsDes\"; label=\"Insertar descripc&ión\"; fixed_width=true;}
    :column {alignment=left; fixed_width=true;
    : edit_box {key=\"txtNumDec\"; edit_width=5; edit_limit=2; label=\"      Número de deci&males         \";}
    : edit_box {key=\"txtEscEtiq\"; edit_width=5; edit_limit=5; label=\"      Escala de la eti&queta     \";}
    : edit_box {key=\"txtRotEtiq\"; edit_width=5; edit_limit=5; label=\"      Ang&ulo de rotación        \";}
    : edit_box {key=\"txtDesX\"; edit_width=5; edit_limit=5; label=\"      Separación desde el pu&nto       \";}
    }
      spacer;
  }
  spacer;
  : row { : button {key=\"accept\"; is_default=true; label= \"&Aceptar\";}: button {key=\"cancel\"; is_cancel=true; label= \"&Cancelar\"; } :button {key=\"Acerca\"; is_cancel=false; label=\"Acerca de...\"; }}
  
}")
(write-line Form-parte-a fnIPC)
(write-line Form-parte-b fnIPC)
(write-line Form-parte-c fnIPC)
(close fnIPC)
)
(setvar "modemacro" "http://www.construcgeek.com/")