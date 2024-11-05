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

  Void test()
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

     // select - one match
     all      := [color, slotA, slotB, slotC, slotD, slotE]
     instance := ["red":m, "dark":m]
     expect   := Spec[redd]
     all.each |spec| { verifySelections(ns, spec, instance, expect) }

     // select - zero matches
     instance = [:]
     expect = Spec[,]
     all.each |spec| { verifySelections(ns, spec, instance, expect) }

     // select - multiple matches
     instance = ["red":m, "light":m, "dark":m]
     expect = Spec[redd, redl]
     all.each |spec| { verifySelections(ns, spec, instance, expect) }
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

  Void verifySelections(LibNamespace ns, Spec spec, Str:Obj tags, Spec[] expect)
  {
    c := ns.choice(spec)
    instance := Etc.makeDict(tags)
    actual := c.selections(instance, false)
    // echo("-- $spec | $instance | $actual ?= $expect")
    verifyEq(actual.size, expect.size)

    // one match
    if (expect.size == 1)
    {
      verifySame(actual[0], expect[0])
      verifySame(c.selection(instance), expect[0])
    }

    // zero matches
    else if (expect.size == 0)
    {
      verifyEq(c.selection(instance, false), null)
      if (c.isMaybe)
      {
        verifyEq(c.selections(instance), Spec[,])
        verifyEq(c.selection(instance), null)
      }
      else
      {
        verifyErr(Err#) { c.selections(instance) }
        verifyErr(Err#) { c.selection(instance) }
      }
    }

    // multiple matches
    else
    {
      verifyEq(actual, expect)
      if (c.isMultiChoice)
      {
        verifyEq(c.selections(instance), expect)
        verifyEq(c.selection(instance), actual.first)
      }
      else
      {
        verifyErr(Err#) { c.selections(instance) }
        verifyErr(Err#) { c.selection(instance) }
      }
    }
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
    verifyPhenomenon(ns, ["domestic":m, "water":m], "ph::Fluid", "ph::DomesticWater")
    verifyPhenomenon(ns, ["water":m, "hot":m, "naturalGas":m], "ph::Fluid", ["ph::HotWater", "ph::NaturalGas"])
  }

  Void verifyPhenomenon(LibNamespace ns, Str:Obj tags, Str qname, Obj? expect)
  {
    spec := ns.spec(qname)
    c := ns.choice(spec)
    if (expect == null)
    {
      actual := c.selection(dict(tags), false)
      verifyEq(actual, null)
    }
    else if (expect is Str)
    {
      actual := c.selection(dict(tags), false)
      // echo("--> $tags choiceOf $c => $actual ?= $expect")
      verifyEq(actual.qname, expect)
    }
    else
    {
      actual := c.selections(dict(tags), false)
      // echo("--> $tags choiceOf $c => $actual ?= $expect")
      verifyEq(actual.map |x->Str| { x.qname }, expect)
    }

  }
}

