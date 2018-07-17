;;; eaf.el --- Emacs application framework

;; Filename: eaf.el
;; Description: Emacs application framework
;; Author: Andy Stewart <lazycat.manatee@gmail.com>
;; Maintainer: Andy Stewart <lazycat.manatee@gmail.com>
;; Copyright (C) 2018, Andy Stewart, all rights reserved.
;; Created: 2018-06-15 14:10:12
;; Version: 0.1
;; Last-Updated: 2018-06-15 14:10:12
;;           By: Andy Stewart
;; URL: http://www.emacswiki.org/emacs/download/eaf.el
;; Keywords:
;; Compatibility: GNU Emacs 27.0.50
;;
;; Features that might be required by this library:
;;
;;
;;

;;; This file is NOT part of GNU Emacs

;;; License
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:
;;
;; Emacs application framework
;;

;;; Installation:
;;
;; Put eaf.el to your load-path.
;; The load-path is usually ~/elisp/.
;; It's set in your ~/.emacs like this:
;; (add-to-list 'load-path (expand-file-name "~/elisp"))
;;
;; And the following to your ~/.emacs startup file.
;;
;; (require 'eaf)
;;
;; No need more.

;;; Customize:
;;
;;
;;
;; All of the above can customize by:
;;      M-x customize-group RET eaf RET
;;

;;; Change log:
;;
;; 2018/06/15
;;      * First released.
;;

;;; Acknowledgements:
;;
;;
;;

;;; TODO
;;
;;
;;

;;; Require
(require 'dbus)

;;; Code:
(defcustom eaf-mode-hook '()
  "Eaf mode hook."
  :type 'hook
  :group 'eaf-mode)

(defvar eaf-mode-map
  (let ((map (make-sparse-keymap)))
    map)
  "Keymap used by `eaf-mode'.")

(define-derived-mode eaf-mode text-mode "Eaf"
  (interactive)
  (kill-all-local-variables)
  (setq major-mode 'eaf-mode)
  (setq mode-name "EAF")
  ;; Split window combinations proportionally.
  (setq window-combination-resize t)    ;
  (set (make-local-variable 'buffer-id) (eaf-generate-id))
  (use-local-map eaf-mode-map)
  (run-hooks 'eaf-mode-hook))

(defvar eaf-python-file (expand-file-name "eaf.py" (file-name-directory load-file-name)))

(defvar eaf-process nil)

(defvar eaf-first-start-url nil)

(defvar eaf-first-start-app-name nil)

(defvar eaf-title-length 30)

(defvar eaf-org-file-list '())
(defvar eaf-org-killed-file-list '())

(defcustom eaf-name "*eaf*"
  "Name of eaf buffer."
  :type 'string
  :group 'eaf)

(defun eaf-call (method &rest args)
  (apply 'dbus-call-method
         :session                   ; use the session (not system) bus
         "com.lazycat.eaf"          ; service name
         "/com/lazycat/eaf"         ; path name
         "com.lazycat.eaf"          ; interface name
         method args))

(defun eaf-get-emacs-xid ()
  (frame-parameter nil 'window-id))

(defun eaf-start-process ()
  (interactive)
  (if (process-live-p eaf-process)
      (message "EAF process has started.")
    (setq eaf-process
          (apply 'start-process
                 eaf-name
                 eaf-name
                 "python3" (append (list eaf-python-file (eaf-get-emacs-xid)) (eaf-get-render-size))
                 ))
    (set-process-query-on-exit-flag eaf-process nil)
    (set-process-sentinel
     eaf-process
     #'(lambda (process event)
         (message (format "%s %s" process event))
         ))
    (message "EAF process starting...")))

(defun eaf-stop-process ()
  (interactive)
  ;; Kill eaf buffers.
  (let ((current-buf (current-buffer))
        (count 0))
    (dolist (buffer (buffer-list))
      (set-buffer buffer)
      (when (equal major-mode 'eaf-mode)
        (incf count)
        (kill-buffer buffer)))
    ;; Just report to me when eaf buffer exists.
    (if (> count 1)
        (message "Killed EAF %s buffer%s" count (if (> count 1) "s" ""))))

  ;; Clean cache url and app name, avoid next start process to open buffer.
  (setq eaf-first-start-url nil)
  (setq eaf-first-start-app-name nil)

  ;; Clean `eaf-org-file-list' and `eaf-org-killed-file-list'.
  (dolist (org-file-name eaf-org-file-list)
    (eaf-delete-org-preview-file org-file-name))
  (setq eaf-org-file-list nil)
  (setq eaf-org-killed-file-list nil)

  ;; Kill process after kill buffer, make application can save session data.
  (if (process-live-p eaf-process)
      ;; Delete eaf server process.
      (delete-process eaf-process)
    (message "EAF process has dead.")))

(defun eaf-restart-process ()
  (interactive)
  (eaf-stop-process)
  (eaf-start-process))

(defun eaf-get-render-size ()
  "Get allocation for render application in backend.
We need calcuate render allocation to make sure no black border around render content."
  (let* (;; We use `window-inside-pixel-edges' and `window-absolute-pixel-edges' calcuate height of window header, such as tabbar.
         (window-header-height (- (nth 1 (window-inside-pixel-edges)) (nth 1 (window-absolute-pixel-edges))))
         (width (frame-pixel-width))
         ;; Render height should minus mode-line height, minibuffer height, header height.
         (height (- (frame-pixel-height) (window-mode-line-height) (window-pixel-height (minibuffer-window)) window-header-height)))
    (mapcar (lambda (x) (format "%s" x)) (list width height))))

(defun eaf-get-window-allocation (&optional window)
  (let* ((window-edges (window-inside-pixel-edges window))
         (x (nth 0 window-edges))
         (y (nth 1 window-edges))
         (w (- (nth 2 window-edges) x))
         (h (- (nth 3 window-edges) y))
         )
    (list x y w h)))

(defun eaf-generate-id ()
  (format "%04x%04x-%04x-%04x-%04x-%06x%06x"
          (random (expt 16 4))
          (random (expt 16 4))
          (random (expt 16 4))
          (random (expt 16 4))
          (random (expt 16 4))
          (random (expt 16 6))
          (random (expt 16 6)) ))

(defun eaf-create-buffer (input-content)
  (let ((eaf-buffer (generate-new-buffer (truncate-string-to-width input-content eaf-title-length))))
    (with-current-buffer eaf-buffer
      (eaf-mode)
      (read-only-mode)
      )
    eaf-buffer))

(defun eaf-is-support (url)
  (dbus-call-method
   :session "com.lazycat.eaf"
   "/com/lazycat/eaf"
   "com.lazycat.eaf"
   "is_support"
   url))

(defun eaf-monitor-configuration-change (&rest _)
  (ignore-errors
    (let (view-infos)
      (dolist (window (window-list))
        (let ((buffer (window-buffer window)))
          (with-current-buffer buffer
            (if (eq major-mode 'eaf-mode)
                (let* ((window-allocation (eaf-get-window-allocation window))
                       (x (nth 0 window-allocation))
                       (y (nth 1 window-allocation))
                       (w (nth 2 window-allocation))
                       (h (nth 3 window-allocation))
                       )
                  (add-to-list 'view-infos (format "%s:%s:%s:%s:%s" buffer-id x y w h))
                  )))))
      ;; I don't know how to make emacs send dbus-message with two-dimensional list.
      ;; So i package two-dimensional list in string, then unpack on server side. ;)
      (eaf-call "update_views" (mapconcat 'identity view-infos ","))
      )))

(defun eaf-delete-org-preview-file (org-file)
  (setq org-html-file (concat (file-name-sans-extension org-file) ".html"))
  (when (file-exists-p org-html-file)
    (delete-file org-html-file)
    (message (format "Clean org preview file %s (%s)" org-html-file org-file))
    ))

(defun eaf-org-killed-buffer-clean ()
  (dolist (org-killed-buffer eaf-org-killed-file-list)
    (unless (get-file-buffer org-killed-buffer)
      (setq eaf-org-file-list (remove org-killed-buffer eaf-org-file-list))
      (eaf-delete-org-preview-file org-killed-buffer)
      ))
  (setq eaf-org-killed-file-list nil))

(defun eaf-monitor-buffer-kill ()
  (ignore-errors
    (with-current-buffer (buffer-name)
      (cond ((eq major-mode 'org-mode)
             ;; NOTE:
             ;; Because save org buffer will trigger `kill-buffer' action,
             ;; but org buffer still live after do `kill-buffer' action.
             ;; So i run a timer to check org buffer is live after `kill-buffer' aciton.
             (when (member (buffer-file-name) eaf-org-file-list)
               (unless (member (buffer-file-name) eaf-org-killed-file-list)
                 (push (buffer-file-name) eaf-org-killed-file-list))
               (run-with-timer 1 nil (lambda () (eaf-org-killed-buffer-clean)))
               ))
            ((eq major-mode 'eaf-mode)
             (eaf-call "kill_buffer" buffer-id)
             (message (format "Kill %s" buffer-id)))
            ))))

(defun eaf-monitor-buffer-save ()
  (ignore-errors
    (with-current-buffer (buffer-name)
      (cond ((and
              (eq major-mode 'org-mode)
              (member (buffer-file-name) eaf-org-file-list))
             (org-html-export-to-html)
             (eaf-call "update_buffer_with_url" "app.orgpreviewer.buffer" (buffer-file-name) "")
             (message (format "export %s to html" (buffer-file-name))))))))

(defun eaf-monitor-key-event ()
  (ignore-errors
    (with-current-buffer (buffer-name)
      (when (eq major-mode 'eaf-mode)
        (let* ((event last-command-event)
               (key (make-vector 1 event))
               (key-command (format "%s" (key-binding key)))
               (key-desc (key-description key))
               )
          (cond
           ;; Just send event when user insert single character.
           ;; Don't send event 'M' if user press Ctrl + M.
           ((and
             (or
              (equal key-command "self-insert-command")
              (equal key-command "completion-select-if-within-overlay"))
             (equal 1 (string-width (this-command-keys))))
            (message (format "Send char: '%s" key-desc))
            (eaf-call "send_key" (format "%s:%s" buffer-id key-desc)))
           ((or
             (equal key-command "nil")
             (equal key-desc "RET")
             (equal key-desc "DEL")
             (equal key-desc "TAB")
             (equal key-desc "<home>")
             (equal key-desc "<end>")
             (equal key-desc "<left>")
             (equal key-desc "<right>")
             (equal key-desc "<up>")
             (equal key-desc "<down>")
             (equal key-desc "<prior>")
             (equal key-desc "<next>")
             )
            (message (format "Send: '%s" key-desc))
            (eaf-call "send_key" (format "%s:%s" buffer-id key-desc))
            )
           (t
            (unless (or
                     (equal key-command "keyboard-quit")
                     (equal key-command "kill-this-buffer")
                     (equal key-command "eaf-open"))
              (ignore-errors (call-interactively (key-binding key))))
            (message (format "Got command: %s" key-command)))))
        ;; Set `last-command-event' with nil, emacs won't notify me buffer is ready-only,
        ;; because i insert nothing in buffer.
        (setq last-command-event nil)
        ))))

(defun eaf-focus-buffer (msg)
  (let* ((coordinate-list (split-string msg ","))
         (mouse-press-x (string-to-number (nth 0 coordinate-list)))
         (mouse-press-y (string-to-number (nth 1 coordinate-list))))
    (catch 'find-window
      (dolist (window (window-list))
        (let ((buffer (window-buffer window)))
          (with-current-buffer buffer
            (if (eq major-mode 'eaf-mode)
                (let* ((window-allocation (eaf-get-window-allocation window))
                       (x (nth 0 window-allocation))
                       (y (nth 1 window-allocation))
                       (w (nth 2 window-allocation))
                       (h (nth 3 window-allocation))
                       )
                  (when (and
                         (> mouse-press-x x)
                         (< mouse-press-x (+ x w))
                         (> mouse-press-y y)
                         (< mouse-press-y (+ y h)))
                    (select-window window)
                    (throw 'find-window t)
                    )
                  ))))))))

(dbus-register-signal
 :session "com.lazycat.eaf" "/com/lazycat/eaf"
 "com.lazycat.eaf" "focus_emacs_buffer"
 'eaf-focus-buffer)

(defun eaf-start-finish ()
  ;; Call `eaf-open-internal' after receive `start_finish' signal from server process.
  (eaf-open-internal eaf-first-start-url eaf-first-start-app-name))

(dbus-register-signal
 :session "com.lazycat.eaf" "/com/lazycat/eaf"
 "com.lazycat.eaf" "start_finish"
 'eaf-start-finish)

(defun eaf-update-buffer-title (bid title)
  (when (> (length title) 0)
    (catch 'find-buffer
      (dolist (window (window-list))
        (let ((buffer (window-buffer window)))
          (with-current-buffer buffer
            (when (and
                   (eq major-mode 'eaf-mode)
                   (equal buffer-id bid))
              (rename-buffer title)
              (throw 'find-buffer t)
              )))))))

(dbus-register-signal
 :session "com.lazycat.eaf" "/com/lazycat/eaf"
 "com.lazycat.eaf" "update_buffer_title"
 'eaf-update-buffer-title)

(defun eaf-open-buffer-url (url)
  (eaf-open url))

(dbus-register-signal
 :session "com.lazycat.eaf" "/com/lazycat/eaf"
 "com.lazycat.eaf" "open_buffer_url"
 'eaf-open-buffer-url)

(defun eaf-input-message (buffer_id interactive_string callback_type)
  (eaf-call "handle_input_message" buffer_id callback_type (read-string interactive_string)))

(dbus-register-signal
 :session "com.lazycat.eaf" "/com/lazycat/eaf"
 "com.lazycat.eaf" "input_message"
 'eaf-input-message)

(add-hook 'window-configuration-change-hook #'eaf-monitor-configuration-change)
(add-hook 'pre-command-hook #'eaf-monitor-key-event)
(add-hook 'kill-buffer-hook #'eaf-monitor-buffer-kill)
(add-hook 'after-save-hook #'eaf-monitor-buffer-save)

(defun eaf-open-internal (url app-name)
  (let* ((buffer (eaf-create-buffer url))
         buffer-result)
    (with-current-buffer buffer
      (setq buffer-result (eaf-call "new_buffer" buffer-id url app-name)))
    (if (equal buffer-result "")
        (progn
          ;; Switch to new buffer if buffer create successful.
          (switch-to-buffer buffer)
          (set (make-local-variable 'buffer-url) url)
          (set (make-local-variable 'buffer-app-name) app-name)
          ;; Focus to file window if is previewer application.
          (when (or (string= app-name "markdownpreviewer")
                    (string= app-name "orgpreviewer"))
            (other-window +1)))
      ;; Kill buffer and show error message from python server.
      (kill-buffer buffer)
      (message buffer-result))
    ))

(defun eaf-open (url &optional app-name)
  (interactive "FOpen with EAF: ")
  (unless app-name
    (cond ((string-equal url "eaf-demo")
           (setq app-name "demo"))
          ((string-equal url "eaf-camera")
           (setq app-name "camera"))
          ((file-exists-p url)
           (setq url (expand-file-name url))
           (setq extension-name (file-name-extension url))
           (cond ((member extension-name '("pdf" "xps" "oxps" "cbz" "epub" "fb2" "fbz"))
                  (setq app-name "pdfviewer"))
                 ((member extension-name '("md"))
                  ;; Split window to show file and previewer.
                  (eaf-split-preview-windows)
                  (setq app-name "markdownpreviewer"))
                 ((member extension-name '("jpg" "png" "bmp"))
                  (setq app-name "imageviewer"))
                 ((member extension-name '("avi" "rmvb" "ogg" "mp4"))
                  (setq app-name "videoplayer"))
                 ((member extension-name '("org"))
                  ;; Find file first, because `find-file' will trigger `kill-buffer' operation.
                  (save-excursion
                    (find-file url)
                    (with-current-buffer (buffer-name)
                      (org-html-export-to-html)))
                  ;; Add file name to `eaf-org-file-list' after command `find-file'.
                  (unless (member url eaf-org-file-list)
                    (push url eaf-org-file-list))
                  ;; Split window to show file and previewer.
                  (eaf-split-preview-windows)
                  (setq app-name "orgpreviewer")
                  )))
          (t
           (setq app-name "browser")
           (unless (string-prefix-p "http" url)
             (setq url (concat "http://" url))))))
  (if (process-live-p eaf-process)
      (let (exists-eaf-buffer)
        ;; Try to opened buffer.
        (catch 'found-match-buffer
          (dolist (buffer (buffer-list))
            (set-buffer buffer)
            (when (equal major-mode 'eaf-mode)
              (when (and (string= buffer-url url)
                         (string= buffer-app-name app-name))
                (setq exists-eaf-buffer buffer)
                (throw 'found-match-buffer t)))))
        ;; Switch to exists buffer,
        ;; if no match buffer found, call `eaf-open-internal'.
        (if exists-eaf-buffer
            (switch-to-buffer exists-eaf-buffer)
          (eaf-open-internal url app-name)))
    ;; Record user input, and call `eaf-open-internal' after receive `start_finish' signal from server process.
    (setq eaf-first-start-url url)
    (setq eaf-first-start-app-name app-name)
    (eaf-start-process)))

(defun eaf-split-preview-windows ()
  (delete-other-windows)
  (find-file url)
  (split-window-horizontally)
  (other-window +1))

(defun eaf-show-file-qrcode (url)
  (interactive "FShow file QR code: ")
  (eaf-open url "filetransfer"))

(defun dired-show-file-qrcode ()
  (interactive)
  (eaf-show-file-qrcode (dired-get-filename)))

(defun eaf-air-share ()
  (interactive)
  (let* ((current-symbol (if (use-region-p)
                             (buffer-substring-no-properties (region-beginning) (region-end))
                           (thing-at-point 'symbol)))
         (input-string (string-trim (read-string (format "Info (%s): " current-symbol)))))
    (when (string-empty-p input-string)
      (setq input-string current-symbol))
    (eaf-open input-string "airshare")
    ))

(defun eaf-upload-file (dir)
  (interactive "DDirectory to save uploade file: ")
  (eaf-open dir "fileuploader"))

;;;;;;;;;;;;;;;;;;;; Utils ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun eaf-get-view-info ()
  (let* ((window-allocation (eaf-get-window-allocation (selected-window)))
         (x (nth 0 window-allocation))
         (y (nth 1 window-allocation))
         (w (nth 2 window-allocation))
         (h (nth 3 window-allocation)))
    (format "%s:%s:%s:%s:%s" buffer-id x y w h)))

;;;;;;;;;;;;;;;;;;;; Advice ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defadvice scroll-other-window (around eaf-scroll-up-or-next-page activate)
  "When next buffer is `eaf-mode', do `eaf-scroll-up-or-next-page'."
  (other-window +1)
  (if (eq major-mode 'eaf-mode)
      (let ((arg (ad-get-arg 0)))
        (if (null arg)
            (eaf-call "scroll_buffer" (eaf-get-view-info) "up" "page")
          (eaf-call "scroll_buffer" (eaf-get-view-info) "up" "line"))
        (other-window -1))
    (other-window -1)
    ad-do-it))

(defadvice scroll-other-window-down (around eaf-scroll-down-or-previous-page activate)
  "When next buffer is `eaf-mode', do `eaf-scroll-down-or-previous-page'."
  (other-window +1)
  (if (eq major-mode 'eaf-mode)
      (let ((arg (ad-get-arg 0)))
        (if (null arg)
            (eaf-call "scroll_buffer" (eaf-get-view-info) "down" "page")
          (eaf-call "scroll_buffer" (eaf-get-view-info) "down" "line"))
        (other-window -1))
    (other-window -1)
    ad-do-it))

(provide 'eaf)

;;; eaf.el ends here
