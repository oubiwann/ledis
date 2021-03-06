(defmodule ledis
  (export all))

(defun start-link ()
  (start-link '()))

(defun start-link (options)
  "The 'options' argument may be a combination of ledis options and eredis
  options."
  (logjam:setup)
  (start-link (eredis:start_link options) options))

(defun start-link
  ((`#(ok ,pid) options)
   (register (ledis-cfg:get-client-process-name) pid))
  ((result options)
   result))

(defun start_link ()
  (start-link))

(defun start ()
  (start-link))

;;; Generated API functions

(include-lib "ledis/include/ledis.lfe")


;;; Hand-wrought API functions - this is for functions which require special
;;; handling of options, usually in the form of keywords/proplists; simple
;;; positional arguments are handled by the macros which automatically generate
;;; ledis API functions.

;; (defun set (key value)
;;   (set key value '()))

(defun set (key value options)
  (let ((cmd (list* "SET" key value (make-set-options options))))
    (cmd cmd options)))

(defun make-set-options (options)
  (lists:foldl
    (lambda (x accum)
      (++ accum (make-set-option x)))
    '()
    options))

(defun make-set-option
  ((`#(ex ,value))
   `("EX" ,value))
  ((`#(px ,value))
   `("PX" ,value))
  ((#(nx))
   '("NX"))
  ((#(xx))
   '("XX"))
  ((_) '()))

;; The next two functions can't be named like the Redis names (mset and mget),
;; as they would conflict with the LFE functions of the same name.

(defun multi-set (pairs options)
  (cmd `("MSET" ,@pairs) options))

(defun multi-get (keys options)
  (cmd `("MGET" ,@keys) options))

(defun del
  ((key options) (when (is_atom key))
   (del-single key options))
  ((key-or-keys options)
   (cond ((io_lib:printable_unicode_list key-or-keys)
          (del-single key-or-keys options))
         ((is_list key-or-keys)
          (del-multi key-or-keys options))
         ('true
          (del-single key-or-keys options)))))

(defun del-single (key options)
  (cmd `("DEL" ,key) options))

(defun del-multi (keys options)
  (cmd `("DEL" ,@keys) options))

;;; General purpose functions for use by API functions

(defun cmd (cmd options)
  "This is a general-purpose function that all ledis functions should use when
  making calls to Redis."
  (logjam:debug (MODULE) 'cmd/2 "Command: ~p" `(,cmd))
  (parse-result
    (eredis:q (get-client) cmd)
    options))

(defun get-client ()
  (whereis (ledis-cfg:get-client-process-name)))

(defun parse-result
  (((= `#(,status ,data) result) options) (when (is_atom data))
   result)
  (((= `#(,status ,data) result) options) (when (is_list data))
   (case (proplists:get_value 'return-type options (ledis-cfg:get-return-type))
     ('binary result)
     ('string `#(,status ,(lists:map #'binary_to_list/1 data)))))
  (((= `#(,status ,data) result) options)
   (logjam:debug (MODULE) 'parse-result/2 "Result: ~p" `(,result))
   (case (proplists:get_value 'return-type options (ledis-cfg:get-return-type))
     ('binary result)
     ('string `#(,status ,(binary_to_list data))))))
