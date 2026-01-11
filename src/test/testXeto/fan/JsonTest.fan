//
// Copyright (c) 2026, Brian Frank
// All Rights Reserved
//
// History:
//   9 Jan 2026  Mike Jarmy
//

using util
using xeto
using xetom
using haystack

**
** JsonTest
**
@Js
class JsonTest : AbstractXetoTest
{
  Void test()
  {
    ns := createNamespace(["hx.test.xeto"])

    verifyRoundTrip(ns, null)
    verifyRoundTrip(ns, true)

    verifyRoundTrip(ns, "abc")
    verifyRoundTrip(ns, "abc", ns.spec("sys::Str"))

    verifyRoundTrip(ns, 1, ns.spec("sys::Int"))
    verifyRoundTrip(ns, 1.234f, ns.spec("sys::Float"))
    verifyRoundTrip(ns, n(10, "db"), ns.spec("sys::Number"))

    verifyRoundTrip(ns,
      DateTime.fromStr("2024-11-25T10:24:35-05:00 New_York"),
      ns.spec("sys::DateTime"))

    //-----------------------------------------------

    a := ns.instance("hx.test.xeto::fidelityA")
    b := XetoJsonReader(ns, toJson(a).in, ns.spec("hx.test.xeto::Fidelity")).readVal

    list := (Obj[]) a->numbers
    echo("-----------------------------")
    list.each |v| { echo("a $v $v.typeof") }

    list = (Obj[]) b->numbers
    echo("-----------------------------")
    list.each |v| { echo("b $v $v.typeof") }

    verifyRoundTrip(ns,
      ns.instance("hx.test.xeto::fidelityA"),
      ns.spec("hx.test.xeto::Fidelity"))
  }

  private Void verifyRoundTrip(MNamespace ns, Obj? a, Spec? spec := null)
  {
    str := toJson(a)

    b := XetoJsonReader(ns, str.in, spec).readVal
    if (a is Dict)
      verifyDictEq(a, b)
    else
      verifyEq(a, b)
  }

  private Str toJson(Obj? x)
  {
    buf := Buf()
    XetoJsonWriter(buf.out, Etc.dict1("pretty", m)).writeVal(x)
    str := buf.flip.readAllStr
    echo("=========================================")
    echo(str)
    return str
  }
}

