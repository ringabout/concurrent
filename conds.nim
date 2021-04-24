type
  Cond* = object
    cond: SysCond ## Nim condition variable


proc init*(cond: var Cond) {.inline.} =
  ## Initializes the given condition variable.
  initSysCond(cond.cond)

proc `=destroy`*(cond: var Cond) {.inline.} =
  ## Frees the resources associated with the condition variable.
  deinitSysCond(cond.cond)

proc wait*(cond: var Cond, lock: var Mutex) {.inline.} =
  ## waits on the condition variable `cond`.
  waitSysCond(cond.cond, lock.lock)

proc wait*(cond: var Cond, lock: var RLock) {.inline.} =
  ## waits on the condition variable `cond`.
  waitSysCond(cond.cond, lock.lock)

proc signal*(cond: var Cond) {.inline.} =
  ## sends a signal to the condition variable `cond`.
  signalSysCond(cond.cond)

proc broadcast*(cond: var Cond) {.inline.} =
  ## Unblocks all threads currently blocked on the
  ## specified condition variable `cond`.
  broadcastSysCond(cond.cond)
