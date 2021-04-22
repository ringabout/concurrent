import std/tasks
import system/ansi_c

import std/locks
import macros

import queue


type
  StaticThreadPool = object
    pool: seq[Thread[pointer]]
    tasks: BoundedQueue[Task]
    lock: Lock
    isStop: bool
    notEmptyCond: Cond

proc `=copy`(x: var StaticThreadPool, y: StaticThreadPool) {.error.}

proc `=destroy`(x: var StaticThreadPool) =
  `=destroy`(x.tasks)
  `=destroy`(x.notEmptyCond)

proc work(t: pointer) {.gcsafe.} =
  var pool = cast[ptr StaticThreadPool](t)
  assert pool != nil
  while true:
    withLock pool.lock:
      while pool.tasks.len == 0 and not pool.isStop:
        wait(pool.notEmptyCond, pool.lock)

      if pool.isStop:
        if pool.tasks.len != 0:
          let task = pool.tasks.pop
          release(pool.lock)
          task.invoke()
        else:
          release(pool.lock)
        break

      # if pool.tasks.len == 0:
      #   continue
      let task = pool.tasks.pop
      release(pool.lock)
      task.invoke()

proc init(result: var StaticThreadPool, num: Positive) =
  result.pool.setLen(num)
  init(result.tasks, 200)
  initLock(result.lock)
  initCond(result.notEmptyCond)

  for t in result.pool.mitems:
    createThread(t, work, cast[pointer](addr result))


macro spawn(pool: var StaticThreadPool, call: typed) =
  result = quote do:
    var task = toTask(`call`)
    withLock `pool`.lock:
      `pool`.tasks.add move task
      signal(`pool`.notEmptyCond)

proc stop(pool: var StaticThreadPool) =
  withLock pool.lock:
    pool.isStop = true
    broadcast(pool.notEmptyCond)
  for t in mitems(pool.pool):
    joinThread(t)

proc hello(a: int) = echo a


var pool: StaticThreadPool
init(pool, 12)
for i in 0 .. 10:
  pool.spawn hello(i)

proc foo(x: string) = echo x

for i in 0 .. 10:
  pool.spawn foo("string: " & $i)


import os

sleep(1000)

pool.stop()
