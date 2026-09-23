//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2026  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** SugarTest
**
@Js
class SugarTest : AbstractXetoTest
{

//////////////////////////////////////////////////////////////////////////
// Flatten
//////////////////////////////////////////////////////////////////////////

  Void testFlatten()
  {
    verifyLocalAndRemote(["hx.test.xeto"]) |ns|
    {
      fan := "ph.points::DuctFanRunCmd"
      verifySugar(ns, "ph.points.sugar::DischargeFanRunCmd",            fan,       ["discharge":m])
      verifySugar(ns, "hx.test.xeto::ColdDeckDischargeFanRunCmd",       fan,       ["coldDeck":m, "discharge":m])
      verifySugar(ns, "hx.test.xeto::Stage2DischargeFanRunCmd",         fan,       ["discharge":m, "stage":2])
      verifySugar(ns, "hx.test.xeto::ColdDeckStage2DischargeFanRunCmd", fan,       ["coldDeck":m, "discharge":m, "stage":2])
      verifySugar(ns, "hx.test.xeto::StandardFanVav",                   "ph::Vav", ["singleDuct":m])

      nominal := ns.spec(fan)
      verifyEq(nominal.isSugar, false)
      verifyErr(UnsupportedErr#) { nominal.sugar }
    }
  }

  Void verifySugar(Namespace ns, Str qname, Str anchor, Str:Obj constraints)
  {
    spec := ns.spec(qname)
    verifyEq(spec.isSugar, true)

    sugar := spec.sugar
    verifySame(sugar.anchor, ns.spec(anchor))
    verifyEq(sugar.constraints.names, constraints.keys.sort)
    sugar.constraints.each |c, n|
    {
      verifyEq(c.isMarker ? Marker.val : c.meta["val"], constraints[n], n)
    }
    verifySame(spec.sugar, sugar)
    verifySame(ns.specx(spec).sugar, sugar)
  }
}

