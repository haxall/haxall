//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Jul 2023  Brian Frank  Creation
//

using xeto
using xeto::Dict
using haystack
using haystack::Ref

**
** FactoryTest
**
@Js
class FactoryTest : AbstractXetoTest
{

  Void testSys()
  {
    verifyAllEnvs("sys") |env| { doTestSys(env) }
  }

  private Void doTestSys(XetoEnv env)
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

    verifySame(env.spec("sys::Obj").fantomType, Obj#)
    verifySame(env.spec("sys::Dict").fantomType, Dict#)
    verifySame(env.spec("sys::Spec").fantomType, Spec#)
    verifySame(env.spec("sys::LibOrg").fantomType, Dict#)
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
    verifySame(env.specOf(v), spec)
    verifySame(env.specOf(v.typeof), spec)
    verifySame(spec.fantomType, type)
  }

}

