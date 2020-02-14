;;; sd.el --- Unit-script system for fastiter -*- lexical-binding: t -*-

;; Author: Leo Gaskin <leo.gaskin@brg-feldkirchen.at>
;; Created: 19 July 2019
;; Homepage: https://github.com/leotaku/fi-emacs
;; Keywords: fi-emacs, configuration, extension, lisp
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

;; TODO: Make API better
;; TODO: proper format for success/failure
;; TODO: non-numerical returns from `sd--reach-unit'

(require 'gv)

;;; Code:

(defconst sd-startup-list '()
  "List used for unit description lookup.
Every entry is a unit object, see `sd-make-unit' for documentation.")

(defconst sd--in-unit-setup-phase t
  "If true, new units may be defined.")

(defsubst sd-make-unit (name)
  "Simplified constructor for `sd-unit' objects.

SD-UNIT FORMAT:
  \(NAME state form . dependencies)
WHERE:
  \(symbolp NAME)
  \(or (memq state '(-1 0 1 2)) (listp state))
  \(listp form)
  \(and (listp dependencies) (all (mapcar 'symbolp dependencies)))"
  (cons name (cons -1 (cons nil nil))))

(defsubst sd-unit-name (unit)
  "Access slot UNIT of UNIT object.
This function acts as a generalized variable."
  (car unit))
(defsubst sd-unit-state (unit)
  "Access slot STATE of UNIT object.
This function acts as a generalized variable."
  (cadr unit))
(defsubst sd-unit-form (unit)
  "Access slot FORM of UNIT object.
This function acts as a generalized variable."
  (caddr unit))
(defsubst sd-unit-dependencies (unit)
  "Access slot DEPENDENCIES of UNIT object.
This function acts as a generalized variable."
  (cdddr unit))

(gv-define-setter sd-unit-name (value item)
  `(setf (car ,item) ,value))
(gv-define-setter sd-unit-state (value item)
  `(setf (cadr ,item) ,value))
(gv-define-setter sd-unit-form (value item)
  `(setf (caddr ,item) ,value))
(gv-define-setter sd-unit-dependencies (value item)
  `(setf (cdddr ,item) ,value))

(defun sd-register-unit (name &optional form requires wanted-by)
  "Define a UNIT named NAME with execution form FORM, requiring
the units REQUIRES, wanted by the units WANTED-BY.

This function will error if other units with the same name have
been defined or any units have already been started when it is
run."
  (unless (and (symbolp name)
               (listp requires)
               (listp form)
               (listp wanted-by))
    (error "Wrong type argument to register-unit"))
  (unless sd--in-unit-setup-phase
    (error "Registering new units after a target has been reached is illegal"))
  (let ((unit (assq name sd-startup-list)))
    ;; construct new unit
    (if (null unit)
        (setq unit (sd-make-unit name))
      (unless (eq (sd-unit-state unit) -1)
        (error "An unit with the same name has already been registered")))
    ;; set unit fields
    (setf (sd-unit-state unit) 0)
    (setf (sd-unit-dependencies unit)
          (nconc requires
                 (sd-unit-dependencies unit)))
    (setf (sd-unit-form unit) form)
    (setf (sd-unit-state unit) 1)
    (sd--destructive-set-unit unit)
    ;; handle wanted-by
    (dolist (wants-name wanted-by)
      (sd--add-unit-dependency wants-name name))))

(defun sd--reach-unit (name)
  (setq sd--in-unit-setup-phase nil)
  (let* ((unit (assq name sd-startup-list))
         (state (if unit (sd-unit-state unit) 0)))
    (cond
     ;; case: unit registered
     ((eq state 1)
      ;; protect against recursion
      ;; possible performance loss
      (setf (sd-unit-state unit) (list name 'recursive))
      (sd--destructive-set-unit unit)
      (let (errors rec-error)
        (dolist (dep (sd-unit-dependencies unit))
          (let ((err (sd--reach-unit dep)))
            (when (listp err)
              (push err errors))))
        ;; REMOVE: ad-hoc feature integration
        ;; (require name nil t)
        (setf (sd-unit-state unit)
              (if errors
                  (cons name (cons 'dependencies errors))
                (let ((eval-error (condition-case-unless-debug err
                                      (prog1 nil
                                        (eval (sd-unit-form unit) nil))
                                    (error err))))
                  (if eval-error
                      (cons name (cons 'eval eval-error))
                    2)))))
      (sd--destructive-set-unit unit)
      (sd-unit-state unit))
     ;; case: unit already reached
     ((eq state 2)
      3)
     ;; case: unit already errored
     ((listp state)
      (if (eq 'recursive (cadr state))
          state
        4))
     ;; case: unit not existent or not registered
     ;; this means either \(null unit) or (<= state 0)
     (t
      (unless unit
        (setq unit (sd-make-unit name)))
      (let* ((str (symbol-name name))
             (is-special (eq (compare-strings
                              str 0 1
                              "." 0 1)
                             t)))
        ;; subcase: unit is a special feature (leading dot)
        (if is-special
            (let ((req-err
                   (condition-case-unless-debug err
                       (prog1 nil
                         (require (intern (substring str 1)) nil))
                     (error err))))
              (if (null req-err)
                  ;; succeded require
                  (progn
                    (setf (sd-unit-state unit) 1)
                    (sd--destructive-set-unit unit)
                    (sd--reach-unit name))
                ;; failed require
                (setf (sd-unit-state unit)
                      (list name 'eval (format "Error during require: %s" req-err)))
                (sd--destructive-set-unit unit)
                (sd-unit-state unit)))
          ;; not special
          (setf (sd-unit-state unit) (list name 'noexist))
          (sd--destructive-set-unit unit)
          (sd-unit-state unit)))))))

(defsubst sd--add-unit-dependency (name dep-name)
  (let ((unit (assq name sd-startup-list)))
    (when (null unit)
      (setq unit (sd-make-unit name)))
    (setf (sd-unit-dependencies unit)
          (nconc (sd-unit-dependencies unit)
                 (list dep-name)))
    (sd--destructive-set-unit unit)))

(defsubst sd--destructive-set-unit (unit)
  (setq sd-startup-list (assq-delete-all (sd-unit-name unit) sd-startup-list))
  (push unit sd-startup-list))

(defun sd--format-error (state &optional prefix)
  "Format the error STATE returned by `sd--reach-unit' in an user-readable manner.
Optional argument PREFIX should be used to describe the recursion
level at which this error has occured."
  (let ((unit (car state))
        (reason (cadr state))
        (context (cddr state))
        (prefix (or prefix 0)))
    (cond
     ((eq reason 'eval)
      (format "%s:`%s' failed because an error occurred: %s" prefix unit context))
     ((eq reason 'noexist)
      (format "%s:`%s' failed because it does not exist." prefix unit))
     ((eq reason 'recursive)
      (format "%s:`%s' failed because it depends on itself." prefix unit))
     ((eq reason 'dependencies)
      (concat (format "%s:`%s' failed because:\n" prefix unit)
              (mapconcat
               (lambda (state)
                 (sd--format-error state (1+ prefix)))
               context "\n"))))))

(defun sd-reach-target (name)
  "Manually reach the unit named NAME.

Returns an user-readable error when the unit has errored, t if it
has newly succeded and nil if it has succeded or errored before."
  (let ((state (sd--reach-unit name)))
    (cond
     ;; case: unit newly errored
     ((listp state)
      (sd--format-error state))
     ((eq state 2)
      t)
     ;; case: unit already succeded/errored
     ((or (eq state 3)
          (eq state 4))
      nil)
     ((t
       (error "This should be unreachable: %s" state))))))

(defun sd--generate-unit-graph (name)
  (let* ((unit (assoc name sd-startup-list))
         (deps (and unit (sd-unit-dependencies unit)))
         (graph))
    (dolist (name deps)
      (setq graph (append graph (sd--generate-unit-graph name))))
    (if graph
        (cons name (cons '| graph))
      (cons name nil))))

(defun sd-poll-target (target delay &optional silent inhibit)
  (let* ((timer (timer-create))
         (poll (sd--poll-setup-polling
                target silent inhibit-message (lambda () (cancel-timer timer)))))
    (timer-set-time timer delay delay)
    (timer-set-function
     timer poll)
    (timer-activate timer)))

(defun sd--poll-setup-polling (target &optional silent inhibit stop-callback)
  (let* ((graph (nreverse (sd--generate-unit-graph target)))
         (timer (timer-create))
         (state 2)
         (skip nil)
         (length (length graph))
         (current 0))
    (lambda ()
      (let ((name (car graph)))
        (setq graph (cdr graph))
        (setq current (1+ current))
        (cond
         ((null name)
          (when stop-callback
            (funcall stop-callback)))
         ((and skip (listp state))
          (let ((unit (assq name sd-startup-list)))
            (setf (sd-unit-state unit) (list name 'dependencies nil))
            (setq state (sd-unit-state unit))
            (setq skip nil)))
         ((eq name '|)
          (setq skip t))
         (t
          (setq skip nil)
          (let ((new-state (let ((inhibit-message inhibit))
                             (sd--reach-only-unit name))))
            (when (listp new-state)
              (setq state (list state new-state))))
          (unless silent
            (message "Polled %s (%s/%s)" name current length))))))))

(defun sd--reach-only-unit (name)
  (let ((unit (assq name sd-startup-list)))
    (if (not unit)
        (list name 'noexist)
      (let ((form (sd-unit-form unit))
            (old-state (sd-unit-state unit)))
        (cond
         ;; available
         ((eq old-state 1)
          (let ((eval-error (condition-case-unless-debug err
                                (prog1 nil
                                  (eval (sd-unit-form unit) nil))
                              (error err))))
            (setf (sd-unit-state unit)
                  (if eval-error
                      (cons name (cons 'eval eval-error))
                    2))
            (sd--destructive-set-unit unit)
            (sd-unit-state unit)))
         ;; unavailable
         ((or (eq old-state -1) (eq old-state 0))
          (setf (sd-unit-state unit)
                (list name 'noexist))
          (sd--destructive-set-unit unit)
          (sd-unit-state unit))
         ;; done
         ((eq old-state 2)
          2)
         ;; errored
         ((listp old-state)
          old-state))))))

(provide 'sd)

;;; sd.el ends here
