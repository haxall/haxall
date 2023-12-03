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
}