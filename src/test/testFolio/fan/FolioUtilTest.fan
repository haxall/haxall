//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Nov 2015  Brian Frank  Creation
//

using xeto
using haystack
using folio

**
** FolioUtilTest
**
class FolioUtilTest : HaystackTest
{

//////////////////////////////////////////////////////////////////////////
// Diff Checks
//////////////////////////////////////////////////////////////////////////

  Void testDiffChecks()
  {
    s60 := ""; 60.times { s60 += "x" }
    s61 := s60 + "x"
    s1000 := ""; 1000.times { s1000 += "x" }
    s32K := ""; 0x7fff.times { s32K += "\u00ff" }


    // checkRecId
    verifyErr(ParseErr#) { FolioUtil.checkRecId(Ref("")) }
    verifyErr(ParseErr#) { FolioUtil.checkRecId(Ref("x y")) }
    verifyErr(ParseErr#) { FolioUtil.checkRecId(Ref("x\u00ffy")) }
    verifyErr(InvalidRecIdErr#) { FolioUtil.checkRecId(Ref(s61)) }
    FolioUtil.checkRecId(Ref(s60))

    // checkTagName
    verifyErr(InvalidTagNameErr#) { FolioUtil.checkTagName("") }
    verifyErr(InvalidTagNameErr#) { FolioUtil.checkTagName("a b") }
    verifyErr(InvalidTagNameErr#) { FolioUtil.checkTagName("x\u00ffy") }
    verifyErr(InvalidTagNameErr#) { FolioUtil.checkTagName(s61) }
    FolioUtil.checkTagName(s60)

    // checkTagVal
    verifyErr(InvalidTagValErr#) { FolioUtil.checkTagVal("foo", null) }
    verifyErr(InvalidTagValErr#) { FolioUtil.checkTagVal("foo", this) }
    verifyErr(InvalidTagValErr#) { FolioUtil.checkTagVal("name", `foo`) }
    verifyErr(InvalidTagValErr#) { FolioUtil.checkTagVal("name", "bad tag") }
    verifyErr(InvalidTagValErr#) { FolioUtil.checkTagVal("foo", Uri(s1000+"x")) }
    verifyErr(InvalidTagValErr#) { FolioUtil.checkTagVal("foo", s32K+"x") }
    verifyErr(InvalidTagValErr#) { FolioUtil.checkTagVal("foo", this) }
    verifyErr(InvalidTagValErr#) { FolioUtil.checkTagVal("foo", DateSpan.today) }
    verifyErr(InvalidTagValErr#) { FolioUtil.checkTagVal("foo", [DateSpan.today]) }
    verifyErr(InvalidTagValErr#) { FolioUtil.checkTagVal("foo", Etc.dict1("span", DateSpan.today)) }
    FolioUtil.checkTagVal("foo", Uri(s1000))
    FolioUtil.checkTagVal("foo", s32K)

    // diff make
    rec1 := Etc.makeDict(["id":Ref.gen, "mod":DateTime.nowUtc])
    rec2 := Etc.makeDict(["id":Ref.gen, "mod":DateTime.nowUtc])
    diff1 := Diff(rec1, ["change":"!"])
    verifyErr(InvalidTagNameErr#) { x := Diff(rec1, ["!bad":"x"]) }
    verifyErr(InvalidTagValErr#) { x := Diff(rec1, ["bad":Env.cur]) }

    // diffs
    verifyErr(DiffErr#) { FolioUtil.checkDiffs(Diff[,]) }
    verifyErr(DiffErr#) { FolioUtil.checkDiffs([diff1, Diff(rec1, ["foo":"%"])]) }
    verifyErr(DiffErr#) { FolioUtil.checkDiffs([diff1, Diff(rec2, ["foo":"%"], Diff.transient)]) }

    // old/new handling
    verifyErr(DiffErr#) { x := Diff.makeAdd(["id":Ref.gen]) }
    verifyErr(DiffErr#) { x := Diff(null, ["id":Ref.gen], Diff.add) }
    verifyErr(DiffErr#) { x := Diff(Etc.dict0, ["foo":m], Diff.add) }
    verifyErr(DiffErr#) { x := Diff(null, ["id":Ref.gen]) }

    // diff flags
    verifyDiffErr(null, ["foo":"bar"], Diff.add.or(Diff.transient))
    verifyDiffErr(rec1, ["foo":"bar"], Diff.remove.or(Diff.transient))

    // diff tag rule: never
    verifyDiffErr(rec1, ["id":Ref.gen])
    verifyDiffErr(rec1, ["id":Ref.gen], Diff.transient)
    verifyDiffErr(rec1, ["mod":DateTime.now])
    verifyDiffErr(rec1, ["mod":DateTime.now], Diff.transient)
    verifyDiffErr(rec1, ["transient":Marker.val])
    verifyDiffErr(rec1, ["transient":Marker.val], Diff.transient)
    verifyDiffErr(rec1, ["hisSize":Number(3)])
    verifyDiffErr(rec1, ["hisSize":Number(3)], Diff.transient)

    // diff tag rule: transient only
    verifyDiffErr(rec1, ["curVal":Number(3)])
    verifyDiffErr(rec1, ["writeLevel":Number(3)])
    verifyDiffErr(rec1, ["hisStatus":"ok"])

    // diff tag rule: persitent  only
    verifyDiffErr(rec1, ["site":Marker.val], Diff.transient)
    verifyDiffErr(rec1, ["ext":"foo"], Diff.transient)
    verifyDiffErr(rec1, ["foobar":Bin("text/plain")], Diff.transient)

    // diff with point
    verifyEq(Diff(rec1, ["point":m]).flags, Diff.point)
    verifyEq(Diff(rec1, ["point":m]).isAddPoint, false)
    verifyEq(Diff.makeAdd(["point":m]).flags, Diff.add.or(Diff.point))
    verifyEq(Diff.makeAdd(["point":m]).isAddPoint, true)

    // diff with curVal
    verifyEq(Diff(rec1, ["curVal":n(123)], Diff.transient).flags, Diff.transient.or(Diff.curVal))
    verifyEq(Diff(rec1, ["curStatus":"ok"], Diff.transient).flags, Diff.transient.or(Diff.curVal))
    verifyEq(Diff(rec1, ["curErr":"foo"], Diff.transient).flags, Diff.transient)
  }

  Void verifyDiffErr(Dict? rec, Obj? changes, Int flags := 0)
  {
    verifyErr(DiffErr#) { x := Diff(rec, changes, flags) }
  }

//////////////////////////////////////////////////////////////////////////
// His Config - hisTz
//////////////////////////////////////////////////////////////////////////

  Void testHisTz()
  {
    verifyHisTz(["tz":"Chicago"], TimeZone("Chicago"))
    verifyHisTz([:],  null)
    verifyHisTz(["tz":n(123)], null)
    verifyHisTz(["tz":"bad!"], null)
  }

  Void verifyHisTz(Str:Obj tags, TimeZone? expected)
  {
    rec := Etc.makeDict(tags)
    verifySame(FolioUtil.hisTz(rec, false), expected)
    if(expected == null)  verifyErr(HisConfigErr#) { FolioUtil.hisTz(rec) }
  }

//////////////////////////////////////////////////////////////////////////
// His Config - hisKind
//////////////////////////////////////////////////////////////////////////

  Void testHisKind()
  {
    verifyHisKind(["kind":"Number"], Kind.number)
    verifyHisKind(["kind":"Bool"], Kind.bool)
    verifyHisKind([:],  null)
    verifyHisKind(["kind":n(123)], null)
    verifyHisKind(["kind":"bad!"], null)
    verifyHisKind(["kind":"Date"], null)
  }

  Void verifyHisKind(Str:Obj tags, Kind? expected)
  {
    rec := Etc.makeDict(tags)
    verifySame(FolioUtil.hisKind(rec, false), expected)
    if(expected == null)  verifyErr(HisConfigErr#) { FolioUtil.hisKind(rec) }
  }

//////////////////////////////////////////////////////////////////////////
// His Config - hisUnit
//////////////////////////////////////////////////////////////////////////

  Void testHisUnit()
  {
    verifyHisUnit([:], null)
    verifyHisUnit(["unit":"%"], Unit("%"))
    verifyHisUnit(["unit":"_foo"], Number.loadUnit("_foo"))
    verifyHisUnit(["unit":n(123)], null)
    verifyHisUnit(["unit":"bad!"], null)
  }

  Void verifyHisUnit(Str:Obj tags, Unit? expected)
  {
    rec := Etc.makeDict(tags)
    verifyEq(FolioUtil.hisUnit(rec, false), expected)
    if(expected == null && rec.has("unit")) verifyErr(HisConfigErr#) { FolioUtil.hisUnit(rec) }
  }

//////////////////////////////////////////////////////////////////////////
// His Config - hisTsPrecision
//////////////////////////////////////////////////////////////////////////

  Void testHisTsPrecision()
  {
    verifyHisTsPrecision([:], 1sec)
    verifyHisTsPrecision(["hisTsPrecision":n(1, "sec")], 1sec)
    verifyHisTsPrecision(["hisTsPrecision":n(1, "ms")], 1ms)
    verifyHisTsPrecision(["hisTsPrecision":"bad"], null)
    verifyHisTsPrecision(["id":Ref.gen, "hisTsPrecision":n(1)], null)
    verifyHisTsPrecision(["id":Ref("a", "A"), "hisTsPrecision":n(1, "min")], null)
  }

  Void verifyHisTsPrecision(Str:Obj tags, Duration? expected)
  {
    verifyEq(FolioUtil.hisTsPrecision(Etc.makeDict(tags), false), expected)
    rec := Etc.makeDict(tags)
    verifyEq(FolioUtil.hisTsPrecision(rec, false), expected)
    if(expected == null) verifyErr(HisConfigErr#) { FolioUtil.hisTsPrecision(rec) }
  }

//////////////////////////////////////////////////////////////////////////
// His Check
//////////////////////////////////////////////////////////////////////////

  Void testHisCheck()
  {
    // point errors
    verifyHisCheckErr("Rec missing 'point' tag", ["dis":"X"])
    verifyHisCheckErr("Rec missing 'his' tag", ["dis":"X", "point":m])
    verifyHisCheckErr("Missing 'kind' tag", ["dis":"X", "point":m, "his":m])
    verifyHisCheckErr("Invalid 'kind' tag: bad", ["dis":"X", "point":m, "his":m, "kind":"bad"])
    verifyHisCheckErr("Unsupported 'kind' for his: Date", ["dis":"X", "point":m, "his":m, "kind":"Date"])
    verifyHisCheckErr("Missing 'tz' tag", ["dis":"X", "point":m, "his":m, "kind":"Bool"])
    verifyHisCheckErr("Invalid 'tz' tag: Bad", ["dis":"X", "point":m, "his":m, "kind":"Bool", "tz":"Bad"])

    // item errors
    tz := TimeZone("Denver")
    verifyHisCheckErr(Str<|Mismatched timezone, rec tz "New_York" != item tz "Denver"|>,
      ["dis":"X", "point":m, "his":m, "kind":"Bool", "tz":"New_York"],
      [item(ts("2016-03-01 00:01:00", tz), true)])
    verifyHisCheckErr(Str<|Timestamps before 1950 not supported: {ts:1949-12-31T00:01:00-07:00 Denver, val:true}|>,
      ["dis":"X", "point":m, "his":m, "kind":"Bool", "tz":"Denver"],
      [item(ts("1949-12-31 00:01:00", tz), true)])
    verifyHisCheckErr(Str<|Cannot write null val|>,
      ["dis":"X", "point":m, "his":m, "kind":"Number", "tz":"Denver"],
      [item(ts("2016-03-01 00:01:00", tz), null)])
    verifyHisCheckErr(Str<|Mismatched value type, rec kind "Number" != item type "sys::TimeZone"|>,
      ["dis":"X", "point":m, "his":m, "kind":"Number", "tz":"Denver"],
      [item(ts("2016-03-01 00:01:00", tz), tz)])
    verifyHisCheckErr(Str<|Mismatched value type, rec kind "Number" != item type "sys::Bool"|>,
      ["dis":"X", "point":m, "his":m, "kind":"Number", "tz":"Denver"],
      [item(ts("2016-03-01 00:01:00", tz), true)])
    verifyHisCheckErr(Str<|Mismatched unit, rec unit '%' != item unit 'kPa'|>,
      ["dis":"X", "point":m, "his":m, "kind":"Number", "tz":"Denver", "unit":"%"],
      [item(ts("2016-03-01 00:01:00", tz), n(33, "kPa"))])
    verifyHisCheckErr(Str<|Mismatched unit, rec unit 'null' != item unit 'kPa'|>,
      ["dis":"X", "point":m, "his":m, "kind":"Number", "tz":"Denver"],
      [item(ts("2016-03-01 00:01:00", tz), n(33, "kPa"))])

    // timestamps sorted and normalized to 1sec
    rec := ["dis":"X", "point":m, "his":m, "kind":"Number", "tz":"Denver"]
    verifyHisCheck(rec,
      [item(ts("2016-03-01 00:02:00.123456", tz), n(5)),
       item(ts("2016-03-01 00:03:00.123456", tz), n(6)),
       item(ts("2016-03-01 00:01:00.123456", tz), n(4)),
       ],
      [item(ts("2016-03-01 00:01:00", tz), n(4)),
       item(ts("2016-03-01 00:02:00", tz), n(5)),
       item(ts("2016-03-01 00:03:00", tz), n(6))
       ])

    // timestamps sorted and normalized to 1ms
    verifyHisCheck(rec.dup.add("hisTsPrecision", n(1, "ms")).add("unit", "%"),
      [item(ts("2016-03-01 00:02:00.123456", tz), n(5)),
       item(ts("2016-03-01 00:03:00.987654", tz), n(6)),
       item(ts("2016-03-01 00:01:00.120099", tz), n(4)),
       ],
      [item(ts("2016-03-01 00:01:00.120", tz), n(4)),
       item(ts("2016-03-01 00:02:00.123", tz), n(5)),
       item(ts("2016-03-01 00:03:00.987", tz), n(6))
       ])

    // floats normalized to 32-bit
    f1 := Float.random
    f2 := Float.random * 100f
    f3 := Float.random * 1_000_000_000f
    verifyHisCheck(rec,
      [item(ts("2016-03-01 00:01:00", tz), n(f1)),
       item(ts("2016-03-01 00:02:00", tz), n(f2)),
       item(ts("2016-03-01 00:03:00", tz), n(f3)),
       ],
      [item(ts("2016-03-01 00:01:00", tz), n(normf(f1))),
       item(ts("2016-03-01 00:02:00", tz), n(normf(f2))),
       item(ts("2016-03-01 00:03:00", tz), n(normf(f3))),
       ])

    // dup timestamps with same value are merged
    verifyHisCheck(rec,
      [item(ts("2016-03-01 00:02:00.123", tz), n(1)),
       item(ts("2016-03-01 00:02:00.987", tz), n(2)),
       item(ts("2016-03-01 00:02:00.987", tz), n(3)),
       item(ts("2016-03-01 00:03:00.000", tz), n(4)),
       item(ts("2016-03-01 00:03:00.000", tz), n(5)),
       item(ts("2016-03-01 00:03:00.100", tz), n(6)),
       ],
      [item(ts("2016-03-01 00:02:00", tz), n(3)),
       item(ts("2016-03-01 00:03:00", tz), n(6)),
       ])

    // special values
    verifyHisCheck(rec,
      [item(ts("2016-03-01 00:50:01.123", tz), n(1)),
       item(ts("2016-03-01 00:50:01.987", tz), n(2)),
       item(ts("2016-03-01 00:50:02.070", tz), n(3)),
       item(ts("2016-03-01 00:50:02.071", tz), NA.val),
       item(ts("2016-03-01 00:50:03.00", tz), Remove.val),
       item(ts("2016-03-01 00:50:04.00",  tz), n(16791117)),
       item(ts("2016-03-01 00:50:05.00",  tz), n(2059198223)),
       item(ts("2016-03-01 00:50:06.00",  tz), n(4275878552)),
       ],
      [item(ts("2016-03-01 00:50:01", tz), n(2)),
       item(ts("2016-03-01 00:50:02", tz), NA.val),
       item(ts("2016-03-01 00:50:03", tz), Remove.val),
       item(ts("2016-03-01 00:50:04", tz), n(16791117)),
       item(ts("2016-03-01 00:50:05",  tz), n(2059198223)),
       item(ts("2016-03-01 00:50:06", tz), n(4275878552)),
       ])


    // negative zero, +/-inf, nan
    pzStr := "0.0"; pz := Float.fromStr(pzStr)
    nzStr := "-0.0";  nz := Float.fromStr(nzStr)
    verifyEq(nz.isNegZero, true)
    actual := verifyHisCheck(rec,
      [item(ts("2017-01-01 00:50:00", tz), n(pz)),
       item(ts("2017-01-01 00:51:00", tz), n(nz)),
       item(ts("2017-01-01 00:52:00", tz), n(Float.posInf)),
       item(ts("2017-01-01 00:53:00", tz), n(Float.negInf)),
       item(ts("2017-01-01 00:54:00", tz), n(Float.nan)),
       ],
      [item(ts("2017-01-01 00:50:00", tz), n(pz)),
       item(ts("2017-01-01 00:51:00", tz), n(pz)),
       item(ts("2017-01-01 00:52:00", tz), n(Float.posInf)),
       item(ts("2017-01-01 00:53:00", tz), n(Float.negInf)),
       item(ts("2017-01-01 00:54:00", tz), n(Float.nan)),
       ])
     verifyEq(actual[0].val->toFloat.toStr, "0.0")
     verifyEq(actual[1].val->toFloat.toStr, "0.0")
  }

  Void verifyHisCheckErr(Str msg, Str:Obj tags, HisItem[]? items := null)
  {
    errType := items == null ? HisConfigErr# : HisWriteErr#
    verifyErrMsg(errType, msg)
    {
      FolioUtil.hisWriteCheck(Etc.makeDict(tags), items ?: HisItem[,])
    }
  }

  HisItem[] verifyHisCheck(Str:Obj tags, HisItem[] items, HisItem[] expected)
  {
    actual := FolioUtil.hisWriteCheck(Etc.makeDict(tags), items)
    verifyItems(actual, expected)
    return actual
  }

//////////////////////////////////////////////////////////////////////////
// His Merge
//////////////////////////////////////////////////////////////////////////

  Void testHisMerge()
  {
    tz := TimeZone.utc

    verifyHisMerge(
      [item(ts("2016-03-01 00:02:00", tz), n(2))],
      [,],
      [item(ts("2016-03-01 00:02:00", tz), n(2))]
      )

    verifyHisMerge(
      [item(ts("2016-03-01 00:02:00", tz), n(2)),
       item(ts("2016-03-01 00:03:00", tz), n(3))],
      [,],
      [item(ts("2016-03-01 00:02:00", tz), n(2)),
       item(ts("2016-03-01 00:03:00", tz), n(3))]
      )

    verifyHisMerge(
      [,],
      [item(ts("2016-03-01 00:02:00", tz), n(2))],
      [item(ts("2016-03-01 00:02:00", tz), n(2))]
      )

    verifyHisMerge(
      [,],
      [item(ts("2016-03-01 00:02:00", tz), Remove.val)],
      [,]
      )

    verifyHisMerge(
      [,],
      [item(ts("2016-03-01 00:01:00", tz), Remove.val),
       item(ts("2016-03-01 00:03:00", tz), n(3)),
       item(ts("2016-03-01 00:05:00", tz), Remove.val)],
      [item(ts("2016-03-01 00:03:00", tz), n(3))]
      )

    verifyHisMerge(
      [item(ts("2016-03-01 00:02:00", tz), n(2)),
       item(ts("2016-03-01 00:04:00", tz), n(4)),
       item(ts("2016-03-01 00:06:00", tz), n(6)),
       ],
      [item(ts("2016-03-01 00:01:00", tz), n(1)),
       item(ts("2016-03-01 00:03:00", tz), n(3)),
       item(ts("2016-03-01 00:05:00", tz), n(5)),
       item(ts("2016-03-01 00:07:00", tz), n(7)),
       ],
      [item(ts("2016-03-01 00:01:00", tz), n(1)),
       item(ts("2016-03-01 00:02:00", tz), n(2)),
       item(ts("2016-03-01 00:03:00", tz), n(3)),
       item(ts("2016-03-01 00:04:00", tz), n(4)),
       item(ts("2016-03-01 00:05:00", tz), n(5)),
       item(ts("2016-03-01 00:06:00", tz), n(6)),
       item(ts("2016-03-01 00:07:00", tz), n(7)),
       ])

    verifyHisMerge(
      [item(ts("2016-03-01 00:02:00", tz), n(2)),
       item(ts("2016-03-01 00:03:00", tz), n(3)),
       item(ts("2016-03-01 00:06:00", tz), n(6)),
       item(ts("2016-03-01 00:07:00", tz), n(7)),
       ],
      [item(ts("2016-03-01 00:04:00", tz), n(4)),
       item(ts("2016-03-01 00:05:00", tz), n(5)),
       ],
      [item(ts("2016-03-01 00:02:00", tz), n(2)),
       item(ts("2016-03-01 00:03:00", tz), n(3)),
       item(ts("2016-03-01 00:04:00", tz), n(4)),
       item(ts("2016-03-01 00:05:00", tz), n(5)),
       item(ts("2016-03-01 00:06:00", tz), n(6)),
       item(ts("2016-03-01 00:07:00", tz), n(7)),
       ])

    verifyHisMerge(
      [item(ts("2016-03-01 00:04:00", tz), n(4)),
       item(ts("2016-03-01 00:05:00", tz), n(5)),
       item(ts("2016-03-01 00:07:00", tz), n(7)),
       ],
      [item(ts("2016-03-01 00:01:00", tz), n(1)),
       item(ts("2016-03-01 00:02:00", tz), n(2)),
       item(ts("2016-03-01 00:03:00", tz), n(3)),
       item(ts("2016-03-01 00:06:00", tz), n(6)),
       ],
      [item(ts("2016-03-01 00:01:00", tz), n(1)),
       item(ts("2016-03-01 00:02:00", tz), n(2)),
       item(ts("2016-03-01 00:03:00", tz), n(3)),
       item(ts("2016-03-01 00:04:00", tz), n(4)),
       item(ts("2016-03-01 00:05:00", tz), n(5)),
       item(ts("2016-03-01 00:06:00", tz), n(6)),
       item(ts("2016-03-01 00:07:00", tz), n(7)),
       ])

    verifyHisMerge(
      [item(ts("2016-03-01 00:01:00", tz), n(1)),
       item(ts("2016-03-01 00:02:00", tz), n(2)),
       item(ts("2016-03-01 00:03:00", tz), n(3)),
       ],
      [item(ts("2016-03-01 00:03:00", tz), n(33)),
       ],
      [item(ts("2016-03-01 00:01:00", tz), n(1)),
       item(ts("2016-03-01 00:02:00", tz), n(2)),
       item(ts("2016-03-01 00:03:00", tz), n(33))
       ])

    verifyHisMerge(
      [item(ts("2016-03-01 00:01:00", tz), n(1)),
       item(ts("2016-03-01 00:02:00", tz), n(2)),
       item(ts("2016-03-01 00:03:00", tz), n(3)),
       ],
      [item(ts("2016-03-01 00:03:00", tz), Remove.val),
       ],
      [item(ts("2016-03-01 00:01:00", tz), n(1)),
       item(ts("2016-03-01 00:02:00", tz), n(2))
       ])

    verifyHisMerge(
      [item(ts("2016-03-01 00:01:00", tz), n(1)),
       item(ts("2016-03-01 00:02:00", tz), n(2)),
       item(ts("2016-03-01 00:03:00", tz), n(3)),
       ],
      [item(ts("2016-03-01 00:03:00", tz), Remove.val),
       item(ts("2016-03-01 00:04:00", tz), Remove.val),
       item(ts("2016-03-01 00:05:00", tz), n(5)),
       ],
      [item(ts("2016-03-01 00:01:00", tz), n(1)),
       item(ts("2016-03-01 00:02:00", tz), n(2)),
       item(ts("2016-03-01 00:05:00", tz), n(5))
       ])

    verifyHisMerge(
      [item(ts("2016-03-01 00:03:00", tz), n(3)),
       item(ts("2016-03-01 00:04:00", tz), n(4)),
       ],
      [item(ts("2016-03-01 00:01:00", tz), n(1)),
       item(ts("2016-03-01 00:02:00", tz), n(2)),
       item(ts("2016-03-01 00:03:00", tz), n(33)),
       ],
      [item(ts("2016-03-01 00:01:00", tz), n(1)),
       item(ts("2016-03-01 00:02:00", tz), n(2)),
       item(ts("2016-03-01 00:03:00", tz), n(33)),
       item(ts("2016-03-01 00:04:00", tz), n(4))
       ])

    verifyHisMerge(
      [item(ts("2016-03-01 00:03:00", tz), n(3)),
       item(ts("2016-03-01 00:04:00", tz), n(4)),
       ],
      [item(ts("2016-03-01 00:01:00", tz), Remove.val),
       item(ts("2016-03-01 00:02:00", tz), Remove.val),
       item(ts("2016-03-01 00:03:00", tz), Remove.val),
       ],
      [item(ts("2016-03-01 00:04:00", tz), n(4))
       ])

    verifyHisMerge(
      [item(ts("2016-03-01 00:03:00", tz), n(3)),
       item(ts("2016-03-01 00:04:00", tz), n(4)),
       ],
      [item(ts("2016-03-01 00:01:00", tz), Remove.val),
       item(ts("2016-03-01 00:02:00", tz), Remove.val),
       item(ts("2016-03-01 00:03:00", tz), Remove.val),
       item(ts("2016-03-01 00:04:00", tz), Remove.val),
       item(ts("2016-03-01 00:05:00", tz), Remove.val),
       ],
      [,
       ])

    verifyHisMerge(
      [item(ts("2016-03-01 00:01:00", tz), n(1)),
       item(ts("2016-03-01 00:02:00", tz), n(2)),
       item(ts("2016-03-01 00:03:00", tz), n(3)),
       item(ts("2016-03-01 00:04:00", tz), n(4)),
       item(ts("2016-03-01 00:05:00", tz), n(5)),
       ],
      [item(ts("2016-03-01 00:02:00", tz), n(22)),
       item(ts("2016-03-01 00:03:00", tz), n(33)),
       item(ts("2016-03-01 00:05:00", tz), Remove.val),
       item(ts("2016-03-01 00:06:00", tz), n(66)),
       item(ts("2016-03-01 00:07:00", tz), Remove.val),
       item(ts("2016-03-01 00:09:00", tz), n(99)),
       item(ts("2016-03-01 00:08:00", tz), Remove.val),
       ],
      [item(ts("2016-03-01 00:01:00", tz), n(1)),
       item(ts("2016-03-01 00:02:00", tz), n(22)),
       item(ts("2016-03-01 00:03:00", tz), n(33)),
       item(ts("2016-03-01 00:04:00", tz), n(4)),
       item(ts("2016-03-01 00:06:00", tz), n(66)),
       item(ts("2016-03-01 00:09:00", tz), n(99)),
       ])

    100.times |->|
    {
      cur := HisItem[,]
      changes := HisItem[,]
      expected := HisItem[,]
      20.times |hr|
      {
        ts := ts("2016-02-29 "+hr.toLocale("00")+":00:00", tz)
        val := n(hr)
        bad := n(99)
        switch ((0..3).random)
        {
          case 0:
            cur.add(HisItem(ts, val))
            expected.add(cur.last)
          case 1:
            changes.add(item(ts, val))
            expected.add(changes.last)
          case 2:
            cur.add(item(ts, bad))
            changes.add(item(ts, val))
            expected.add(changes.last)
          case 3:
            cur.add(item(ts, bad))
            changes.add(item(ts, Remove.val))
        }
      }
      verifyHisMerge(cur, changes, expected)
    }
  }

  Void verifyHisMerge(HisItem[] cur, HisItem[] changes , HisItem[] expected)
  {
    actual := FolioUtil.hisWriteMerge(cur, changes)
    verifyNotSame(actual, cur)
    verifyNotSame(actual, changes)
    verifyItems(actual, expected)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Void verifyItems(HisItem[] actual, HisItem[] expected)
  {
    verifyEq(actual.size, expected.size)
    actual.each |a, i|
    {
      verifyEq(a, expected[i])
    }
  }

  static HisItem item(DateTime ts, Obj? val)
  {
    HisItem(ts, val)
  }

  static DateTime ts(Str s, TimeZone tz)
  {
    DateTime.fromLocale(s, "YYYY-MM-DD hh:mm:ss.FFFFFF", tz)
  }

  static Float normf(Float f)
  {
    Float.makeBits32(f.bits32)
  }

}

