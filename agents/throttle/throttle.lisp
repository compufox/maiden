#|
 This file is a part of Maiden
 (c) 2016 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.maiden.agents.throttle)

(define-consumer throttle (agent)
  ((attempts :accessor attempts)
   (time-frame :accessor time-frame)
   (cooldown-function :accessor cooldown-function)
   (cooldown-step :accessor cooldown-step)
   (cooldown-max :accessor cooldown-max)
   (records :initform (make-hash-table :test 'eql) :accessor records)))

(defmethod initialize-instance :after ((throttle throttle) &key attempts time-frame cooldown-function cooldown-step cooldown-max)
  (setf (attempts throttle) (or attempts (value :attempts) 3))
  (setf (time-frame throttle) (or time-frame (value :time-frame) 5))
  (setf (cooldown-function throttle) (or cooldown-function (value :cooldown :function) :linear))
  (setf (cooldown-step throttle) (or cooldown-step (value :cooldown :step) 10))
  (setf (cooldown-max throttle) (or cooldown-max (value :cooldown :max) (* 60 60 24))))

(defmethod (setf cooldown-function) :before (value (throttle throttle))
  (ecase value (:constant) (:linear) (:exponential)))

(define-stored-accessor throttle attempts :attempts)
(define-stored-accessor throttle time-frame :time-frame)
(define-stored-accessor throttle cooldown-function :cooldown :function)
(define-stored-accessor throttle cooldown-step :cooldown :step)
(define-stored-accessor throttle cooldown-max :cooldown :maximum)

(defmethod record (user throttle)
  (gethash user (records throttle)))

(defmethod (setf record) (value user throttle)
  (setf (gethash user (records throttle)) value))

(defclass record ()
  ((attempts :initarg :attempts :accessor attempts)
   (timestamp :initarg :timestamp :accessor timestamp)
   (timeout :initarg :timeout :accessor timeout))
  (:default-initargs
   :attempts 0
   :timestamp (get-universal-time)
   :timeout 0))

(defmethod clear-tax (user (throttle throttle))
  (setf (record user throttle) (make-instance 'record)))

(defmethod tax (user (throttle throttle))
  (let ((record (or (record user throttle)
                    (clear-tax user throttle))))
    (with-accessors ((attempts attempts) (timestamp timestamp) (timeout timeout)) record
      (cond ((< timestamp (get-universal-time) (+ timestamp timeout))
             (incf attempts)
             (let ((counter (- attempts (attempts throttle))))
               (setf timeout (min (cooldown-max throttle)
                                  (ecase (cooldown-function throttle)
                                    (:constant (cooldown-step throttle))
                                    (:linear (* (cooldown-step throttle) counter))
                                    (:exponential (expt (cooldown-step throttle) counter)))))))
            ((< timestamp (get-universal-time) (+ timestamp (time-frame throttle)))
             (incf attempts)
             (when (< (attempts throttle) attempts)
               (setf timeout (cooldown-step throttle))))
            (T
             (setf timeout 0)
             (setf attempts 1)
             (setf timestamp (get-universal-time))))
      record)))

(define-handler (throttle block-commands command-event) (c ev dispatch-event)
  :before '(:main)
  :class deeds:locally-blocking-handler
  (when (typep dispatch-event 'user-event)
    (let* ((record (tax (user dispatch-event) c)))
      (when (< 0 (timeout record))
        (reply dispatch-event "Please calm down. You are on cooldown for ~d second~:p."
               (- (+ (timestamp record) (timeout record)) (get-universal-time)))
        (cancel ev)))))
