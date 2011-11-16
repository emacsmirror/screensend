;;; screensend.el --- Send blocks of text from emacs to screen or tmux sessions.

;; Copyright (C) 2010-2011 Ben Booth
;; Author: Ben Booth <benwbooth@gmail.com>
;; Maintainer: Ben Booth <benwbooth@gmail.com>
;; Created: 2011-11-16
;; Version: 1.0.0
;; Keywords: lisp, screen, tmux, send, terminal
;; EmacsWiki: http://www.emacswiki.org/emacs/ScreenSend
;; Github: https://github.com/benbooth5/screensend.el 
;; URL: https://raw.github.com/benbooth5/screensend.el/master/screensend.el 

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
;;;
;;; screensend.el
;;; -------------
;;; 
;;; Simple Emacs script to allow you to send selected blocks of text to a
;;; running screen or tmux session. This is useful for sending text to interactive
;;; programs like clojure, psql, etc. in cases where the built-in term-mode is
;;; too slow.
;;; 
;;; # Usage:
;;; 
;;;     ; for screen
;;;     (require 'screensend)
;;;     (global-set-key [f4] 'screen-select)
;;;     (global-set-key [f5] 'screen-send)
;;;   
;;;     ; for tmux
;;;     (require 'screensend)
;;;     (global-set-key [f4] 'tmux-select)
;;;     (global-set-key [f5] 'tmux-send)
;;; 
;;; Start a screen session:
;;; 
;;;     screen -S mysession
;;; 
;;; Or if you're using tmux:
;;;   
;;;     tmux new-session -s mysession
;;; 
;;; Now press F4 and select "mysession"
;;; 
;;; Now either select some text or place the cursor in between a text paragraph 
;;; and hit F5.
;;; 
;;; The selected text is transmitted to the screen session.

;;; Code:

(defun screen-list ()
  "Get list of active screen sessions."
  (let ((output (with-output-to-string
                  (with-current-buffer standard-output
                    (call-process "screen" nil '(t nil) nil "-list"))))
        (re "^\\s-+\\(\\S-+\\)")
        (sessions '()))
    (when (string-match re output)
      (push (match-string 1 output) sessions))
    (while (string-match re output (match-end 1))
      (push (match-string 1 output) sessions))
    sessions))
  
;;;###autoload
(defun screen-select (session)
  "Select a screen session"
  (interactive
   (list (completing-read "Select a screen session:" (screen-list))))
  (setq screen-session session))

;;;###autoload
(defun screen-send ()
  "Send selected region or currently-surrounding blank line-separated \
block of text to the dedicated multi-term buffer"
  (interactive)
  (when (not screen-session)
    (call-interactively 'screen-select))
  (let ((selected (progn 
                    (when (equal mark-active nil) 
                      (mark-paragraph))
                    (concat (buffer-substring (mark) (point)) "\n")))
        (tmpfile (make-temp-file "screen-send.")))
    (with-temp-file tmpfile
      (insert selected))
    (call-process "screen" nil nil nil
                  "-S" screen-session
                  "-X" "eval"
                  "msgminwait 0"
                  "msgwait 0"
                  (concat "readbuf " (shell-quote-argument tmpfile))
                  "paste ."
                  "msgwait 5"
                  "msgminwait 1")
    (delete-file tmpfile)
    (deactivate-mark)))

(defun tmux-list ()
  "Get list of active tmux sessions."
  (let ((output (with-output-to-string
                  (with-current-buffer standard-output
                    (call-process "tmux" nil '(t nil) nil "list-sessions"))))
        (re "^\\([^:]*\\):")
        (sessions '()))
    (when (string-match re output)
      (push (match-string 1 output) sessions))
    (while (string-match re output (match-end 1))
      (push (match-string 1 output) sessions))
    sessions))
  
;;;###autoload
(defun tmux-select (session)
  "Select a tmux session."
  (interactive
   (list (completing-read "Select a tmux session:" (tmux-list))))
  (setq tmux-session session))

;;;###autoload
(defun tmux-send ()
  "Send selected region or currently-surrounding blank line-separated \
block of text to the selected tmux session."
  (interactive)
  (when (not tmux-session)
    (call-interactively 'tmux-select))
  (let ((selected (progn 
                    (when (equal mark-active nil) 
                      (mark-paragraph))
                    (concat (buffer-substring (mark) (point)) "\n")))
        (tmpfile (make-temp-file "tmux-send.")))
    (with-temp-file tmpfile
      (insert selected))
    (call-process "tmux" nil nil nil
                  "load-buffer" tmpfile ";"
                  "paste-buffer" "-t" tmux-session ";")
    (delete-file tmpfile)
    (deactivate-mark)))

(provide 'screensend)

;;; screensend.el ends here
