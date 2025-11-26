//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Dec 2023  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** GlobalTest
**
@Js
class GlobalTest : AbstractXetoTest
{

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  Void testBasics()
  {
    ns := createNamespace(["hx.test.xeto"])

    marker := ns.spec("sys::Marker")
    str    := ns.spec("sys::Str")
    number := ns.spec("sys::Number")

    ta := ns.spec("hx.test.xeto::TestGlobalsA")
    tb := ns.spec("hx.test.xeto::TestGlobalsB")
    tc := ns.spec("hx.test.xeto::TestGlobalsC")
    td := ns.spec("hx.test.xeto::TestGlobalsD")

    a := verifyGlobal(ta, "globA", marker)
    b := verifyGlobal(ta, "globB", str)
    c := verifyGlobal(ta, "globC", number)
    d := verifyGlobal(ta, "globD", marker)
    e := verifyGlobal(ta, "globE", str)

    f := verifyGlobal(tb, "globF", str)
    g := verifyGlobal(tb, "globG", str)
    ao := verifySlot(tb, "globA", a)

    h := verifyGlobal(tc, "globH", str)
    i := verifyGlobal(tc, "globI", str)
    bo := verifySlot(tc, "globB", b)

    j := verifyGlobal(td, "globJ", str)
    co := verifySlot(td, "globC", c)
    io := verifySlot(td, "globI", i)
    bo2 := verifySlot(td, "globB", b)

    // maps own

    verifySlotMap(ta.slotsOwn,   [,])
    verifySlotMap(ta.globalsOwn, [a, b, c, d, e])
    verifySlotMap(ta.membersOwn, [a, b, c, d, e])

    verifySlotMap(tb.slotsOwn,   [ao])
    verifySlotMap(tb.globalsOwn, [f, g])
    verifySlotMap(tb.membersOwn, [ao, f, g])

    verifySlotMap(tc.slotsOwn,   [bo])
    verifySlotMap(tc.globalsOwn, [h, i])
    verifySlotMap(tc.membersOwn, [bo, h, i])

    verifySlotMap(td.slotsOwn,   [co, io])
    verifySlotMap(td.globalsOwn, [j])
    verifySlotMap(td.membersOwn, [co, io, j])

    // maps inherited

    verifyMembers(ta, [,], [a, b, c, d, e])
    verifyMembers(tb, [ao], [f, g, a, b, c, d, e], [ao, f, g, b, c, d, e])
    verifyMembers(tc, [bo], [h, i, a, b, c, d, e], [bo, h, i, a, c, d, e])
    verifyMembers(td, [ao, bo, co, io], [j, f, g, a, b, c, d, e, h, i], [ao, bo, co, io, j, f, g, d, e, h])

    // interned

    verifySlotMapsSame(ta)
    verifySlotMapsSame(tb)
    verifySlotMapsSame(tc)
    verifySlotMapsSame(td)
  }

  Spec verifyGlobal(Spec parent, Str name, Spec type)
  {
    x := parent.globalsOwn.get(name)

    // normal spec identity
    verifyEq(x.name, name)
    verifyEq(x.qname, "${parent.qname}.${name}")
    verifySame(x.parent, parent)
    verifySame(x.lib, parent.lib)
    verifySame(x.base, type)
    verifySame(x.type, type)

    // global meta
    verifyEq(x.meta["global"], Marker.val)
    verifySame(x.flavor, SpecFlavor.global)
    verifyEq(x.isType, false)
    verifyEq(x.isMixin, false)
    verifyEq(x.isMember, true)
    verifyEq(x.isSlot, false)
    verifyEq(x.isGlobal, true)

    // verify not in slots
    verifyEq(parent.slot(name, false), null)
    verifyEq(parent.slotOwn(name, false), null)

    return x
  }

  Spec verifySlot(Spec parent, Str name, Spec base)
  {
    x := parent.slots.get(name)

    verifySame(x.flavor, SpecFlavor.slot)
    verifyEq(x.isType, false)
    verifyEq(x.isMixin, false)
    verifyEq(x.isMember, true)
    verifyEq(x.isSlot, true)
    verifyEq(x.isGlobal, false)

    return x
  }

  Void verifyMembers(Spec parent, Spec[] slots, Spec[] globals, Spec[]? members := null)
  {
    // echo(">> $parent")
    if (members == null) members = slots.dup.addAll(globals)
    verifySlotMap(parent.members, members)
    verifySlotMap(parent.slots,   slots)
    verifySlotMap(parent.globals, globals)

    slots.each |x|
    {
      verifySame(parent.member(x.name), x)
      verifySame(parent.slot(x.name), x)
    }

    globals.each |x|
    {
      slot := parent.slot(x.name, false)
      if (slot == null)
      verifySame(parent.member(x.name), slot ?: x)
      verifySame(parent.globals.get(x.name), x)
    }
  }

  Void verifySlotMap(SpecMap map, Spec[] expect)
  {
    actual := Spec[,]
    map.each |x| { actual.add(x) }
    actualStr := actual.join(",") { it.name }
    expectStr := expect.join(",") { it.name }
    // echo("   a: $actualStr"); echo("   e: $expectStr")
    verifyEq(actualStr, expectStr)
  }

  Void verifySlotMapsSame(Spec x)
  {
    // always interned
    verifySame(x.globalsOwn, x.globalsOwn)
    verifySame(x.globals,    x.globals)
    verifySame(x.slotsOwn,   x.slotsOwn)
    verifySame(x.slots,      x.slots)
  }

  /*
  Void dumpSlotMaps(Spec x)
  {
    echo(">> $x")
    echo("   slotsOwn:   $x.slotsOwn")
    echo("   globsOwn:   $x.globalsOwn")
    echo("   membersOwn: $x.membersOwn")
    echo("   slots:      $x.slots")
    echo("   globs:      $x.globals")
    echo("   members:    $x.members")
 }
 */

//////////////////////////////////////////////////////////////////////////
// PH Shared
//////////////////////////////////////////////////////////////////////////

  Void testPhShared()
  {
    ns := createNamespace(["sys", "ph", "ph.points", "ph.attrs", "ph.points.elec"])

    entity := ns.spec("ph::PhEntity")

    // make sure that every subtype of PhEntity is sharing
    // same globals instance/ so we don't explode memory usage
    ns.libs.each |lib|
    {
      lib.types.each |spec|
      {
        if (!spec.isa(entity)) return
        if (spec === entity)
          verifySame(spec.globalsOwn, entity.globals)
        else
          verifySame(spec.globalsOwn, SpecMap.empty)
        verifySame(spec.globals, entity.globals)
      }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Constrained Queries
//////////////////////////////////////////////////////////////////////////

  Void testConstrainedQueries()
  {
    // we want to verify that constrained query slots don't use global slots

    ns := createNamespace(["sys", "ph", "ph.points"])
    lib := ns.compileTempLib(
      Str<|pragma: Lib < version: "0.0.0", depends: { { lib:"sys" }, { lib:"ph" }, { lib:"ph.points" } } >

           Foo: Equip {
             ahu
             points: {
               discharge: DischargeAirTempSensor
               return: {return, air, temp, sensor, point}
             }
           }
           |>)

     dict := ns.spec("sys::Dict")
     dat := ns.spec("ph.points::DischargeAirTempSensor")

     foo := lib.type("Foo")
     // env.print(foo)

     pts := foo.slot("points")
     verifySame(pts.base, ns.spec("ph::Equip.points"))

     verifySlotOld(pts, "discharge", dat, dat)
     verifySlotOld(pts, "return",   dict, dict)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Spec verifyGlobalOld(Spec global, Spec type, [Str:Obj]? meta)
  {
    verifySame(global.type, type)
    verifySame(global.base, type)
    if (meta != null)
    {
      verifyDictEq(global.metaOwn, meta)
      meta.each |v, n| { verifyEq(global.meta[n], v) }
    }
    return global
  }

  Spec verifySlotOld(Spec parent, Str name, Spec base, Spec type, Str:Obj meta := [:])
  {
    slot := parent.slot(name)
    verifySame(slot.base, base)
    verifySame(slot.type, type)
    meta.each |v, n| { verifyEq(slot.meta[n], v) }
    return slot
  }

  Void dumpBases(Spec spec)
  {
    echo
    echo("-- $spec.qname")
    spec.slots.each |s|
    {
      echo("  $s.name base=$s.base type=$s.type meta=$s.meta")
    }
  }
}

