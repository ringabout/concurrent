type
  NonCopyable* = object of RootObj

proc `=copy`*(x: var NonCopyable, y: NonCopyable) {.error.}
