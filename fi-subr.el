;;; fi-subr --- misc subroutines for use in fi-emacs -*- lexical-binding: t; -*-

;; Author: Leo Gaskin <leo.gaskin@brg-feldkirchen.at>
;; Created: 21 June 2019
;; Homepage: https://github.com/leotaku/fi-emacs
;; Keywords: fi, fi-emacs
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

;;; Commentary

;;; Code

(require 'seq)

(defun fi-simulate-key (key &optional keymap)
  "Send fake keypresses for `key' in `keymap'."
  (let ((overriding-local-map (or keymap global-map)))
    (setq unread-command-events
          (nconc
           (mapcar (lambda (ev) (cons t ev))
                   (listify-key-sequence key))
           unread-command-events))))

(defun fi-insert-at (list n item)
  "Return `list' with `item' inserted at position `n'."
  (nconc (seq-take list n) (cons item (seq-drop list n))))

(defun fi-insert-after (list after item)
  "Return `list' with `item' inserted right after `after'."
  (let ((n (1+ (seq-position list after))))
    (if n
        (fi-insert-at list n item)
      list)))

(defun fi-insert-before (list before item)
  "Return `list' with `item' inserted right before `before'."
  (let ((n (seq-position list before)))
    (if n
        (fi-insert-at list n item)
      list)))

(provide 'fi-subr)