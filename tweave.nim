type
  Ref = ref object
    id: int
  Test = object
    id: Ref

proc `=copy`(x: var Test, y: Test) =
  deepCopy(x.id, y.id)

proc `=destroy`(x: var Test) =
  echo 1234
  x.id.id = 9999999

var x = Test(id: Ref())

block:
  var y = x

echo x.repr
