#|
 This file is a part of Maiden
 (c) 2016 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.maiden.clients.irc)

(defvar *reply-events* (make-hash-table :test 'equalp))

(define-event irc-event (client-event)
  ())

(define-event irc-channel-event (irc-event channel-event)
  ())

(defmethod initialize-instance :after ((event irc-channel-event) &key client channel)
  (unless (typep channel 'channel)
    (deeds:with-immutable-slots-unlocked ()
      (setf (slot-value event 'channel) (coerce-irc-object channel NIL NIL client)))))

(define-event reply-event (irc-event user-event incoming-event passive-event)
  ((code :initarg :code)
   (args :initarg :args)))

(defmethod print-object ((reply-event reply-event) stream)
  (print-unreadable-object (reply-event stream :type T :identity T)
    (format stream "~s ~a" :user (name (user reply-event)))))

(define-event unknown-event (reply-event)
  ())

(defun parse-reply (client message)
  (or
   (cl-ppcre:register-groups-bind (NIL nick NIL user NIL host code NIL args)
       ("^(:([^! ]+)(!([^@ ]+))?(@([^ ]+))? +)?([^ ]+)( +(.+))?$" message)
     (let ((event-types (or (gethash code *reply-events*)
                            (progn (warn 'unknown-data-warning :client client :data message)
                                   '(unknown-event))))
           (user (coerce-irc-object nick user host client)))
       (loop for event-type in event-types
             nconc (make-reply-events event-type :client client :code code :args args :user user))))
   (error 'data-parse-error :client client :data message)))

(defgeneric make-reply-events (type &key client code args user))

(defmethod make-reply-events ((type (eql 'unknown-event)) &key client code args user)
  (list (make-instance 'unknown-event :args args :code code :user user :client client)))

(defun permute (args)
  (flet ((modf (func list)
           (mapl (lambda (c) (setf (car c) (funcall func (car c)))) list)))
    (cond ((not args)
           (list ()))
          ((listp (first args))
           (loop for arg in (first args)
                 nconc (modf (lambda (rest) (list* arg rest)) (permute (rest args)))))
          (T
           (let ((arg (first args)))
             (modf (lambda (rest) (list* arg rest)) (permute (rest args))))))))

(defmacro define-irc-reply (name code (&optional regex &rest slots) &optional direct-superclasses)
  (let ((name (intern (string name) '#:org.shirakumo.maiden.clients.irc.events))
        (code (etypecase code
                (symbol (string code))
                (string code)
                (integer (format NIL "~3,'0d" code))))
        (slot-kargs (loop for slot in slots
                          for (name delim) = (enlist slot NIL)
                          when name append (list (kw name) (if delim `(cl-ppcre:split ,(string delim) ,name) name)))))
    `(progn
       (define-event ,name (,@direct-superclasses reply-event)
         ,(loop for slot in slots
                for (name delim) = (enlist slot NIL)
                when name collect `(,name :initarg ,(kw name)))
         (:default-initargs :code ,code))
       (defmethod make-reply-events ((type (eql ',name)) &key client code args user)
         ;; If there's a chance of a multi-target field, we need to generate a list and permute.
         ;; However, this case is rare, so we spend a small amount of code dupe optimising the
         ;; common case to not do any of that crap.
         ,(cond ((some #'consp slots)
                 `(mapcar (lambda (other-args)
                            (apply #'make-instance ',name :client client :code code :args args :user user other-args))
                          (or (when args
                                (cl-ppcre:register-groups-bind ,(mapcar #'unlist slots) (,regex args)
                                  (permute (list ,@slot-kargs))))
                              ())))
                (slots
                 `(cl-ppcre:register-groups-bind ,(mapcar #'unlist slots) (,regex args)
                    (list (make-instance ',name :client client :code code :args args :user user ,@slot-kargs))))
                (T
                 `(list (make-instance ',name :client client :code code :args args :user user)))))
       (pushnew ',name (gethash ,code *reply-events*)))))

;; Parsed from https://www.alien.net.au/irc/irc2numerics.html
;; Manually edited to suit a more parseable format, and to
;; remove conflicting duplicates.
(define-irc-reply MSG-PASS PASS ("(.*)" PASSWORD))
;; Note: The MSG-NICK is not a subclass of USER-NAME-CHANGED because of the way in which user and old-name are
;;       reversed in order. Instead we explicitly convert the event and issue the proper one in the track-nick
;;       handler in user.lisp
(define-irc-reply MSG-NICK NICK (":?([^ ]+)( (.*))?" NICKNAME NIL HOPCOUNT))
(define-irc-reply MSG-USER USER ("([^ ]+) ([^ ]+) ([^ ]+) :(.*)" USERNAME HOSTNAME SERVERNAME REALNAME))
(define-irc-reply MSG-SERVER SERVER ("([^ ]+) ([^ ]+) :(.*)" SERVERNAME HOPCOUNT INFO))
(define-irc-reply MSG-OPER OPER ("([^ ]+) ([^ ]+)" USERNAME PASSWORD))
(define-irc-reply MSG-QUIT QUIT ("(:(.*))?" NIL COMMENT))
(define-irc-reply MSG-SQUIT SQUIT ("([^ ]+) :(.*)" SERVER COMMENT))
(define-irc-reply MSG-JOIN JOIN (":?([^ ]+)" (CHANNEL #\,)) (user-entered irc-channel-event))
(define-irc-reply MSG-PART PART ("([^ ]+)" (CHANNEL #\,)) (user-left irc-channel-event))
(define-irc-reply MSG-MODE MODE ("([^ ]+) ([^ ]+)( ([^ ]+)( ([^ ]+)( ([^ ]+))?)?)?" TARGET MODE NIL LIMIT NIL USERNAME NIL BAN-MASK))
(define-irc-reply MSG-TOPIC TOPIC ("([^ ]+)( :(.*))?" CHANNEL NIL TOPIC) (irc-channel-event))
(define-irc-reply MSG-NAMES NAMES ("([^ ]+)" (CHANNEL #\,)) (irc-channel-event))
(define-irc-reply MSG-LIST LIST ("([^ ]+)( ([^ ]+))?" (CHANNEL #\,) NIL SERVER) (irc-channel-event))
(define-irc-reply MSG-INVITE INVITE ("([^ ]+) ([^ ]+)" NICKNAME CHANNEL) (irc-channel-event))
(define-irc-reply MSG-KICK KICK ("([^ ]+) ([^ ]+)( :(.*))?" CHANNEL NICKNAME NIL COMMENT) (irc-channel-event))
(define-irc-reply MSG-VERSION VERSION ("([^ ]+)?" SERVER))
(define-irc-reply MSG-STATS STATS ("(([^ ]+)( ([^ ]+))?)?" NIL QUERY NIL SERVER))
(define-irc-reply MSG-LINKS LINKS ("((([^ ]+) )?([^ ]+))?" NIL NIL REMOTE-SERVER SERVER-MASK))
(define-irc-reply MSG-TIME TIME ("([^ ]+)?" SERVER))
(define-irc-reply MSG-CONNECT CONNECT ("(([^ ]+)( ([^ ]+)( ([^ ]+))?)?)?" NIL TARGET NIL PORT NIL REMOTE))
(define-irc-reply MSG-TRACE TRACE ("([^ ]+)?" SERVER))
(define-irc-reply MSG-ADMIN ADMIN ("([^ ]+)?" SERVER))
(define-irc-reply MSG-INFO INFO ("([^ ]+)?" SERVER))
(define-irc-reply MSG-PRIVMSG PRIVMSG ("([^ ]+) :(.*)" (CHANNEL #\,) MESSAGE) (irc-channel-event message-event))
(define-irc-reply MSG-NOTICE NOTICE ("([^ ]+)? ?:(.*)" NICKNAME MESSAGE))
(define-irc-reply MSG-WHO WHO ("(([^ ]+)( o)?)?" NIL NAME OPERS-ONLY))
(define-irc-reply MSG-WHOIS WHOIS ("(([^ ]+) )?([^ ]+)" NIL SERVER (NICKMASK #\,)))
(define-irc-reply MSG-WHOWAS WHOWAS ("([^ ]+)( ([^ ]+)( ([^ ]+))?)?" NICKNAME NIL COUNT NIL SERVER))
(define-irc-reply MSG-KILL KILL ("([^ ]+) :(.*)" NICKNAME COMMENT))
(define-irc-reply MSG-PING PING ("([^ ]+)( ([^ ]+))?" SERVER NIL OTHER-SERVER))
(define-irc-reply MSG-PONG PONG ("([^ ]+)( ([^ ]+))?" DAEMON NIL OTHER-DAEMON))
(define-irc-reply MSG-ERROR ERROR (":(.*)" MESSAGE))
(define-irc-reply MSG-AWAY AWAY ("(:(.*))?" NIL MESSAGE))
(define-irc-reply MSG-REHASH REHASH ())
(define-irc-reply MSG-RESTART RESTART ())
(define-irc-reply MSG-SUMMON SUMMON ("([^ ]+)( ([^ ]+))?" NICKNAME NIL SERVER))
(define-irc-reply MSG-USERS USERS ("([^ ]+)?" SERVER))
(define-irc-reply MSG-WALLOPS WALLOPS (":(.*)" MESSAGE))
(define-irc-reply MSG-USERHOST USERHOST ("(.*)" (NICKNAME #\ )))
(define-irc-reply MSG-ISON ISON ("(.*)" (NICKNAME #\ )))
(define-irc-reply RPL-WELCOME 001 ("(:.*)" INFO))
(define-irc-reply RPL-YOURHOST 002 ("(:.*)" INFO))
(define-irc-reply RPL-CREATED 003 ("(:.*)" INFO))
(define-irc-reply RPL-MYINFO 004 ("([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+)" SERVER-NAME VERSION USER-MODES CHAN-MODES))
(define-irc-reply RPL-BOUNCE 005 ("(:.*)" INFO))
(define-irc-reply RPL-MAP 006 ())
(define-irc-reply RPL-MAPEND 007 ())
(define-irc-reply RPL-SNOMASK 008 ())
(define-irc-reply RPL-STATMEMTOT 009 ())
(define-irc-reply RPL-YOURCOOKIE 014 ())
(define-irc-reply RPL-MAP 015 ())
(define-irc-reply RPL-MAPMORE 016 ())
(define-irc-reply RPL-MAPEND 017 ())
(define-irc-reply RPL-YOURID 042 ())
(define-irc-reply RPL-SAVENICK 043 ("(:.*)" INFO))
(define-irc-reply RPL-ATTEMPTINGJUNC 050 ())
(define-irc-reply RPL-ATTEMPTINGREROUTE 051 ())
(define-irc-reply RPL-TRACELINK 200 ("Link
\([^(]+)(\\.([ ]+))? ([^
]+)
\([^ ]+) (V([^
]+)
\([^ ]+) ([^
]+)
\(.+))?" VERSION NIL DEBUG-LEVEL DESTINATION NEXT-SERVER NIL PROTOCOL-VERSION LINK-UPTIME-IN-SECONDS BACKSTREAM-SENDQ UPSTREAM-SENDQ))
(define-irc-reply RPL-TRACECONNECTING 201 ("Try\\. ([^ ]+) ([^ ]+)" CLASS SERVER))
(define-irc-reply RPL-TRACEHANDSHAKE 202 ("H\\.S\\. ([^ ]+) ([^ ]+)" CLASS SERVER))
(define-irc-reply RPL-TRACEUNKNOWN 203 ("[^ ]* ([^ ]+)( (.+))?" CLASS NIL CONNECTION-ADDRESS))
(define-irc-reply RPL-TRACEOPERATOR 204 ("Oper ([^ ]+) ([^ ]+)" CLASS NICKNAME))
(define-irc-reply RPL-TRACEUSER 205 ("User ([^ ]+) ([^ ]+)" CLASS NICKNAME))
(define-irc-reply RPL-TRACESERVER 206 ("Serv ([^ ]+) ([^S]+)S ([^C]+)C ([^
]+)
\([^@]+)@([^ ]+)( V(.+))?" CLASS SERVERS CLIENTS SERVER USERNAME HOST NIL PROTOCOL-VERSION))
(define-irc-reply RPL-TRACESERVICE 207 ("Service ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+)" CLASS NAME TYPE ACTIVE-TYPE))
(define-irc-reply RPL-TRACENEWTYPE 208 ("([^ ]+) 0 ([^ ]+)" NEWTYPE CLIENT-NAME))
(define-irc-reply RPL-TRACECLASS 209 ("Class ([^ ]+) ([^ ]+)" CLASS COUNT))
(define-irc-reply RPL-TRACERECONNECT 210 ())
(define-irc-reply RPL-STATSLINKINFO 211 ("([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+)" LINKNAME SENDQ SENT-MSGS SENT-BYTES RECVD-MSGS RCVD-BYTES TIME-OPEN))
(define-irc-reply RPL-STATSCOMMANDS 212 ("([^ ]+) ([^ ]+)( ([^ ]+) (.+))?" COMMAND COUNT NIL BYTE-COUNT REMOTE-COUNT))
(define-irc-reply RPL-STATSCLINE 213 ("C ([^ ]+) \\* ([^ ]+) ([^ ]+) ([^ ]+)" HOST NAME PORT CLASS))
(define-irc-reply RPL-STATSNLINE 214 ("N ([^ ]+) \\* ([^ ]+) ([^ ]+) ([^ ]+)" HOST NAME PORT CLASS))
(define-irc-reply RPL-STATSILINE 215 ("I ([^ ]+) \\* ([^ ]+) ([^ ]+) ([^ ]+)" HOST STATS-HOST PORT CLASS))
(define-irc-reply RPL-STATSKLINE 216 ("K ([^ ]+) \\* ([^ ]+) ([^ ]+) ([^ ]+)" HOST USERNAME PORT CLASS))
(define-irc-reply RPL-STATSQLINE 217 ())
(define-irc-reply RPL-STATSYLINE 218 ("Y ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+)" CLASS PING-FREQ CONNECT-FREQ MAX-SENDQ))
(define-irc-reply RPL-ENDOFSTATS 219 ("([^ ]+) (:.*)" QUERY INFO))
(define-irc-reply RPL-UMODEIS 221 ("([^ ]+)( (.+))?" USER-MODES NIL USER-MODE-PARAMS))
(define-irc-reply RPL-STATSQLINE 228 ())
(define-irc-reply RPL-SERVICEINFO 231 ())
(define-irc-reply RPL-ENDOFSERVICES 232 ())
(define-irc-reply RPL-SERVICE 233 ())
(define-irc-reply RPL-SERVLIST 234 ("([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+)" NAME SERVER MASK TYPE HOPCOUNT INFO))
(define-irc-reply RPL-SERVLISTEND 235 ("([^ ]+) ([^ ]+) (:.*)" MASK TYPE INFO))
(define-irc-reply RPL-STATSVERBOSE 236 ())
(define-irc-reply RPL-STATSENGINE 237 ())
(define-irc-reply RPL-STATSFLINE 238 ())
(define-irc-reply RPL-STATSIAUTH 239 ())
(define-irc-reply RPL-STATSLLINE 241 ("L ([^ ]+) \\* ([^ ]+) ([^ ]+)" HOSTMASK SERVERNAME MAXDEPTH))
(define-irc-reply RPL-STATSUPTIME 242 ("(:.*)" INFO))
(define-irc-reply RPL-STATSOLINE 243 ("O ([^ ]+) \\* ([^ ]+)( :(.*))?" HOSTMASK NICKNAME NIL INFO))
(define-irc-reply RPL-STATSHLINE 244 ("H ([^ ]+) \\* ([^ ]+)" HOSTMASK SERVERNAME))
(define-irc-reply RPL-STATSSLINE 245 ())
(define-irc-reply RPL-STATSDLINE 250 ())
(define-irc-reply RPL-LUSERCLIENT 251 ("(:.*)" INFO))
(define-irc-reply RPL-LUSEROP 252 ("([^ ]+) (:.*)" INT INFO))
(define-irc-reply RPL-LUSERUNKNOWN 253 ("([^ ]+) (:.*)" INT INFO))
(define-irc-reply RPL-LUSERCHANNELS 254 ("([^ ]+) (:.*)" INT INFO))
(define-irc-reply RPL-LUSERME 255 ("(:.*)" INFO))
(define-irc-reply RPL-ADMINME 256 ("([^ ]+) (:.*)" SERVER INFO))
(define-irc-reply RPL-ADMINLOC1 257 ("(:.*)" INFO))
(define-irc-reply RPL-ADMINLOC2 258 ("(:.*)" INFO))
(define-irc-reply RPL-ADMINEMAIL 259 ("(:.*)" INFO))
(define-irc-reply RPL-TRACELOG 261 ("File ([^ ]+) ([^ ]+)" LOGFILE DEBUG-LEVEL))
(define-irc-reply RPL-TRACEEND 262 ("([^ ]+) ([^. ]+)(\\.([^ ]+))? (:.*)" SERVER-NAME VERSION NIL DEBUG-LEVEL INFO))
(define-irc-reply RPL-TRYAGAIN 263 ("([^ ]+) (:.*)" COMMAND INFO))
(define-irc-reply RPL-LOCALUSERS 265 ())
(define-irc-reply RPL-GLOBALUSERS 266 ())
(define-irc-reply RPL-START-NETSTAT 267 ())
(define-irc-reply RPL-NETSTAT 268 ())
(define-irc-reply RPL-END-NETSTAT 269 ())
(define-irc-reply RPL-PRIVS 270 ())
(define-irc-reply RPL-SILELIST 271 ())
(define-irc-reply RPL-ENDOFSILELIST 272 ())
(define-irc-reply RPL-NOTIFY 273 ())
(define-irc-reply RPL-STATSDLINE 275 ())
(define-irc-reply RPL-VCHANEXIST 276 ())
(define-irc-reply RPL-VCHANLIST 277 ())
(define-irc-reply RPL-VCHANHELP 278 ())
(define-irc-reply RPL-GLIST 280 ())
(define-irc-reply RPL-CHANINFO-KICKS 296 ())
(define-irc-reply RPL-END-CHANINFO 299 ())
(define-irc-reply RPL-NONE 300 ())
(define-irc-reply RPL-AWAY 301 ("([^ ]+) (:.*)" NICKNAME INFO))
(define-irc-reply RPL-USERHOST 302 ("(:.*)" INFO))
(define-irc-reply RPL-ISON 303 ("(:.*)" INFO))
(define-irc-reply RPL-TEXT 304 ())
(define-irc-reply RPL-UNAWAY 305 ("(:.*)" INFO))
(define-irc-reply RPL-NOWAWAY 306 ("(:.*)" INFO))
(define-irc-reply RPL-WHOISUSER 311 ("([^ ]+) ([^ ]+) ([^ ]+) \\* (:.*)" NICKNAME USERNAME HOST INFO))
(define-irc-reply RPL-WHOISSERVER 312 ("([^ ]+) ([^ ]+) (:.*)" NICKNAME SERVER INFO))
(define-irc-reply RPL-WHOISOPERATOR 313 ("([^ ]+) (:.*)" NICKNAME INFO))
(define-irc-reply RPL-WHOWASUSER 314 ("([^ ]+) ([^ ]+) ([^ ]+) \\* (:.*)" NICKNAME USERNAME HOST INFO))
(define-irc-reply RPL-ENDOFWHO 315 ("([^ ]+) (:.*)" NAME INFO))
(define-irc-reply RPL-WHOISCHANOP 316 ())
(define-irc-reply RPL-WHOISIDLE 317 ("([^ ]+) ([^ ]+) (:.*)" NICKNAME SECONDS INFO))
(define-irc-reply RPL-ENDOFWHOIS 318 ("([^ ]+) (:.*)" NICKNAME INFO))
(define-irc-reply RPL-WHOISCHANNELS 319 ("([^ ]+) (:.*)" NICKNAME INFO))
(define-irc-reply RPL-LISTSTART 321 ("Channels (:.*)" INFO))
(define-irc-reply RPL-LIST 322 ("([^ ]+) ([^ ]+) (:.*)" CHANNEL VISIBLE-COUNT INFO) (irc-channel-event))
(define-irc-reply RPL-LISTEND 323 ("(:.*)" INFO))
(define-irc-reply RPL-CHANNELMODEIS 324 ("([^ ]+) ([^ ]+) ([^ ]+)" CHANNEL MODE MODE-PARAMS) (irc-channel-event))
(define-irc-reply RPL-UNIQOPIS 325 ("([^ ]+) ([^ ]+)" CHANNEL NICKNAME) (irc-channel-event))
(define-irc-reply RPL-NOCHANPASS 326 ())
(define-irc-reply RPL-CHPASSUNKNOWN 327 ())
(define-irc-reply RPL-CHANNEL-URL 328 ())
(define-irc-reply RPL-CREATIONTIME 329 ())
(define-irc-reply RPL-NOTOPIC 331 ("([^ ]+) (:.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply RPL-TOPIC 332 ("([^ ]+) (:.*)" CHANNEL TOPIC) (irc-channel-event))
(define-irc-reply RPL-TOPICWHOTIME 333 ())
(define-irc-reply RPL-WHOISBOT 335 ())
(define-irc-reply RPL-BADCHANPASS 339 ())
(define-irc-reply RPL-USERIP 340 ())
(define-irc-reply RPL-INVITING 341 ("([^ ]+) ([^ ]+)" NICKNAME CHANNEL) (irc-channel-event))
(define-irc-reply RPL-SUMMONING 342 ("([^ ]+) (:.*)" USERNAME INFO))
(define-irc-reply RPL-INVITED 345 ("([^ ]+) ([^ ]+) ([^ ]+) (:.*)" CHANNEL USER-BEING-INVITED USER-ISSUING-INVITE INFO) (irc-channel-event))
(define-irc-reply RPL-INVITELIST 346 ("([^ ]+) ([^ ]+)" CHANNEL INVITEMASK) (irc-channel-event))
(define-irc-reply RPL-ENDOFINVITELIST 347 ("([^ ]+) (:.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply RPL-EXCEPTLIST 348 ("([^ ]+) ([^ ]+)" CHANNEL EXCEPTIONMASK) (irc-channel-event))
(define-irc-reply RPL-ENDOFEXCEPTLIST 349 ("([^ ]+) (:.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply RPL-VERSION 351 ("([^. ]+)(\\.([^ ]+))? ([^ ]+) (:.*)" VERSION NIL DEBUGLEVEL SERVER INFO))
(define-irc-reply RPL-WHOREPLY 352 ("([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^*@+ ]+\\*?[@+]?) (:.*)" CHANNEL USERNAME HOST SERVER NICKNAME HG INFO) (irc-channel-event))
(define-irc-reply RPL-NAMREPLY 353 ("[=*@] ([^ ]+) :(.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply RPL-WHOSPCRPL 354 ())
(define-irc-reply RPL-NAMREPLY- 355 ("[=*@] ([^ ]+) :(.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply RPL-MAP 357 ())
(define-irc-reply RPL-MAPMORE 358 ())
(define-irc-reply RPL-MAPEND 359 ())
(define-irc-reply RPL-KILLDONE 361 ())
(define-irc-reply RPL-CLOSING 362 ())
(define-irc-reply RPL-CLOSEEND 363 ())
(define-irc-reply RPL-LINKS 364 ("([^ ]+) ([^ ]+) (:.*)" MASK SERVER INFO))
(define-irc-reply RPL-ENDOFLINKS 365 ("([^ ]+) (:.*)" MASK INFO))
(define-irc-reply RPL-ENDOFNAMES 366 ("([^ ]+) (:.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply RPL-BANLIST 367 ("([^ ]+) ([^ ]+)( ([^ ]+) (:.*))?" CHANNEL BANID TIME-LEFT INFO) (irc-channel-event))
(define-irc-reply RPL-ENDOFBANLIST 368 ("([^ ]+) (:.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply RPL-ENDOFWHOWAS 369 ("([^ ]+) (:.*)" NICKNAME INFO))
(define-irc-reply RPL-INFO 371 ("(:.*)" INFO))
(define-irc-reply RPL-MOTD 372 ("(:.*)" INFO))
(define-irc-reply RPL-INFOSTART 373 ())
(define-irc-reply RPL-ENDOFINFO 374 ("(:.*)" INFO))
(define-irc-reply RPL-MOTDSTART 375 ("(:.*)" INFO))
(define-irc-reply RPL-ENDOFMOTD 376 ("(:.*)" INFO))
(define-irc-reply RPL-YOUREOPER 381 ("(:.*)" INFO))
(define-irc-reply RPL-REHASHING 382 ("([^ ]+) (:.*)" CONFIG-FILE INFO))
(define-irc-reply RPL-YOURESERVICE 383 ("(:.*)" INFO))
(define-irc-reply RPL-MYPORTIS 384 ())
(define-irc-reply RPL-NOTOPERANYMORE 385 ())
(define-irc-reply RPL-ALIST 388 ())
(define-irc-reply RPL-ENDOFALIST 389 ())
(define-irc-reply RPL-TIME 391 ("([^ ]+) (:.*)" SERVER INFO))
(define-irc-reply RPL-USERSSTART 392 ("(:.*)" INFO))
(define-irc-reply RPL-USERS 393 ("(:.*)" INFO))
(define-irc-reply RPL-ENDOFUSERS 394 ("(:.*)" INFO))
(define-irc-reply RPL-NOUSERS 395 ("(:.*)" INFO))
(define-irc-reply RPL-HOSTHIDDEN 396 ())
(define-irc-reply ERR-UNKNOWNERROR 400 ("([^ ]+)( ?)? (:.*)" COMMAND ? INFO))
(define-irc-reply ERR-NOSUCHNICK 401 ("([^ ]+) (:.*)" NICKNAME INFO))
(define-irc-reply ERR-NOSUCHSERVER 402 ("([^ ]+) (:.*)" SERVER INFO))
(define-irc-reply ERR-NOSUCHCHANNEL 403 ("([^ ]+) (:.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply ERR-CANNOTSENDTOCHAN 404 ("([^ ]+) (:.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply ERR-TOOMANYCHANNELS 405 ("([^ ]+) (:.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply ERR-WASNOSUCHNICK 406 ("([^ ]+) (:.*)" NICKNAME INFO))
(define-irc-reply ERR-TOOMANYTARGETS 407 ("([^ ]+) (:.*)" TARGET INFO))
(define-irc-reply ERR-NOSUCHSERVICE 408 ("([^ ]+) (:.*)" SERVICE-NAME INFO))
(define-irc-reply ERR-NOORIGIN 409 ("(:.*)" INFO))
(define-irc-reply ERR-NORECIPIENT 411 ("(:.*)" INFO))
(define-irc-reply ERR-NOTEXTTOSEND 412 ("(:.*)" INFO))
(define-irc-reply ERR-NOTOPLEVEL 413 ("([^ ]+) (:.*)" MASK INFO))
(define-irc-reply ERR-WILDTOPLEVEL 414 ("([^ ]+) (:.*)" MASK INFO))
(define-irc-reply ERR-BADMASK 415 ("([^ ]+) (:.*)" MASK INFO))
(define-irc-reply ERR-LENGTHTRUNCATED 419 ())
(define-irc-reply ERR-UNKNOWNCOMMAND 421 ("([^ ]+) (:.*)" COMMAND INFO))
(define-irc-reply ERR-NOMOTD 422 ("(:.*)" INFO))
(define-irc-reply ERR-NOADMININFO 423 ("([^ ]+) (:.*)" SERVER INFO))
(define-irc-reply ERR-FILEERROR 424 ("(:.*)" INFO))
(define-irc-reply ERR-NOOPERMOTD 425 ())
(define-irc-reply ERR-TOOMANYAWAY 429 ())
(define-irc-reply ERR-EVENTNICKCHANGE 430 ())
(define-irc-reply ERR-NONICKNAMEGIVEN 431 ("(:.*)" INFO))
(define-irc-reply ERR-ERRONEUSNICKNAME 432 ("([^ ]+) (:.*)" NICKNAME INFO))
(define-irc-reply ERR-NICKNAMEINUSE 433 ("([^ ]+) (:.*)" NICKNAME INFO))
(define-irc-reply ERR-NICKCOLLISION 436 ("([^ ]+) (:.*)" NICKNAME INFO))
(define-irc-reply ERR-UNAVAILRESOURCE 437 ("([^ ]+) (:.*)" RESOURCE INFO))
(define-irc-reply ERR-TARGETTOOFAST 439 ())
(define-irc-reply ERR-SERVICESDOWN 440 ())
(define-irc-reply ERR-USERNOTINCHANNEL 441 ("([^ ]+) ([^ ]+) (:.*)" NICKNAME CHANNEL INFO) (irc-channel-event))
(define-irc-reply ERR-NOTONCHANNEL 442 ("([^ ]+) (:.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply ERR-USERONCHANNEL 443 ("([^ ]+) ([^ ]+)( :(.*))?" NICKNAME CHANNEL NIL INFO) (irc-channel-event))
(define-irc-reply ERR-NOLOGIN 444 ("([^ ]+) (:.*)" USERNAME INFO))
(define-irc-reply ERR-SUMMONDISABLED 445 ("(:.*)" INFO))
(define-irc-reply ERR-USERSDISABLED 446 ("(:.*)" INFO))
(define-irc-reply ERR-NONICKCHANGE 447 ())
(define-irc-reply ERR-NOTIMPLEMENTED 449 ())
(define-irc-reply ERR-NOTREGISTERED 451 ("(:.*)" INFO))
(define-irc-reply ERR-IDCOLLISION 452 ())
(define-irc-reply ERR-NICKLOST 453 ())
(define-irc-reply ERR-HOSTILENAME 455 ())
(define-irc-reply ERR-ACCEPTFULL 456 ())
(define-irc-reply ERR-ACCEPTEXIST 457 ())
(define-irc-reply ERR-ACCEPTNOT 458 ())
(define-irc-reply ERR-NOHIDING 459 ())
(define-irc-reply ERR-NOTFORHALFOPS 460 ())
(define-irc-reply ERR-NEEDMOREPARAMS 461 ("([^ ]+) (:.*)" COMMAND INFO))
(define-irc-reply ERR-ALREADYREGISTERED 462 ("(:.*)" INFO))
(define-irc-reply ERR-NOPERMFORHOST 463 ("(:.*)" INFO))
(define-irc-reply ERR-PASSWDMISMATCH 464 ("(:.*)" INFO))
(define-irc-reply ERR-YOUREBANNEDCREEP 465 ("(:.*)" INFO))
(define-irc-reply ERR-YOUWILLBEBANNED 466 ())
(define-irc-reply ERR-KEYSET 467 ("([^ ]+) (:.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply ERR-LINKSET 469 ())
(define-irc-reply ERR-CHANNELISFULL 471 ("([^ ]+) (:.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply ERR-UNKNOWNMODE 472 ("([^ ]+) (:.*)" CHAR INFO))
(define-irc-reply ERR-INVITEONLYCHAN 473 ("([^ ]+) (:.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply ERR-BANNEDFROMCHAN 474 ("([^ ]+) (:.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply ERR-BADCHANNELKEY 475 ("([^ ]+) (:.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply ERR-BADCHANMASK 476 ("([^ ]+) (:.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply ERR-NOCHANMODES 477 ("([^ ]+) (:.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply ERR-BANLISTFULL 478 ("([^ ]+) ([^ ]+) (:.*)" CHANNEL CHAR INFO) (irc-channel-event))
(define-irc-reply ERR-NOPRIVILEGES 481 ("(:.*)" INFO))
(define-irc-reply ERR-CHANOPRIVSNEEDED 482 ("([^ ]+) (:.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply ERR-CANTKILLSERVER 483 ("(:.*)" INFO))
(define-irc-reply ERR-RESTRICTED 484 ("(:.*)" INFO))
(define-irc-reply ERR-UNIQOPRIVSNEEDED 485 ("(:.*)" INFO))
(define-irc-reply ERR-TSLESSCHAN 488 ())
(define-irc-reply ERR-NOOPERHOST 491 ("(:.*)" INFO))
(define-irc-reply ERR-NOSERVICEHOST 492 ())
(define-irc-reply ERR-NOFEATURE 493 ())
(define-irc-reply ERR-BADFEATURE 494 ())
(define-irc-reply ERR-BADLOGTYPE 495 ())
(define-irc-reply ERR-BADLOGSYS 496 ())
(define-irc-reply ERR-BADLOGVALUE 497 ())
(define-irc-reply ERR-ISOPERLCHAN 498 ())
(define-irc-reply ERR-CHANOWNPRIVNEEDED 499 ())
(define-irc-reply ERR-UMODEUNKNOWNFLAG 501 ("(:.*)" INFO))
(define-irc-reply ERR-USERSDONTMATCH 502 ("(:.*)" INFO))
(define-irc-reply ERR-USERNOTONSERV 504 ())
(define-irc-reply ERR-SILELISTFULL 511 ())
(define-irc-reply ERR-TOOMANYWATCH 512 ())
(define-irc-reply ERR-BADPING 513 ())
(define-irc-reply ERR-BADEXPIRE 515 ())
(define-irc-reply ERR-DONTCHEAT 516 ())
(define-irc-reply ERR-DISABLED 517 ("([^ ]+) (:.*)" COMMAND INFO))
(define-irc-reply ERR-LISTSYNTAX 521 ())
(define-irc-reply ERR-WHOSYNTAX 522 ())
(define-irc-reply ERR-WHOLIMEXCEED 523 ())
(define-irc-reply ERR-REMOTEPFX 525 ("([^ ]+) (:.*)" NICKNAME INFO))
(define-irc-reply ERR-PFXUNROUTABLE 526 ("([^ ]+) (:.*)" NICKNAME INFO))
(define-irc-reply ERR-BADHOSTMASK 550 ())
(define-irc-reply ERR-HOSTUNAVAIL 551 ())
(define-irc-reply ERR-USINGSLINE 552 ())
(define-irc-reply ERR-STATSSLINE 553 ())
(define-irc-reply RPL-LOGON 600 ())
(define-irc-reply RPL-LOGOFF 601 ())
(define-irc-reply RPL-WATCHOFF 602 ())
(define-irc-reply RPL-WATCHSTAT 603 ())
(define-irc-reply RPL-NOWON 604 ())
(define-irc-reply RPL-NOWOFF 605 ())
(define-irc-reply RPL-WATCHLIST 606 ())
(define-irc-reply RPL-ENDOFWATCHLIST 607 ())
(define-irc-reply RPL-WATCHCLEAR 608 ())
(define-irc-reply RPL-ISLOCOP 611 ())
(define-irc-reply RPL-ISNOTOPER 612 ())
(define-irc-reply RPL-ENDOFISOPER 613 ())
(define-irc-reply RPL-WHOISHOST 616 ())
(define-irc-reply RPL-DCCLIST 618 ())
(define-irc-reply RPL-RULES 621 ())
(define-irc-reply RPL-ENDOFRULES 622 ())
(define-irc-reply RPL-MAPMORE 623 ())
(define-irc-reply RPL-OMOTDSTART 624 ())
(define-irc-reply RPL-OMOTD 625 ())
(define-irc-reply RPL-ENDOFO 626 ())
(define-irc-reply RPL-SETTINGS 630 ())
(define-irc-reply RPL-ENDOFSETTINGS 631 ())
(define-irc-reply RPL-DUMPING 640 ())
(define-irc-reply RPL-DUMPRPL 641 ())
(define-irc-reply RPL-EODUMP 642 ())
(define-irc-reply RPL-TRACEROUTE-HOP 660 ("([^ ]+) ([^ ]+) (([^ ]+)( ([^ ]+|\\*))? (.+))?" TARGET HOP-COUNT NIL ADDRESS NIL HOSTNAME USEC-PING))
(define-irc-reply RPL-TRACEROUTE-START 661 ("([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+)" TARGET TARGET-FQDN TARGET-ADDRESS MAX-HOPS))
(define-irc-reply RPL-MODECHANGEWARN 662 ("([+-]?[^ ]+) (:.*)" MODE-CHAR INFO))
(define-irc-reply RPL-CHANREDIR 663 ("([^ ]+) ([^ ]+) (:.*)" OLD-CHAN NEW-CHAN INFO))
(define-irc-reply RPL-SERVMODEIS 664 ("([^ ]+) ([^ ]+) ([^.]+).." SERVER MODES PARAMETERS))
(define-irc-reply RPL-OTHERUMODEIS 665 ("([^ ]+) ([^ ]+)" NICKNAME MODES))
(define-irc-reply RPL-ENDOF-GENERIC 666 ("([^ ]+) (([^ ]+))* (:.*)" COMMAND PARAMETER INFO))
(define-irc-reply RPL-WHOWASDETAILS 670 ("([^ ]+) ([^ ]+) (:.*)" NICKNAME TYPE INFO))
(define-irc-reply RPL-WHOISSECURE 671 ("([^ ]+) ([^ ]+)( :(.*))?" NICKNAME TYPE NIL INFO))
(define-irc-reply RPL-UNKNOWNMODES 672 ("([^ ]+) (:.*)" MODES INFO))
(define-irc-reply RPL-CANNOTSETMODES 673 ("([^ ]+) (:.*)" MODES INFO))
(define-irc-reply RPL-LUSERSTAFF 678 ("([^ ]+) (:.*)" STAFF-ONLINE-COUNT INFO))
(define-irc-reply RPL-TIMEONSERVERIS 679 ("([^ ]+)( ([^ ]+|0))? ([^ ]+) ([^ ]+) (:.*)" SECONDS NIL NANOSECONDS TIMEZONE FLAGS INFO))
(define-irc-reply RPL-NETWORKS 682 ("([^ ]+) ([^ ]+) ([^ ]+) (:.*)" NAME THROUGH-NAME HOPS INFO))
(define-irc-reply RPL-YOURLANGUAGEIS 687 ("([^ ]+) (:.*)" CODES INFO))
(define-irc-reply RPL-LANGUAGE 688 ("([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) * (:.*)" LANGUAGE-CODE REVISION MAINTAINER FLAGS INFO))
(define-irc-reply RPL-WHOISSTAFF 689 ("(:.*)" INFO))
(define-irc-reply RPL-WHOISLANGUAGE 690 ("([^ ]+) ([^ ]+)" NICKNAME LANGUAGE-CODES))
(define-irc-reply RPL-MODLIST 702 ())
(define-irc-reply RPL-ENDOFMODLIST 703 ("(:.*)" INFO))
(define-irc-reply RPL-HELPSTART 704 ("([^ ]+) (:.*)" COMMAND INFO))
(define-irc-reply RPL-HELPTXT 705 ("([^ ]+) (:.*)" COMMAND INFO))
(define-irc-reply RPL-ENDOFHELP 706 ("([^ ]+) (:.*)" COMMAND INFO))
(define-irc-reply RPL-ETRACEFULL 708 ())
(define-irc-reply RPL-ETRACE 709 ())
(define-irc-reply RPL-KNOCK 710 ("([^ ]+) ([^!]+)!([^@]+)@([^ ]+) (:.*)" CHANNEL NICKNAME USERNAME HOST INFO) (irc-channel-event))
(define-irc-reply RPL-KNOCKDLVR 711 ("([^ ]+) (:.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply ERR-TOOMANYKNOCK 712 ("([^ ]+) (:.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply ERR-CHANOPEN 713 ("([^ ]+) (:.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply ERR-KNOCKONCHAN 714 ("([^ ]+) (:.*)" CHANNEL INFO) (irc-channel-event))
(define-irc-reply ERR-KNOCKDISABLED 715 ("(:.*)" INFO))
(define-irc-reply RPL-TARGUMODEG 716 ("([^ ]+) (:.*)" NICKNAME INFO))
(define-irc-reply RPL-TARGNOTIFY 717 ("([^ ]+) (:.*)" NICKNAME INFO))
(define-irc-reply RPL-UMODEGMSG 718 ("([^ ]+) ([^@]+)@([^ ]+) (:.*)" NICKNAME USERNAME HOST INFO))
(define-irc-reply RPL-OMOTDSTART 720 ("(:.*)" INFO))
(define-irc-reply RPL-OMOTD 721 ("(:.*)" INFO))
(define-irc-reply RPL-ENDOFOMOTD 722 ("(:.*)" INFO))
(define-irc-reply ERR-NOPRIVS 723 ("([^ ]+) (:.*)" COMMAND INFO))
(define-irc-reply RPL-TESTMARK 724 ("([^!]+)!([^@]+)@([^ ]+) ([^ ]+) ([^ ]+) (:.*)" NICKNAME USERNAME HOST A B INFO))
(define-irc-reply RPL-TESTLINE 725 ())
(define-irc-reply RPL-NOTESTLINE 726 ("([^ ]+) (:.*)" INT INFO))
(define-irc-reply RPL-XINFO 771 ())
(define-irc-reply RPL-XINFOSTART 773 ())
(define-irc-reply RPL-XINFOEND 774 ())
(define-irc-reply RPL-LOGGEDIN 900 ())
(define-irc-reply RPL-LOGGEDOUT 901 ())
(define-irc-reply ERR-NICKLOCKED 902 ())
(define-irc-reply ERR-CANNOTDOCOMMAND 972 ())
(define-irc-reply ERR-CANNOTCHANGEUMODE 973 ("([^ ]+) (:.*)" MODE-CHAR INFO))
(define-irc-reply ERR-CANNOTCHANGECHANMODE 974 ("([^ ]+) (:.*)" MODE-CHAR INFO))
(define-irc-reply ERR-CANNOTCHANGESERVERMODE 975 ("([^ ]+) (:.*)" MODE-CHAR INFO))
(define-irc-reply ERR-CANNOTSENDTONICK 976 ("([^ ]+) (:.*)" NICKNAME INFO))
(define-irc-reply ERR-UNKNOWNSERVERMODE 977 ("([^ ]+) (:.*)" MODECHAR INFO))
(define-irc-reply ERR-SERVERMODELOCK 979 ("([^ ]+) (:.*)" TARGET INFO))
(define-irc-reply ERR-BADCHARENCODING 980 ("([^ ]+) ([^ ]+) (:.*)" COMMAND CHARSET INFO))
(define-irc-reply ERR-TOOMANYLANGUAGES 981 ("([^ ]+) (:.*)" MAX-LANGS INFO))
(define-irc-reply ERR-NOLANGUAGE 982 ("([^ ]+) (:.*)" LANGUAGE-CODE INFO))
(define-irc-reply ERR-TEXTTOOSHORT 983 ("([^ ]+) (:.*)" COMMAND INFO))
(define-irc-reply ERR-NUMERIC-ERR 999 ())

;; Implement reply
(defmethod reply ((event reply-event) fmst &rest args)
  (irc:privmsg (client event) (name (user event)) (apply #'format NIL fmst args)))

(defmethod reply ((event irc-channel-event) fmst &rest args)
  ;; If the channel is a user (us), we need to reply to them directly.
  (cond ((typep (channel event) 'user)
         (irc:privmsg (client event) (name (user event)) (apply #'format NIL fmst args)))
        (T
         (irc:privmsg (client event) (name (channel event)) (apply #'format NIL fmst args)))))
