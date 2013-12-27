(c-declare #<<c-declare-end

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include "table.h"

typedef struct { int x; int y; } point;
typedef struct { point center; int radius; } circle;
// Running out of ideas here...
typedef struct { circle c1; circle c2; } two_circles;

int rc(void *ptr) {
    return (___CAST(___rc_header*,ptr) - 1)->refcount;
}

___SCMOBJ release_root(void *ptr) {
    printf("*** BYE! cc (but not necessarily the memory it manages)\n");
    printf("Refcount becomes %d\n", rc(ptr)-1);
    ___EXT(___release_rc)(ptr);
    return ___FIX(___NO_ERR);
}

___SCMOBJ release_dependency(void *ptr) {
    printf("*** BYE! some foreign object pointing to %p; ", ptr);
    table_entry *e;
    e = table_get(ptr);
    assert(e);
    if (--e->refcount > 0) {
        printf("decreasing INTERNAL count to %d\n",
               e->refcount);
    } else {
        printf("no more references via this address; ");
        printf("ROOT's refcount becomes %d\n", rc(e->root) - 1);
        ___EXT(___release_rc)(e->root);
        table_remove(ptr);
    }
    table_print();
    return ___FIX(___NO_ERR);
}

void register_dependency(void *address, void *target) {
    table_entry *e;
    e = table_get(address);
    if (e) {
        e->refcount++;
        printf("increasing INTERNAL count for reference from %p to %p to %d\n",
               e->key,
               e->root,
               e->refcount);
        table_print();
        return;
    }
    e = table_get(target);
    void *root = e ? e->root : target;
    table_put(address, root);
    ___EXT(___addref_rc)(root);
    printf("adding new reference from %p to %p; new ROOT refcount is %d\n",
           address,
           root,
           rc(root));
    table_print();
}

c-declare-end
)

(c-define-type void* (pointer void #f))

(define register-dependency!
  (c-lambda (void* void*) void "register_dependency"))

(c-define-type two-circles
               ; We only set a finalizer here in order to get a printout; the
               ; default finalizer would work.
               (type "two_circles" (two_circles) "release_root"))
(c-define-type dependent-circle
               (pointer "circle" (circle* circle) "release_dependency"))
(c-define-type dependent-point
               (pointer "point" (point* point) "release_dependency"))

(define make-two-circles
  (c-lambda () two-circles
    ; This is the only allocation of C data in this example.
    "___result_voidstar = ___EXT(___alloc_rc)(sizeof(two_circles));"))

; Initialization of fields, accessors and printers omitted for brevity.

(define (first-circle cc)
  (let ((ret ((c-lambda (two-circles) dependent-circle
                "___result_voidstar = &((two_circles*)___arg1_voidstar)->c1;")
              cc)))
    (register-dependency! ret cc)
    ret))

(define (second-circle cc)
  (let ((ret ((c-lambda (two-circles) dependent-circle
                "___result_voidstar = &((two_circles*)___arg1_voidstar)->c2;")
              cc)))
    (register-dependency! ret cc)
    ret))

(define (circle-center c)
  (let ((ret
         ; A dependent-circle will be accepted here as well.
        ((c-lambda ((pointer "circle")) dependent-point
          "___result_voidstar = &((circle*)___arg1_voidstar)->center;")
         c)))
    (register-dependency! ret c)
    ret))

(define (gc-for-good-measure)
  ; Perform more than enough garbage collections to convince us that an object
  ; will remain reachable indefinitely until we severe more references to it.
  (let loop ((i 100))
    (##gc)
    (if (> i 0)
      (loop (- i 1)))))

; This would be the only foreign holding actual memory.
(newline)
(println "Creating cc...")
(define cc (make-two-circles))

; Dependent.
(newline)
(println "Creating c1...")
(define c1 (first-circle cc))
; Transitively dependent.
(newline)
(println "Creating c1-center...")
(define c1-center (circle-center c1))
; More than one dependency on the same object.
(newline)
(println "Creating c2...")
(define c2 (second-circle cc))

(newline)
(println "addresses are:")
(for-each
  (lambda (name)
    (let ((foreign (eval name)))
      (println "   "
               name
               ": 0x"
               (number->string (foreign-address foreign) 16))))
  (list 'cc 'c1 'c2 'c1-center))

(newline)
(println "forgetting global reference to cc")
(set! cc #f)
(gc-for-good-measure)

(newline)
(println "letting go of c2")
(set! c2 #f)
(##gc)
(println "first garbage collection done")
(gc-for-good-measure)
(println "more garbage collections done; nothing should have happened here")

(newline)
(println "letting go of c1")
(set! c1 #f)
(##gc)
(println "first garbage collection done")
(gc-for-good-measure)
(println "more garbage collections done; nothing should have happened here")

(newline)
(println "letting go of c1-center")
(set! c1-center #f)
(##gc)
(println "first garbage collection done")
(println "the root's memory should have been released by now")
(gc-for-good-measure)
(println "more garbage collections done; nothing should have happened here")
(println "bye!")

