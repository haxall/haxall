//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Nov 2024  Brian Frank  Creation
//

using util
using xeto
using xeto::Lib
using xetoEnv
using xetoc
using haystack
using haystack::Dict
using haystack::Ref

**
** FidelityTest
**
@Js
class FidelityTest : AbstractXetoTest
{
  Void test()
  {
    ns := createNamespace(["hx.test.xeto"])
    verifyFidelity(ns, "bool",  true, true, true)
    verifyFidelity(ns, "int",   123, n(123), 123f)
    verifyFidelity(ns, "float", 72f, n(72f), 72f)
    verifyFidelity(ns, "number", n(90, "kW"), n(90, "kW"), "90kW")
    verifyFidelity(ns, "str", "hello", "hello", "hello")
    verifyFidelity(ns, "uri", `file.txt`, `file.txt`, "file.txt")
    verifyFidelity(ns, "date", Date("2024-11-25"), Date("2024-11-25"), "2024-11-25")
    verifyFidelity(ns, "time", Time("14:30:00"), Time("14:30:00"), "14:30:00")
    verifyFidelity(ns, "dateTime", DateTime("2024-11-25T10:24:35-05:00 New_York"), DateTime("2024-11-25T10:24:35-05:00 New_York"), "2024-11-25T10:24:35-05:00 New_York")
    verifyFidelity(ns, "span", Span("2024-11-25"), Span("2024-11-25"), "2024-11-25")

    verifyFidelity(ns, "tz", TimeZone("Chicago"), "chicago")
    verifyFidelity(ns, "unit", Unit("meter"), "meter")
    verifyFidelity(ns, "unitQuantity", UnitQuantity.electricCurrentDensity, "electricCurrentDensity")
    verifyFidelity(ns, "spanMode", SpanMode.yesterday, "yesterday")
    verifyFidelity(ns, "version", Version("4.0.9"), "4.0.9")

return  // TODO
    verifyFidelity(ns, "scalarA", Scalar("hx.test.xeto::ScalarA", "alpha"), "alpha")
    verifyFidelity(ns, "scalarB", Scalar("hx.test.xeto::ScalarB", "bravo"), "bravo")
  }

  Void verifyFidelity(LibNamespace ns, Str slot, Obj full, Obj hay, Obj json := hay)
  {
    // spec def val
    spec := ns.spec("hx.test.xeto::Fidelity")
    v := spec.slot(slot).meta["val"]
    if (debug) echo(">>>> $slot")
    if (debug) echo("   > s = $v [$v.typeof]")
    verifyValEq(v, full)

    // instantiate spec
    v = ((Dict)ns.instantiate(spec)).get(slot)
    if (debug) echo("   > i = $v [$v]")
    verifyValEq(v, full)

    // instance A
    v = ns.instance("hx.test.xeto::fidelityA").get(slot)
    if (debug) echo("   > a = $v [$v]")
    verifyValEq(v, full)

    // instance B
    v = ns.instance("hx.test.xeto::fidelityB").get(slot)
    if (debug) echo("   > b = $v [$v]")
    verifyValEq(v, full)
  }

  const Bool debug := true
}

