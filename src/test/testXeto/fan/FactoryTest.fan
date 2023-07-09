//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Jul 2023  Brian Frank  Creation
//

using haystack

**
** FactoryTest
**
@Js
class FactoryTest : AbstractXetoTest
{
  Void testSys()
  {
    verifyScalar("sys::Str",     "hello")
    verifyScalar("sys::Bool",     true)
    verifyScalar("sys::Int",      123)
    verifyScalar("sys::Float",    123f)
    verifyScalar("sys::Duration", 10sec)
    verifyScalar("sys::Date",     Date("2023-07-01"))
    verifyScalar("sys::Time",     Time("13:00:00"))
    verifyScalar("sys::DateTime", DateTime.now)
    verifyScalar("sys::Uri",      `foo.txt`)
    verifyScalar("sys::Version",  Version("1.2.3"))

    verifyScalar("sys::Marker",   Marker.val)
    verifyScalar("sys::None",     Remove.val)
    verifyScalar("sys::NA",       NA.val)
    verifyScalar("sys::Number",   Number(80, Unit("%")))
    verifyScalar("sys::Ref",      Ref("abc"))
  }

  Void testPh()
  {
    verifyScalar("ph::Coord",     Coord(23f, 45f))
    verifyScalar("ph::Symbol",    Symbol("tag"), Symbol#)

    // what to do with this guy?
    //verifyScalar("ph::XStr", XStr("Foo", "bar"))
  }

  Void verifyScalar(Str qname, Obj val, Type? type := val.typeof)
  {
    spec := env.spec(qname)
    verifySame(spec.factory.type, type)
    s := spec.factory.encodeScalar(val)
    v := spec.factory.decodeScalar(s)
    // echo("::: $type <=> $spec | $v")
    verifyEq(v, val)
    verifySame(env.typeOf(v), spec)
  }

}

