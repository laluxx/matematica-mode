;;; matematica.el --- Major mode for editing matematica programming language -*- lexical-binding: t; -*-

;; Package metadata
(defvar matematica-mode-version "0.1"
  "Version of matematica-mode.")


;; TODO interactive beta reduction

(defvar true-face 'success
  "face for true in matematica-mode.")

(defvar x-face 'outline-5
  "face for x in matematica-mode.")

(defvar y-face 'outline-6
  "face for x in matematica-mode.")



(define-derived-mode matematica-mode prog-mode "matematica"
  "A major mode for editing matematica expressions."

  (setq font-lock-defaults '((("\\<\\(lambda\\|λ\\)\\>" . font-lock-keyword-face)
                              ("\\<true\\>" . true-face)
                              ("\\<false\\>" . font-lock-negation-char-face)
                              ("\\<b\\>" . font-lock-warning-face)
                              ("\\<x\\>" . x-face)
                              ("\\<y\\>" . y-face))))
  

  ;; Comment "¶" 
  (modify-syntax-entry ?¶ "<" (syntax-table))
  (modify-syntax-entry ?\n ">" (syntax-table)))


(defun insert-lambda ()
  "Inserts a lambda character at the cursor position if there is a space, the cursor is at the beginning of a line, or there is a dot to the left; otherwise, inserts a space."
  (interactive)
  (if (or (equal (char-before) ?\s)
          (bolp)  ; is the cursor at the beginning of a line ?
          (equal (char-before) ?.))
      (insert "λ")
    (insert ".")))

(defun insert-comment ()
  "Inserts a comment."
  (interactive)
  (insert "¶ "))

(defun insert-function-f ()
  "Inserts a stylized mathematical function 'f' character at the cursor position."
  (interactive)
  (insert "𝒇"))

(defun insert-composition ()
  "Inserts the composition character"
  (interactive)
  (insert "∘"))

(defun insert-arrow ()
  "Inserts '↱ ' if at the beginning of the line, otherwise inserts ' -> '."
  (interactive)
  (if (bolp)
      (insert "↱ ")
    (if (and (not (bolp)) (not (eq (char-before) ?\s)))
        (insert " -> ")
      (insert "-> "))))


;; TODO smarly insert composition
(defun smart-space ()
  "Insert '¶ ' or '↱ ' at the beginning of the line depending on the next line, or insert ' ' or ' -> ' if within a line.
If the line starts with '↱', insert ' -> ' after it."
  (interactive)
  (let ((next-line-contains-equals-sign
         (save-excursion
           (forward-line 1)
           (string-match-p "=" (thing-at-point 'line t))))
        (current-line-starts-with-arrow
         (save-excursion
           (beginning-of-line)
           (looking-at "^↱"))))
    (if (bolp)
        (if current-line-starts-with-arrow
            (progn
              (forward-char 1)
              (insert "-> "))
          (insert (if next-line-contains-equals-sign "↱ " "¶ ")))
      (if (and (save-excursion
                 (beginning-of-line)
                 (looking-at "^↱")))
          (insert " -> ")
        (insert " ")))))

(defun smart-return ()
  "Inserts a newline. If the current line starts with '¶', the new line will also start with '¶'."
  (interactive)
  (let ((current-line-starts-with-para
         (save-excursion
           (beginning-of-line)
           (looking-at "¶"))))
    (newline)
    (when current-line-starts-with-para
      (insert "¶ "))))


(define-key matematica-mode-map (kbd "RET") 'smart-return)
(define-key matematica-mode-map (kbd "SPC") 'smart-space)
(define-key matematica-mode-map (kbd "C-j") 'toggle-lambda-definition)
(define-key matematica-mode-map (kbd "C-k") 'expand-composition)
(define-key matematica-mode-map (kbd "C-l") 'insert-lambda)
(define-key matematica-mode-map (kbd "C-S-l") 'insert-composition)
(define-key matematica-mode-map (kbd "C-c C-c") 'insert-comment)
(define-key matematica-mode-map (kbd "C-c C-f") 'insert-function-f)
(define-key matematica-mode-map (kbd "C-c C-l") 'insert-arrow)


(add-to-list 'auto-mode-alist '("\\.lam\\'" . matematica-mode))


(defun parse-lambda-definitions ()
  "Parse the buffer for lambda calculus definitions, ignoring comments."
  (save-excursion
    (goto-char (point-min))
    (let (definitions)  ; Initialize the definitions list within the local scope.
      (while (re-search-forward "^\\([^=]+\\)\\s-*=\\s-*\\([^¶]+?\\)\\s-*\\(?:¶.*\\)?$" nil t)
        (let ((name (match-string-no-properties 1))
              (expr (match-string-no-properties 2)))
          (when (and name expr)  ; Ensure both name and expr are non-nil.
            (push (cons (string-trim name) (string-trim expr)) definitions))))
      definitions)))  ; Return the collected definitions.

(defun replace-word (old-text new-text)
  "Replace OLD-TEXT at point with NEW-TEXT, handling bounds correctly."
  (let ((bounds (bounds-of-thing-at-point 'symbol)))
    (when (and bounds new-text)  ; Check that new-text is not nil
      (goto-char (car bounds))
      (delete-region (car bounds) (cdr bounds))
      (insert new-text))))


(defun toggle-lambda-definition ()
  "Toggle between a shorthand and its full lambda calculus definition."
  (interactive)
  (let ((definitions (parse-lambda-definitions)))
    (save-excursion
      (skip-syntax-backward "w_")  ; Move back to include entire symbols.
      (let ((symbol (thing-at-point 'symbol t)))  ; Capture the full symbol.
        (if-let ((def (assoc symbol definitions)))  ; If symbol is a key in definitions.
            (replace-word symbol (cdr def))
          (dolist (pair definitions)  ; Otherwise, find where symbol is a value.
            (when (string= symbol (cdr pair))
              (replace-word symbol (car pair)))))))))


;; TODO Handle function arguments and curry
(defun expand-composition ()
  "Expand a composition around the point."
  (interactive)
  (let ((composition-regexp "\\([^∘\s]+\\)\\s-*∘\\s-*\\([^∘\s]+\\)")
        expansion found)
    (save-excursion
      (beginning-of-line)
      (while (and (not found) (re-search-forward composition-regexp (line-end-position) t))
        (let ((func1 (match-string 1))
              (func2 (match-string 2))
              (match-start (match-beginning 0))
              (match-end (match-end 0)))
          (setq expansion (format "%s (%s a b)" func1 func2))
          (goto-char match-start)
          (delete-region match-start match-end)
          (insert expansion)
          (setq found t)))  ; Mark that we found and expanded a composition
      (unless found
        (message "No composition pattern found near point!")))))



;; TODO IMPORTANT
;; (defun insert-char-or-docstring (char)
;;   "Insert CHAR or wrap CHAR in double quotes if there is
;;  an `=` character on the line before the point and no existing double quotes on the line."
;;   (interactive "cInsert character: ")
;;   (let ((line-contains-equals (save-excursion
;;                                 (beginning-of-line)
;;                                 (search-backward "=" (line-beginning-position 0) t)))
;;         (line-contains-quotes (save-excursion
;;                                 (beginning-of-line)
;;                                 (search-forward "\"" (line-end-position) t))))
;;     (if (and line-contains-equals (not line-contains-quotes))
;;         (progn
;;           (insert (format "\"%c\"" char))
;;           (backward-char 1))  ; Move cursor back inside the quotes
;;       (insert char))))

;; (defun lambda-calculus-mode-hook ()
;;   "Hook to modify key bindings in matematica-mode."
;;   (let ((map (m0ake-sparse-keymap)))
;;     ;; Bind printable characters to our custom function
;;     (dolist (char (number-sequence 32 126)) ; ASCII printable characters
;;       (define-key map (char-to-string char)
;;                   `(lambda () (interactive) (insert-char-or-docstring ,char))))
;;     (use-local-map (append map matematica-mode-map))))

;; (add-hook 'lambda-calculus-mode-hook 'lambda-calculus-mode-hook)



(provide 'matematica-mode)
;;; matematica-mode.el ends here


