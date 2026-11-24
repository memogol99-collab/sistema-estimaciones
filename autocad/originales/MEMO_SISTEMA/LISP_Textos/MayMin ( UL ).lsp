;;CADALYST 01/04 Tip1923: ULCASE.LSP  Uppercase
;;(c) 2004 Martin Fryer and Christopher Eriksen

					;ulcase.lsp v1.0
					;Christopher Eriksen and Martin Fryer
					;June 25 2003
					;Changes multiple selected text entities
					;from upper case to lower case and visa versa

(defun c:ul	()
  (prompt "Convertir Mayusculas a Minusculas [Upper or Lower]:")
  (setq casestr (getstring))
  (if (or (or (= casestr "u") (= casestr "U")) (= casestr ""))
    (setq casemode nil)
					;else
    (if	(or (= casestr "l") (= casestr "L"))
      (setq casemode 1)
    )
  )
  (prompt "\nPick lines of text: ")
  (setq ss (ssget '((0 . "TEXT,MTEXT"))))
  (if (/= ss nil)
    (progn
      (setq ssposition 0)		;Setup index to point at first entity in selection set
      (while (< ssposition (sslength ss))
					;For each entity in the selection set, do....
	(setq entityname (ssname ss ssposition))
					;Get next entities name from the selection set
	(setq entity1 (entget entityname)) ;Get entity list from name
	(setq ssposition (+ ssposition 1)) ;Advance index

	(setq string1 (cdr (assoc 1 entity1)))
	(setq string1 (strcase string1 casemode))
					;Convert text to upper/lower case
	(setq string1 (fixmtext string1))
	(setq
	  entity1 (subst (cons 1 string1) (assoc 1 entity1) entity1)
	)				;Substitue new text element with new
	(entmod entity1)		;Update entity
      )					;end while
    )					;end progn
					;else
    (princ "No text entities were selected")
  )					;end if
  (princ)				;Exit quietly

)					;end defun


(defun fixmtext	(string1)
  (while (/= (vl-string-search "\\p" string1) nil)
    (setq string1 (vl-string-subst "\\P" "\\p" string1))
  )
  (while (/= (vl-string-search "\\l" string1) nil)
    (setq string1 (vl-string-subst "\\L" "\\l" string1))
  )
  (while (/= (vl-string-search "\\F" string1) nil)
    (setq string1 (vl-string-subst "\\f" "\\F" string1))
  )
  (while (/= (vl-string-search "\\h" string1) nil)
    (setq string1 (vl-string-subst "\\H" "\\h" string1))
  )
  (while (/= (vl-string-search "\\s" string1) nil)
    (setq string1 (vl-string-subst "\\s" "\\S" string1))
  )
  (while (/= (vl-string-search "\\q" string1) nil)
    (setq string1 (vl-string-subst "\\q" "\\Q" string1))
  )
  (while (/= (vl-string-search "\\t" string1) nil)
    (setq string1 (vl-string-subst "\\t" "\\T" string1))
  )
  (while (/= (vl-string-search "\\w" string1) nil)
    (setq string1 (vl-string-subst "\\w" "\\W" string1))
  )
  (while (/= (vl-string-search "\\a" string1) nil)
    (setq string1 (vl-string-subst "\\a" "\\A" string1))
  )
  (while (/= (vl-string-search "\\o" string1) nil)
    (setq string1 (vl-string-subst "\\o" "\\O" string1))
  )

  string1
)					;end defun