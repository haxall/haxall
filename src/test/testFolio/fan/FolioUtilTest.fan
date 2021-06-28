//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Nov 2015  Brian Frank  Creation
//

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
    FolioUtil.checkTagVal("foo", Uri(s1000))
    FolioUtil.checkTagVal("foo", s32K)

    // diffs
    rec1 := Etc.makeDict(["id":Ref.gen, "mod":DateTime.nowUtc])
    rec2 := Etc.makeDict(["id":Ref.gen, "mod":DateTime.nowUtc])
    diff1 := Diff(rec1, ["change":"!"])
    FolioUtil.checkDiff(diff1)
    verifyErr(InvalidTagNameErr#) { FolioUtil.checkDiff(Diff(rec1, ["!bad":"x"])) }
    verifyErr(InvalidTagValErr#) { FolioUtil.checkDiff(Diff(rec1, ["bad":Env.cur])) }
    verifyErr(DiffErr#) { FolioUtil.checkDiffs(Diff[,]) }
    verifyErr(DiffErr#) { FolioUtil.checkDiffs([diff1, Diff(rec1, ["foo":"%"])]) }
    verifyErr(DiffErr#) { FolioUtil.checkDiffs([diff1, Diff(rec2, ["foo":"%"], Diff.transient)]) }

    // diff flags
    verifyDiffErr(Diff(null, ["foo":"bar"], Diff.add.or(Diff.transient)))
    verifyDiffErr(Diff(rec1, ["foo":"bar"], Diff.remove.or(Diff.transient)))

    // diff tag rule: never
    verifyDiffErr(Diff(rec1, ["id":Ref.gen]))
    verifyDiffErr(Diff(rec1, ["id":Ref.gen], Diff.transient))
    verifyDiffErr(Diff(rec1, ["mod":DateTime.now]))
    verifyDiffErr(Diff(rec1, ["mod":DateTime.now], Diff.transient))
    verifyDiffErr(Diff(rec1, ["transient":Marker.val]))
    verifyDiffErr(Diff(rec1, ["transient":Marker.val], Diff.transient))
    verifyDiffErr(Diff(rec1, ["hisSize":Number(3)]))
    verifyDiffErr(Diff(rec1, ["hisSize":Number(3)], Diff.transient))

    // diff tag rule: transient only
    verifyDiffErr(Diff(rec1, ["curVal":Number(3)]))
    verifyDiffErr(Diff(rec1, ["writeLevel":Number(3)]))
    verifyDiffErr(Diff(rec1, ["hisStatus":"ok"]))

    // diff tag rule: persitent  only
    verifyDiffErr(Diff(rec1, ["site":Marker.val], Diff.transient))
    verifyDiffErr(Diff(rec1, ["ext":"foo"], Diff.transient))
    verifyDiffErr(Diff(rec1, ["foobar":Bin("text/plain")], Diff.transient))
  }

  Void verifyDiffErr(Diff bad)
  {
    ok := Diff(Etc.makeDict(["id":Ref.gen, "mod":DateTime.nowUtc]), ["change":"ok"])
    verifyErr(DiffErr#) { FolioUtil.checkDiff(bad) }
    verifyErr(DiffErr#) { FolioUtil.checkDiffs([ok, bad]) }
  }

}