#
#
#           The Nim Compiler
#        (c) Copyright 2021 Mamy André-Ratsimbazafy & Nim Contributors
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

import system/ansi_c

type
  BoundedQueue*[T] = object
    head: int     # Items are taken from head and new items are inserted at tail
    tail: int
    size: int
    buffer: ptr UncheckedArray[T]

func init*[T](result: var BoundedQueue[T], size: int) {.inline.} =
  result.size = size
  result.buffer = cast[ptr UncheckedArray[T]](c_calloc(1, csize_t (size * sizeof(T))))
  if result.buffer == nil:
    raise newException(OutOfMemDefect, "Could not allocate memory")

proc `=copy`*[T](x: var BoundedQueue[T], y: BoundedQueue[T]) {.error.}

proc `=destroy`*[T](x: var BoundedQueue[T]) {.inline.} =
  if x.buffer != nil:
    for i in 0 ..< x.size:
      `=destroy`(x.buffer[i])
    c_free(x.buffer)

proc size*[T](x: BoundedQueue[T]): int {.inline.} =
  result = x.size

proc len*[T](x: BoundedQueue[T]): int {.inline.} =
  result = x.tail - x.head
  if result < 0:
    inc(result, 2 * x.size)

  assert result <= x.size

func isEmpty*[T](x: BoundedQueue[T]): bool {.inline.} =
  x.head == x.tail

func isFull*[T](x: BoundedQueue[T]): bool {.inline.} =
  abs(x.tail - x.head) == x.size

func add*[T](q: var BoundedQueue[T], elem: sink T) {.inline.} =
  let writeIdx = if q.tail < q.size: q.tail
                 else: q.tail - q.size
  q.buffer[writeIdx] = elem
  q.tail += 1
  if q.tail == 2*q.size:
    q.tail = 0

func pop*[T](
       q: var BoundedQueue[T]
     ): T {.inline.} =
  let readIdx = if q.head < q.size: q.head
                else: q.head - q.size
  result = move q.buffer[readIdx]
  q.head += 1
  if q.head == 2*q.size:
    q.head = 0

func peek*[T](q: BoundedQueue[T]): lent T {.inline.} =
  let readIdx = if q.head < q.size: q.head
                else: q.head - q.size
  result = q.buffer[readIdx]
