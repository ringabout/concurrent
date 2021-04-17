#
#
#            Nim's Runtime Library
#        (c) Copyright 2021 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

# Low level system locks and condition vars.

{.push stackTrace: off.}

when defined(windows):
  type
    Handle = int

    DWORD = int32

    SysLock {.importc: "CRITICAL_SECTION",
              header: "<windows.h>", final, pure.} = object # CRITICAL_SECTION in WinApi
      DebugInfo: pointer
      LockCount: int32
      RecursionCount: int32
      OwningThread: int
      LockSemaphore: int
      SpinCount: int

    RTL_CONDITION_VARIABLE {.importc: "RTL_CONDITION_VARIABLE", header: "synchapi.h".} = object
      thePtr {.importc: "ptr".} : Handle
    SysCond* = RTL_CONDITION_VARIABLE

  proc initSysLock(L: var SysLock) {.importc: "InitializeCriticalSection",
                                     header: "<windows.h>".}
    ## Initializes the lock `L`.

  proc tryAcquireSysAux(L: var SysLock): int32 {.importc: "TryEnterCriticalSection",
                                                 header: "<windows.h>".}
    ## Tries to acquire the lock `L`.

  proc tryAcquireSys(L: var SysLock): bool {.inline.} =
    result = tryAcquireSysAux(L) != 0'i32

  proc acquireSys(L: var SysLock) {.importc: "EnterCriticalSection",
                                    header: "<windows.h>".}
    ## Acquires the lock `L`.

  proc releaseSys(L: var SysLock) {.importc: "LeaveCriticalSection",
                                    header: "<windows.h>".}
    ## Releases the lock `L`.

  proc deinitSys(L: var SysLock) {.importc: "DeleteCriticalSection",
                                   header: "<windows.h>".}

  proc initializeConditionVariable(
    conditionVariable: var SysCond
  ) {.stdcall, noSideEffect, dynlib: "kernel32", importc: "InitializeConditionVariable".}

  proc sleepConditionVariableCS(
    conditionVariable: var SysCond,
    PCRITICAL_SECTION: SysLock,
    dwMilliseconds: int
  ): int32 {.stdcall, noSideEffect, dynlib: "kernel32", importc: "SleepConditionVariableCS".}

  proc signalSysCond(hEvent: var SysCond) {.stdcall, noSideEffect,
    dynlib: "kernel32", importc: "WakeConditionVariable".}

  proc broadcastSysCond(hEvent: var SysCond) {.stdcall, noSideEffect,
    dynlib: "kernel32", importc: "WakeAllConditionVariable".}

  proc initSysCond(cond: var SysCond) {.inline.} =
    initializeConditionVariable(cond)
  proc deinitSysCond(cond: var SysCond) {.inline.} =
    discard
  proc waitSysCond(cond: var SysCond, lock: var SysLock) =
    discard sleepConditionVariableCS(cond, lock, -1'i32)

elif defined(genode):
  const
    Header = "genode_cpp/syslocks.h"
  type
    SysLock {.importcpp: "Nim::SysLock", pure, final,
              header: Header.} = object
    SysCond {.importcpp: "Nim::SysCond", pure, final,
              header: Header.} = object

  proc initSysLock(L: var SysLock) = discard
  proc deinitSys(L: var SysLock) = discard
  proc acquireSys(L: var SysLock) {.noSideEffect, importcpp.}
  proc tryAcquireSys(L: var SysLock): bool {.noSideEffect, importcpp.}
  proc releaseSys(L: var SysLock) {.noSideEffect, importcpp.}

  proc initSysCond(L: var SysCond) = discard
  proc deinitSysCond(L: var SysCond) = discard
  proc waitSysCond(cond: var SysCond, lock: var SysLock) {.
    noSideEffect, importcpp.}
  proc signalSysCond(cond: var SysCond) {.
    noSideEffect, importcpp.}

else:
  type
    SysLockObj {.importc: "pthread_mutex_t", pure, final,
               header: """#include <sys/types.h>
                          #include <pthread.h>""".} = object

    SysLockAttr {.importc: "pthread_mutexattr_t", pure, final
               header: """#include <sys/types.h>
                          #include <pthread.h>""".} = object

    SysCondObj {.importc: "pthread_cond_t", pure, final,
               header: """#include <sys/types.h>
                          #include <pthread.h>""".} = object

    SysCondAttr {.importc: "pthread_condattr_t", pure, final
               header: """#include <sys/types.h>
                          #include <pthread.h>""".} = object

    SysLockType = distinct cint

  proc initSysLockAux(L: var SysLockObj, attr: ptr SysLockAttr) {.
    importc: "pthread_mutex_init", header: "<pthread.h>", noSideEffect.}
  proc deinitSysAux(L: var SysLockObj) {.noSideEffect,
    importc: "pthread_mutex_destroy", header: "<pthread.h>".}

  proc acquireSysAux(L: var SysLockObj) {.noSideEffect,
    importc: "pthread_mutex_lock", header: "<pthread.h>".}
  proc tryAcquireSysAux(L: var SysLockObj): cint {.noSideEffect,
    importc: "pthread_mutex_trylock", header: "<pthread.h>".}

  proc releaseSysAux(L: var SysLockObj) {.noSideEffect,
    importc: "pthread_mutex_unlock", header: "<pthread.h>".}

  when defined(ios):
    # iOS will behave badly if sync primitives are moved in memory. In order
    # to prevent this once and for all, we're doing an extra malloc when
    # initializing the primitive.
    type
      SysLock* = ptr SysLockObj
      SysCond* = ptr SysCondObj

    when not declared(c_malloc):
      proc c_malloc(size: csize_t): pointer {.
        importc: "malloc", header: "<stdlib.h>".}
      proc c_free(p: pointer) {.
        importc: "free", header: "<stdlib.h>".}

    proc initSysLock(L: var SysLock, attr: ptr SysLockAttr = nil) =
      L = cast[SysLock](c_malloc(csize_t(sizeof(SysLockObj))))
      initSysLockAux(L[], attr)

    proc deinitSys(L: var SysLock) =
      deinitSysAux(L[])
      c_free(L)

    template acquireSys(L: var SysLock) =
      acquireSysAux(L[])
    template tryAcquireSys(L: var SysLock): bool =
      tryAcquireSysAux(L[]) == 0'i32
    template releaseSys(L: var SysLock) =
      releaseSysAux(L[])
  else:
    type
      SysLock* = SysLockObj
      SysCond* = SysCondObj

    template initSysLock(L: var SysLock, attr: ptr SysLockAttr = nil) =
      initSysLockAux(L, attr)
    template deinitSys(L: var SysLock) =
      deinitSysAux(L)
    template acquireSys(L: var SysLock) =
      acquireSysAux(L)
    template tryAcquireSys(L: var SysLock): bool =
      tryAcquireSysAux(L) == 0'i32
    template releaseSys(L: var SysLock) =
      releaseSysAux(L)

  let SysLockType_Reentrant {.importc: "PTHREAD_MUTEX_RECURSIVE",
    header: "<pthread.h>".}: SysLockType
  proc initSysRLockAttr(a: var SysLockAttr) {.
    importc: "pthread_mutexattr_init", header: "<pthread.h>", noSideEffect.}
  proc setSysRLockType(a: var SysLockAttr, t: SysLockType) {.
    importc: "pthread_mutexattr_settype", header: "<pthread.h>", noSideEffect.}

  proc initSysCondAux(cond: var SysCondObj, cond_attr: ptr SysCondAttr = nil) {.
    importc: "pthread_cond_init", header: "<pthread.h>", noSideEffect.}
  proc deinitSysCondAux(cond: var SysCondObj) {.noSideEffect,
    importc: "pthread_cond_destroy", header: "<pthread.h>".}

  proc waitSysCondAux(cond: var SysCondObj, lock: var SysLockObj): cint {.
    importc: "pthread_cond_wait", header: "<pthread.h>", noSideEffect.}
  proc signalSysCondAux(cond: var SysCondObj) {.
    importc: "pthread_cond_signal", header: "<pthread.h>", noSideEffect.}
  proc broadcastSysCondAux(cond: var SysCondObj) {.
    importc: "pthread_cond_broadcast", header: "<pthread.h>", noSideEffect.}

  when defined(ios):
    proc initSysCond(cond: var SysCond, cond_attr: ptr SysCondAttr = nil) =
      cond = cast[SysCond](c_malloc(csize_t(sizeof(SysCondObj))))
      initSysCondAux(cond[], cond_attr)

    proc deinitSysCond(cond: var SysCond) =
      deinitSysCondAux(cond[])
      c_free(cond)

    template waitSysCond(cond: var SysCond, lock: var SysLock) =
      discard waitSysCondAux(cond[], lock[])
    template signalSysCond(cond: var SysCond) =
      signalSysCondAux(cond[])
    template broadcastSysCond(cond: var SysCond) =
      broadcastSysCondAux(cond[])
  else:
    template initSysCond(cond: var SysCond, cond_attr: ptr SysCondAttr = nil) =
      initSysCondAux(cond, cond_attr)
    template deinitSysCond(cond: var SysCond) =
      deinitSysCondAux(cond)

    template waitSysCond(cond: var SysCond, lock: var SysLock) =
      discard waitSysCondAux(cond, lock)
    template signalSysCond(cond: var SysCond) =
      signalSysCondAux(cond)
    template broadcastSysCond(cond: var SysCond) =
      broadcastSysCondAux(cond)

{.pop.}

type
  Lock* = object
    lock: SysLock ## Nim lock; whether this is re-entrant
                  ## or not is unspecified!
  Cond* = object
    cond: SysCond ## Nim condition variable


{.push stackTrace: off.}

proc initLock*(lock: var Lock) {.inline.} =
  ## Initializes the given lock.
  when not defined(js):
    initSysLock(lock.lock)

proc `=copy`*(x: var Lock, y: Lock) {.error.}

proc `=destroy`*(lock: var Lock) {.inline.} =
  ## Frees the resources associated with the lock.
  deinitSys(lock.lock)

proc tryAcquire*(lock: var Lock): bool =
  ## Tries to acquire the given lock. Returns `true` on success.
  result = tryAcquireSys(lock.lock)

proc acquire*(lock: var Lock) =
  ## Acquires the given lock.
  when not defined(js):
    acquireSys(lock.lock)

proc release*(lock: var Lock) =
  ## Releases the given lock.
  when not defined(js):
    releaseSys(lock.lock)

template withLock*(a: Lock, body: untyped) =
  ## Acquires the given lock, executes the statements in body and
  ## releases the lock after the statements finish executing.
  mixin acquire, release
  acquire(a)
  {.locks: [a].}:
    try:
      body
    finally:
      release(a)

proc initCond*(cond: var Cond) {.inline.} =
  ## Initializes the given condition variable.
  initSysCond(cond.cond)

proc `=destroy`*(cond: var Cond) {.inline.} =
  ## Frees the resources associated with the condition variable.
  deinitSysCond(cond.cond)

proc wait*(cond: var Cond, lock: var Lock) {.inline.} =
  ## waits on the condition variable `cond`.
  waitSysCond(cond.cond, lock.lock)

proc signal*(cond: var Cond) {.inline.} =
  ## sends a signal to the condition variable `cond`.
  signalSysCond(cond.cond)

proc broadcast*(cond: var Cond) {.inline.} =
  ## Unblocks all threads currently blocked on the
  ## specified condition variable `cond`.
  broadcastSysCond(cond.cond)


type
  RLock* = object
    lock: SysLock ## Nim lock, re-entrant

proc initRLock*(lock: var RLock) {.inline.} =
  ## Initializes the given lock.
  when defined(posix):
    var a: SysLockAttr
    initSysRLockAttr(a)
    setSysRLockType(a, SysLockType_Reentrant)
    initSysLock(lock.lock, a.addr)
  else:
    initSysLock(lock.lock)

proc `=destroy`*(lock: var RLock) {.inline.} =
  ## Frees the resources associated with the lock.
  deinitSys(lock.lock)

proc tryAcquire*(lock: var RLock): bool =
  ## Tries to acquire the given lock. Returns `true` on success.
  result = tryAcquireSys(lock.lock)

proc acquire*(lock: var RLock) =
  ## Acquires the given lock.
  acquireSys(lock.lock)

proc release*(lock: var RLock) =
  ## Releases the given lock.
  releaseSys(lock.lock)

template withRLock*(lock: var RLock, code: untyped): untyped =
  ## Acquires the given lock and then executes the code.
  block:
    acquire(lock)
    defer:
      release(lock)
    {.locks: [lock].}:
      code

{.pop.}
