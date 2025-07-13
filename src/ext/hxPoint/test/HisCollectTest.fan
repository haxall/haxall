//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Mar 2021  Brian Frank  Creation
//

using haystack
using concurrent
using folio
using hx

**
** HisCollectTest
**
class HisCollectTest : HxTest
{

  @HxTestProj
  Void testConfig()
  {
    PointExt ext := addLib("point")

    verifyConfig(ext, ["hisCollectInterval":n(20, "min"), "kind":"Number"],
      "20min (0hr, 20min, 0sec)", "null", "1min", "null")

    verifyConfig(ext, ["hisCollectInterval":n(1, "hr"), "kind":"Bool"],
      "1hr (1hr, 0min, 0sec)", "null", "1sec", "null")

    verifyConfig(ext, ["hisCollectInterval":n(10, "sec"), "kind":"Str", "hisCollectWriteFreq":n(10, "min")],
      "10sec (0hr, 0min, 10sec)", "null", "1sec", "10min")

    verifyConfig(ext, ["hisCollectCov":m, "kind":"Bool"],
      "null (0hr, 0min, 0sec)", "marker", "1sec", "null")

    verifyConfig(ext, ["hisCollectCov":m, "kind":"Bool", "hisCollectCovRateLimit":n(5, "sec")],
      "null (0hr, 0min, 0sec)", "marker", "5sec", "null")

    verifyConfig(ext, ["hisCollectCov":n(1, "kW"), "kind":"Number", "hisCollectCovRateLimit":n(7, "sec"), "hisCollectWriteFreq":n(15, "min")],
      "null (0hr, 0min, 0sec)", "1kW", "7sec", "15min")

    verifyConfig(ext, ["hisCollectInterval":n(10, "sec"), "hisCollectCov":n(1, "kW"), "kind":"Number", "hisCollectCovRateLimit":n(7, "sec")],
      "10sec (0hr, 0min, 10sec)", "1kW", "7sec", "null")

    verifyConfig(ext, ["hisCollectInterval":n(20, "sec"), "hisCollectCov":n(1, "kW"), "kind":"Number"],
      "20sec (0hr, 0min, 20sec)", "1kW", "2sec", "null")
  }

  Void verifyConfig(PointExt ext, Str:Obj ptTags, Str interval, Str cov, Str rateLimit, Str writeFreq)
  {
    pt := addRec(ptTags.dup.addAll(["dis":"Point", "point":m, "his":m, "tz":"Chicago"]))

    proj.sync

    str := eval("pointDetails($pt.id.toCode)").toStr
    // echo("\n--- $ptTags"); echo(str)
    lines := str.splitLines
    findLine := |Str key->Str|
    {
      line := lines.find |x| { x.startsWith(key+":") }
      if (line == null) fail(key)
      return line[line.index(":")+1..-1].trim
    }

    verifyEq(findLine("interval"),  interval)
    verifyEq(findLine("cov"),  cov)
    verifyEq(findLine("covRateLimit"), rateLimit)
    verifyEq(findLine("writeFreq"), writeFreq)

    ext.hisCollectMgr.forceCheck
    watch := proj.watch.list.first ?: throw Err("no watch!")
    verifyEq(watch.dis, "HisCollect")
    verifyEq(watch.list.contains(pt.id), true)
  }

}

