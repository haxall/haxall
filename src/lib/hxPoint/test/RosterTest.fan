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
    addRec(["dis":"A", "point":m])
    addRec(["dis":"W", "point":m, "writable":m, "writeDef":n(123)])

    // now add library
    this.lib = rt.libs.add("point")
    this.lib.spi.sync
    sync

    // run tests
    verifyEnumMeta
    verifyWritables
  }

//////////////////////////////////////////////////////////////////////////
// EnumMeta
//////////////////////////////////////////////////////////////////////////

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
    sync

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

//////////////////////////////////////////////////////////////////////////
// Writables
//////////////////////////////////////////////////////////////////////////

  Void verifyWritables()
  {
    a := rt.db.read("dis==\"A\"")
    w := rt.db.read("dis==\"W\"")

    // initial writable point
    array := verifyWritable(w.id, n(123), 17)
    verifyEq(array[16]->val, n(123))

    // add writable tag to normal point
    a = commit(a, ["writable":m])
    sync
    verifyWritable(a.id, null, 17)

    // remove writable tag
    a = commit(a, ["writable":Remove.val])
    sync
    verifyNotWritable(a.id)

    // create new record
    x := addRec(["dis":"New", "point":m, "writable":m])
    sync
    verifyWritable(x.id, null, 17)

    // trash rec
    commit(x, ["trash":m])
    sync
    verifyNotWritable(x.id)

    // remove rec
    verifyWritable(w.id, n(123), 17)
    commit(w, null, Diff.remove)
    sync
    verifyNotWritable(w.id)
  }

  Grid verifyWritable(Ref id, Obj? val, Int level)
  {
    rec := rt.db.readById(id)
    if (rec.missing("writeLevel"))
    {
      rt.db.sync
      rec = rt.db.readById(id)
    }
    verifyEq(rec["writeVal"], val)
    verifyEq(rec["writeLevel"], n(level))
    array := writeArray(id)
    verifyEq(array.size, 17)
    return array
  }

  Void verifyNotWritable(Ref id)
  {
    verifyErrMsg(Err#, "Not writable point: $id.toZinc") { writeArray(id) }
  }

  Grid writeArray(Ref id) { lib.writeMgr.array(id) }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private Void sync() { rt.sync }

}