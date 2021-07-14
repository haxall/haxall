//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Jul 2021  Brian Frank  Creation
//

using haystack
using concurrent
using folio
using hx

**
** RosterTest
**
class RosterTest : HxTest
{
  PointLib? lib

  @HxRuntimeTest
  Void test()
  {
    // initial recs
    addRec(["enumMeta":m,
            "alpha": Str<|ver:"3.0"
                          name
                          "off"
                          "slow"
                          "fast"|>])

    // now add library
    this.lib = rt.libs.add("point")
    this.lib.spi.sync
    rt.sync

    // run tests
    verifyEnumMeta
  }

  Void verifyEnumMeta()
  {
    // initial setup has one alpha enum def
    verifyEq(lib.enums.list.size, 1)
    e := lib.enums.get("alpha")
    verifyEnumDef(e, "off",  0)
    verifyEnumDef(e, "slow", 1)
    verifyEnumDef(e, "fast", 2)

    // make a change to alpha and add beta
    commit(rt.db.read("enumMeta"), [
       "alpha": Str<|ver:"3.0"
                     name
                     "xoff"
                     "xslow"
                     "xfast"|>,
       "beta": Str<|ver:"3.0"
                     name,code
                     "one",1
                     "two",2|>])
    rt.sync

    verifyEq(lib.enums.list.size, 2)
    e = lib.enums.get("alpha")
    verifyEnumDef(e, "xoff",  0)
    verifyEnumDef(e, "xslow", 1)
    verifyEnumDef(e, "xfast", 2)

    e = lib.enums.get("beta")
    verifyEnumDef(e, "one",  1)
    verifyEnumDef(e, "two", 2)

    // trash the enumMeta record
    commit(rt.db.read("enumMeta"), ["trash":m])
    rt.sync
    verifyEq(lib.enums.list.size, 0)
  }

  Void verifyEnumDef(EnumDef e, Str name, Int code)
  {
    verifyEq(e.nameToCode(name), n(code))
    verifyEq(e.codeToName(n(code)), name)
  }

}