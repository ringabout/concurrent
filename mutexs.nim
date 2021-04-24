import std/locks
import std/rlocks

type
  Mutex* = object
    lock: Lock ## Nim lock; whether this is re-entrant
                  ## or not is unspecified!

  RecursiveMutex* = object
    lock: RLock

proc init*(mutex: var Mutex) {.inline.} =
  ## Initializes the given lock.
  initLock(mutex.lock)

proc `=copy`*(x: var Mutex, y: Mutex) {.error.}

proc `=destroy`*(mutex: var Mutex) {.inline.} =
  ## Frees the resources associated with the lock.
  deinitLock(mutex.lock)

proc tryAcquire*(mutex: var Mutex): bool {.inline.} =
  ## Tries to acquire the given lock. Returns `true` on success.
  result = tryAcquire(mutex.lock)

proc acquire*(mutex: var Mutex) {.inline.} =
  ## Acquires the given lock.
  acquire(mutex.lock)

proc release*(mutex: var Mutex) {.inline.} =
  ## Releases the given lock.
  release(mutex.lock)

proc init*(mutex: var RecursiveMutex) {.inline.} =
  ## Initializes the given lock.
  initRLock(mutex.lock)

proc `=destroy`*(mutex: var RecursiveMutex) {.inline.} =
  ## Frees the resources associated with the lock.
  deinitRlock(mutex.lock)

proc tryAcquire*(mutex: var RecursiveMutex): bool {.inline.} =
  ## Tries to acquire the given lock. Returns `true` on success.
  result = tryAcquire(mutex.lock)

proc acquire*(mutex: var RecursiveMutex) {.inline.} =
  ## Acquires the given lock.
  acquire(mutex.lock)

proc release*(mutex: var RecursiveMutex) {.inline.} =
  ## Releases the given lock.
  release(mutex.lock)
