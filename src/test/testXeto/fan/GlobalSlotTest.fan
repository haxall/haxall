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
** GlobalSlotTest
**
@Js
class GlobalSlotTest : AbstractXetoTest
{

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  Void testBasics()
  {
    lib := compileLib(
      Str<|// Person global slot marker
           person: Marker <foo>

           // Person spec
           Person: Dict { person }
           |>)

     marker := env.spec("sys::Marker")

     g := lib.top("person")
     t := lib.top("Person")
     m := t.slot("person")

     // Lib.top lookups
     verifyEq(lib.tops, Spec[t, g])
     verifyEq(lib.tops.isImmutable, true)
     verifyEq(lib.top("Bad", false), null)
     verifyErr(UnknownSpecErr#) { lib.top("Bad") }
     verifyErr(UnknownSpecErr#) { lib.top("bad", true) }

     // Lib.global lookups
     verifyEq(g.isType, false)
     verifyEq(g.isGlobal, true)
     verifyEq(lib.globals, Spec[g])
     verifyEq(lib.globals.isImmutable, true)
     verifyEq(g.base, marker)
     verifyEq(g.type, marker)
     verifySame(lib.global("person"), g)
     verifyEq(lib.type("person", false), null)
     verifyErr(UnknownSpecErr#) { lib.type("person") }
     verifyErr(UnknownSpecErr#) { lib.type("person", true) }

     // Lib.type lookups
     verifyEq(t.isType, true)
     verifyEq(t.isGlobal, false)
     verifyEq(lib.types, Spec[t])
     verifyEq(lib.types.isImmutable, true)
     verifySame(lib.type("Person"), t)
     verifyErr(UnknownSpecErr#) { lib.global("Person") }
     verifyErr(UnknownSpecErr#) { lib.global("Person", true) }

     // verify Person.person is derived from global person
     verifySame(m.base, g)
     verifySame(m.type, env.spec("sys::Marker"))
     verifyEq(m.meta["doc"], "Person global slot marker")
     verifyEq(m.meta["foo"], Marker.val)
  }

//////////////////////////////////////////////////////////////////////////
// Inheritance
//////////////////////////////////////////////////////////////////////////

  Void testInheritance()
  {
    lib := compileLib(
      Str<|a: Str <foo> "alpha"
           b: Date <bar> "2023-12-03"
           c: Marker <foo, bar>

           Baz: Dict {
             a: Str
             b: Date <baz>
             c
           }

           Qux: Baz {
             b: Date <qux> "2024-01-01"
           }

           Rux: Qux {
             c: Marker <rux>
           }
           |>)

     str    := env.spec("sys::Str")
     date   := env.spec("sys::Date")
     marker := env.spec("sys::Marker")

     a := verifyGlobal(lib.global("a"), str,    ["foo":m, "val":"alpha"])
     b := verifyGlobal(lib.global("b"), date,   ["bar":m, "val":Date("2023-12-03")])
     c := verifyGlobal(lib.global("c"), marker, ["foo":m, "bar":m])

     baz := lib.type("Baz")
     qux := lib.type("Qux")
     rux := lib.type("Rux")

     verifyEq(a.base, str)
     verifyEq(a.type, str)

     //dumpBases(baz)
     //dumpBases(qux)
     //dumpBases(rux)

     // Baz
     bazA := verifySlot(baz, "a", a, str,    ["foo":m, "val":"alpha"])
     bazB := verifySlot(baz, "b", b, date,   ["bar":m, "val":Date("2023-12-03")])
     bazC := verifySlot(baz, "c", c, marker, ["foo":m, "bar":m])

     // Qux
     quxA := verifySlot(qux, "a", a,    str,    ["foo":m, "val":"alpha"])
     quxB := verifySlot(qux, "b", bazB, date,   ["bar":m, "val":Date("2024-01-01"), "qux":m])
     quxC := verifySlot(qux, "c", c,    marker, ["foo":m, "bar":m])
     verifySame(quxA, bazA)
     verifySame(quxC, bazC)

     // Rux
     ruxA := verifySlot(rux, "a", a,    str,    ["foo":m, "val":"alpha"])
     ruxB := verifySlot(rux, "b", bazB, date,   ["bar":m, "val":Date("2024-01-01"), "qux":m])
     ruxC := verifySlot(rux, "c", quxC, marker, ["foo":m, "bar":m, "rux":m])
     verifySame(ruxA, bazA)
     verifySame(ruxB, quxB)
  }

  Spec verifyGlobal(Spec global, Spec type, Str:Obj meta)
  {
    verifySame(global.type, type)
    verifySame(global.base, type)
    verifyDictEq(global.metaOwn, meta)
    meta.each |v, n| { verifyEq(global.meta[n], v) }
    return global
  }

  Spec verifySlot(Spec parent, Str name, Spec base, Spec type, Str:Obj meta)
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