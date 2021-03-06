;;; fi-config.el --- Additional configuration helpers for fi-emacs -*- lexical-binding: t; -*-

;; Author: Leo Gaskin <leo.gaskin@brg-feldkirchen.at>
;; Created: 21 June 2019
;; Homepage: https://github.com/leotaku/fi-emacs
;; Keywords: fi-emacs, configuration, lisp
;; Package-Version: 0.1.0
;; Package-Requires: ((emacs "25.1"))

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;; 

;;; Code:

(defmacro fi-csetq (sym value)
  "Set the default value of symbol named SYM, respecting the custom-set property.
Taken from the following blogpost: `https://oremacs.com/2015/01/17/setting-up-ediff/'."
  `(fi-cset ',sym ,value))

(defun fi-cset (symbol value)
  "Set the default value of SYMBOL, respecting the custom-set property.
Taken from the following blogpost: `https://oremacs.com/2015/01/17/setting-up-ediff/'."
  (funcall (or (get symbol 'custom-set)
               'set-default)
           symbol value))

(defmacro fi-configure-gui (&rest body)
  "Evaluate BODY whenever the Emacs GUI is ready.
If the GUI is already running or has previously been started, execute BODY immediately."
  `(if (and (display-graphic-p) (window-system))
       (progn ,@body)
     (add-hook 'focus-in-hook 'fi--run-at-gui)
     (push (lambda () ,@body) fi--run-at-gui-body)))

(defvar fi--run-at-gui-body nil)
(defun fi--run-at-gui ()
  (when (and (display-graphic-p) (window-system))
    (remove-hook 'focus-in-hook 'fi--run-at-gui)
    (run-hooks 'fi--run-at-gui-body)
    (setq fi--run-at-gui-body nil)))

(provide 'fi-config)

;;; fi-config.el ends here
