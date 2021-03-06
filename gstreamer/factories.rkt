#lang racket/base

(require ffi/unsafe/introspection
         racket/class
         racket/contract
         (only-in racket/list first last)
         "private/core.rkt"
         gstreamer/clock
         gstreamer/element
         gstreamer/bin
         gstreamer/pipeline
         gstreamer/device)

(provide (contract-out [element-factory%-find
                        (-> string? (or/c false/c
                                          (is-a?/c element-factory%)))]
                       [element-factory%-make
                        (->* (string?)
                             ((or/c string? false/c)
                              #:class (subclass?/c element%))
                             (or/c false/c
                                   (is-a?/c element%)))]
                       [pad%-new-from-template
                        (->* (pad-template?)
                             ((or/c string? false/c))
                             (or/c (is-a?/c pad%)
                                   false/c))]
                       [ghost-pad%-new
                        (-> (or/c string? false/c) (is-a?/c pad%)
                            (or/c (is-a?/c ghost-pad%)
                                  false/c))]
                       [ghost-pad%-new-no-target
                        (-> (or/c string? false/c) pad-direction?
                            (or/c (is-a?/c ghost-pad%)
                                  false/c))]
                       [bin%-new
                        (->* ()
                             ((or/c string? false/c))
                             (is-a?/c bin%))]
                       [bin%-compose
                        (-> (or/c string? false/c)
                            (is-a?/c element%) (is-a?/c element%) ...
                            (or/c (is-a?/c bin%) false/c))]
                       [pipeline%-new
                        (->* ()
                             ((or/c string? false/c))
                             (is-a?/c pipeline%))]
                       [pipeline%-compose
                        (-> (or/c string? false/c)
                            (is-a?/c element%) ...
                            (or/c (is-a?/c pipeline%) false/c))]
                       [obtain-system-clock
                        (-> (is-a?/c clock%))]
                       [parse/launch
                        (-> string? (or/c (is-a?/c element%) false/c))]
                       [device-monitor%-new
                        (-> (is-a?/c device-monitor%))]))

(define (element-factory%-find name)
  (let ([factory (gst-element-factory 'find name)])
    (and factory
         (new element-factory% [pointer factory]))))

(define (element-factory%-make factory-name [name #f]
                               #:class [factory% element%])
  (let ([el (gst-element-factory 'make factory-name name)])
    (and el
         (new factory% [pointer el]))))

(define (pad%-new-from-template templ [name #f])
  (let ([pad (gst-pad 'new_from_template templ name)])
    (and pad
         (new pad% [pointer pad]))))

(define (ghost-pad%-new name target)
  (let ([ghost (gst-ghost-pad 'new name target)])
    (and ghost
         (new ghost-pad% [pointer ghost]))))

(define (ghost-pad%-new-no-target name dir)
  (let ([ghost (gst-ghost-pad 'new_no_target name dir)])
    (and ghost
         (new ghost-pad% [pointer ghost]))))

(define (bin%-new [name #f])
  (new bin% [pointer (gst-bin 'new name)]))

(define (bin%-compose name el . els)
  (let* ([bin (bin%-new name)]
         [sink el]
         [source (if (null? els) el (last els))])
    (and (send/apply bin add-many el els)
         (when (pair? els)
           (send/apply el link-many els))
         (let ([sink-pad (send sink get-static-pad "sink")])
           (when sink-pad
             (send bin add-pad (ghost-pad%-new "sink" sink-pad))))
         (let ([source-pad (send source get-static-pad "src")])
           (when source-pad
             (send bin add-pad (ghost-pad%-new "src" source-pad))))
         bin)))

(define (pipeline%-new [name #f])
  (new pipeline% [pointer (gst-pipeline 'new name)]))

(define (pipeline%-compose name . els)
  (let* ([pl (pipeline%-new name)]
         [bin (apply bin%-compose #f els)])
    (and bin
         (send pl add bin)
         pl)))

(define (obtain-system-clock)
  (new clock% [pointer ((gst 'SystemClock) 'obtain)]))

(define (parse/launch description)
  (let ([parsed ((gst 'parse_launch) description)])
    (and parsed
         (new element% [pointer parsed]))))

(define (device-monitor%-new)
  (let ([monitor ((gst 'DeviceMonitor) 'new)])
    (new device-monitor% [pointer monitor])))
