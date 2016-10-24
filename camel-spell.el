(defvar-local camel-spell-sub-word-list '()
  "A buffer-local stack to hold parts of a camel cased word to check.
For example, the word \"myCamelCase\" should populate the list like so:

'((\"my\" 0 2) (\"Camel\" 2 7) (\"Case\" 7 11)))

The format of the entries of the stack match the output of
`ispell-get-word'.")

(defun camel-spell-sub-word-list-has-entries-p ()
  "Returns t if the local `camel-spell-sub-word-list' has entries."
  (not (eq camel-spell-sub-word-list nil)))

(defun camel-spell-pop-sub-word-list ()
  "Pops and returns the first element from `camel-spell-sub-word-list'.
If `camel-spell-sub-word-list' is nil, then return nil."
  (pop camel-spell-sub-word-list))

;; Helper function that parses the output of ispell-get-word.  If the word from
;; ispell-get-word is a camelCasedWord, then break up the result into [camel,
;; Cased, Word].  Adjust the start and end locations accordingly.  Return the
;; first entry and save the other two entries in the word queue.

(defun camel-spell-break-string (str)
  "FooBar => '(\"foo\" \"Bar\")"
  (let ((case-fold-search nil))
    (setq str (replace-regexp-in-string
               "\\([a-z0-9]\\)\\([A-Z]\\)" "\\1 \\2" str))
    (split-string str)))

(defun camel-spell-break-camel-case-results (word-info)
  "Breaks WORD-INFO into separate WORD-INFOs on camel casing.
WORD-INFO is a list of '(\"string\" start-point end-point).  If
the word in WORD-INFO is not camel-cased, then return a list with
one word info."
  (when (car-safe word-info)
    (let* ((original-string (nth 0 word-info))
           (start-point (nth 1 word-info))
           (case-fold-search nil)
           (sub-words (camel-spell-break-string original-string))
           result)
      (dolist (word sub-words result)
        (setq result (cons (list word start-point (+ start-point (length word)))
                           result))
        (setq start-point (+ start-point (length word)))))))

(defun camel-spell-get-word-advisor (orig-ispell-get-words &rest args)
  "Advises `ispell-get-word' to correctly spell check camel cased words."
  (if (camel-spell-sub-word-list-has-entries-p)
      (camel-spell-pop-sub-word-list)
    
    (let* ((word-info (apply orig-ispell-get-words args))
           (camel-infos (camel-spell-break-camel-case-results word-info)))
      
      (setq camel-spell-sub-word-list
            (append camel-spell-sub-word-list (cdr-safe camel-infos)))
      (car camel-infos))))

(advice-add #'flyspell-get-word :around #'camel-spell-get-word-advisor)

