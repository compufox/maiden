#|
 This file is a part of Maiden
 (c) 2017 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.maiden.agents.lookup)

(define-webpage-lookup clhs (term)
  (format NIL "http://l1sp.org/cl/~a" (drakma:url-encode term :utf-8)))

(macrolet ((define-l1sp-lookups (&rest lookups)
             `(progn ,@(loop for lookup in lookups
                             collect `(define-webpage-lookup ,lookup (term)
                                        (format NIL "http://l1sp.org/~a/~a"
                                                ,(string-downcase lookup) (drakma:url-encode term :utf-8)))))))
  (define-l1sp-lookups asdf ccl cffi clim clisp clx mop pcl sbcl))

(define-staple-doc-lookup 3d-matrices "https://shinmera.github.io/3d-matrices")
(define-staple-doc-lookup 3d-vectors "https://shinmera.github.io/3d-vectors")
(define-staple-doc-lookup array-utils "https://shinmera.github.io/array-utils")
(define-staple-doc-lookup cari3s "https://shinmera.github.io/cari3s")
(define-staple-doc-lookup chirp "https://shinmera.github.io/chirp")
(define-staple-doc-lookup cl-flac "https://shirakumo.github.io/cl-flac")
(define-staple-doc-lookup cl-fond "https://shirakumo.github.io/cl-fond")
(define-staple-doc-lookup cl-gamepad "https://shirakumo.github.io/cl-gamepad")
(define-staple-doc-lookup cl-gpio "https://shinmera.github.io/cl-gpio")
(define-staple-doc-lookup cl-mixed "https://shirakumo.github.io/cl-mixed")
(define-staple-doc-lookup cl-monitors "https://shirakumo.github.io/cl-monitors")
(define-staple-doc-lookup cl-mpg123 "https://shirakumo.github.io/cl-mpg123")
(define-staple-doc-lookup cl-out123 "https://shirakumo.github.io/cl-out123")
(define-staple-doc-lookup cl-spidev "https://shinmera.github.io/cl-spidev")
(define-staple-doc-lookup clip "https://shinmera.github.io/clip")
(define-staple-doc-lookup clss "https://shinmera.github.io/CLSS")
(define-staple-doc-lookup crypto-shortcuts "https://shinmera.github.io/crypto-shortcuts")
(define-staple-doc-lookup deeds "https://shinmera.github.io/deeds")
(define-staple-doc-lookup deferred "https://shinmera.github.io/deferred")
(define-staple-doc-lookup definitions "https://shinmera.github.io/definitions")
(define-staple-doc-lookup deploy "https://shinmera.github.io/deploy")
(define-staple-doc-lookup dissect "https://shinmera.github.io/dissect")
(define-staple-doc-lookup documentation-utils "https://shinmera.github.io/documentation-utils")
(define-staple-doc-lookup flare "https://shinmera.github.io/flare")
(define-staple-doc-lookup float-features "https://shinmera.github.io/float-features")
(define-staple-doc-lookup flow "https://shinmera.github.io/flow")
(define-staple-doc-lookup for "https://shinmera.github.io/for")
(define-staple-doc-lookup form-fiddle "https://shinmera.github.io/form-fiddle")
(define-staple-doc-lookup glsl-toolkit "https://shirakumo.github.io/glsl-toolkit")
(define-staple-doc-lookup harmony "https://shirakumo.github.io/harmony")
(define-staple-doc-lookup humbler "https://shinmera.github.io/humbler")
(define-staple-doc-lookup iclendar "https://shinmera.github.io/iclendar")
(define-staple-doc-lookup inkwell "https://shinmera.github.io/inkwell")
(define-staple-doc-lookup lambda-fiddle "https://shinmera.github.io/lambda-fiddle")
(define-staple-doc-lookup language-codes "https://shinmera.github.io/language-codes")
(define-staple-doc-lookup lass "https://shinmera.github.io/LASS")
(define-staple-doc-lookup legit "https://shinmera.github.io/legit")
(define-staple-doc-lookup lichat "https://shirakumo.github.io/lichat-protocol")
(define-staple-doc-lookup lquery "https://shinmera.github.io/lquery")
(define-staple-doc-lookup maiden "https://shirakumo.github.io/maiden")
(define-staple-doc-lookup mmap "https://shinmera.github.io/mmap")
(define-staple-doc-lookup modularize "https://shinmera.github.io/modularize")
(define-staple-doc-lookup modularize-hooks "https://shinmera.github.io/modularize-hooks")
(define-staple-doc-lookup modularize-interfaces "https://shinmera.github.io/modularize-interfaces")
(define-staple-doc-lookup multilang-documentation "https://shinmera.github.io/multilang-documentation")
(define-staple-doc-lookup multiposter "https://shinmera.github.io/multiposter")
(define-staple-doc-lookup north "https://shinmera.github.io/north")
(define-staple-doc-lookup oxenfurt "https://shinmera.github.io/oxenfurt")
(define-staple-doc-lookup pango-markup "https://shinmera.github.io/pango-markup")
(define-staple-doc-lookup parachute "https://shinmera.github.io/parachute")
(define-staple-doc-lookup pathname-utils "https://shinmera.github.io/pathname-utils")
(define-staple-doc-lookup piping "https://shinmera.github.io/piping")
(define-staple-doc-lookup plump "https://shinmera.github.io/plump")
(define-staple-doc-lookup qt-libs "https://shinmera.github.io/qt-libs")
(define-staple-doc-lookup qtools "https://shinmera.github.io/qtools")
(define-staple-doc-lookup qtools-ui "https://shinmera.github.io/qtools-ui")
(define-staple-doc-lookup radiance "https://shirakumo.github.io/radiance")
(define-staple-doc-lookup random-state "https://shinmera.github.io/random-state")
(define-staple-doc-lookup ratify "https://shinmera.github.io/ratify")
(define-staple-doc-lookup redirect-stream "https://shinmera.github.io/redirect-stream")
(define-staple-doc-lookup simple-inferiors "https://shinmera.github.io/simple-inferiors")
(define-staple-doc-lookup simple-tasks "https://shinmera.github.io/simple-tasks")
(define-staple-doc-lookup softdrink "https://shinmera.github.io/softdrink")
(define-staple-doc-lookup staple "https://shinmera.github.io/staple")
(define-staple-doc-lookup system-locale "https://shinmera.github.io/system-locale")
(define-staple-doc-lookup tooter "https://shinmera.github.io/tooter")
(define-staple-doc-lookup trivial-arguments "https://shinmera.github.io/trivial-arguments")
(define-staple-doc-lookup trivial-benchmark "https://shinmera.github.io/trivial-benchmark")
(define-staple-doc-lookup trivial-indent "https://shinmera.github.io/trivial-indent")
(define-staple-doc-lookup trivial-main-thread "https://shinmera.github.io/trivial-main-thread")
(define-staple-doc-lookup trivial-mimes "https://shinmera.github.io/trivial-mimes")
(define-staple-doc-lookup trivial-thumbnail "https://shinmera.github.io/trivial-thumbnail")
(define-staple-doc-lookup ubiquitous "https://shinmera.github.io/ubiquitous")
(define-staple-doc-lookup verbose "https://shinmera.github.io/verbose")

(define-weitz-doc-lookup chunga "https://edicl.github.io/chunga/")
(define-weitz-doc-lookup cl-fad "https://edicl.github.io/cl-fad/")
(define-weitz-doc-lookup cl-gd "https://edicl.github.io/cl-gd/")
(define-weitz-doc-lookup cl-ppcre "https://edicl.github.io/cl-ppcre/")
(define-weitz-doc-lookup cl-unicode "https://edicl.github.io/cl-unicode/")
(define-weitz-doc-lookup cl-webdav "https://edicl.github.io/cl-webdav/")
(define-weitz-doc-lookup cl-who "https://edicl.github.io/cl-who/" :iso-8859-1)
(define-weitz-doc-lookup drakma "https://edicl.github.io/drakma/")
(define-weitz-doc-lookup flexi-streams "https://edicl.github.io/flexi-streams/")
(define-weitz-doc-lookup html-template "https://edicl.github.io/html-template/" :iso-8859-1)
(define-weitz-doc-lookup hunchentoot "https://edicl.github.io/hunchentoot/")
(define-weitz-doc-lookup url-rewrite "https://edicl.github.io/url-rewrite/")

(macrolet ((define-alexandria-docs ()
             `(define-table-lookup alexandria
                ,@(coerce (parse-alexandria-docs) 'list))))
  (define-alexandria-docs))

(macrolet ((define-usocket-docs ()
             `(define-table-lookup usocket
                ,@(coerce (parse-usocket-docs) 'list))))
  (define-usocket-docs))

(macrolet ((define-cffi-docs ()
             `(define-table-lookup cffi
                ,@(parse-cffi-docs))))
  (define-cffi-docs))

(define-table-lookup bordeaux-threads
  (("About") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation")
  (("Thread Creation") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#ThreadCreation")
  (("Locks") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#Resourcecontention:locksandrecursivelocks")
  (("Condition Variables") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#Resourcecontention:conditionvariables")
  (("Introspection" "Debugging") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#Introspectiondebugging")
  (("function make-thread" "make-thread") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#make-threadfunctionkeyname")
  (("variable *default-special-bindings*" "*default-special-bindings*") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#default-special-bindings")
  (("function current-thread" "current-thread") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#current-thread")
  (("function threadp" "threadp") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#threadpobject")
  (("function thread-name" "thread-name") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#thread-namethread")
  (("function make-lock" "make-lock") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#make-lockoptionalname")
  (("function acquire-lock" "acquire-lock") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#acquire-locklockoptionalwait-p")
  (("function release-lock" "release-lock") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#release-locklock")
  (("macro with-lock-held" "with-lock-held") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#with-lock-heldplacebodybody")
  (("function make-recursive-lock" "make-recursive-lock") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#make-recursive-lockoptionalname")
  (("function acquire-recursive-lock" "acquire-recursive-lock") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#acquire-recursive-locklock")
  (("function release-recursive-lock" "release-recursive-lock") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#release-recursive-locklock")
  (("macro with-recursive-lock-held" "with-recursive-lock-held") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#with-recursive-lock-heldplacekeytimeoutbodybody")
  (("function thread-yield" "thread-yield") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#thread-yield")
  (("function make-condition-variable" "make-condition-variable") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#make-condition-variable")
  (("function condition-wait" "condition-wait") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#condition-waitcondition-variablelock")
  (("function condition-notify" "condition-notify") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#condition-notifycondition-variable")
  (("function all-threads" "all-threads") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#all-threads")
  (("function interrupt-thread" "interrupt-thread") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#interrupt-threadthreadfunction")
  (("function destroy-thread" "destroy-thread") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#destroy-threadthread")
  (("function thread-alive-p" "thread-alive-p") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#thread-alive-pthread")
  (("function join-thread" "join-thread") "https://trac.common-lisp.net/bordeaux-threads/wiki/ApiDocumentation#join-threadthread"))

(define-table-lookup trivial-garbage
  (("About") "https://common-lisp.net/project/trivial-garbage/#about-package-legend" "About Trivial-Garbage")
  (("function make-weak-pointer" "weak-pointer") "https://common-lisp.net/project/trivial-garbage/#trivial-garbage__fun__make-weak-pointer" "function make-weak-pointer")
  (("function weak-pointer-value" "weak-pointer-value") "https://common-lisp.net/project/trivial-garbage/#trivial-garbage__fun__weak-pointer-value" "function weak-pointer-value")
  (("function weak-pointer-p" "weak-pointer-p") "https://common-lisp.net/project/trivial-garbage/#trivial-garbage__fun__weak-pointer-p" "function weak-pointer-p")
  (("function make-weak-hash-table" "make-weak-hash-table") "https://common-lisp.net/project/trivial-garbage/#trivial-garbage__fun__make-weak-hash-table" "function make-weak-hash-table")
  (("function hash-table-weakness" "hash-table-weakness") "https://common-lisp.net/project/trivial-garbage/#trivial-garbage__fun__hash-table-weakness" "function hash-table-weakness")
  (("function finalize" "finalize") "https://common-lisp.net/project/trivial-garbage/#trivial-garbage__fun__finalize" "function finalize")
  (("function cancel-finalization" "cancel-finalization") "https://common-lisp.net/project/trivial-garbage/#trivial-garbage__fun__cancel-finalization" "function cancel-finalization")
  (("function gc" "gc") "https://common-lisp.net/project/trivial-garbage/#trivial-garbage__fun__gc" "function gc"))
