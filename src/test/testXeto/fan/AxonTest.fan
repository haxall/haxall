//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Mar 2023  Brian Frank  Creation
//

using xeto
using haystack
using haystack::Dict  // TODO: need Dict.id
using haystack::Ref
using axon
using folio
using hx

**
** AxonTest
**
class AxonTest : AbstractAxonTest
{

//////////////////////////////////////////////////////////////////////////
// SpecsExpr
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testSpecExpr()
  {
    // simple
    ns := initNamespace(["ph", "ph.points", "hx.test.xeto", "hx.test.xeto.deep"])
    verifySpecRef(Str<|Str|>, "sys::Str")
    verifySpecRef(Str<|Dict|>, "sys::Dict")
    verifySpecRef(Str<|Point|>, "ph::Point")

    // qualified
    verifySpecRef(Str<|ph::Point|>, "ph::Point")
    verifySpecRef(Str<|ph.points::AirTempSensor|>, "ph.points::AirTempSensor")
    verifySpecRef(Str<|hx.test.xeto::Alpha|>, "hx.test.xeto::Alpha")
    verifySpecRef(Str<|hx.test.xeto.deep::Beta|>, "hx.test.xeto.deep::Beta")
  }

  Spec verifySpecRef(Str expr, Str qname)
  {
    cx := makeContext
    Spec x := cx.eval(expr)
    // echo(":::REF:::: $expr => $x [$x.typeof]")
    verifySame(cx.ns.xeto, xns)
    verifySame(x, xns.spec(qname))
    return x
  }

//////////////////////////////////////////////////////////////////////////
// Reflection Funcs
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testReflect()
  {
    ns := initNamespace(["ph", "ph.points", "hx.test.xeto"])

    // specLib
    verifySame(eval("""specLib("ph.points")"""), ns.lib("ph.points"))
    verifySame(eval("""specLib(@lib:ph.points)"""), ns.lib("ph.points"))
    verifyEq(eval("""specLib("badone", false)"""), null)
    verifyEq(eval("""specLib(@lib:bad.one, false)"""), null)

    // specLibs
    verifyDictsEq(eval("""specLibs()"""), ns.libs)
    verifyDictsEq(eval("""specLibs(id==@lib:ph.points)"""), [xns.lib("ph.points")])

    // spec
    verifySame(eval("""spec("sys::Str")"""), ns.spec("sys::Str"))
    verifySame(eval("""spec(@sys::Str)"""), ns.spec("sys::Str"))
    verifySame(eval("""spec("ph::Site.site")"""), ns.spec("ph::Site.site"))
    verifyEq(eval("""spec("ph::Site.badOne", false)"""), null)

    // specs
    allTypes := Spec[,]
    ns.eachType |t| { allTypes.add(t) }
    verifyDictsEq(eval("""specs()"""), allTypes)
    verifyDictsEq(eval("""specs(null)"""), allTypes)
    verifyDictsEq(eval("""specLib("ph").specs"""), ns.lib("ph").types)
    verifyDictsEq(eval("""do x: specLib("ph"); specs(x); end"""), ns.lib("ph").types)
    verifyDictsEq(eval("""specs(null, abstract)"""), allTypes.findAll |x| { x.has("abstract") })
    verifyDictsEq(eval("""specs(null, abstract)"""),allTypes.findAll |x| { x.has("abstract") })
    verifyDictsEq(eval("""specs(null, base==@sys::Seq)"""), allTypes.findAll |x| { x.base?.qname == "sys::Seq" })
    verifyDictsEq(eval("""specs(null, slots->of)"""), Spec[ns.spec("sys::Spec")])
    verifyDictsEq(eval("""specLib("ph").specs(slots->vav)"""), [ns.spec("ph::Vav")])
    verifyDictsEq(eval("""[specLib("ph")].specs(slots->vav)"""), [ns.spec("ph::Vav")])

    // specX
    verifyReflect("Obj", ns.type("sys::Obj"))
    verifyReflect("Str", ns.type("sys::Str"))
    verifyReflect("Dict", ns.type("sys::Dict"))
    verifyReflect("LibOrg", ns.type("sys::LibOrg"))

    // instance
    verifySame(eval("""instance("hx.test.xeto::test-a")"""), ns.instance("hx.test.xeto::test-a"))
    verifySame(eval("""instance(@hx.test.xeto::test-a)"""), ns.instance("hx.test.xeto::test-a"))
    verifySame(eval("""instance(@bad::one, false)"""), null)

    // instances
    allInstances := Dict[,]
    ns.libs.each |lib| { lib.instances.each |x| { allInstances.add(x) } }
    verifyDictsEq(eval("""instances()"""), allInstances)
    verifyDictsEq(eval("""do x: specLib("hx.test.xeto"); instances(x); end"""), ns.lib("hx.test.xeto").instances)
    verifyDictsEq(eval("""specLib("hx.test.xeto").instances"""), ns.lib("hx.test.xeto").instances)
    verifyDictsEq(eval("""[specLib("hx.test.xeto")].instances(alpha)"""), [ns.instance("hx.test.xeto::test-a")])
  }

  Void verifyReflect(Str expr, Spec spec)
  {
    verifyEval("specParent($expr)", spec.parent)
    verifyEval("specName($expr)", spec.name)
    verifyEval("specQName($expr)", spec.qname)
    verifyEval("specType($expr)", spec.type)
    verifyEval("specBase($expr)", spec.base)
    verifyDictEq(eval("specMetaOwn($expr)"), spec.metaOwn)
    verifyDictEq(eval("specSlots($expr)"), spec.slots.toDict)
    verifyDictEq(eval("specSlotsOwn($expr)"), spec.slotsOwn.toDict)
  }

//////////////////////////////////////////////////////////////////////////
// SpecOf function
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testSpecOf()
  {
    ns := initNamespace(["ph"])

    verifySpec(Str<|specOf(marker())|>, "sys::Marker")
    verifySpec(Str<|specOf("hi")|>, "sys::Str")
    verifySpec(Str<|specOf(@id)|>, "sys::Ref")
    verifySpec(Str<|specOf([])|>, "sys::List")
    verifySpec(Str<|specOf({})|>, "sys::Dict")
    verifySpec(Str<|specOf(Str)|>, "sys::Spec")
    verifySpec(Str<|specOf(toGrid("hi"))|>, "sys::Grid")
    verifySpec(Str<|specOf(toGrid("hi"))|>, "sys::Grid")
    verifySpec(Str<|specOf(Str)|>, "sys::Spec")
  }

//////////////////////////////////////////////////////////////////////////
// SpecIs function
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testSpecIs()
  {
    verifySpecIs(Str<|specIs(Str, Obj)|>,    true)
    verifySpecIs(Str<|specIs(Str, Scalar)|>, true)
    verifySpecIs(Str<|specIs(Str, Str)|>,    true)
    verifySpecIs(Str<|specIs(Str, Marker)|>, false)
    verifySpecIs(Str<|specIs(Str, Dict)|>,   false)

    ns := initNamespace(["ph"])

    verifySpecIs(Str<|specIs(Meter, Obj)|>,    true)
    verifySpecIs(Str<|specIs(Meter, Dict)|>,   true)
    verifySpecIs(Str<|specIs(Meter, Entity)|>, true)
    verifySpecIs(Str<|specIs(Meter, Equip)|>,  true)
    verifySpecIs(Str<|specIs(Meter, Point)|>,  false)
    verifySpecIs(Str<|specIs(Meter, Str)|>,    false)
  }

  Void verifySpecIs(Str expr, Bool expect)
  {
    // override hook to reuse specIs() tests for specFits()
    if (verifySpecIsFunc != null) return verifySpecIsFunc(expr, expect)

    verifyEval(expr, expect)
  }

  |Str,Bool|? verifySpecIsFunc := null

//////////////////////////////////////////////////////////////////////////
// Is function
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testIs()
  {
    verifyIs(Str<|is("hi", Str)|>,    true)
    verifyIs(Str<|is("hi", Marker)|>, false)
    verifyIs(Str<|is("hi", Dict)|>,   false)

    verifyIs(Str<|is(marker(), Str)|>,    false)
    verifyIs(Str<|is(marker(), Marker)|>, true)
    verifyIs(Str<|is(marker(), Dict)|>,   false)

    verifyIs(Str<|is({}, Str)|>,    false)
    verifyIs(Str<|is({}, Marker)|>, false)
    verifyIs(Str<|is({}, Dict)|>,   true)

  }

  Void verifyIs(Str expr, Bool expect)
  {
    // override hook to reuse is() tests for fits()
    if (verifyIsFunc != null) return verifyIsFunc(expr, expect)

    verifyEval(expr, expect)
  }

  |Str,Bool|? verifyIsFunc := null

//////////////////////////////////////////////////////////////////////////
// Filter Is
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testFilterIs()
  {
    ns := initNamespace(["ph"])

    a := Etc.makeDict(["dis":"A"])
    b := Etc.makeDict(["dis":"B", "spec":Ref("ph::Ahu")])
    c := Etc.makeDict(["dis":"C", "spec":Ref("ph::Rtu")])
    recs := [a, b, c]

    verifyFilterIs(recs, "None", Dict[,])
    verifyFilterIs(recs, "Dict", [a, b, c])
    verifyFilterIs(recs, "Equip", [b, c])
    verifyFilterIs(recs, "Ahu", [b, c])
    verifyFilterIs(recs, "Rtu", [c])
  }

  Void verifyFilterIs(Dict[] recs, Str expr, Dict[] expect)
  {
    filter := Filter(expr)
    verifyEq(filter.type, FilterType.isSpec)
    cx := makeContext
    actual := Dict[,]
    recs.each |r| { if (filter.matches(r, cx)) actual.add(r) }
    verifyEq(actual, expect)
  }

//////////////////////////////////////////////////////////////////////////
// Folio ReadAll
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testFolioReadAll()
  {
    ns := initNamespace(["ph"])

    a := addRec(["dis":"a", "spec":Ref("ph::Ahu")])
    b := addRec(["dis":"b", "spec":Ref("ph::Rtu")])
    c := addRec(["dis":"c", "spec":Ref("ph::ElecMeter")])
    d := addRec(["dis":"d", "spec":Ref("ph::Meter")])

    verifyFolioReadAll("Equip", [a, b, c, d])
    verifyFolioReadAll("ph::Equip", [a, b, c, d])
    verifyFolioReadAll("Ahu", [a, b])
    verifyFolioReadAll("ph::Rtu", [b])
    verifyFolioReadAll("Meter", [c, d])
    verifyFolioReadAll("ElecMeter", [c])
  }

  Void verifyFolioReadAll(Str filter, Dict[] expect)
  {
    actual := rt.db.readAll(Filter(filter)).sortDis
    a := actual.toRows.join(",") { it.dis }
    e := expect.join(",") { it.dis }
    // echo("-- $filter | $a ?= $e")
    verifyEq(a, e)
  }

//////////////////////////////////////////////////////////////////////////
// SpecFits function
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testSpecFits()
  {
    ns := initNamespace(["ph"])

    // run all the is tests with fits
    verifySpecIsFunc = |Str expr, Bool expect|
    {
      verifySpecFits(expr.replace("specIs(", "specFits("), expect)
    }
    testSpecIs
  }

  Void verifySpecFits(Str expr, Bool expect)
  {
    // echo("   $expr")
    verifyEval(expr, expect)
  }

//////////////////////////////////////////////////////////////////////////
// Fits function
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testFits()
  {
    // run all the is tests with fits
    verifyIsFunc = |Str expr, Bool expect|
    {
      verifyFits(expr.replace("is(", "fits("), expect)
    }
    testIs

    verifyFits(Str<|fits("hi", Str)|>, true)
    verifyFits(Str<|fits("hi", Marker)|>, false)
    verifyFits(Str<|fits("hi", Dict)|>, false)

    ns := initNamespace(["ph"])

    verifyFits(Str<|fits({site}, Str)|>, false)
    verifyFits(Str<|fits({site}, Dict)|>, true)
    verifyFits(Str<|fits({id:@x, site}, Equip)|>, false)
    verifyFits(Str<|fits({id:@x, site}, Site)|>, true)
    verifyFits(Str<|fits(`ok`, CurStatus)|>, false)
    verifyFits(Str<|fits("foo", CurStatus)|>, false)
    verifyFits(Str<|fits("ok", CurStatus)|>, true)
    verifyFits(Str<|fits("bool", Kind)|>, false)
    verifyFits(Str<|fits("Bool", Kind)|>, true)
    verifyFits(Str<|fits({discharge}, Choice)|>, false)
    verifyFits(Str<|fits({discharge}, DuctSection)|>, false)
    verifyFits(Str<|fits({discharge}, DischargeDuct)|>, true)
    // TODO: to fit these, we need to namespace to look for all subtypes
    // verifyFits(Str<|fits({water}, Substance)|>, true)
    // verifyFits(Str<|fits({water}, Fluid)|>, true)
    verifyFits(Str<|fits({water}, Water)|>, true)
    verifyFits(Str<|fits({water}, HotWater)|>, false)
    verifyFits(Str<|fits({hot, water}, HotWater)|>, true)
    verifyFits(Str<|fits({hot, water}, ChilledWater)|>, false)

    ns = initNamespace(["ph", "ph.points"])

    verifyFits(Str<|fits({id:@x}, DischargeAirTempSensor)|>, false)
    verifyFits(Str<|fits({id:@x, air, temp, sensor, point}, DischargeAirTempSensor)|>, false)
    verifyFits(Str<|fits({id:@x, discharge, temp, sensor, point}, DischargeAirTempSensor)|>, false)
    verifyFits(Str<|fits({id:@x, discharge, air, sensor, point}, DischargeAirTempSensor)|>, false)
    verifyFits(Str<|fits({id:@x, discharge, air, temp, point}, DischargeAirTempSensor)|>, false)
    verifyFits(Str<|fits({id:@x, discharge, air, temp, sensor}, DischargeAirTempSensor)|>, false)
    verifyFits(Str<|fits({id:@x, discharge, air, temp, sensor, point}, DischargeAirTempSensor)|>, false)
    verifyFits(Str<|fits({id:@x, discharge, air, temp, sensor, point, kind:"Number", unit:"°F"}, DischargeAirTempSensor)|>, false)
    verifyFits(Str<|fits({id:@x, discharge, air, temp, sensor, point, kind:"Number", unit:"°F", equipRef:@y, siteRef:@z}, DischargeAirTempSensor)|>, false)
    verifyFits(Str<|fits({id:@x, discharge, air, temp, sensor, point, kind:"Number", unit:"°F", equipRef:@y, siteRef:@z}, DischargeAirTempSensor, {ignoreRefs})|>, true)
  }

  Void verifyFits(Str expr, Bool expect)
  {
    // echo("-- $expr => $expect")
    res := eval(expr)
    if (res != expect)
    {
      echo("FAIL: $expr")
      grid := (Grid)eval(expr.replace("fits(", "fitsExplain("))
      grid.dump
    }
    verifyEq(res, expect)
  }

//////////////////////////////////////////////////////////////////////////
// Fits function
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testFitsExplain()
  {
    ns := initNamespace(["ph", "ph.points", "hx.test.xeto"])

    verifyFitsExplain(Str<|fitsExplain({}, Dict)|>, [,])

    verifyFitsExplain(Str<|fitsExplain({id:@x, site}, Site)|>, [,])
    verifyFitsExplain(Str<|fitsExplain({}, Site)|>, [
      "Slot 'id': Missing required slot",
      "Slot 'site': Missing required marker"
      ])
    verifyFitsExplain(Str<|fitsExplain({id:@x}, Site)|>, [
      "Slot 'site': Missing required marker"
      ])

    verifyFitsExplain(Str<|fitsExplain({id:@x, ahu, equip, siteRef:@s}, Ahu, {ignoreRefs})|>, [,])
    verifyFitsExplain(Str<|fitsExplain({id:@x}, Ahu)|>, [
      "Slot 'equip': Missing required marker",
      "Slot 'siteRef': Missing required slot",
      "Slot 'ahu': Missing required marker"
      ])

    verifyFitsExplain(Str<|fitsExplain({}, FitsExplain1)|>, [
      "Slot 'a': Missing required slot",
      ])

    verifyFitsExplain(Str<|fitsExplain({a:"x", b}, FitsExplain1)|>, [
      "Slot 'b': Slot type is 'sys::Str', value type is 'sys::Marker'",
      ])
  }

  Void verifyFitsExplain(Str expr, Str[] expect)
  {

    grid := (Grid)makeContext.eval(expr)

    // echo; echo("-- $expr"); grid.dump

    if (expect.isEmpty) return verifyEq(grid.size, 0)

    verifyEq(grid.size, expect.size+1)
    verifyEq(grid[0]->msg, expect.size == 1 ? "1 error" : "$expect.size errors")
    expect.each |msg, i|
    {
      verifyEq(grid[i+1]->msg, msg)
    }
  }

  Void dumpFitsExplain(Dict rec, Str qname)
  {
    recAxon := Etc.toAxon(rec)
    eval("fitsExplain($recAxon, $qname).dump")
  }

//////////////////////////////////////////////////////////////////////////
// FitsMatchAll
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testFitsMatchAll()
  {
    ns := initNamespace(["ph"])

    site := addRec(["id":Ref("site"), "spec":Ref("ph::Site"), "site":m])
    ahu := addRec(["id":Ref("ahu"), "dis":"AHU", "ahu":m, "equip":m, "siteRef":site.id])
    rtu := addRec(["id":Ref("rtu"), "dis":"RTU", "ahu":m, "rtu":m, "equip":m, "siteRef":site.id])
    meter := addRec(["id":Ref("meter"), "dis":"Meter", "ahu":m, "meter":m, "equip":m, "siteRef":site.id])
    elec := addRec(["id":Ref("elec-meter"), "dis":"Elec-Meter", "ahu":m, "elec":m, "meter":m, "equip":m, "siteRef":site.id])

    grid := (Grid)eval("readAll(equip).sortDis.fitsMatchAll")
    verifyFitsMatchAll(grid, ahu,   ["ph::Ahu"])
    verifyFitsMatchAll(grid, elec,  ["ph::Ahu", "ph::Elec", "ph::ElecMeter"])
    verifyFitsMatchAll(grid, meter, ["ph::Ahu", "ph::Meter"])
    verifyFitsMatchAll(grid, rtu,   ["ph::Rtu"])
  }

  Void verifyFitsMatchAll(Grid g, Dict r, Str[] expect)
  {
    x := g.find { it.id == r.id }
    verifyEq(x->num, n(expect.size))
    verifyEq(((Spec[])x->specs).join(", "), expect.join(", "))
  }

//////////////////////////////////////////////////////////////////////////
// Query
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testQuery()
  {
    ns := initNamespace(["ph"])

    site := addRec(["id":Ref("site"), "spec":Ref("ph::Site"), "site":m])

    ahu       := addRec(["id":Ref("ahu"),   "dis":"AHU", "spec":Ref("ph::Ahu"), "ahu":m, "equip":m, "siteRef":site.id])
      mode    := addRec(["id":Ref("mode"),  "dis":"Mode",             "spec":Ref("ph::Point"), "hvacMode":m, "kind":"Str","point":m, "equipRef":ahu.id, "siteRef":site.id])
      dduct   := addRec(["id":Ref("dduct"), "dis":"Discharge Duct",   "spec":Ref("ph::Equip"), "discharge":m, "duct":m, "equip":m, "equipRef":ahu.id, "siteRef":site.id])
        dtemp := addRec(["id":Ref("dtemp"), "dis":"Discharge Temp",   "spec":Ref("ph::Point"), "discharge":m, "temp":m, "kind":"Number", "point":m, "equipRef":dduct.id, "siteRef":site.id])
        dflow := addRec(["id":Ref("dflow"), "dis":"Discharge Flow",   "spec":Ref("ph::Point"), "discharge":m, "flow":m, "kind":"Number", "point":m, "equipRef":dduct.id, "siteRef":site.id])
        dfan  := addRec(["id":Ref("dfan"),  "dis":"Discharge Fan",    "spec":Ref("ph::Equip"), "discharge":m, "fan":m, "equip":m, "equipRef":dduct.id, "siteRef":site.id])
         drun := addRec(["id":Ref("drun"),  "dis":"Discharge Fan Run","spec":Ref("ph::Point"), "discharge":m, "fan":m, "run":m, "kind":"Bool", "point":m, "equipRef":dfan.id, "siteRef":site.id])

    // Point.equips
    verifyQuery(mode,  "ph::Point.equips", [ahu])
    verifyQuery(dtemp, "ph::Point.equips", [ahu, dduct])
    verifyQuery(drun,  "ph::Point.equips", [ahu, dduct, dfan])

    // Equip.points
    verifyQuery(dfan,  "ph::Equip.points", [drun])
    verifyQuery(dduct, "ph::Equip.points", [dtemp, dflow, drun])
    verifyQuery(ahu,   "ph::Equip.points", [mode, dtemp, dflow, drun])

    // query with no matches
    verifyEq(eval("""query($drun.id.toCode, spec("ph::Equip.points"), false)"""), null)
    verifyEvalErr("""query($drun.id.toCode, spec("ph::Equip.points"))""", UnknownRecErr#)
    verifyEvalErr("""query($drun.id.toCode, spec("ph::Equip.points"), true)""", UnknownRecErr#)

    // compile some types with query constraints
    lib := ns.compileLib(
      Str<|pragma: Lib < version: 0.0.0, depends: { { lib:"sys" }, { lib:"ph" } } >
           Ahu1: ph::Equip {
             points: {
               temp: {discharge, temp}
               flow: {discharge, flow}
               fan:  {fan, run}
             }
           }

           DTemp: {discharge, temp}
           DFlow: {discharge, flow}
           DPressure: {discharge, pressure}
           Ahu2: ph::Equip { points: { DTemp, DFlow, DPressure? } }
           |>)
     ahu1 := lib.type("Ahu1")
     ahu2 := lib.type("Ahu2")

     // verify queryNamed
     verifyQueryNamed(ahu, ahu1.slot("points"), ["temp":dtemp, "flow":dflow, "fan":drun])

     // verify fitsExplain for missing points
     ahuX := addRec(["id":Ref("x"), "spec":Ref("ph::Ahu"), "equip":m, "siteRef":site.id])
     verifyQueryFitsExplain(ahuX, ahu1, [
       "Slot 'points': Missing required Point: temp",
       "Slot 'points': Missing required Point: flow",
       "Slot 'points': Missing required Point: fan",
      ])
     verifyQueryFitsExplain(ahuX, ahu2, [
       "Slot 'points': Missing required Point: ${lib.name}::DTemp",
       "Slot 'points': Missing required Point: ${lib.name}::DFlow",
      ])

     // ambiguous matches
     d1 := addRec(["id":Ref("d1"), "dis":"Temp 1", "spec":Ref("ph::Point"), "discharge":m, "temp":m, "kind":"Number", "point":m, "equipRef":ahuX.id, "siteRef":site.id])
     d2 := addRec(["id":Ref("d2"), "dis":"Temp 2", "spec":Ref("ph::Point"), "discharge":m, "temp":m, "kind":"Number", "point":m, "equipRef":ahuX.id, "siteRef":site.id])
     verifyQueryFitsExplain(ahuX, ahu1, [
       "Slot 'points': Ambiguous match for Point: temp [$d1.id.toZinc, $d2.id.toZinc]",
       "Slot 'points': Missing required Point: flow",
       "Slot 'points': Missing required Point: fan",
      ])
     verifyQueryFitsExplain(ahuX, ahu2, [
       "Slot 'points': Ambiguous match for Point: ${lib.name}::DTemp [$d1.id.toZinc, $d2.id.toZinc]",
       "Slot 'points': Missing required Point: ${lib.name}::DFlow",
      ])

     // ambiguous matches for optional point
     rt.db.commit(Diff(d1, null, Diff.remove))
     p1 := addRec(["id":Ref("p1"), "dis":"Pressure 1", "spec":Ref("ph::Point"), "discharge":m, "pressure":m, "kind":"Number", "point":m, "equipRef":ahuX.id, "siteRef":site.id])
     p2 := addRec(["id":Ref("p2"), "dis":"Pressure 2", "spec":Ref("ph::Point"), "discharge":m, "pressure":m, "kind":"Number", "point":m, "equipRef":ahuX.id, "siteRef":site.id])
     verifyQueryFitsExplain(ahuX, ahu2, [
       "Slot 'points': Missing required Point: ${lib.name}::DFlow",
       "Slot 'points': Ambiguous match for Point: ${lib.name}::DPressure [$p1.id.toZinc, $p2.id.toZinc]",
      ])
  }

  Void verifyQuery(Dict rec, Str query, Dict[] expect)
  {
    // no options
    expr := "queryAll($rec.id.toCode, spec($query.toCode))"
echo("-- $expr")
    Grid actual := eval(expr)
actual.dump
    origActual := actual
    x := actual.sortDis.mapToList { it.dis }.join(",")
    y := Etc.sortDictsByDis(expect).join(",") { it.dis }
    // echo("   $x ?= $y")
    verifyEq(x, y)

    // sort option
    expr = "queryAll($rec.id.toCode, spec($query.toCode), {sort})"
    actual = eval(expr)
    x = actual.mapToList { it.dis }.join(",")
    y = Etc.sortDictsByDis(expect).join(",") { it.dis }
    verifyEq(x, y)

    // limit  option
    expr = "queryAll($rec.id.toCode, spec($query.toCode), {limit:2})"
    actual = eval(expr)
    if (expect.size == 1)
    {
      verifyEq(actual.size, 1)
      verifyEq(y.contains(actual[0].dis), true)
    }
    else
    {
      verifyEq(actual.size, 2)
      verifyEq(y.contains(actual[0].dis), true)
      verifyEq(y.contains(actual[1].dis), true)
    }

    // query
    single := eval("query($rec.id.toCode, spec($query.toCode))")
    verifyDictEq(single, origActual.first)
  }

  Void verifyQueryNamed(Dict subject, Spec spec, Str:Dict expect)
  {
    cx := makeContext
    Dict actual := cx.evalToFunc("queryNamed").call(cx, [subject, spec])
    // echo("-- queryNamed:"); Etc.dictDump(actual)
    expect.each |e, name|
    {
      a := actual[name]
      if (a == null) fail("Missing $name")
      verifyDictEq(e, a)
    }
  }

  Void verifyQueryFitsExplain(Dict subject, Spec spec, Str[] expect)
  {
    cx := makeContext

    // first eval with without opts to verify we don't validate graph
    Grid grid := cx.evalToFunc("fitsExplain").call(cx, [subject, spec])
    verifyEq(grid.size, 0)

    // now verify with graph option
    opts := Etc.makeDict1("graph", Marker.val)
    grid = cx.evalToFunc("fitsExplain").call(cx, [subject, spec, opts])

    // echo; echo("-- $subject | $spec"); grid.dump

    if (expect.isEmpty) return verifyEq(grid.size, 0)

    verifyEq(grid.size, expect.size+1)
    verifyEq(grid[0]->msg, expect.size == 1 ? "1 error" : "$expect.size errors")
    expect.each |msg, i|
    {
      verifyEq(grid[i+1]->msg, msg)
    }
  }

}

