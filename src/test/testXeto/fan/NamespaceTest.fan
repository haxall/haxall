//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jan 2023  Brian Frank  Creation
//

using util
using xeto
using xeto::Dict
using xeto::Lib
using haystack
using haystack::Ref

**
** NamespaceTest
**
@Js
class NamespaceTest : AbstractXetoTest
{

  static Version curVersion() { Version("0.1.1") }

//////////////////////////////////////////////////////////////////////////
// Sys Lib
//////////////////////////////////////////////////////////////////////////

  Void testSysLib()
  {
    verifyLocalAndRemote(["sys"]) |ns| { doTestSysLib(ns) }
  }

  private Void doTestSysLib(LibNamespace ns)
  {
    // lib basics
    sys := verifyLibBasics(ns, "sys", curVersion)
    verifySame(ns.lib("sys"), sys)
    verifyEq(sys.name, "sys")
    verifyEq(sys.version, curVersion)
    verifySame(ns.sysLib, sys)

    // verify lib meta inference
    verifyEq(sys.meta["version"], curVersion)
    sysOrg := sys.meta["org"] as Dict
    verifyEq(sysOrg->dis, "Project Haystack")
    verifyEq(sysOrg->uri, `https://project-haystack.org/`)
    verifyEq(sysOrg->spec, Ref("sys::LibOrg"))

    // types
    obj    := verifyLibType(ns, sys, "Obj",      null)
    self   := verifyLibType(ns, sys, "Self",     obj)
    scalar := verifyLibType(ns, sys, "Scalar",   obj)
    none   := verifyLibType(ns, sys, "None",     scalar, none)
    marker := verifyLibType(ns, sys, "Marker",   scalar, m)
    na     := verifyLibType(ns, sys, "NA",       scalar, na)
    str    := verifyLibType(ns, sys, "Str",      scalar, "")
    uri    := verifyLibType(ns, sys, "Uri",      scalar, ``)
    ref    := verifyLibType(ns, sys, "Ref",      scalar, ref("x"))
    time   := verifyLibType(ns, sys, "Time",     scalar, Time.defVal)
    date   := verifyLibType(ns, sys, "Date",     scalar, Date.defVal)
    dt     := verifyLibType(ns, sys, "DateTime", scalar, DateTime.defVal)
    seq    := verifyLibType(ns, sys, "Seq",      obj)
    dict   := verifyLibType(ns, sys, "Dict",     seq)
    list   := verifyLibType(ns, sys, "List",     seq)
    spec   := verifyLibType(ns, sys, "Spec",     dict)
    lib    := verifyLibType(ns, sys, "Lib",      dict)
    org    := verifyLibType(ns, sys, "LibOrg",   dict)
    and    := verifyLibType(ns, sys, "And",      obj)
    or     := verifyLibType(ns, sys, "Or",      obj)

    // types
    verifyEq(sys.types.isEmpty, false)
    verifyEq(sys.types.isImmutable, true)
    verifySame(sys.types, sys.types)
    verifyEq(sys.types.containsSame(str), true)

    // instances
    verifyEq(sys.instances.size, 0)
    verifyEq(sys.instances.isImmutable, true)
    verifySame(sys.instances, sys.instances)

    // slots
    orgDis := verifySlot(ns, org, "dis", str)
    orgUri := verifySlot(ns, org, "uri", uri)

    // Spec.of: Spec?
    specOf := verifySlot(ns, spec, "of", ref)
    verifyEq(specOf.qname, "sys::Spec.of")
    verifySame(specOf.parent, spec)
    verifyEq(specOf["doc"], "Item type for parameterized Seq, Query, and Ref specs")
    verifyEq(specOf["maybe"], m)
    verifyEq(specOf["of"], Ref("sys::Spec"))
    verifySame(specOf.of, spec)

    // Spec.ofs: List? <of:Ref<of:Spec>>
    specOfs := verifySlot(ns, spec, "ofs", list)
    specOfsOfRef := (Ref)specOfs["of"]
    verifyEq(specOfs.parent, spec)
    verifyEq(specOfs.qname, "sys::Spec.ofs")
    verifyEq(specOfs["doc"], "Types used in compound types like And and Or")
    verifyEq(specOfs["maybe"], m)
    verifyEq(specOfsOfRef.toStr.startsWith("sys::_"), true)
    specOfsOf := ns.spec(specOfsOfRef.id)
    verifySame(specOfs.of, specOfsOf)
    verifySame(specOfsOf.base, ref)
    verifyEq(specOfsOf["of"], Ref("sys::Spec"))

    // lookups
    verifySame(sys.type("DateTime"), dt)
    verifySame(sys.type("Bad", false), null)
    verifyErr(UnknownSpecErr#) { sys.type("Bad") }
    verifyErr(UnknownSpecErr#) { sys.type("Bad", true) }
    verifySame(sys.instance("bad", false), null)
    verifyErr(UnknownRecErr#) { sys.instance("bad") }
    verifyErr(UnknownRecErr#) { sys.instance("bad", true) }
    verifySame(ns.spec("sys::LibOrg"), org)
    verifySame(ns.spec("sys::LibOrg.dis"), orgDis)
    verifyErr(UnknownSpecErr#) { ns.spec("foo.bar.baz::Qux") }
    verifyErr(UnknownSpecErr#) { ns.spec("sys::Baz") }
    verifyErr(UnknownSpecErr#) { ns.spec("sys::Str.foo") }

    // specials
    verifyEq(self.isSelf, true)
    verifyEq(none.isNone, true)
    verifyEq(or.isAnd, false)
    verifyEq(or.isOr, false)
    verifyEq(marker.isMarker, true)
  }

//////////////////////////////////////////////////////////////////////////
// Ph Lib
//////////////////////////////////////////////////////////////////////////

  Void testPhLib()
  {
    verifyLocalAndRemote(["sys", "ph"]) |ns| { doTestPhLib(ns) }
  }

  private Void doTestPhLib(LibNamespace ns)
  {
    verifyEq(ns.isAllLoaded, ns.isRemote)

    // lib basics
    ph := verifyLibBasics(ns, "ph", curVersion)
    verifyEq(ph.depends.size, 1)
    verifyEq(ph.depends[0].name, "sys")
    verifyEq(ph.depends[0].versions.toStr, "" + curVersion.major + "." + curVersion.minor + ".x")

    entity    := verifyLibType(ns, ph, "Entity",   ns.spec("sys::Dict"))
    equip     := verifyLibType(ns, ph, "Equip",    entity)
    meter     := verifyLibType(ns, ph, "Meter",    equip)
    elecMeter := verifyLibType(ns, ph, "ElecMeter",meter)

    water := ph.global("water")
    verifySame(ns.spec("ph::water"), water)

    // env.print(elecMeter, Env.cur.out, dict1("effective", m))
    marker := ns.spec("sys::Marker")
    verifyEq(elecMeter.slot("elec").type, marker)
    verifyEq(elecMeter.slot("meter").type, marker)
    verifyEq(elecMeter.slot("equip").type, marker)

    // feature instances
    verifyFeatureInstance(ph.instance("filetype:zinc"),
      ["id":Ref("ph::filetype:zinc"), "spec":Ref("ph::Filetype"), "filetype":m, "dis":"Zinc", "fileExt":"zinc", "mime":"text/zinc"])
    verifyFeatureInstance(ph.instance("op:about"),
      ["id":Ref("ph::op:about"), "spec":Ref("ph::Op"), "op":m, "noSideEffects":m])
    verifyFeatureInstance(ph.instance("op:pointWrite"),
      ["id":Ref("ph::op:pointWrite"), "spec":Ref("ph::Op"), "op":m])

    // hot water
    hotWater := ph.type("HotWater")
    verifyEq(hotWater.slots.names.join(","), "water,hot")

    // unqualifiedType
    verifyEq(ns.isAllLoaded, true)
    verifySame(ns.unqualifiedType("Str"), ns.spec("sys::Str"))
    verifySame(ns.unqualifiedType("Equip"), ns.spec("ph::Equip"))
  }

  Void verifyFeatureInstance(Dict dict, Str:Obj expect)
  {
    verifyDictEq(dict, expect)
  }

//////////////////////////////////////////////////////////////////////////
// HxTest Lib
//////////////////////////////////////////////////////////////////////////

  Void testHxTestLib()
  {
    verifyLocalAndRemote(["sys", "hx.test.xeto"]) |ns| { doTestHxTestLib(ns) }
  }

  private Void doTestHxTestLib(LibNamespace ns)
  {
    // lib basics
    lib := verifyLibBasics(ns, "hx.test.xeto", curVersion)

    a  := lib.type("A");  ax := a.slot("x")
    b  := lib.type("B");  by := b.slot("y")
    c  := lib.type("C");  cz := c.slot("z")
    d  := lib.type("D");  dz := d.slot("z")
    ab := lib.type("AB"); abz := ab.slot("z")

    // single inheritance - slots
    verifySame(c.base, a)
    verifyEq(c.slotOwn("x", false), null)
    verifySame(c.slotOwn("z"), cz)
    verifySame(c.slot("x"), ax)
    verifyEq(slotNames(c.slots), "x,z")
    verifyEq(slotNames(c.slotsOwn), "z")

    // AND inheritance - slots
    verifyEq(ab.isAnd, true)
    verifyEq(ab.slotOwn("x", false), null)
    verifyEq(ab.slotOwn("y", false), null)
    verifySame(ab.slotOwn("z"), abz)
    verifySame(ab.slot("x"), ax)
    verifySame(ab.slot("y"), by)
    verifyEq(slotNames(ab.slots), "x,y,z")
    verifyEq(slotNames(ab.slotsOwn), "z")

    // single inheritance - C meta, reuse A.meta actual instance
    verifyDictEq(c.meta, ["doc":"A", "q":Date("2024-01-01"), "foo":"A", "bar":"A"])
    verifySame(c.meta, a.meta)
    verifyDictEq(c.metaOwn, [:])

    // single inheritance - D meta (abstract should not be inherited)
    verifyDictEq(d.meta, ["doc":"B", "r":Date("2024-02-01"), "foo":"B", "qux":"B"])
    verifyNotSame(d.meta, b.meta)
    verifyDictEq(d.metaOwn, [:])

    // AND inheritance - meta
    abOfs := ab.metaOwn->ofs
    verifyDictEq(ab.metaOwn, ["doc":"AB", "ofs":abOfs, "s":Date("2024-03-01"), "qux":"AB"])
    verifyDictEq(ab.meta, ["doc":"AB", "ofs":abOfs, "s":Date("2024-03-01"), "qux":"AB",
      "q":Date("2024-01-01"), "r":Date("2024-02-01"), "foo":"A", "bar":"A", ])
  }

//////////////////////////////////////////////////////////////////////////
// NameTable
//////////////////////////////////////////////////////////////////////////

  Void testNameTable()
  {
    ns  := createNamespace(["sys", "ph"])
    sys := verifyLibBasics(ns, "sys", curVersion)
    ph  := verifyLibBasics(ns, "ph", curVersion)
    str := sys.type("Str")
    org := sys.type("LibOrg")
    ref := sys.type("Ref")

    // ns.names.dump(Env.cur.out)

    verifyNameTable(ns, sys.name)
    verifyNameTable(ns, str.name)
    verifyNameTable(ns, org.slot("dis").name)
    verifyNameDict(ns, sys.meta)
    verifyNameDict(ns, ref.meta)
  }

  Void verifyNameTable(LibNamespace ns, Str name)
  {
    code := ns.names.toCode(name)
    // echo("-- $name = $code")
    verifyEq(code > 0, true)
    verifySame(ns.names.toName(code), name)
  }

  Void verifyNameDict(LibNamespace ns, Dict meta)
  {
    verifyEq(meta.typeof.qname, "xetoEnv::MNameDict")
    meta.each |v, n| { verifyNameTable(ns, n) }
  }

//////////////////////////////////////////////////////////////////////////
// Factories
//////////////////////////////////////////////////////////////////////////

  Void testFactories()
  {
    verifySame(m, Marker.val)
    verifySame(na, NA.val)
    verifySame(none, Remove.val)
    verifyEq(ref("foo"), haystack::Ref("foo", null))
    verifyValEq(ref("foo", "Foo"), haystack::Ref("foo", "Foo"))
    verifySame(dict0, Etc.emptyDict)
    verifyDictEq(dict1("a", "A"), ["a":"A"])
  }

//////////////////////////////////////////////////////////////////////////
// Lookups
//////////////////////////////////////////////////////////////////////////

  Void testLookups()
  {
    // sys
    ns := createNamespace(["hx.test.xeto"])
    sys := ns.lib("sys")
    verifySame(ns.lib("sys"), sys)
    verifySame(ns.type("sys::Dict"), sys.type("Dict"))

    // bad libs
    verifyEq(ns.lib("bad.one", false), null)
    verifyEq(ns.type("bad.one::Foo", false), null)
    verifyErr(UnknownLibErr#) { ns.lib("bad.one") }
    verifyErr(UnknownLibErr#) { ns.lib("bad.one", true) }
    verifyErr(UnknownSpecErr#) { ns.type("bad.one::Foo") }
    verifyErr(UnknownSpecErr#) { ns.type("bad.one::Foo", true) }

    asyncErr := null
    asyncLib := null
    ns.libAsync("sys") |e, x| { asyncErr = e ; asyncLib = x }
    verifyEq(asyncLib, sys)
    verifyEq(asyncErr, null)
    ns.libAsync("badLib") |e, x| { asyncErr = e; asyncLib = x }
    verifyEq(asyncLib, null)
    verifyEq(asyncErr?.typeof, UnknownLibErr#)

    // good lib, bad type
    verifyEq(ns.type("sys::Foo", false), null)
    verifyErr(UnknownSpecErr#) { ns.type("sys::Foo") }
    verifyErr(UnknownSpecErr#) { ns.type("sys::Foo", true) }

    // instances
    verifyEq(ns.libStatus("hx.test.xeto"), LibStatus.notLoaded)
    verifyDictEq(ns.instance("hx.test.xeto::test-a"), ["id":Ref("hx.test.xeto::test-a"), "alpha":m])
    verifyEq(ns.libStatus("hx.test.xeto"), LibStatus.ok)
    verifyEq(ns.instance("hx.test.xeto::badOne", false), null)
    verifyEq(ns.instance("hx.test.xeto::badOne", false), null)
    verifyErr(UnknownRecErr#) { ns.instance("hx.test.xeto::badOne") }
    verifyErr(UnknownRecErr#) { ns.instance("hx.test.xeto::badOne", true) }
    verifyErr(UnknownRecErr#) { ns.instance("badOne::badOne") }
  }

//////////////////////////////////////////////////////////////////////////
// Dicts
//////////////////////////////////////////////////////////////////////////

  Void testDicts()
  {
    ns := LibRepo.cur.bootNamespace
    verifyDict(ns, Str:Obj[:])
    verifyDict(ns, ["str":"hi there!"])
    verifyDict(ns, ["str":"hi", "int":123])
  }

  Void verifyDict(LibNamespace ns, Str:Obj map, Str qname := "sys::Dict")
  {
    d := dict(map)

    type := ns.specOf(d)

    verifyEq(type.qname, qname)
    if (map.isEmpty) verifySame(d, dict0)

    map.each |v, n|
    {
      verifyEq(d.has(n), true)
      verifyEq(d.missing(n), false)
      verifySame(d.get(n), v)
      verifySame(d.trap(n), v)
    }

    keys := map.keys
    if (keys.isEmpty)
      verifyEq(d.eachWhile |v,n| { "break" }, null)
    else
      verifyEq(d.eachWhile |v,n| { n == keys[0] ? "foo" : null }, "foo")

    verifyEq(d.has("badOne"), false)
    verifyEq(d.missing("badOne"), true)
    verifyEq(d.get("badOne", null), null)
    verifyEq(d.get("badOne", "foo"), "foo")
  }

//////////////////////////////////////////////////////////////////////////
// Derive
//////////////////////////////////////////////////////////////////////////

  Void testDerive()
  {
    ns := createNamespace(["sys"])
    obj := ns.type("sys::Obj")
    scalar := ns.type("sys::Scalar")
    marker := ns.type("sys::Marker")
    str := ns.type("sys::Str")
    list := ns.type("sys::List")
    dict := ns.type("sys::Dict")
    m := Marker.val

    verifyDerive(ns, "foo", list, dict0, null)
    verifyDerive(ns, "foo", list, dict1("bar", m), null)
    verifyDerive(ns, "foo", list, dict2("bar", m, "baz", "hi"), Str:Spec[:])
    verifyDerive(ns, "foo", dict, dict0, ["foo":marker])
    verifyDerive(ns, "foo", dict, dict1("bar", m), ["foo":marker, "dis":str])
    verifyDerive(ns, "foo", dict, dict1("maybe", m), null)

    verifyDeriveErr(ns, "foo bar", scalar, dict0, null, "Invalid spec name: foo bar")
    verifyDeriveErr(ns, "foo", scalar, dict0, ["foo":marker], "Cannot add slots to non-dict type: sys::Scalar")
    verifyDeriveErr(ns, "foo", list, dict0, ["foo":marker], "Cannot add slots to non-dict type: sys::List")
  }

  Void verifyDerive(LibNamespace ns, Str name, Spec base, Dict meta, [Str:Spec]? slots)
  {
    x := ns.derive(name, base, meta, slots)

    verifyEq(x.name, name)
    verifyEq(x.parent, null)
    verifyEq(x.qname.startsWith("derived"), true)
    verifyEq(x.qname.endsWith("::$name"), true)
    verifyDictEq(x.metaOwn, meta)
    verifyEq(x.isMaybe, meta.has("maybe"))

    if (slots == null || slots.isEmpty)
    {
      verifyEq(x.slotsOwn.isEmpty, true)
    }
    else
    {
      slots.each |eslot, n|
      {
        aslot := x.slotsOwn.get(n)
        verifyEq(aslot.name, n)
        verifySame(aslot.parent, x)
        verifySame(aslot.base, eslot)
      }
      x.slotsOwn.each |s| { verifySame(s.base, slots[s.name]) }
    }
  }

  Void verifyDeriveErr(LibNamespace ns, Str name, Spec base, Dict meta, [Str:Spec]? slots, Str msg)
  {
    verifyErrMsg(ArgErr#, msg) { ns.derive(name, base, meta, slots) }
  }

//////////////////////////////////////////////////////////////////////////
// Instantiate
//////////////////////////////////////////////////////////////////////////

  Void testInstantiate()
  {
    ns := createNamespace(["ph", "ph.points", "ashrae.g36", "hx.test.xeto"])

    verifyInstantiate(ns, "sys::None",     null)
    verifyInstantiate(ns, "sys::Str",      "")
    verifyInstantiate(ns, "sys::Number",   n(0))
    verifyInstantiate(ns, "sys::Int",      0)
    verifyInstantiate(ns, "sys::Ref",      Ref("x"))
    verifyInstantiate(ns, "sys::Date",     Date.defVal)
    verifyInstantiate(ns, "sys::Time",     Time.defVal)
    verifyInstantiate(ns, "sys::DateTime", DateTime.defVal)

    verifyInstantiate(ns, "sys::Unit",     "%")

    verifyInstantiate(ns, "sys::Dict", dict0)
    verifyInstantiate(ns, "sys::List", Obj?[,])

    verifyInstantiate(ns, "ph::Meter", ["dis":"Meter", "equip":m, "meter":m])
    verifyInstantiate(ns, "ph::ElecMeter", ["dis":"ElecMeter", "equip":m, "meter":m, "elec":m])
    verifyInstantiate(ns, "ph::AcElecMeter", ["dis":"AcElecMeter", "equip":m, "meter":m, "elec":m, "ac":m])

    verifyInstantiate(ns, "ph::Meter", ["id":Ref("foo"), "dis":"Meter", "equip":m, "meter":m], ["id":Ref("foo")])

    verifyInstantiate(ns, "ph.points::DischargeAirTempSensor", ["dis":"DischargeAirTempSensor", "discharge":m, "air":m, "temp":m, "sensor":m, "point":m, "kind":"Number", "unit":"°F"])
    verifyInstantiate(ns, "ashrae.g36::G36ReheatVav", ["dis":"G36ReheatVav", "equip":m, "vav":m, "hotWaterHeating":m, "singleDuct":m])

    x := Ref("x")
    verifyInstantiateGraph(ns, "ashrae.g36::G36ReheatVav", [
      ["id":Ref("x"), "dis":"G36ReheatVav", "equip":m, "vav":m, "hotWaterHeating":m, "singleDuct":m],
      ["id":Ref("x"), "dis":"ZoneAirTempSensor",      "point":m, "sensor":m,  "kind":"Number", "equipRef":x, "unit":"°F", "zone":m, "air":m, "temp":m],
      ["id":Ref("x"), "dis":"ZoneAirTempEffectiveSp", "point":m, "sp":m,      "kind":"Number", "equipRef":x, "unit":"°F", "zone":m, "air":m, "effective":m, "temp":m],
      ["id":Ref("x"), "dis":"ZoneOccupiedSensor",     "point":m, "sensor":m,  "kind":"Bool",   "equipRef":x, "enum":Ref("ph.points::OccupiedEnum"), "zone":m, "occupied":m],
      ["id":Ref("x"), "dis":"ZoneCo2Sensor",          "point":m, "sensor":m,  "kind":"Number", "equipRef":x, "unit":"ppm", "zone":m, "air":m, "co2":m, "concentration":m],
      ["id":Ref("x"), "dis":"HotWaterValveCmd",       "point":m, "cmd":m,     "kind":"Number", "equipRef":x, "unit":"%",  "hot":m, "water":m, "valve":m],
      ["id":Ref("x"), "dis":"DischargeDamperCmd",     "point":m, "cmd":m,     "kind":"Number", "equipRef":x, "unit":"%",  "discharge":m, "air":m, "damper":m],
      ["id":Ref("x"), "dis":"DischargeAirFlowSensor", "point":m, "sensor":m,  "kind":"Number", "equipRef":x, "unit":"cfm","discharge":m, "air":m, "flow":m],
      ["id":Ref("x"), "dis":"DischargeAirTempSensor", "point":m, "sensor":m , "kind":"Number", "equipRef":x, "unit":"°F", "discharge":m, "air":m, "temp":m],
    ])

    verifyInstantiateGraph(ns, "hx.test.xeto::EqA", [
      ["id":Ref("x"), "dis":"EqA", "equip":m],
      ["id":Ref("x"), "dis":"a", "point":m, "sensor":m, "air":m, "co2":m, "concentration":m, "kind":"Number", "zone":m, "unit":"ppm", "equipRef":x],
      ["id":Ref("x"), "dis":"b", "point":m, "sensor":m, "air":m, "co2":m, "concentration":m, "kind":"Number", "zone":m, "unit":"ppm", "equipRef":x, "foo":m],
    ])

    verifyErr(Err#) { ns.instantiate(ns.spec("sys::Obj")) }
    verifyErr(Err#) { ns.instantiate(ns.spec("sys::Scalar")) }
  }

  Void verifyInstantiate(LibNamespace ns, Str qname, Obj? expect, Obj? opts := null)
  {
    spec := ns.spec(qname)
    actual := ns.instantiate(spec, Etc.makeDict(opts))
    // echo("-- $qname: $actual ?= $expect")
    if (expect is Map)
      verifyDictEq(actual, expect)
    else
      verifyValEq(actual, expect)
  }

  Void verifyInstantiateGraph(LibNamespace ns, Str qname, [Str:Obj][] expect)
  {
    spec := ns.spec(qname)
    Dict[] actual := ns.instantiate(spec, dict1("graph", m))
    // echo; TrioWriter(Env.cur.out).writeAllDicts(actual)
    baseId := (Ref)actual[0]->id
    verifyEq(actual.size, expect.size)
    actual.each |a, i|
    {
      e := expect[i]
      e = e.map |v, n|
      {
        if (n == "id") return a->id
        if (v is Ref && n != "enum") return baseId
        return v
      }
      verifyDictEq(a, e)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Lib verifyLibBasics(LibNamespace ns, Str name, Version version)
  {
    lib := ns.lib(name)

    verifySame(ns.lib(name), lib)
    verifyEq(lib.name, name)
    verifyEq(lib.version, version)
    verifySame(lib.name, ns.names.toName(ns.names.toCode(name)))

    verifyEq(lib._id, Ref("lib:$name"))
    verifySame(lib->id, lib._id)
    verifyEq(lib["loaded"], Marker.val)
    verifyEq(lib["spec"], Ref("sys::Lib"))

    asDict := Etc.dictMerge(lib.meta, [
      "id":lib._id,
      "spec":Ref("sys::Lib"),
      "loaded":m])
    verifyDictEq((haystack::Dict)lib, asDict)

    Lib? async := null
    ns.libAsync(name) |e, x| { async = x }
    verifySame(async, lib)

    verifyEq(lib.type("Bad", false), null)
    verifyErr(UnknownSpecErr#) { lib.type("Bad") }
    verifyErr(UnknownSpecErr#) { lib.type("Bad", true) }

    return lib
  }

  Spec verifyLibType(LibNamespace ns, Lib lib, Str name, Spec? base, Obj? val := null)
  {
    type := lib.type(name)
    verifySame(type, lib.type(name))
    verifyEq(lib.types.containsSame(type), true)
    verifySame(type.parent, null)
    verifySame(type.lib, lib)

    // name/qname
    verifyEq(type.name, name)
    verifyEq(type.qname, lib.name + "::" + name)
    verifySame(type.qname, type.qname)
    verifySame(type.name, ns.names.toName(ns.names.toCode(name)))

    // id
    verifyRefEq(((haystack::Dict)type).id, Ref(type.qname))
    verifyRefEq(type._id, Ref(type.qname))
    verifySame(type._id, type._id)
    verifySame(type["id"], type._id)
    verifySame(type->id, type._id)

    verifySame(lib.type(name), type)
    verifySame(type.type, type)
    verifySame(type.base, base)
    verifyEq(type.toStr, type.qname)
    verifySame(ns.specOf(type), ns.type("sys::Spec"))
    verifyEq(type.isType, true)
    verifyEq(type["val"], val)
    return type
  }

  Spec verifySlot(LibNamespace ns, Spec parent, Str name, Spec type)
  {
    slot := parent.slotOwn(name)
    verifyEq(slot.typeof.qname, "xetoEnv::XetoSpec") // not type
    verifySame(slot.parent, parent)
    verifyEq(slot.name, name)
    verifyEq(slot.qname, parent.qname + "." + name)
    verifyNotSame(slot.qname, slot.qname)
    verifySame(parent.lib, slot.lib)
    verifySame(parent.slot(name), slot)
    verifySame(parent.slotOwn(name), slot)
    verifyEq(parent.slots.names.contains(name), true)
    verifyEq(slot.toStr, slot.qname)
    verifySame(slot.type, type)
    verifySame(slot.base, type)
    verifySame(ns.specOf(slot), ns.type("sys::Spec"))
    verifyEq(slot.isType, false)
    return slot
  }

  Str slotNames(SpecSlots slots)
  {
    buf := StrBuf()
    slots.each |x| { buf.join(x.name, ",") }
    return buf.toStr
  }

  Void dumpLib(Lib lib)
  {
    echo("--- dump $lib.name ---")
    lib.types.each |t|
    {
      hasSlots := !t.slotsOwn.isEmpty
      echo("$t.name: $t.type <$t>" + (hasSlots ? " {" : ""))
      //t.list.each |s| { echo("  $s.name: <$s.meta> $s.base") }
      if (hasSlots) echo("}")
    }
  }

}

