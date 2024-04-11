//
// Copyright (c) 2023, SkyFoundry LLC
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
class AxonTest : HxTest
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

    // slot
    verifySpecRef(Str<|Equip.equip|>, "ph::Equip.equip")
    verifySpecRef(Str<|Equip.points|>, "ph::Equip.points")

    // with meta
    verifySpecDerive(Str<|Dict <>|>, "sys::Dict")
    verifySpecDerive(Str<|Dict <foo>|>, "sys::Dict", ["foo":m])
    verifySpecDerive(Str<|Dict <foo,>|>, "sys::Dict", ["foo":m])
    verifySpecDerive(Str<|Dict <foo, bar:"baz">|>, "sys::Dict", ["foo":m, "bar":"baz"])
    verifySpecDerive(Str<|Dict <a:"1">|>, "sys::Dict", ["a":"1"])
    verifySpecDerive(Str<|Dict <a:"1", b:"2">|>, "sys::Dict", ["a":"1", "b":"2"])
    verifySpecDerive(Str<|Dict <a:"1", b:"2", c:"3">|>, "sys::Dict", ["a":"1", "b":"2", "c":"3"])
    verifySpecDerive(Str<|Dict <a:"1", b:"2", c:"3", d:"4">|>, "sys::Dict", ["a":"1", "b":"2", "c":"3", "d":"4"])
    verifySpecDerive(Str<|Dict <a:"1", b:"2", c:"3", d:"4", e:"5">|>, "sys::Dict", ["a":"1", "b":"2", "c":"3", "d":"4", "e":"5"])
    x := verifySpecDerive(Str<|Dict <of:Str>|>, "sys::Dict", ["of":ns.type("sys::Str")])
    verifySame(x->of, ns.type("sys::Str"))

    // with value
    verifySpecDerive(Str<|Scalar "foo"|>, "sys::Scalar", ["val":"foo"])
    verifySpecDerive(Str<|Scalar 123|>, "sys::Scalar", ["val":"123"])
    verifySpecDerive(Str<|Scalar 2023-03-13|>, "sys::Scalar", ["val":"2023-03-13"])
    verifySpecDerive(Str<|Scalar 13:14:15|>, "sys::Scalar", ["val":"13:14:15"])
    verifySpecDerive(Str<|Scalar <qux> "bar"|>, "sys::Scalar", ["qux":m, "val":"bar"])

    // with slots
    verifySpecDerive(Str<|Dict {}|>, "sys::Dict")
    verifySpecDerive(Str<|Dict { equip }|>, "sys::Dict", [:], ["equip":"sys::Marker"])
    verifySpecDerive(Str<|Dict { equip, ahu }|>, "sys::Dict", [:], ["equip":"sys::Marker", "ahu":"sys::Marker"])
    verifySpecDerive(Str<|Dict { equip, ahu, }|>, "sys::Dict", [:], ["equip":"sys::Marker", "ahu":"sys::Marker"])
    verifySpecDerive(Str<|Dict
                          {
                             equip
                             ahu
                          }|>, "sys::Dict", [:], ["equip":"sys::Marker", "ahu":"sys::Marker"])
    verifySpecDerive(Str<|Dict { dis:Str }|>, "sys::Dict", [:], ["dis":"sys::Str"])
    verifySpecDerive(Str<|Dict { dis:Str, foo, baz:Date }|>, "sys::Dict", [:], ["dis":"sys::Str", "foo":"sys::Marker", "baz":"sys::Date"])
    verifySpecDerive(Str<|Dict {
                            dis:Str
                            foo,
                            baz:Date
                          }|>, "sys::Dict", [:], ["dis":"sys::Str", "foo":"sys::Marker", "baz":"sys::Date"])
    verifySpecDerive(Str<|Dict { Ahu }|>, "sys::Dict", [:], ["_0":"ph::Ahu"])
    verifySpecDerive(Str<|Dict { Ahu, Meter }|>, "sys::Dict", [:], ["_0":"ph::Ahu", "_1":"ph::Meter"])

    // with slot and meta
    verifySpecDerive(Str<|Dict <foo> { bar }|>, "sys::Dict", ["foo":m], ["bar":"sys::Marker"])
    verifySpecDerive(Str<|Dict {
                            dis: Str <qux>
                            foo,
                            baz: Date <x:"y">
                          }|>, "sys::Dict", [:], ["dis":"sys::Str <qux>", "foo":"sys::Marker", "baz":"sys::Date <x:y>"])

    // maybe
    verifySpecDerive(Str<|Dict?|>, "sys::Dict", ["maybe":m])
    verifySpecDerive(Str<|Dict? <foo>|>, "sys::Dict", ["maybe":m, "foo":m])

    // and/or
    ofs := Spec[ns.type("ph::Meter"), ns.type("ph::Chiller")]
    verifySpecDerive(Str<|Meter & Chiller|>, "sys::And", ["ofs":ofs])
    verifySpecDerive(Str<|Meter | Chiller|>, "sys::Or",  ["ofs":ofs])
    verifySpecDerive(Str<|Meter & Chiller <foo>|>, "sys::And", ["ofs":ofs, "foo":m])
    verifySpecDerive(Str<|Meter | Chiller <foo>|>, "sys::Or",  ["ofs":ofs, "foo":m])
// TODO
//   verifySpecDerive(Str<|Meter & Chiller { foo: Str }|>, "sys::And", ["ofs":Spec[ns.type("ph::Meter"), ns.type("ph::Chiller")]], ["foo":"sys::Str"])

    // and/or with qualified
    verifySpecDerive(Str<|ph::Meter & Chiller|>, "sys::And", ["ofs":ofs])
    verifySpecDerive(Str<|Meter & ph::Chiller|>, "sys::And", ["ofs":ofs])
    verifySpecDerive(Str<|ph::Meter & ph::Chiller|>, "sys::And", ["ofs":ofs])
    ofs = Spec[ns.type("ph::Meter"), ns.type("hx.test.xeto::Alpha")]
    verifySpecDerive(Str<|ph::Meter & hx.test.xeto::Alpha|>, "sys::And", ["ofs":ofs])
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

  Spec verifySpecDerive(Str expr, Str type, Str:Obj meta := [:], Str:Str slots := [:])
  {
    Spec x := makeContext.eval(expr)
    // echo(":::DERIVE::: $expr => $x [$x.typeof] " + Etc.dictToStr((Dict)x.metaOwn))

    // verify spec
    verifyNotSame(x, xns.type(type))
    verifySame(x.type, xns.type(type))
    verifySame(x.base, x.type)
    verifyDictEq(x.metaOwn, meta)
    slots.each |expect, name|
    {
      verifySpecExprSlot(x.slotOwn(name), expect)
    }
    return x
  }

  Void verifySpecExprSlot(Spec x, Str expect)
  {
    s := StrBuf().add(x.type.qname)
    if (expect.contains("<"))
    {
      s.add(" <")
      x.each |v, n|
      {
        if (n == "id" || n == "spec" || n == "type" || n == "base") return
        if (x.type.has(n)) return
        s.add(n)
        if (v !== Marker.val) s.add(":").add(v)
      }
      s.add(">")
    }
    verifyEq(s.toStr, expect)
  }

//////////////////////////////////////////////////////////////////////////
// Deftype
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testDeftype()
  {
    cx := makeContext
    person := cx.eval(Str<|Person: Dict|>)
    verifySame(cx.varsInScope.getChecked("Person"), person)
    verifySame(cx.eval("Person"), person)
    verifyEq(cx.eval("specParent(Person)"), null)
    verifyEq(cx.eval("specName(Person)"), "Person")
    verifyEq(cx.eval("specBase(Person)"), xns.type("sys::Dict"))
    verifyEq(cx.eval("specType(Person)"), xns.type("sys::Dict"))
    verifySame(cx.eval("specMetaOwn(Person)"), AbstractXetoTest.nameDictEmpty)
    verifyEq(cx.eval("specSlotsOwn(Person).isEmpty"), true)

    person2 := cx.eval(Str<|Person2: Person { dis:Str }|>)
    verifySame(cx.varsInScope.getChecked("Person2"), person2)
    verifySame(cx.eval("Person2"), person2)
    verifyEq(cx.eval("specParent(Person2)"), null)
    verifyEq(cx.eval("specName(Person2)"), "Person2")
    verifyEq(cx.eval("specBase(Person2)"), person)
    verifyEq(cx.eval("specType(Person2)"), xns.type("sys::Dict"))
    verifySame(cx.eval("specMetaOwn(Person2)"), AbstractXetoTest.nameDictEmpty)
    verifyEq(cx.eval("specSlotsOwn(Person2)->dis.specName"), "dis")
    verifyEq(cx.eval("specSlotsOwn(Person2)->dis.specType"), xns.type("sys::Str"))

    person3 := cx.eval(Str<|Person3: { dis: Str }|>)
    verifySame(cx.varsInScope.getChecked("Person3"), person3)
    verifySame(cx.eval("Person3"), person3)
    verifyEq(cx.eval("specSlotsOwn(Person3)->dis.specName"), "dis")
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
    verifySpec(Str<|specOf(toGrid("hi"))|>, "ph::Grid")
    verifySpec(Str<|specOf(toGrid("hi"))|>, "ph::Grid")
    verifySpec(Str<|specOf(Str)|>, "sys::Spec")
    verifySpec(Str<|specOf(Str <foo>)|>, "sys::Spec")
    verifySpec(Str<|specOf({spec:@ph::Equip})|>, "ph::Equip")
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
    verifyFits(Str<|fits({id:@x, discharge, air, temp, sensor, point, kind:"Number", unit:"°F", equipRef:@y, siteRef:@z}, DischargeAirTempSensor)|>, true)
  }

  Void verifyFits(Str expr, Bool expect)
  {
    // echo("-- $expr => $expect")
    verifyEval(expr, expect)
  }

//////////////////////////////////////////////////////////////////////////
// Fits function
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testFitsExplain()
  {
    ns := initNamespace(["ph"])

    verifyFitsExplain(Str<|fitsExplain({}, Dict)|>, [,])

    verifyFitsExplain(Str<|fitsExplain({id:@x, site}, Site)|>, [,])
    verifyFitsExplain(Str<|fitsExplain({}, Site)|>, [
      "Missing required slot 'id'",
      "Missing required marker 'site'"
      ])
    verifyFitsExplain(Str<|fitsExplain({id:@x}, Site)|>, [
      "Missing required marker 'site'"
      ])

    verifyFitsExplain(Str<|fitsExplain({id:@x, ahu, equip, siteRef:@s}, Ahu)|>, [,])
    verifyFitsExplain(Str<|fitsExplain({id:@x}, Ahu)|>, [
      "Missing required marker 'equip'",
      "Missing required slot 'siteRef'",
      "Missing required marker 'ahu'"
      ])

    verifyFitsExplain(
       Str<|do
              Foo: Dict { a:Str, b: Str? }
              fitsExplain({}, Foo)
            end
            |>, [
      "Missing required slot 'a'",
      ])

    verifyFitsExplain(
       Str<|do
              Foo: Dict { a:Str, b: Str? }
              fitsExplain({a:"x", b}, Foo)
            end
            |>, [
      "Invalid value type for 'b' - 'haystack::Marker' does not fit 'sys::Str'",
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

    site := addRec(["id":Ref("site"), "site":m])
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

    site := addRec(["id":Ref("site"), "site":m])

    ahu       := addRec(["id":Ref("ahu"), "dis":"AHU", "ahu":m, "equip":m, "siteRef":site.id])
      mode    := addRec(["id":Ref("mode"), "dis":"Mode", "hvacMode":m, "kind":"Str","point":m, "equipRef":ahu.id, "siteRef":site.id])
      dduct   := addRec(["id":Ref("dduct"), "dis":"Discharge Duct", "discharge":m, "duct":m, "equip":m, "equipRef":ahu.id, "siteRef":site.id])
        dtemp := addRec(["id":Ref("dtemp"), "dis":"Discharge Temp", "discharge":m, "temp":m, "kind":"Number", "point":m, "equipRef":dduct.id, "siteRef":site.id])
        dflow := addRec(["id":Ref("dflow"), "dis":"Discharge Flow", "discharge":m, "flow":m, "kind":"Number", "point":m, "equipRef":dduct.id, "siteRef":site.id])
        dfan  := addRec(["id":Ref("dfan"), "dis":"Discharge Fan", "discharge":m, "fan":m, "equip":m, "equipRef":dduct.id, "siteRef":site.id])
         drun := addRec(["id":Ref("drun"), "dis":"Discharge Fan Run", "discharge":m, "fan":m, "run":m, "kind":"Bool", "point":m, "equipRef":dfan.id, "siteRef":site.id])

    // Point.equips
    verifyQuery(mode,  "Point.equips", [ahu])
    verifyQuery(dtemp, "Point.equips", [ahu, dduct])
    verifyQuery(drun,  "Point.equips", [ahu, dduct, dfan])

    // Equip.points
    verifyQuery(dfan,  "Equip.points", [drun])
    verifyQuery(dduct, "Equip.points", [dtemp, dflow, drun])
    verifyQuery(ahu, "  Equip.points", [mode, dtemp, dflow, drun])

    // query with no matches
    verifyEq(eval("query($drun.id.toCode, Equip.points, false)"), null)
    verifyEvalErr("query($drun.id.toCode, Equip.points)", UnknownRecErr#)
    verifyEvalErr("query($drun.id.toCode, Equip.points, true)", UnknownRecErr#)

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
     ahuX := addRec(["id":Ref("x"), "equip":m, "siteRef":site.id])
     verifyQueryFitsExplain(ahuX, ahu1, [
       "Missing required Point: temp",
       "Missing required Point: flow",
       "Missing required Point: fan",
      ])
     verifyQueryFitsExplain(ahuX, ahu2, [
       "Missing required Point: ${lib.name}::DTemp",
       "Missing required Point: ${lib.name}::DFlow",
      ])

     // ambiguous matches
     d1 := addRec(["id":Ref("d1"), "dis":"Temp 1", "discharge":m, "temp":m, "kind":"Number", "point":m, "equipRef":ahuX.id, "siteRef":site.id])
     d2 := addRec(["id":Ref("d2"), "dis":"Temp 2", "discharge":m, "temp":m, "kind":"Number", "point":m, "equipRef":ahuX.id, "siteRef":site.id])
     verifyQueryFitsExplain(ahuX, ahu1, [
       "Ambiguous match for Point: temp [$d1.id.toZinc, $d2.id.toZinc]",
       "Missing required Point: flow",
       "Missing required Point: fan",
      ])
     verifyQueryFitsExplain(ahuX, ahu2, [
       "Ambiguous match for Point: ${lib.name}::DTemp [$d1.id.toZinc, $d2.id.toZinc]",
       "Missing required Point: ${lib.name}::DFlow",
      ])

     // ambiguous matches for optional point
     rt.db.commit(Diff(d1, null, Diff.remove))
     p1 := addRec(["id":Ref("p1"), "dis":"Pressure 1", "discharge":m, "pressure":m, "kind":"Number", "point":m, "equipRef":ahuX.id, "siteRef":site.id])
     p2 := addRec(["id":Ref("p2"), "dis":"Pressure 2", "discharge":m, "pressure":m, "kind":"Number", "point":m, "equipRef":ahuX.id, "siteRef":site.id])
     verifyQueryFitsExplain(ahuX, ahu2, [
       "Missing required Point: ${lib.name}::DFlow",
       "Ambiguous match for Point: ${lib.name}::DPressure [$p1.id.toZinc, $p2.id.toZinc]",
      ])
  }

  Void verifyQuery(Dict rec, Str query, Dict[] expect)
  {
    // no options
    expr := "queryAll($rec.id.toCode, $query)"
    // echo("-- $expr")
    Grid actual := eval(expr)
    origActual := actual
    x := actual.sortDis.mapToList { it.dis }.join(",")
    y := Etc.sortDictsByDis(expect).join(",") { it.dis }
    // echo("   $x ?= $y")
    verifyEq(x, y)

    // sort option
    expr = "queryAll($rec.id.toCode, $query, {sort})"
    actual = eval(expr)
    x = actual.mapToList { it.dis }.join(",")
    y = Etc.sortDictsByDis(expect).join(",") { it.dis }
    verifyEq(x, y)

    // limit  option
    expr = "queryAll($rec.id.toCode, $query, {limit:2})"
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
    single := eval("query($rec.id.toCode, $query)")
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
    Grid grid := cx.evalToFunc("fitsExplain").call(cx, [subject, spec])

    // echo; echo("-- $subject | $spec"); grid.dump

    if (expect.isEmpty) return verifyEq(grid.size, 0)

    verifyEq(grid.size, expect.size+1)
    verifyEq(grid[0]->msg, expect.size == 1 ? "1 error" : "$expect.size errors")
    expect.each |msg, i|
    {
      verifyEq(grid[i+1]->msg, msg)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  LibNamespace initNamespace(Str[] libs)
  {
    // nuke existing using recs
    rt.db.readAll(Filter("using")).each |r| { rt.db.commit(Diff(r, null, Diff.remove)) }

    // add new using recs
    libs.each |lib| { addRec(["using":lib]) }

    // sync
    rt.sync
    ns := rt.ns.xeto
    return ns
  }

  LibNamespace xns()
  {
    rt.ns.xeto
  }

  Void verifyEval(Str expr, Obj? expect)
  {
    verifyEq(makeContext.eval(expr), expect)
  }

  Void verifySpec(Str expr, Str qname)
  {
    x := makeContext.eval(expr)
    // echo("::: $expr => $x [$x.typeof]")
    verifySame(x, xns.type(qname))
  }

  Void verifyEvalErr(Str expr, Type? errType)
  {
    EvalErr? err := null
    try { eval(expr) } catch (EvalErr e) { err = e }
    if (err == null) fail("EvalErr not thrown: $expr")
    if (errType == null)
    {
      verifyNull(err.cause)
    }
    else
    {
      if (err.cause == null) fail("EvalErr.cause is null: $expr")
      verifyErr(errType) { throw err.cause }
    }
  }

}

