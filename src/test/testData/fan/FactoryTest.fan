//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Jul 2023  Brian Frank  Creation
//

**
** FactoryTest
**
@Js
class FactoryTest : AbstractDataTest
{
  Void testSys()
  {
    verifyScalar("sys::Str",     "hello")
    verifyScalar("sys::Bool",     true)
    verifyScalar("sys::Int",      123)
    verifyScalar("sys::Float",    123f)
    verifyScalar("sys::Date",     Date("2023-07-01"))
    verifyScalar("sys::Time",     Time("13:00:00"))
    verifyScalar("sys::DateTime", DateTime.now)
    verifyScalar("sys::Uri",      `foo.txt`)
    verifyScalar("sys::Version",  Version("1.2.3"))
  }

  Void verifyScalar(Str qname, Obj val)
  {
    type := val.typeof
    spec := env.spec(qname)
    verifySame(spec.factory.type, type)
    s := spec.factory.encodeScalar(val)
    v := spec.factory.decodeScalar(s)
    verifyEq(v, val)
    verifySame(env.typeOf(v), spec)
  }

}

