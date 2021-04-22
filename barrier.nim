block: # Locked based barrier
  type
    Barrier = object



# import nlock

# type
#   Barrier* = object
#     counter: int
#     cv: Cond
#     size: int

# proc `=copy`*(x: var Barrier, y: Barrier) {.error.}

# proc `=destroy`*(b: var Barrier) =
#   `=destroy`(b.cv)

# proc init*(b: var Barrier, size: int) =
#   b.counter = 0
#   b.cv.init

# proc enter*(b: var Barrier) =
#   atomicInc b.counter

# proc leave*(b: var Barrier) =
#   atomicDec b.counter
#   if b.counter <= 0: signal(b.cv)
