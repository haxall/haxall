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
    addRec(["dis":"A", "point":m, "his":m, "tz":"New_York"])
    addRec(["dis":"W", "point":m, "his":m, "tz":"New_York", "writable":m, "writeDef":n(123)])
    addRec(["dis":"Int", "point":m, "his":m, "tz":"New_York", "hisCollectInterval":n(10, "sec")])
    addRec(["dis":"Cov", "point":m, "his":m, "tz":"New_York", "hisCollectCov":m])

    // now add library
    this.lib = rt.libs.add("point")
    this.lib.spi.sync
    sync

    // run tests
    verifyEnumMeta
    verifyWritables
    verifyHisCollects
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
    commit(rt.db.read(Filter("enumMeta")), [
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
    commit(rt.db.read(Filter("enumMeta")), ["trash":m])
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
    a := rt.db.read(Filter("dis==\"A\""))
    w := rt.db.read(Filter("dis==\"W\""))

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
// HisCollect
//////////////////////////////////////////////////////////////////////////

  Void verifyHisCollects()
  {
    int := rt.db.read(Filter("dis==\"Int\""))
    cov := rt.db.read(Filter("dis==\"Cov\""))
    a := rt.db.read(Filter("dis==\"A\""))

    verifyHisCollect(int.id, 10sec, false)
    verifyHisCollect(cov.id, null, true)
    verifyNotHisCollect(a.id)
    verifyHisCollectWatch([int, cov])

    // add collect to non-collect point
    a = commit(a, ["hisCollectInterval":n(5, "min"), "hisCollectCov":m])
    sync
    verifyHisCollect(a.id, 5min, true)
    verifyHisCollectWatch([int, cov, a])

    // remove hisCollectCov tag
    a = commit(a, ["hisCollectCov":Remove.val])
    sync
    verifyHisCollect(a.id, 5min, false)
    verifyHisCollectWatch([int, cov, a])

    // change hisCollectInterval tag
    a = commit(a, ["hisCollectInterval":n(1, "hr")])
    sync
    verifyHisCollect(a.id, 1hr, false)
    verifyHisCollectWatch([int, cov, a])

    // remove hisCollectInterval tag
    a = commit(a, ["hisCollectInterval":Remove.val])
    sync
    verifyNotHisCollect(a.id)
    verifyHisCollectWatch([int, cov])

    // create new record
    x := addRec(["dis":"New", "point":m, "his":m, "tz":"New_York", "hisCollectInterval":n(30, "sec")])
    sync
    verifyHisCollect(x.id, 30sec, false)
    verifyHisCollectWatch([int, cov, x])

    // trash rec
    commit(x, ["trash":m])
    sync
    verifyNotHisCollect(x.id)
    verifyHisCollectWatch([int, cov])

    // remove rec
    verifyHisCollect(cov.id, null, true)
    commit(cov, null, Diff.remove)
    sync
    verifyNotWritable(cov.id)
    verifyHisCollectWatch([int])
  }

  Void verifyHisCollect(Ref id, Duration? interval, Bool cov)
  {
    details := lib.hisCollectMgr.details(id)
    // echo("\n----$id.dis | $details")
    verifyNotNull(details)
    lines := details.splitLines
    intLine := lines.find { it.startsWith("interval:") }
    covLine := lines.find { it.startsWith("cov:")  }
    verifyEq(intLine.contains(interval?.toStr ?: "_x_"), interval != null)
    verifyEq(covLine.contains("marker"), cov)
    verifyEq(rt.watch.isWatched(id), true)
  }

  Void verifyNotHisCollect(Ref id)
  {
    details := lib.hisCollectMgr.details(id)
    verifyNull(details)
    verifyEq(rt.watch.isWatched(id), false)
  }

  Void verifyHisCollectWatch(Dict[] recs)
  {
    watch := rt.watch.list.first ?: throw Err("no watch")
    verifyEq(watch.dis, "HisCollect")
    verifyEq(recs.map |r->Ref| { r.id }.sort, watch.list.dup.sort)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private Void sync()
  {
    rt.sync
    lib.hisCollectMgr.forceCheck
  }

}