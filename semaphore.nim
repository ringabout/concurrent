import nlock

type
  Semaphore* = object
    c: Cond
    L: Lock
    counter: int

proc `=copy`*(x: var Semaphore, y: Semaphore) {.error.}

proc `=destroy`*(cv: var Semaphore) =
  `=destroy`(cv.c)
  `=destroy`(cv.L)

proc init*(cv: var Semaphore) =
  init(cv.c)
  init(cv.L)

proc blockUntil*(cv: var Semaphore) =
  acquire(cv.L)
  while cv.counter <= 0:
    wait(cv.c, cv.L)
  dec cv.counter
  release(cv.L)

proc signal*(cv: var Semaphore) =
  acquire(cv.L)
  inc cv.counter
  release(cv.L)
  signal(cv.c)
