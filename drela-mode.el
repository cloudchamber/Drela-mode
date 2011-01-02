;;; drela-mode.el --- mode for editing files used in Drela's aerodynamic codes

;; Copyright (C) 2010, Kenneth Jensen.

;; Author: Kenneth Jensen <kjensen@alum.mit.edu>
;; Keywords: aerodynamics, AVL

;;; Commentary:

;; This is a major mode for editing files used in Drela's aerodynamic
;; codes.  The mode supports syntax highlighting, easy tabbing through
;; and indentation of data elements, plotting of geometries, and running
;; AVL within EMACS.  This version only supports AVL.  Future versions 
;; will support other Drela codes.
;;
;; AVL functions:
;; C-p        Plots the geometry of the current AVL file
;; C-e        Executes AVL on the current AVL file
;; C-RET      Inserts a "standard" comment
;; C-Sh-RET   Removes the preceding comment
;; Tab        Moves to next element/indents elements
;; Sh-Tab     Moves to previous element

;;; Code:


(defgroup avl nil
  "Major mode for editing AVL (.avl) files."
  :group 'languages)


(defcustom avl-indent-level 10
  "Indentation between number fields"
  :type 'integer
  :group 'avl)

(defcustom avl-executable-location "C:\\Progra~1\\Aero\\Avl\\bin\\avl.exe"
  "Location of the avl executable"
  :type 'string
  :group 'avl)


(defvar avl-mode-map ()
  "Keymap used in AVL mode.")
(if (null avl-mode-map)
    (progn
      (setq avl-mode-map (make-sparse-keymap))
      (if (functionp 'set-keymap-name)
	  (set-keymap-name avl-mode-map 'avl-mode-map)) ;XEmacs
      (define-key avl-mode-map [(control p)] 'avl-plot-geometry)
      (define-key avl-mode-map [(control e)] 'avl-execute)
      (define-key avl-mode-map "\t" 'avl-indent-command)
      (define-key avl-mode-map [(control return)] 'avl-insert-standard-comment)
      (define-key avl-mode-map [(control shift return)] 'avl-uninsert-comment)
      (define-key avl-mode-map [(shift tab)] 'avl-unindent-command)))


(defvar avl-mode-syntax-table nil
  "Syntax table in use in avl-mode buffers.")
(if (null avl-mode-syntax-table)
    (progn
      (setq avl-mode-syntax-table (make-syntax-table))
      (modify-syntax-entry ?\n ">" avl-mode-syntax-table)
      (modify-syntax-entry ?\f ">" avl-mode-syntax-table)
      (modify-syntax-entry ?\# "<" avl-mode-syntax-table)
      (modify-syntax-entry ?! "<" avl-mode-syntax-table)))


(defcustom avl-mode-hook nil
  "Hook run on entry to AVL mode."
  :type 'hook
  :group 'avl)


(defvar avl-standard-comments
  '(("^ *[Ss][Es][Cc][Tt][^ \n]*"  "#Xle     Yle     Zle     Chord   Ainc    [Nspan]   [Sspace]")
    ("^ *[Cc][Oo][Nn][Tt][^ \n]*"  "#name    gain    Xhinge  Xhvec   Yhvec   Zhvec     SgnDup" )
    ("^ *[Cc][Dd][Cc][Ll][^ \n]*"  "#CL1   CD1   CL2   CD2   CL3   CD3" )
    ("^ *[Ss][Uu][Rr][Ff][^\n]*\n[^\n]*"  "#Nchord  Cspace   [Nspan]  [Sspace]")
    ("^ *[Sc][Cc][Aa][Ll][^ \n]*"  "#Xscale   Yscale   Zscale")
    ("^ *[Tt][Rr][Aa][Nn][^ \n]*"  "#dX   dY   dZ")
    ("^ *[Bb][Oo][Dd][Yy][^ \n]*"  "#Nbody   Bspace")))


(defvar avl-keyword-list
  '(; Section headings
    "^ *[Ss][Uu][Rr][Ff][^ \n]*" 
    "^ *[Ii][Nn][Dd][Ee][^ \n]*" 
    "^ *[Yy][Dd][Uu][Pp][^ \n]*" 
    "^ *[Ss][Cc][Aa][Ll][^ \n]*" 
    "^ *[Tt][Rr][Aa][Nn][^ \n]*" 
    "^ *[Aa][Nn][Gg][Ll][^ \n]*" 
    "^ *[Ss][Es][Cc][Tt][^ \n]*" 
    "^ *[Nn][Aa][Cc][Aa][^ \n]*" 
    "^ *[Aa][Ii][Rr][Ff][^ \n]*" 
    "^ *[Cc][Ll][Aa][Ff][^ \n]*" 
    "^ *[Cc][Dd][Cc][Ll][^ \n]*" 
    "^ *[Aa][Ff][Ii][Ll][^ \n]*" 
    "^ *[Cc][Oo][Nn][Tt][^ \n]*" 
    "^ *[Bb][Oo][Dd][Yy][^ \n]*" 
    "^ *[Bb][Ff][Ii][Ll][^ \n]*" 
    "^ *[Dd][Ee][Ss][Ii][^ \n]*"))

(defvar avl-keyword-list-regexp
  (concat "\\(\\s-\\|^\\)\\("
	  (mapconcat 'identity avl-keyword-list "\\|")
	  "\\)\\(\\s-\\|$\\)"))


(defvar avl-last-point nil
  "The point before the last command")
(if (null avl-last-point)
    (make-variable-buffer-local 'avl-last-point))


(defvar avl-use-wide-fontify-buffer nil
  "Widen the fontify buffer for items that require multiline regexps")
(if (null avl-use-wide-fontify-buffer)
    (make-variable-buffer-local 'avl-use-wide-fontify-buffer))


(defconst avl-font-lock-keywords
  (list
   (cons "\\(?:[Ss][Uu][Rr][Ff].*\\|[Aa][Ff][Ii][Ll].*\\|[Bb][Oo][Dd][Yy]\\)\n\\(.*\\)$" 
	 (list 1 'font-lock-type-face))
   (cons "[Cc][Oo][Nn][Tt].*\n\\([a-zA-Z0-9]*\\) "
	 (list 1 'font-lock-type-face))
   (cons avl-keyword-list-regexp
	 'font-lock-keyword-face)
   (cons "^\\([a-zA-Z ]+\\)$"   ; for non SURFACE/AFILE/BODY/CONTROL strings
	 (list 1 'font-lock-type-face))
   )
  "Keywords to highlight for AVL.  See variable `font-lock-keywords'.")


	    

(defun avl-mode ()
  "Major mode for editing AVL code."
  (interactive)
  (kill-all-local-variables)
  
  (setq major-mode 'avl-mode)
  (setq mode-name "AVL")

  (set-syntax-table avl-mode-syntax-table)
  (use-local-map avl-mode-map)

  (setq indent-tabs-mode nil)     ; spaces not tabs!
  (setq tab-stop-list (numseq 0 100 avl-indent-level))

  (if (featurep 'emacs)
      (font-lock-add-keywords 'avl-mode avl-font-lock-keywords))

; this is necessary because font-lock defaults to "not immediately" which messes
; with the avl-pre/post-commands
  (set (make-local-variable 'font-lock-always-fontify-immediately) t) 

  (if (functionp 'add-local-hook) 
      (progn
	(add-local-hook 'pre-command-hook 'avl-pre-command) ;XEmacs
	(add-local-hook 'post-command-hook 'avl-post-command))
    (progn
      (add-hook 'pre-command-hook 'avl-pre-command t) ;Emacs
      (add-hook 'post-command-hook 'avl-post-command t)))

  (run-hooks 'avl-mode-hook)

  (font-lock-fontify-buffer)
)


(defun avl-run ()
  (write-file (file-name-nondirectory (buffer-file-name)))
  (if (get-buffer "AVL-RUN")
      (kill-buffer "AVL-RUN"))
  (shell-command (concat avl-executable-location 
			 " "
			 (file-name-nondirectory (buffer-file-name))
			 " &") 
		 "AVL-RUN"))
  


(defun avl-execute () 
  (interactive)
  (avl-run)
  (switch-to-buffer "AVL-RUN")
  (delete-other-windows))


(defun avl-send-command (cmd &optional buffer)
  (if buffer
      (let ((old-buffer (current-buffer)))
	(set-buffer buffer)
	(avl-send-command cmd)
	(set-buffer old-buffer)
	(delete-other-windows))
    (if cmd
	(let ((end (string-match "\n" cmd)))
	  (if end   ; send up to string match, recurse
	      (progn
		(goto-char (point-max))
		(insert (substring cmd 0 end))
		(comint-send-input)
		(avl-send-command (substring cmd (min (length cmd) (1+ end)))))
	    (progn   ; send remaing string
	      (goto-char (point-max))
	      (insert cmd)
	      (comint-send-input)))))))


(defun avl-plot-geometry () 
  (interactive)
  (avl-run)
  (avl-send-command "oper\ng\nk\n \n \nquit\n" "AVL-RUN"))


(defun avl-uninsert-comment ()
  "Removes the preceding full line comment"
  (interactive)
  (search-backward-regexp "^ *[#!]")
  (kill-entire-line))


(defun avl-insert-standard-comment ()
  "Inserts a comment describing the fields below a section heading"
  (interactive)
  (search-backward-section)
  (let ((final-point (point)))
    (dolist (standard-comment avl-standard-comments)
      (save-excursion
	(if (search-forward-regexp (car standard-comment) (point-at-eol 2) t)
	    (progn
	      (forward-line 1)
	      (save-excursion (insert (concat (second standard-comment) "\n")))
	      (avl-indent-region (cons '(point-at-bol) '(point-at-eol)))
	      (setq final-point (1+ (point-at-eol)))))))
    (goto-char final-point)))


(defun search-backward-section ()
  "Returns the point of and positions cursor at the beginning of the previous section heading."
  (if (search-backward-regexp avl-keyword-list-regexp nil t)
      (point)
    (goto-char (point-min))))


(defun avl-pre-command ()
  "Actions before a command is executed.  Used for font-lock on multiline regexps"
  (save-excursion 
    (setq avl-last-point (point))
    (setq avl-use-wide-fontify-buffer 
	  (or (is-face 'font-lock-type-face)
	      (progn 	      ; this second bit helps with backspace edits to the control surface string 
		(beginning-of-line)
		(is-face 'font-lock-type-face))))))


(defun avl-post-command ()
  "Actions after a command is executed.  Used for font-lock on multiline regexps"
  (save-excursion 
    (if avl-use-wide-fontify-buffer
	(avl-wide-fontify))))


(defun avl-wide-fontify ()
  (let ((beg (save-excursion
	       (if avl-last-point (goto-char avl-last-point))   ; goto point where there was a font-lock-type-face
	       (beginning-of-line)                              ; goto beginning of line
	       (search-backward-section)))
	(end (save-excursion (forward-line 1) (point))))
    (font-lock-fontify-region beg end t)))


(defun avl-unindent-command ()
  "Skips to previous indent point"
  (interactive)
  (avl-skip-field-backward))


(defun avl-indent-command ()
  "Indents text to appropriate tab stop or skips to next field"
  (interactive)
  (if (or (not (avl-in-comment))
	  (avl-is-tabable-comment))
      (progn
	(skip-chars-backward "^ \t\n")
	(let ((orig (point)))
	  (delete-horizontal-space)
	  (or (bolp) (tab-to-tab-stop))
	  (if (eq orig (point))
	      (progn
		(skip-chars-forward "^ \t\n")
		(avl-skip-field-forward)))))
    (progn 
      (skip-chars-forward "^\n")
      (forward-char))))


(defun avl-indent-region (region)
  "Indents a region where region is a cons of two functions identifying the beginning
and ending points"
  (save-excursion
    (goto-char (eval (car region)))
    (let ((last-point (point))
	  (last-last-point (point)))
      (avl-indent-command) 
      (avl-indent-command)
      (while (and (< (point) (eval (cdr region))) (> (point) last-last-point))
	(setq last-last-point last-point)
	(setq last-point (point))
	(avl-indent-command)
	(avl-indent-command))))
  (font-lock-fontify-region (eval (car region)) (eval (cdr region))))
  

(defun avl-indent-all () 
  "Indents the entire file"
  (interactive)
  (avl-indent-region (cons 'point-min 'point-max)))


(defun avl-skip-field-forward ()
  (interactive)
  (skip-face-forward 'font-lock-type-face)
  (search-forward-regexp "\\(\\s-\\|^\\)\\([^ \t\n]+\\)\\(\\s-\\|$\\)" nil t)
  (goto-char (match-beginning 2)))


(defun avl-skip-field-backward ()
  (interactive)
  (search-backward-regexp "\\(\\s-\\|^\\)\\([^ \t\n]+\\)\\(\\s-\\|$\\)")
  (goto-char (match-beginning 2))
  (if (save-excursion 
	(forward-char)
	(is-face 'font-lock-type-face))
      (progn
	(forward-char)
	(skip-face-backward 'font-lock-type-face)
	(forward-char))))


(defun avl-is-tabable-comment ()
  "A tabable comment is one where tabbing through it affects spacing.  These
are comments where the first character of a line is # or ! and the next character
is not a space"
  (save-excursion
    (beginning-of-line)
    (looking-at "[#!][^ ]")))


(defun avl-in-comment ()
  "Returns the point of the beginning of comment, nil if not in comment"
  (save-excursion
    (let ((orig (point)))
      (beginning-of-line)
      (search-forward-regexp "[#!]" orig t))))


(add-to-list 'auto-mode-alist '("\\.avl\\'" . avl-mode))




;;; Helper functions

(defun numseq (beg end incr)
  "Returns a sequence of numbers beginning at beg, increasing by incr, upto end"
  (if (< beg end)
      (cons beg (numseq (+ beg incr) end incr))))    

(defun is-face (face)
  "Returns true if the current point is equal to face"
  (eq (get-text-property (point) 'face) face))

(defun skip-face-forward (face)
  "Skips forward until at a different face"
  (skip-face 'forward-char face))

(defun skip-face-backward (face)
  "Skips backward until at a different face"
  (skip-face 'backward-char face))

(defun skip-face (cmd face)
  "Skips using cmd until at a different face"
  (let ((num-skipped 0))
    (while (is-face face)
      (funcall cmd)
      (setq num-skipped (1+ num-skipped)))
    num-skipped))


