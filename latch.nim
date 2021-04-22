import nlock
import utils

# Locked based barrier
type
  Latch* = object of NonCopyable
    cond: Cond
    lock: Lock
    count: int

proc init*(x: var Latch, count: int) =
  init(x.cond)
  init(x.lock)
  x.count = count

proc `=destroy`*(x: var Latch) =
  `=destroy`(x.cond)
  `=destroy`(x.lock)

proc dec*(x: var Latch) =
  acquire x.lock
  dec x.count
  if x.count == 0:
    broadcast(x.cond)
  release x.lock

proc wait*(x: var Latch) =
  acquire x.lock
  while x.count != 0:
    x.cond.wait(x.lock)
  release x.lock


proc main() =
  var x: Latch
  init(x, 10)
  var y = x
  var z = y


main()


type
  Barrier* = object of Latch
    generation: int
    size: int


proc init*(x: var Barrier, count: int) =
  init(x.cond)
  init(x.lock)
  x.count = count
  x.size = count
  x.generation = 0

proc wait*(x: var Barrier) =
  withLock x.lock:
    dec x.count
    if x.count == 0:
      inc x.generation
      x.count = x.size
      broadcast(x.cond)
    else:
      let generation = x.generation
      while generation == x.generation:
        x.cond.wait(x.lock)


when isMainModule:
  import std/threadpool

  block:
    var workDone: Latch
    var cleanup: Latch

    init(workDone, 3)
    init(cleanup, 1)

    proc hello(name: string) =
      echo "work: " & name
      dec workDone
      wait cleanup
      echo "clean: " & name


    spawn hello("1")
    spawn hello("2")
    spawn hello("3")

    workDone.wait()

    dec cleanup

    sync()

  block:
    var workDone: Barrier

    init(workDone, 3)

    proc hello(name: string) =
      echo "work: " & name
      wait workDone
      echo "clean: " & name


    spawn hello("1")
    spawn hello("2")
    spawn hello("3")

    sync()


# import atom

# type
#   Latch* = object
#     value: Atomic[int]


# proc `=copy`*(x: var Latch, y: Latch) {.error.}

# proc init*(latch: var Latch, count: int) =
#   latch.value.store(count, moRelaxed)

# proc countDown(latch: var Latch, value = 1) =
#   if fetchSub(latch.value, value, moRelease) == 1:
#     broadcast(latch.value)

# proc tryWait(latch: var Latch): bool =
#   latch.value.load(moAcquire) == 0

# proc wait(latch: var Latch) =
#   latch.value.wait()