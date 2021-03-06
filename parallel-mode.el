;;; parallel-mode.el --- Read Text With Visible Connections  -*- lexical-binding: t; -*-

;; Copyright (C) 2021  i-am

;; Author: i-am <i@fbsd>
;; Keywords: hypermedia, faces

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; A way of viewing EDL files to show visible connections
;;
;;; Code:

(require 'shr)
(require 'eww)
(require 'url)
(require 'org)

(defface xanalink
  '((t :box (:line-width 3 :color "tomato")))
  "Face used for link in parallel-mode")
(defcustom parallel-url-regexp
  "\\b\\(\\(www\\.\\|\\(s?https?\\|ftp\\|file\\|gopher\\|nntp\\|news\\|telnet\\|wais\\|mailto\\|info\\):\\)\\(//[-a-z0-9_.]+:[0-9]*\\)?\\(?:[-a-z0-9_=#$@~%&*+\\/[:word:]!?:;.,]+([-a-z0-9_=#$@~%&*+\\/[:word:]!?:;.,]+[-a-z0-9_=#$@~%&*+\\/[:word:]]*)\\(?:[-a-z0-9_=#$@~%&*+\\/[:word:]!?:;.,]+[-a-z0-9_=#$@~%&*+\\/[:word:]]\\)?\\|[-a-z0-9_=#$@~%&*+\\/[:word:]!?:;.,]+[-a-z0-9_=#$@~%&*+\\/[:word:]]\\)\\)"
  "Regular expression that matches URLS.")

(defcustom parallel-url-regexp-span
  (concat parallel-url-regexp ",start=\\([0-9]*\\)?,length=\\([0-9]*\\)?")
  "Regular expression that matches URLS with span.  
This is `match-string' data
`(match-string 5)' matches NUM after 'start='  
`(match-string 6)' matches NUM after 'length='")

(defvar edl-highlights
  '(("^span:" . font-lock-doc-face)
    ("^xanalink:" . font-lock-keyword-face)
    (",start\\|,length" . font-lock-constant-face)
    ("#.*$" . font-lock-comment-face)))

(defun eww-parse-content (url &optional to-buffer) 
  "Use `url-retrieve' then `eww-render' and parse to a hidden buffer called 'URL#output'
 then append region from POINT-START to POINT-END to existing TO-BUFFER or create a new buffer"
  (let ((url-mime-accept-string eww-accept-content-types)
	(buf (or to-buffer
		 (concat " " url "#output"))))
    (url-retrieve (eww--dwim-expand-url url) 'eww-render
       		  (list (eww--dwim-expand-url url) nil (get-buffer-create buf)))))

(defun follow-xanalink (target point)
  (save-current-buffer
    (switch-to-buffer-other-window target)
    (goto-char point)))
  
;;;###autoload
(define-derived-mode edl-mode fundamental-mode "EDL"
  "Major mode for reading EDL format"
  (setq font-lock-defaults '(edl-highlights)))

(defun parallel-make-sourcedoc (buffer)
  "Render URLS on the 'span: ' region on their own hidden '#output' buffer then
insert their content to BUFFER"
  (with-current-buffer (get-buffer-create buffer)
    (erase-buffer))
  (while (progn
	   (re-search-forward parallel-url-regexp-span nil t)
	   (save-match-data
	     (eww-parse-content (format "%s" (match-string 1)))
     	     (forward-line 1))
	   (let* ((url-buf (get-buffer (concat " " (match-string 1) "#output")))
		  (desired-beg (string-to-number (match-string 5)))
		  (desired-leng (string-to-number (match-string 6)))
		  (desired-end (+ desired-beg desired-leng))
		  (valid-region (buffer-size url-buf))
		  ;; Check if desired-beg is in range of the size of BUFFER,
		  ;; if not, fallbacks on the beginning of BUFFER.
		  (region-beg (if (< desired-beg valid-region)
				  desired-beg
				(point-min)))
		  ;; Check if desired-end is in range of the size of BUFFER,
		  ;; if not, fallbacks on the end of BUFFER.
		  (region-end (if (< (- desired-end 1) valid-region)
				  desired-end
				(+ 1 valid-region))))
	     (with-current-buffer (get-buffer-create buffer)
	       (insert "\n")
	       (insert-buffer-substring url-buf region-beg region-end)
	       (fill-paragraph (point-min) (point-max))
	       (org-mode))
	     (with-current-buffer url-buf
	       (setq buffer-read-only t)))
	     ;; (with-current-buffer url-buf
     	     ;;   (make-text-button region-beg region-end)))
    	   ;; return nil when point reached the end of buffer
	   ;; or when there was "xanalink: " under point.
	   ;; In effect, stops the `while' function
	   (and (not (looking-at-p "xanalink: "))
		(not (eq (point) (point-max)))))))

(defun parallel ()
  "Start `parallel' session."
  (interactive)
  (cond ((eq major-mode 'edl-mode)
	 (goto-char (point-min))
	 (parallel-make-sourcedoc "doc.org"))
	(t (user-error "This is not an EDL file."))))

(provide 'parallel-mode.el)
;;; parallel.el ends here
