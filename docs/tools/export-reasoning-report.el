;;; export-reasoning-report.el --- Offline results replay and standalone HTML export -*- lexical-binding: t; -*-
;; Load only the selected upstream Babel support. Refresh executes five named
;; offline MLPL blocks; export never runs shell commands or live inference.
(require 'org)
(require 'ob)
(require 'ox-html)
(let* ((repo (file-name-as-directory (getenv "REPORT_REPO")))
       (support (getenv "MLPL_ELISP"))
       (program (getenv "MLPL"))
       (source (expand-file-name "docs/reasoning-results.org" repo))
       (check (equal (getenv "REPORT_REFRESH") "check"))
       (refresh (member (getenv "REPORT_REFRESH") '("1" "check"))))
  (unless (and program (file-executable-p program))
    (error "Set MLPL to the tested interpreter"))
  (unless (file-readable-p (expand-file-name "ob-mlpl.el" support))
    (error "Set MLPL_ELISP to the directory containing ob-mlpl.el"))
  (add-to-list 'load-path support)
  (require 'ob-mlpl)
  (require 'mlpl-mode nil t)
  (make-directory (expand-file-name "out" repo) t)
  (setq temporary-file-directory (expand-file-name "out/" repo)
        org-babel-mlpl-command
        (mapconcat #'shell-quote-argument
                   (list program "--source-dir" repo "--data-dir" repo) " ")
        org-babel-mlpl-line-threshold 10000
        make-backup-files nil
        org-html-validation-link nil
        org-html-postamble nil
        org-html-head-include-default-style nil
        org-html-head-include-scripts nil
        org-html-htmlize-output-type nil
        org-export-time-stamp-file nil
        org-export-with-broken-links nil)
  (with-current-buffer (find-file-noselect source)
    (when refresh
      (let ((org-confirm-babel-evaluate nil)
            (before (buffer-string)))
        (dolist (name '("replay-heldout-summary" "replay-budget-grades" "replay-grades" "reward-advantages" "toy-sgd"))
          (org-babel-goto-named-src-block name)
          (let ((result (org-babel-execute-src-block)))
            (unless (and (stringp result)
                         (string-match-p "Ok(" result)
                         (not (string-match-p "error:" result)))
              (error "Offline research block failed: %s: %s" name result))))
        (when (and check (not (equal before (buffer-string))))
          (error "Recorded Org results drift; run just research-refresh")))
      (unless check (save-buffer)))
    ;; The document declares :eval no-export; disable Babel export evaluation
    ;; as well so even new live blocks cannot perform inference while exporting.
    (let ((org-export-use-babel nil)
          (org-html-head-extra
           (with-temp-buffer
             (insert-file-contents (expand-file-name "docs/research-report.css" repo))
             (concat "<style>\n" (buffer-string) "\n</style>"))))
      (random "reasoning-results-v1")
      (if check
          (let ((actual (concat (org-export-as 'html) "\n"))
                (expected (with-temp-buffer
                            (insert-file-contents (expand-file-name "docs/reasoning-results.html" repo))
                            (buffer-string))))
            (unless (equal actual expected)
              (with-temp-file (expand-file-name "out/reasoning-report-actual.html" repo)
                (insert actual))
              (error "HTML report drift; run just research-html"))
            (princ "PASS offline report replay and exact HTML export.\n"))
        (org-html-export-to-html)
        (princ "Exported docs/reasoning-results.html (no live inference).\n")))))
