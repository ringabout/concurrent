# For the C backend, atomics map to C11 built-ins on GCC and Clang for
# trivial Nim types. Other types are implemented using spin locks.
# This could be overcome by supporting advanced importc-patterns.

# Since MSVC does not implement C11, we fall back to MS intrinsics
# where available.

type
  Trivial = SomeNumber | bool | enum | ptr | pointer
    # A type that is known to be atomic and whose size is known at
    # compile time to be 8 bytes or less

template nonAtomicType*(T: typedesc[Trivial]): untyped =
  # Maps types to integers of the same size
  when sizeof(T) == 1: int8
  elif sizeof(T) == 2: int16
  elif sizeof(T) == 4: int32
  elif sizeof(T) == 8: int64

when defined(vcc):

  # TODO: Trivial types should be volatile and use VC's special volatile
  # semantics for store and loads.

  type
    MemoryOrder* = enum
      moRelaxed
      moConsume
      moAcquire
      moRelease
      moAcquireRelease
      moSequentiallyConsistent

    Atomic*[T] = object
      when T is Trivial:
        value: T.nonAtomicType
      else:
        nonAtomicValue: T
        guard: AtomicFlag

    AtomicFlag* = distinct int8

  {.push header: "<intrin.h>".}

  # MSVC intrinsics
  proc interlockedExchange(location: pointer; desired: int8): int8 {.importc: "_InterlockedExchange8".}
  proc interlockedExchange(location: pointer; desired: int16): int16 {.importc: "_InterlockedExchange".}
  proc interlockedExchange(location: pointer; desired: int32): int32 {.importc: "_InterlockedExchange16".}
  proc interlockedExchange(location: pointer; desired: int64): int64 {.importc: "_InterlockedExchange64".}

  proc interlockedCompareExchange(location: pointer; desired, expected: int8): int8 {.importc: "_InterlockedCompareExchange8".}
  proc interlockedCompareExchange(location: pointer; desired, expected: int16): int16 {.importc: "_InterlockedCompareExchange16".}
  proc interlockedCompareExchange(location: pointer; desired, expected: int32): int32 {.importc: "_InterlockedCompareExchange".}
  proc interlockedCompareExchange(location: pointer; desired, expected: int64): int64 {.importc: "_InterlockedCompareExchange64".}

  proc interlockedAnd(location: pointer; value: int8): int8 {.importc: "_InterlockedAnd8".}
  proc interlockedAnd(location: pointer; value: int16): int16 {.importc: "_InterlockedAnd16".}
  proc interlockedAnd(location: pointer; value: int32): int32 {.importc: "_InterlockedAnd".}
  proc interlockedAnd(location: pointer; value: int64): int64 {.importc: "_InterlockedAnd64".}

  proc interlockedOr(location: pointer; value: int8): int8 {.importc: "_InterlockedOr8".}
  proc interlockedOr(location: pointer; value: int16): int16 {.importc: "_InterlockedOr16".}
  proc interlockedOr(location: pointer; value: int32): int32 {.importc: "_InterlockedOr".}
  proc interlockedOr(location: pointer; value: int64): int64 {.importc: "_InterlockedOr64".}

  proc interlockedXor(location: pointer; value: int8): int8 {.importc: "_InterlockedXor8".}
  proc interlockedXor(location: pointer; value: int16): int16 {.importc: "_InterlockedXor16".}
  proc interlockedXor(location: pointer; value: int32): int32 {.importc: "_InterlockedXor".}
  proc interlockedXor(location: pointer; value: int64): int64 {.importc: "_InterlockedXor64".}

  proc fence(order: MemoryOrder): int64 {.importc: "_ReadWriteBarrier()".}
  proc signalFence(order: MemoryOrder): int64 {.importc: "_ReadWriteBarrier()".}

  {.pop.}

  proc testAndSet*(location: var AtomicFlag; order: MemoryOrder = moSequentiallyConsistent): bool =
    interlockedOr(addr(location), 1'i8) == 1'i8
  proc clear*(location: var AtomicFlag; order: MemoryOrder = moSequentiallyConsistent) =
    discard interlockedAnd(addr(location), 0'i8)

  proc load*[T: Trivial](location: var Atomic[T]; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
    cast[T](interlockedOr(addr(location.value), (nonAtomicType(T))0))
  proc store*[T: Trivial](location: var Atomic[T]; desired: T; order: MemoryOrder = moSequentiallyConsistent) {.inline.} =
    discard interlockedExchange(addr(location.value), cast[nonAtomicType(T)](desired))

  proc exchange*[T: Trivial](location: var Atomic[T]; desired: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
    cast[T](interlockedExchange(addr(location.value), cast[int64](desired)))
  proc compareExchange*[T: Trivial](location: var Atomic[T]; expected: var T; desired: T; success, failure: MemoryOrder): bool {.inline.} =
    cast[T](interlockedCompareExchange(addr(location.value), cast[nonAtomicType(T)](desired), cast[nonAtomicType(T)](expected))) == expected
  proc compareExchange*[T: Trivial](location: var Atomic[T]; expected: var T; desired: T; order: MemoryOrder = moSequentiallyConsistent): bool {.inline.} =
    compareExchange(location, expected, desired, order, order)
  proc compareExchangeWeak*[T: Trivial](location: var Atomic[T]; expected: var T; desired: T; success, failure: MemoryOrder): bool {.inline.} =
    compareExchange(location, expected, desired, success, failure)
  proc compareExchangeWeak*[T: Trivial](location: var Atomic[T]; expected: var T; desired: T; order: MemoryOrder = moSequentiallyConsistent): bool {.inline.} =
    compareExchangeWeak(location, expected, desired, order, order)

  proc fetchAdd*[T: SomeInteger](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
    var currentValue = location.load()
    while not compareExchangeWeak(location, currentValue, currentValue + value): discard
  proc fetchSub*[T: SomeInteger](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
    fetchAdd(location, -value, order)
  proc fetchAnd*[T: SomeInteger](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
    cast[T](interlockedAnd(addr(location.value), cast[nonAtomicType(T)](value)))
  proc fetchOr*[T: SomeInteger](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
    cast[T](interlockedOr(addr(location.value), cast[nonAtomicType(T)](value)))
  proc fetchXor*[T: SomeInteger](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
    cast[T](interlockedXor(addr(location.value), cast[nonAtomicType(T)](value)))

else:
  {.push, header: "<stdatomic.h>".}

  type
    MemoryOrder* {.importc: "memory_order".} = enum
      moRelaxed
      moConsume
      moAcquire
      moRelease
      moAcquireRelease
      moSequentiallyConsistent

  type
    AtomicInt8 {.importc: "_Atomic NI8", size: 1.} = object
    AtomicInt16 {.importc: "_Atomic NI16", size: 2.} = object
    AtomicInt32 {.importc: "_Atomic NI32", size: 4.} = object
    AtomicInt64 {.importc: "_Atomic NI64", size: 8.} = object

  template atomicType*(T: typedesc[Trivial]): untyped =
    # Maps the size of a trivial type to it's internal atomic type
    when sizeof(T) == 1: AtomicInt8
    elif sizeof(T) == 2: AtomicInt16
    elif sizeof(T) == 4: AtomicInt32
    elif sizeof(T) == 8: AtomicInt64

  type
    AtomicFlag* {.importc: "atomic_flag", size: 1.} = object

    Atomic*[T] = object
      when T is Trivial:
        value: T.atomicType
      else:
        nonAtomicValue: T
        guard: AtomicFlag

  #proc init*[T](location: var Atomic[T]; value: T): T {.importcpp: "atomic_init(@)".}
  proc atomic_load_explicit[T, A](location: ptr A; order: MemoryOrder): T {.importc.}
  proc atomic_store_explicit[T, A](location: ptr A; desired: T; order: MemoryOrder = moSequentiallyConsistent) {.importc.}
  proc atomic_exchange_explicit[T, A](location: ptr A; desired: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc.}
  proc atomic_compare_exchange_strong_explicit[T, A](location: ptr A; expected: ptr T; desired: T; success, failure: MemoryOrder): bool {.importc.}
  proc atomic_compare_exchange_weak_explicit[T, A](location: ptr A; expected: ptr T; desired: T; success, failure: MemoryOrder): bool {.importc.}

  # Numerical operations
  proc atomic_fetch_add_explicit[T, A](location: ptr A; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc.}
  proc atomic_fetch_sub_explicit[T, A](location: ptr A; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc.}
  proc atomic_fetch_and_explicit[T, A](location: ptr A; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc.}
  proc atomic_fetch_or_explicit[T, A](location: ptr A; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc.}
  proc atomic_fetch_xor_explicit[T, A](location: ptr A; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.importc.}

  proc testAndSet*(location: var AtomicFlag; order: MemoryOrder = moSequentiallyConsistent): bool {.importc: "atomic_flag_test_and_set_explicit".}
  proc clear*(location: var AtomicFlag; order: MemoryOrder = moSequentiallyConsistent) {.importc: "atomic_flag_clear_explicit".}

  proc fence*(order: MemoryOrder) {.importc: "atomic_thread_fence".}
  proc signalFence*(order: MemoryOrder) {.importc: "atomic_signal_fence".}

  {.pop.}

  proc load*[T: Trivial](location: var Atomic[T]; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
    cast[T](atomic_load_explicit[nonAtomicType(T), typeof(location.value)](addr(location.value), order))
  proc store*[T: Trivial](location: var Atomic[T]; desired: T; order: MemoryOrder = moSequentiallyConsistent) {.inline.} =
    atomic_store_explicit(addr(location.value), cast[nonAtomicType(T)](desired), order)
  proc exchange*[T: Trivial](location: var Atomic[T]; desired: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
    cast[T](atomic_exchange_explicit(addr(location.value), cast[nonAtomicType(T)](desired), order))
  proc compareExchange*[T: Trivial](location: var Atomic[T]; expected: var T; desired: T; success, failure: MemoryOrder): bool {.inline.} =
    atomic_compare_exchange_strong_explicit(addr(location.value), cast[ptr nonAtomicType(T)](addr(expected)), cast[nonAtomicType(T)](desired), success, failure)
  proc compareExchange*[T: Trivial](location: var Atomic[T]; expected: var T; desired: T; order: MemoryOrder = moSequentiallyConsistent): bool {.inline.} =
    compareExchange(location, expected, desired, order, order)

  proc compareExchangeWeak*[T: Trivial](location: var Atomic[T]; expected: var T; desired: T; success, failure: MemoryOrder): bool {.inline.} =
    atomic_compare_exchange_weak_explicit(addr(location.value), cast[ptr nonAtomicType(T)](addr(expected)), cast[nonAtomicType(T)](desired), success, failure)
  proc compareExchangeWeak*[T: Trivial](location: var Atomic[T]; expected: var T; desired: T; order: MemoryOrder = moSequentiallyConsistent): bool {.inline.} =
    compareExchangeWeak(location, expected, desired, order, order)

  # Numerical operations
  proc fetchAdd*[T: SomeInteger](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
    cast[T](atomic_fetch_add_explicit(addr(location.value), cast[nonAtomicType(T)](value), order))
  proc fetchSub*[T: SomeInteger](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
    cast[T](atomic_fetch_sub_explicit(addr(location.value), cast[nonAtomicType(T)](value), order))
  proc fetchAnd*[T: SomeInteger](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
    cast[T](atomic_fetch_and_explicit(addr(location.value), cast[nonAtomicType(T)](value), order))
  proc fetchOr*[T: SomeInteger](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
    cast[T](atomic_fetch_or_explicit(addr(location.value), cast[nonAtomicType(T)](value), order))
  proc fetchXor*[T: SomeInteger](location: var Atomic[T]; value: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
    cast[T](atomic_fetch_xor_explicit(addr(location.value), cast[nonAtomicType(T)](value), order))


proc `=copy`*[T](x: var Atomic[T], y: Atomic[T]) {.error.}

# Flag operations
proc init*(location: var AtomicFlag) {.inline.} = clear(location)

template withLock[T: not Trivial](location: var Atomic[T]; order: MemoryOrder; body: untyped): untyped =
  while location.guard.testAndSet(moAcquire): discard
  try:
    body
  finally:
    location.guard.clear(moRelease)

proc load*[T: not Trivial](location: var Atomic[T]; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
  withLock(location, order):
    result = location.nonAtomicValue

proc store*[T: not Trivial](location: var Atomic[T]; desired: T; order: MemoryOrder = moSequentiallyConsistent) {.inline.} =
  withLock(location, order):
    location.nonAtomicValue = desired

proc exchange*[T: not Trivial](location: var Atomic[T]; desired: T; order: MemoryOrder = moSequentiallyConsistent): T {.inline.} =
  withLock(location, order):
    result = location.nonAtomicValue
    location.nonAtomicValue = desired

proc compareExchange*[T: not Trivial](location: var Atomic[T]; expected: var T; desired: T; success, failure: MemoryOrder): bool {.inline.} =
  withLock(location, success):
    if location.nonAtomicValue != expected:
      expected = location.nonAtomicValue
      return false
    expected = desired
    swap(location.nonAtomicValue, expected)
    return true

proc compareExchangeWeak*[T: not Trivial](location: var Atomic[T]; expected: var T; desired: T; success, failure: MemoryOrder): bool {.inline.} =
  compareExchange(location, expected, desired, success, failure)

proc compareExchange*[T: not Trivial](location: var Atomic[T]; expected: var T; desired: T; order: MemoryOrder = moSequentiallyConsistent): bool {.inline.} =
  compareExchange(location, expected, desired, order, order)

proc compareExchangeWeak*[T: not Trivial](location: var Atomic[T]; expected: var T; desired: T; order: MemoryOrder = moSequentiallyConsistent): bool {.inline.} =
  compareExchangeWeak(location, expected, desired, order, order)

proc atomicInc*[T: SomeInteger](location: var Atomic[T]; value: T = 1) {.inline.} =
  ## Atomically increments the atomic integer by some `value`.
  discard location.fetchAdd(value)

proc atomicDec*[T: SomeInteger](location: var Atomic[T]; value: T = 1) {.inline.} =
  ## Atomically decrements the atomic integer by some `value`.
  discard location.fetchSub(value)

proc `+=`*[T: SomeInteger](location: var Atomic[T]; value: T) {.inline.} =
  ## Atomically increments the atomic integer by some `value`.
  discard location.fetchAdd(value)

proc `-=`*[T: SomeInteger](location: var Atomic[T]; value: T) {.inline.} =
  ## Atomically decrements the atomic integer by some `value`.
  discard location.fetchSub(value)


import std/os

proc wakeByAddressAll(address: pointer) {.stdcall, importc: "WakeByAddressAll",
                                         dynlib: "API-MS-Win-Core-Synch-l1-2-0.dll".}


proc wakeByAddressSingle(address: pointer) {.stdcall, importc: "WakeByAddressSingle",
                                         dynlib: "API-MS-Win-Core-Synch-l1-2-0.dll".}

proc signal*[T](location: var Atomic[T]) =
  when T is Trivial:
    wakeByAddressSingle(addr location.value)
  else:
    wakeByAddressSingle(addr location.nonAtomicValue)


proc broadcast*[T](location: var Atomic[T]) =
  when T is Trivial:
    wakeByAddressAll(addr location.value)
  else:
    wakeByAddressAll(addr location.nonAtomicValue)

proc wait*[T](location: var Atomic[T]) =
  sleep(0)
