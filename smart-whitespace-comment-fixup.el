;;; smart-whitespace-comment-fixup.el --- Enables advice around yanking/killing lines that auto-indents and formats properly

;; Copyright (C) 2013 Nathaniel Flath <nflath@gmail.com>

;; Author: Nathaniel Flath <nflath@gmail.com>
;; URL: http://github.com/nflath/smart-whitespace-comment-fixup
;; Version: 1.0

;; This file is not part of GNU Emacs.

;;; Commentary:

;; This file advices yank, yank-pop, kill-line, and indent-for-tab-command to fixup
;; whitespace and comment characters.  Features include:
;;  - yank and yank-pop indent whatever you pasted
;;  - Kill-line calls fixup-whitespace if you kill a line
;;  - If you kill a \n that causes two comment lines to join, the comment characters
;;    will be stripped from the middle of the newly-joined lines
;;  - Indenting will align comments after code blocks

;;; Installation

;; To use this mode, just put the following in your .emacs file:
;; (require 'smart-whitespace-comment-fixup)

;;; License:

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Code:


;; Create a prog-mode variable so we can check if we are in a programming mode
;; (Why doesn't this exist already?)
(setq prog-mode nil)
(make-variable-buffer-local 'prog-mode)
(add-hook 'prog-mode-hxook (lambda () (setq prog-mode t)))

;;These advices cause copy-pasted code to be properly indented.
(defadvice yank (after indent-region activate)
  (when prog-mode
    (let ((mark-even-if-inactive t))
      (indent-region (region-beginning) (region-end) nil))))

(defadvice yank-pop (after indent-region activate)
  (when prog-mode
    (let ((mark-even-if-inactive transient-mark-mode))
      (indent-region (region-beginning) (region-end) nil))))

(defadvice kill-line (after fixup-whitespace activate)
  "Call fixup whitespace after killing line."
  (when (not (eq major-mode 'python-mode))
    (if (not (looking-at "$"))
        (fixup-whitespace))
    (if (not (looking-at "$"))
        (fixup-whitespace))
    (if (and (not (eq major-mode 'shell-mode))
             (not (looking-at "^$"))
             (not (eq indent-line-function 'indent-relative)))
        (funcall indent-line-function))))

(defun string-trim (str)
  "Chomp leading and tailing whitespace from STR."
  (let ((s (if (symbolp str) (symbol-name str) str)))
    (replace-regexp-in-string "\\(^[[:space:]\n]*\\|[[:space:]\n]*$\\)" "" s)))

(defadvice kill-line (after fixup-comments activate)
  "Don't leave comment characters after killing a line."
  (when prog-mode
    (let* ((pt (point))
           (comment-at-start (progn (back-to-indentation) (looking-at (concat "[ \t]*" (regexp-opt (list (string-trim comment-start)))))))
           (only (eq (point) pt)))
      (goto-char pt)
      (let ((start (point)))
        (when (and comment-start
                 comment-at-start
                 (looking-at (concat "[ \t]*" (regexp-opt (list (string-trim comment-start))))))
          (let ((len (- (match-end 0) (match-beginning 0))))
            (back-to-indentation)
            (when (and (looking-at (regexp-opt (list (string-trim comment-start))))
                     (not (= (point) start)))
              (goto-char start)
              (delete-char len))))))))

(defadvice indent-for-tab-command (after indent-comments activate)
  ;;; Aligns comments when indenting, even if they are after lines of code
  (save-excursion
    (beginning-of-line)
    (when (not (looking-at (concat "\\(\\s-*\\)" comment-start)))
      (end-of-line)
      (let ((end (point)))
        (while (and (line-matches comment-start) (= 0 (forward-line -1))))
        ;; Move backwards until a line that does not contain a comment
        (forward-line)
        (beginning-of-line)
        (if (not (looking-at (concat "\\(\\s-*\\)" comment-start))) (forward-line -1))
        (end-of-line)
        ;; We don't want to indent comments that start at beginning of line to match
        ;; comments after lines of code
        (let ((start (point)))
          (forward-line)
          (beginning-of-line)
          (let ((saved (point)))
            (re-search-forward (concat "\\(\\s-*\\)" comment-start) nil t)
            (if (= (point) (+ (length comment-start) saved))
                (align-regexp start end (concat "\\(\\s-*\\)" comment-start "+") 1 0 t)
              (align-regexp start end (concat "\\(\\s-*\\)" comment-start "+") 1 1 t))))))))

(provide 'smart-whitespace-comment-fixup)
;;; smart-whitespace-comment-fixup.el ends here
