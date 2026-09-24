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

      // defaults such as unit are not constraints
      verifySugar(ns, "ph.points.sugar::NaturalGasFlowSp", "ph.points::FluidVolumetricFlowSp", ["naturalGas":m])

      nominal := ns.spec(fan)
      verifyEq(nominal.isSugar, false)
      verifyErr(UnsupportedErr#) { nominal.sugar }

      // mixin constraints are only seen thru specx
      ret := ns.spec("ph.points.sugar::ReturnFanRunCmd")
      verifyEq(ret.sugar.constraints.names, ["return"])
      verifyEq(ns.specx(ret).sugar.constraints.names, ["hotDeck", "return"])
      verifySame(ns.specx(ret).sugar.anchor, nominal)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Isa
//////////////////////////////////////////////////////////////////////////

  Void testIsa()
  {
    verifyLocalAndRemote(["hx.test.xeto"]) |ns|
    {
      fan    := ns.spec("ph.points::DuctFanRunCmd")
      dis    := ns.spec("ph.points.sugar::DischargeFanRunCmd")
      ret    := ns.spec("ph.points.sugar::ReturnFanRunCmd")
      myDis  := ns.spec("hx.test.xeto::MyDischargeFanRunCmd")
      cold   := ns.spec("hx.test.xeto::ColdDeckDischargeFanRunCmd")
      stage2 := ns.spec("hx.test.xeto::Stage2DischargeFanRunCmd")
      stage3 := ns.spec("hx.test.xeto::Stage3DischargeFanRunCmd")

      // nominal
      verifyIsa(dis, fan, true)
      verifyIsa(fan, dis, false)

      // same anchor and constraints are the same type
      verifyIsa(myDis, dis, true)
      verifyIsa(dis, myDis, true)

      // constraint superset with equal invariants
      verifyIsa(cold,   myDis,  true)
      verifyIsa(myDis,  cold,   false)
      verifyIsa(stage2, myDis,  true)
      verifyIsa(stage2, stage3, false)
      verifyIsa(ret,    dis,    false)
    }
  }

  Void verifyIsa(Spec a, Spec b, Bool expect)
  {
    verifyEq(a.isa(b), expect, "$a isa $b")
  }

//////////////////////////////////////////////////////////////////////////
// Fits
//////////////////////////////////////////////////////////////////////////

  Void testFits()
  {
    verifyLocalAndRemote(["hx.test.xeto"]) |ns|
    {
      fan    := Ref("ph.points::DuctFanRunCmd")
      dis    := "ph.points.sugar::DischargeFanRunCmd"
      stage2 := "hx.test.xeto::Stage2DischargeFanRunCmd"
      ret    := "ph.points.sugar::ReturnFanRunCmd"

      // scalars and nominal dicts
      verifyFits(ns, "foo", "sys::Str", true)
      verifyFits(ns, "foo", "sys::Marker", false)
      verifyFits(ns, Str:Obj[:], "sys::Dict", true)
      verifyFits(ns, ["spec":Ref("ph::Ahu")], "ph::Equip", true)
      verifyFits(ns, ["spec":Ref("ph::Ahu")], "ph::Site", false)

      // sugar by anchor plus tags, or by assertion
      verifyFits(ns, ["spec":fan, "discharge":m], dis, true)
      verifyFits(ns, ["spec":fan], dis, false)
      verifyFits(ns, ["spec":fan, "discharge":"x"], dis, true)  // presence like filter has
      verifyFits(ns, ["spec":Ref("ph::Point"), "discharge":m], dis, false)
      verifyFits(ns, ["discharge":m, "fan":m, "run":m, "cmd":m, "point":m], dis, false)
      verifyFits(ns, ["spec":Ref(dis)], dis, true)
      verifyFits(ns, ["spec":Ref("hx.test.xeto::MyDischargeFanRunCmd")], dis, true)

      // invariants at full and haystack fidelity
      verifyFits(ns, ["spec":fan, "discharge":m, "stage":2],    stage2, true)
      verifyFits(ns, ["spec":fan, "discharge":m, "stage":n(2)], stage2, true)
      verifyFits(ns, ["spec":fan, "discharge":m, "stage":n(3)], stage2, false)
      verifyFits(ns, ["spec":fan, "discharge":m], stage2, false)

      // defaults are not constraints
      verifyFits(ns, ["spec":Ref("ph.points::FluidVolumetricFlowSp"), "naturalGas":m, "unit":"L/s"],
        "ph.points.sugar::NaturalGasFlowSp", true)

      // mixin constraints only apply thru specx
      retx := ns.specx(ns.spec(ret))
      noHotDeck := Etc.makeDict(["spec":fan, "return":m])
      verifyFits(ns, noHotDeck, ret, true)
      verifyEq(ns.fits(noHotDeck, retx), false)
      verifyEq(ns.fits(Etc.makeDict(["spec":fan, "return":m, "hotDeck":m]), retx), true)

      // query items are anonymous sugar
      item := ns.spec("hx.test.xeto::SugarItemsEquip").slot("points").slot("fan")
      verifyEq(item.isSugar, true)
      verifySame(item.sugar.anchor, ns.spec(fan.id))
      verifyEq(item.sugar.constraints.names, ["discharge"])
      verifyEq(ns.fits(Etc.makeDict(["spec":fan, "discharge":m]), item), true)
      verifyEq(ns.fits(Etc.makeDict(["spec":fan]), item), false)
    }
  }

  Void verifyFits(Namespace ns, Obj val, Str qname, Bool expect)
  {
    if (val is Map) val = Etc.makeDict(val)
    verifyEq(ns.fits(val, ns.spec(qname)), expect, "$val fits $qname")
  }

//////////////////////////////////////////////////////////////////////////
// Compile Errs
//////////////////////////////////////////////////////////////////////////

  Void testCompileErrs()
  {
    ns := createNamespace(["ph.protocols", "ph.points.sugar"])

    // body rules: every slot must be a global in scope
    verifyCompileErrs(ns, src(
      Str<|Ok: DuctFanRunCmd <sugar> {
             discharge
             stage: Int <invariant> 2
             dis: "default"
             bacnetCurAddr: { addr: "AI1" }
           }
           OkQuery: Vav <sugar> {
             singleDuct
             points: { DuctFanRunCmd }
           }
           Bad1: DuctFanRunCmd <sugar> { surgeMargin: Number }
           Bad2: DuctFanRunCmd <sugar> { dischrage }
           Bad3: DuctFanRunCmd <sugar> { stage: Int }
           Bad4: DuctFanRunCmd <sugar> { *newTag: Marker }
           Bad5: Ok { nested: { discharge } }
           Bad6: DuctFanRunCmd <sugar> { discharge: Marker? }
           Bad7: DuctFanRunCmd <sugar> { stage: Int <invariant> }
           |>), [
      "Sugar slot 'surgeMargin' is not a global tag",
      "Sugar slot 'dischrage' is not a global tag",
      "Sugar slot 'stage' must be marker, invariant, or default value",
      "Sugar spec cannot declare global 'newTag'",
      "Sugar slot 'nested' is not a global tag",
      "Sugar constraint 'discharge' cannot be maybe",
      "Sugar slot 'stage' must be marker, invariant, or default value",
    ])

    // anchors; defaults may be overridden but invariants may not
    verifyCompileErrs(ns, src(
      Str<|S1: DuctFanRunCmd <sugar> { discharge }
           S2: DuctFanRunCmd <sugar> { coldDeck }
           OkAnd: S1 & S2
           OkSubAnchor: S1 & Point
           BadOr: S1 | S2 <sugar>
           A: Dict
           B: Dict
           SA: A <sugar>
           SB: B <sugar>
           BadAnchors: SA & SB
           D1: DuctFanRunCmd <sugar> { dis: "a" }
           OkDefault: D1 { dis: "b" }
           Stage2: DuctFanRunCmd <sugar> { stage: Int <invariant> 2 }
           BadStage: Stage2 { stage: 3 }
           |>), [
      "Sugar spec cannot be Or type: BadOr",
      "Sugar spec must have one nominal anchor: BadAnchors [temp::A, temp::B]",
      "Slot 'stage' is invariant and cannot declare new default value",
    ])

    // mixins on sugar specs follow the body rules
    verifyCompileErrs(ns, src(
      Str<|+DischargeFanRunCmd {
             coldDeck
             dis: "default"
             installNotes: Str
             dischrage
           }
           |>), [
      "Sugar slot 'installNotes' is not a global tag",
      "Sugar slot 'dischrage' is not a global tag",
    ])

    // inline query constraints are anonymous sugar
    verifyCompileErrs(ns, src(
      Str<|MyVav: Vav {
             points: {
               ok: DuctFanRunCmd { discharge, dis: "Fan", bacnetCurAddr: { addr: "BO1" } }
               bad: DuctFanRunCmd { dischrage, BacnetAddr { addr: "BO2" } }
             }
           }
           |>), [
      "Sugar slot 'dischrage' is not a global tag",
      "Sugar slot '_0' is not a global tag",
    ])
  }

  private Str src(Str body)
  {
    Str<|pragma: Lib <
           version: "0.0.0"
           depends: { {lib:"sys"}, {lib:"ph"}, {lib:"ph.protocols"}, {lib:"ph.points"}, {lib:"ph.points.sugar"} }
         >
         |> + body
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

