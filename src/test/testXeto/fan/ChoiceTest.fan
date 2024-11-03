//
// Copyright (c) 2024, Brian Frank
// All Rights Reserved
//
// History:
//   3 Nov 2024  Brian Frank  Creation
//

using util
using xeto
using xetoEnv
using haystack
using haystack::Dict
using haystack::Ref

**
** ChoiceTest
**
@Js
class ChoiceTest : AbstractXetoTest
{

  Void testChoiceOf()
  {
    ns := createNamespace(["sys", "ph", "hx.test.xeto"])
    lib := ns.lib("hx.test.xeto")

    color := lib.spec("Color")
    red   := lib.spec("Red")
    redl  := lib.spec("LightRed")
    redd  := lib.spec("DarkRed")
    blue  := lib.spec("Blue")
    bluel := lib.spec("LightBlue")
    blued := lib.spec("DarkBlue")

    carA  := lib.spec("CarA"); slotA := carA.slot("color")
    carB  := lib.spec("CarB"); slotB := carB.slot("color")
    carC  := lib.spec("CarC"); slotC := carC.slot("color")
    carD  := lib.spec("CarD"); slotD := carD.slot("color")
    carE  := lib.spec("CarE"); slotE := carE.slot("color")

    // Spec.isChoice
    verifyIsChoice(color, true)
    verifyIsChoice(red,   true); verifyIsChoice(redl,  true); verifyIsChoice(redd,  true)
    verifyIsChoice(blue,  true); verifyIsChoice(bluel, true); verifyIsChoice(blued, true)
    verifyIsChoice(carA,  false); verifyIsChoice(slotA, true)
    verifyIsChoice(carB,  false); verifyIsChoice(slotB, true)
    verifyIsChoice(carC,  false); verifyIsChoice(slotC, true)
    verifyIsChoice(carD,  false); verifyIsChoice(slotD, true)
    verifyIsChoice(carE,  false); verifyIsChoice(slotE, true)

     // SpecChoice
     verifyErr(UnsupportedErr#) { ns.choice(carB) }
     verifyChoice(ns, color, "")
     verifyChoice(ns, red, "")
     verifyChoice(ns, slotA, "")
     verifyChoice(ns, slotB, "?")
     verifyChoice(ns, slotC, "m")
     verifyChoice(ns, slotD, "?m")
     verifyChoice(ns, slotE, "m")
  }

  Void verifyIsChoice(Spec spec, Bool expect)
  {
    // echo("-- isChoice $spec $spec.isChoice | $spec.base")
    verifyEq(spec.isChoice, expect, spec.qname)
  }

  Void verifyChoice(LibNamespace ns, Spec spec, Str flags)
  {
    c := ns.choice(spec)
    // echo("--> $c.spec | $c.type | $c.isMaybe/$c.isMultiChoice")
    verifySame(c.spec, spec)
    verifySame(c.type, spec.type)
    verifyEq(c.isMaybe, flags.contains("?"))
    verifyEq(c.isMultiChoice, flags.contains("m"))
  }

//////////////////////////////////////////////////////////////////////////
// Phenomenon
//////////////////////////////////////////////////////////////////////////

  Void testPhenomenon()
  {
    ns := createNamespace(["sys", "ph"])

    verifyPhenomenon(ns, ["discharge":m], "ph::DuctSection", "ph::DischargeDuct")
    verifyPhenomenon(ns, ["foo":m], "ph::DuctSection", null)
    verifyPhenomenon(ns, ["elec":m], "ph::Phenomenon", "ph::Elec")
    verifyPhenomenon(ns, ["elec":m, "dc":m], "ph::Phenomenon", "ph::DcElec")
    verifyPhenomenon(ns, ["naturalGas":m], "ph::Phenomenon", "ph::NaturalGas")
    verifyPhenomenon(ns, ["naturalGas":m], "ph::Liquid", null)
    verifyPhenomenon(ns, ["water":m], "ph::Fluid", "ph::Water")
    verifyPhenomenon(ns, ["water":m, "hot":m], "ph::Fluid", "ph::HotWater")

    // TODO
    //verifyPhenomenon(ns, ["water":m, "hot":m, "naturalGas":m], "ph::Fluid", null)
  }

  Void verifyPhenomenon(LibNamespace ns, Str:Obj tags, Str qname, Str? expect)
  {
    spec := ns.spec(qname)
    c := ns.choice(spec)
    actual := c.selection(dict(tags), false)
    // echo("--> $tags choiceOf $c => $actual ?= $expect")
    verifyEq(actual?.qname, expect)
  }
}

