//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jan 2023  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** NamespaceTest
**
@Js
class NamespaceTest : AbstractXetoTest
{

  Version phVersion() { Version("5.0.0") }
  Version hxVersion() { typeof.pod.version }

//////////////////////////////////////////////////////////////////////////
// Sys Lib
//////////////////////////////////////////////////////////////////////////

  Void testSysLib()
  {
    verifyLocalAndRemote(["sys"]) |ns| { doTestSysLib(ns) }
  }

  private Void doTestSysLib(Namespace ns)
  {
    // lib basics
    sys := verifyLibBasics(ns, "sys", phVersion, ["sys"], false)
    verifySame(ns.lib("sys"), sys)
    verifyEq(sys.name, "sys")
    verifyEq(sys.version, phVersion)
    verifySame(ns.sysLib, sys)

    // verify lib meta inference
    verifyEq(sys.meta["version"], phVersion)
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
    mref   := verifyLibType(ns, sys, "MultiRef", obj)
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
    or     := verifyLibType(ns, sys, "Or",       obj)

    // types
    verifyEq(sys.types.isEmpty, false)
    verifyEq(sys.types.isImmutable, true)
    verifySame(sys.types, sys.types)
    verifyEq(sys.types.get("Str"), str)
    verifyEq(sys.types.list.containsSame(str), true)

    // instances
    verifyEq(sys.instances.size, 0)
    verifyEq(sys.instances.isImmutable, true)
    verifySame(sys.instances, sys.instances)

    // slots
    orgDis := verifySlot(ns, org, "dis", str)
    orgUri := verifySlot(ns, org, "uri", uri)

    // of: Spec?
    of := verifyMeta(ns, sys, "of", ref)
    verifyEq(of.qname, "sys::Spec.of")
    verifySame(of.parent, spec)
    verifyEq(of["doc"], "Item type for parameterized Seq/Query; target type for Ref/MultiRef")
    verifyEq(of["of"], Ref("sys::Spec"))
    verifySame(of.of, spec)

    // ofs: List? <of:Ref<of:Spec>>
    ofs := verifyMeta(ns, sys, "ofs", list)
    ofsOfRef := (Ref)ofs["of"]
    verifyEq(ofs.qname, "sys::Spec.ofs")
    verifyEq(ofs["doc"], "Types used in compound types like And and Or")
    verifyEq(ofsOfRef.toStr.startsWith("sys::_"), true)
    ofsOf := ns.spec(ofsOfRef.id)
    verifySame(ofs.of, ofsOf)
    verifySame(ofsOf.base, ref)
    verifyEq(ofsOf["of"], Ref("sys::Spec"))

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
    verifyEq(ns.spec("bad qname", false), null) // to ensure bad specOf refs don't fail
    verifyEq(ns.type("bad qname", false), null)
    verifyEq(ns.instance("bad qname", false), null)

    // reify scalar default values
    verifySame(sys.type("Unit").meta["val"], Unit("%"))
    verifySame(sys.type("Unit").metaOwn["val"], Unit("%"))
    verifySame(sys.type("TimeZone").meta["val"], TimeZone.utc)
    verifySame(sys.type("TimeZone").metaOwn["val"], TimeZone.utc)

    // enum (ensure items are of same type, but don't dup slots)
    unit := sys.type("Unit")
    item := unit.enum.spec("%RH")
    verifyEq(unit.isEnum, true)
    verifyEq(item.type, unit)
    verifyEq(item.base, unit)
    verifyEq(item.name, "percent_relative_humidity")
    verifyEq(item.slots.isEmpty, true)
    verifyEq(item.slotsOwn.isEmpty, true)
    verifySame(item.slots, SpecMap.empty)

    // specials
    verifyEq(self.isSelf, true)
    verifyEq(none.isNone, true)
    verifyEq(or.isAnd, false)
    verifyEq(or.isOr, false)
    verifyEq(marker.isMarker, true)
    verifyEq(ref.isRef, true)
    verifyEq(mref.isRef, false)
    verifyEq(mref.isMultiRef, true)

    // meta specs
    verifyMeta(ns, sys, "doc", str)

    // files
    verifyEq(sys.files.isSupported, !ns.env.isRemote)
    if (!ns.env.isRemote)
    {
      verifyEq(sys.files.list, Uri[,])
      verifyEq(sys.files.get(`bad`, false), null)
      verifyErr(UnresolvedErr#) { sys.files.get(`bad`) }
      verifyErr(UnresolvedErr#) { sys.files.get(`bad`, true) }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Ph Lib
//////////////////////////////////////////////////////////////////////////

  Void testPhLib()
  {
    verifyLocalAndRemote(["sys", "ph"]) |ns| { doTestPhLib(ns) }
  }

  private Void doTestPhLib(Namespace ns)
  {
    // lib basics
    ph := verifyLibBasics(ns, "ph", phVersion, ["ph"], false)
    verifyEq(ph.depends.size, 1)
    verifyEq(ph.depends[0].name, "sys")
    verifyEq(ph.depends[0].versions.toStr, phVersion.toStr)

    entity    := ns.spec("ph::PhEntity")
    equip     := verifyLibType(ns, ph, "Equip",    entity)
    meter     := verifyLibType(ns, ph, "Meter",    equip)
    elecMeter := verifyLibType(ns, ph, "ElecMeter",meter)
    geoPlace  := verifyLibType(ns, ph, "GeoPlace", entity)
    site      := verifyLibType(ns, ph, "Site",     geoPlace)

    water := entity.globalsOwn.get("water")
    verifySame(ns.spec("ph::PhEntity.water"), water)
    verifySame(water.meta["val"], Marker.val)
    verifyEq(water.isGlobal, true)

    // env.print(elecMeter, Env.cur.out, dict1("effective", m))
    marker := ns.spec("sys::Marker")
    verifyEq(elecMeter.slot("elec").type, marker)
    verifyEq(elecMeter.slot("meter").type, marker)
    verifyEq(elecMeter.slot("equip").type, marker)

    // siteRef
    verifySame(ns.spec("ph::PhEntity.siteRef").of, site)
    verifySame(ns.spec("ph::Equip.siteRef").of, site)

    // hot water
    hotWater := ph.type("HotWater")
    verifyEq(hotWater.slots.names.join(","), "water,hot")

// TODO: globals

    // unqualifiedType
    verifySame(ns.unqualifiedType("Str"), ns.spec("sys::Str"))
    verifySame(ns.unqualifiedType("Equip"), ns.spec("ph::Equip"))
    verifyEq(ns.unqualifiedType("FooBarBazBad", false), null)
    verifyErr(UnknownTypeErr#) { ns.unqualifiedType("FooBarBazBad") }
    verifyErr(UnknownTypeErr#) { ns.unqualifiedType("FooBarBazBad", true) }

    /*
    verifySame(ns.unqualifiedMeta("nodoc"), ns.spec("sys::nodoc"))
    verifyEq(ns.unqualifiedMetas("nodoc"), Spec[ns.spec("sys::nodoc")])
    verifySame(ns.unqualifiedMeta("badOne", false), null)
    verifyEq(ns.unqualifiedMetas("badOne"), Spec[,])
    verifyErr(UnknownSpecErr#) { ns.unqualifiedMeta("badOne") }
    verifyErr(UnknownSpecErr#) { ns.unqualifiedMeta("badOne", true) }
    */

    // enum (ensure items are of same type, but don't dup slots)
    phase := ph.type("Phase")
    item := phase.enum.spec("L2-L3")
    verifyEq(phase.isEnum, true)
    verifyEq(phase.isEnum, true)
    verifyEq(item.type, phase)
    verifyEq(item.base, phase)
    verifyEq(item.name, "l2L3")
    verifyEq(item.slots.isEmpty, true)
    verifyEq(item.slotsOwn.isEmpty, true)
    verifySame(item.slots, SpecMap.empty)

    // files
    verifyEq(ph.files.isSupported, !ns.env.isRemote)
    if (!ns.env.isRemote)
    {
      verifyEq(ph.files.list, Uri[,])
      verifyEq(ph.files.get(`bad`, false), null)
      verifyErr(UnresolvedErr#) { ph.files.get(`bad`) }
      verifyErr(UnresolvedErr#) { ph.files.get(`bad`, true) }
    }
  }

//////////////////////////////////////////////////////////////////////////
// HxTest Lib
//////////////////////////////////////////////////////////////////////////

  Void testHxTestLib()
  {
    verifyLocalAndRemote(["sys", "hx.test.xeto"]) |ns| { doTestHxTestLib(ns) }
  }

  private Void doTestHxTestLib(Namespace ns)
  {
    // lib basics
    lib := verifyLibBasics(ns, "hx.test.xeto", hxVersion, ["haxall"], true)
    verifyEq(lib.meta["org"]->dis, "Haxall")
    verifyEq(lib.meta["org"]->uri, `https://haxall.io/`)
    verifyEq(lib.meta["vcs"]->type, "git")
    verifyEq(lib.meta["vcs"]->uri,  `https://github.com/haxall/haxall`)

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

    // grid
    testGrid := lib.type("TestGrid")
    verifyEq(testGrid.isGrid, true)
    verifyEq(testGrid.base.qname, "sys::Grid")
    verifyEq(testGrid.base.isGrid, true)
    verifyEq(testGrid.base.base.isGrid, false)

    // nested - type with slot of its own type
    nestType := lib.type("TestNest")
    nestSlot := nestType.slot("nest")
    verifySame(nestSlot.type, nestType)
    verifySame(nestSlot.base, nestType)
    verifyEq(nestType.slots.names, ["nest"])
    if (ns.env.isRemote)
      echo("TODO fix RemoteLoader")
    else
      verifyEq(nestSlot.slots.names, ["nest"])

    // meta spec
    verifyMeta(ns, lib, "qux", ns.spec("sys::Str"))

    // mixin (only inherits slots it overrides in remote ns)
    sitem := lib.spec("Site")
    site := sitem.base
    verifyEq(sitem.isMixin, true)
    verifyEq(sitem.flavor, SpecFlavor.mixIn)
    verifyEq(sitem.meta["mixin"], Marker.val)
    verifyEq(site.qname, "ph::Site")
    verifySame(sitem.type, site)
    verifySame(sitem.slot("area").parent, sitem)
    verifySame(sitem.slot("area").base, site.slot("area"))
    verifySame(site.slot("weatherStationRef").parent, site)
    verifyEq(sitem.slot("weatherStationRef", false), null)

    // instances
    verifyDictEq(lib.instance("simple-inst"), ["id":Ref("hx.test.xeto::simple-inst"), "dis":"hi"])

    // files
    files := lib.files
    verifyEq(files.isSupported, !ns.env.isRemote)
    if (!ns.env.isRemote)
    {
      verifyEq(files.list, [`/ChapterA.md`, `/Readme.md`, `/res/a.txt`, `/res/subdir/b.txt`])

      verifyEq(files.get(`bad`, false), null)
      verifyErr(UnresolvedErr#) { files.get(`bad`) }
      verifyErr(UnresolvedErr#) { files.get(`bad`, true) }

      verifyEq(files.get(`/lib.xeto`, false), null)
      verifyErr(UnresolvedErr#) { files.get(`/lib.xeto`) }

      res := files.get(`/res/a.txt`).readAllStr.trim
      verifyEq(res, "alpha")

      res = files.get(`/res/subdir/b.txt`).readAllStr.trim
      verifyEq(res, "beta")
    }

    // this tests the case where the actual slots map keys don't
    // necessarily match the slot names themselves if they are
    // inherited using auto-naming; in the case of TemplateB the
    // first point is assigned name "_0", then in the inherited map
    // its actually "_2" becauase it inherits two slots from its parent
    aPts := lib.spec("EquipA").slot("points")
    bPts := lib.spec("EquipB").slot("points")
    verifySame(bPts.base, aPts)
    verifyEq(aPts.slots.names, ["_0", "_1"])
    verifyEq(bPts.slots.names, ["_0", "_1", "_2"])
    verifyEq(bPts.slot("_2").name, "_0")
    verifyEq(bPts.slot("_2").qname, "hx.test.xeto::EquipB.points._0")
    ptSigs := Str[,]
    bPts.slots.each |x, n|
    {
      ptSigs.add("$n | $x.qname | $x.name: $x.type.name")
      verifySame(bPts.slot(n), x)
    }
    // echo(ptSigs.join("\n"))
    verifyEq(ptSigs, [
      "_0 | hx.test.xeto::EquipA.points._0 | _0: ZoneAirTempSensor",
      "_1 | hx.test.xeto::EquipA.points._1 | _1: ZoneAirHumiditySensor",
      "_2 | hx.test.xeto::EquipB.points._0 | _0: ZoneCo2Sensor"])  // not _2 key maps to name_0
 }

//////////////////////////////////////////////////////////////////////////
// NameTable
//////////////////////////////////////////////////////////////////////////

  /*
  Void testNameTable()
  {
    ns  := createNamespace(["sys", "ph"])
    sys := verifyLibBasics(ns, "sys", phVersion, ["sys"])
    ph  := verifyLibBasics(ns, "ph",  phVersion, ["ph"])
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

  Void verifyNameTable(Namespace ns, Str name)
  {
    code := ns.names.toCode(name)
    // echo("-- $name = $code")
    verifyEq(code > 0, true)
    verifySame(ns.names.toName(code), name)
  }

  Void verifyNameDict(Namespace ns, Dict meta)
  {
    verifyEq(meta.typeof.qname, "xetom::MNameDict")
    meta.each |v, n| { verifyNameTable(ns, n) }
  }
  */

//////////////////////////////////////////////////////////////////////////
// Factories
//////////////////////////////////////////////////////////////////////////

  Void testFactories()
  {
    verifySame(m, Marker.val)
    verifySame(na, NA.val)
    verifySame(none, None.val)
    verifyEq(ref("foo"), Ref("foo", null))
    verifyValEq(ref("foo", "Foo"), Ref("foo", "Foo"))
    verifySame(dict0, Etc.dict0)
    verifyDictEq(dict1("a", "A"), ["a":"A"])
  }

//////////////////////////////////////////////////////////////////////////
// Lookups
//////////////////////////////////////////////////////////////////////////

  Void testLookups()
  {
    // sys
    ns := createNamespace(["hx.test.xeto", "ashrae.g36"])
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

    // good lib, bad type
    verifyEq(ns.type("sys::Foo", false), null)
    verifyErr(UnknownSpecErr#) { ns.type("sys::Foo") }
    verifyErr(UnknownSpecErr#) { ns.type("sys::Foo", true) }

    // instances
    verifyEq(ns.libStatus("hx.test.xeto"), LibStatus.ok)
    verifyDictEq(ns.instance("hx.test.xeto::test-a"), ["id":Ref("hx.test.xeto::test-a"), "alpha":m])
    verifyEq(ns.instance("hx.test.xeto::badOne", false), null)
    verifyEq(ns.instance("hx.test.xeto::badOne", false), null)
    verifyErr(UnknownRecErr#) { ns.instance("hx.test.xeto::badOne") }
    verifyErr(UnknownRecErr#) { ns.instance("hx.test.xeto::badOne", true) }
    verifyErr(UnknownRecErr#) { ns.instance("badOne::badOne") }

    // eachType
    types := Spec[,]
    ns.eachType |t| { types.add(t) }
    verifyEq(types.containsSame(ns.spec("sys::Str")), true)
    verifyEq(types.containsSame(ns.spec("ph::Equip")), true)

    // eachTypeWhile
    verifyEq(types.size > 100, true)
    typesWhile := Spec[,]
    r := ns.eachTypeWhile |t| { typesWhile.add(t); return typesWhile.size == 100 ? "break" : null }
    verifyEq(r, "break")
    verifyEq(typesWhile.size, 100)

    // eachInstance
    instances := Dict[,]
    ns.eachInstance |i| { instances.add(i) }
    verifyEq(instances.containsSame(ns.instance("hx.test.xeto::test-a")), true)

    // hasSubtype
    verifyEq(ns.hasSubtypes(ns.spec("sys::Str")), false)
    verifyEq(ns.hasSubtypes(ns.spec("ph::Equip")), true)

    // eachSubtypes
    subtypes := Spec[,]
    ns.eachSubtype(ns.spec("ph::Equip")) |x| { subtypes.add(x) }
    verifyEq(subtypes.containsSame(ns.spec("ph::AirTerminalUnit")), true)
    verifyEq(subtypes.containsSame(ns.spec("ph::Vav")), false)
  }

//////////////////////////////////////////////////////////////////////////
// Dicts
//////////////////////////////////////////////////////////////////////////

  Void testDicts()
  {
    ns := createNamespace
    verifyDict(ns, Str:Obj[:])
    verifyDict(ns, ["str":"hi there!"])
    verifyDict(ns, ["str":"hi", "int":123])
  }

  Void verifyDict(Namespace ns, Str:Obj map, Str qname := "sys::Dict")
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
    verifyEq(d.get("badOne"), null)
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
    verifyInstantiate(ns, "sys::Int",      n(0))
    verifyInstantiate(ns, "sys::Ref",      Ref("x"))
    verifyInstantiate(ns, "sys::MultiRef", Ref[,])
    verifyInstantiate(ns, "sys::Date",     Date.defVal)
    verifyInstantiate(ns, "sys::Time",     Time.defVal)
    verifyInstantiate(ns, "sys::DateTime", DateTime.defVal)

    verifyInstantiate(ns, "sys::Unit",     "%")

    verifyInstantiate(ns, "sys::Dict", dict0)
    verifyInstantiate(ns, "sys::List", Obj[,])

    verifyInstantiate(ns, "ph::Meter", ["dis":"Meter", "spec":Ref("ph::Meter"), "equip":m, "meter":m])
    verifyInstantiate(ns, "ph::ElecMeter", ["dis":"ElecMeter", "spec":Ref("ph::ElecMeter"), "equip":m, "meter":m, "elec":m])
    verifyInstantiate(ns, "ph::AcElecMeter", ["dis":"AcElecMeter", "spec":Ref("ph::AcElecMeter"), "equip":m, "meter":m, "elec":m, "ac":m])

    verifyInstantiate(ns, "ph::Meter", ["id":Ref("foo", "Meter"), "dis":"Meter", "spec":Ref("ph::Meter"), "equip":m, "meter":m], ["id":Ref("foo")])

    verifyInstantiate(ns, "ph.points::DischargeAirTempSensor", ["dis":"DischargeAirTempSensor", "spec":Ref("ph.points::DischargeAirTempSensor"),  "discharge":m, "air":m, "temp":m, "sensor":m, "point":m, "kind":"Number", "unit":"°F"])
    verifyInstantiate(ns, "ashrae.g36::G36ReheatVav", ["dis":"G36ReheatVav", "spec":Ref("ashrae.g36::G36ReheatVav"), "equip":m, "vav":m, "hotWaterHeating":m, "singleDuct":m])

    instantiateA := ns.spec("hx.test.xeto::InstantiateA")
    instantiateB := ns.spec("hx.test.xeto::InstantiateB")
    instantiateC := ns.spec("hx.test.xeto::InstantiateC")
    instantiateD := ns.spec("hx.test.xeto::InstantiateD")
    carA         := ns.spec("hx.test.xeto::CarA")

    Dict dict := ns.instantiate(instantiateA)
    verifyEq(dict->listRef, Ref[,])
    verifyEq(dict->listRefNullable, Ref?[,])
    verifyEq(dict["a"], "alpha-a")
    verifyEq(dict["b"], "bravo-a")
    verifyEq(dict["c"], null)
    verifyEq(dict["d"], null)
    verifyEq(dict["icon"], null)

    dict = ns.instantiate(instantiateB)
    verifyEq(dict["a"], "alpha-b")
    verifyEq(dict["b"], "bravo-b")
    verifyEq(dict["c"], "charlie-b")
    verifyEq(dict["d"], null)
    verifyEq(dict["icon"], Ref("hx.test.xeto::icon-b"))

    dict = ns.instantiate(instantiateC)
    verifyEq(dict["a"], "alpha-b")
    verifyEq(dict["b"], "bravo-b")
    verifyEq(dict["c"], "charlie-b")
    verifyEq(dict["d"], "delta-c")
    verifyEq(dict["icon"], Ref("hx.test.xeto::icon-b"))

    dict = ns.instantiate(instantiateD)
    // dict.each |v, n| { echo("$n = $v [$v.typeof]") }
    verifyEq(dict["numA"], n(37))
    verifyEq(dict["numB"], n(37))

    dict = ns.instantiate(carA)
    verifyEq(dict["color"], null)  // verif we skip choices, at least for now
    verifyDictEq(dict, ["spec":Ref("hx.test.xeto::CarA"), "dis":"CarA"])

    x := Ref("x")
    verifyInstantiateGraph(ns, "ashrae.g36::G36ReheatVav", [
      ["id":Ref("x"), "dis":"G36ReheatVav", "spec":Ref("ashrae.g36::G36ReheatVav"), "equip":m, "vav":m, "hotWaterHeating":m, "singleDuct":m],
      ["id":Ref("a"), "dis":"ZoneAirTempSensor",      "spec":Ref("ph.points::ZoneAirTempSensor"),      "point":m, "sensor":m,  "kind":"Number", "equipRef":x, "unit":"°F", "zone":m, "air":m, "temp":m],
      ["id":Ref("b"), "dis":"ZoneAirTempEffectiveSp", "spec":Ref("ph.points::ZoneAirTempEffectiveSp"), "point":m, "sp":m,      "kind":"Number", "equipRef":x, "unit":"°F", "zone":m, "air":m, "effective":m, "temp":m],
      ["id":Ref("c"), "dis":"ZoneOccupiedSensor",     "spec":Ref("ph.points::ZoneOccupiedSensor"),     "point":m, "sensor":m,  "kind":"Bool",   "equipRef":x, "enum":Ref("ph.points::OccupiedEnum"), "zone":m, "occupied":m],
      ["id":Ref("d"), "dis":"ZoneCo2Sensor",          "spec":Ref("ph.points::ZoneCo2Sensor"),          "point":m, "sensor":m,  "kind":"Number", "equipRef":x, "unit":"ppm", "zone":m, "air":m, "co2":m, "concentration":m],
      ["id":Ref("e"), "dis":"HotWaterValveCmd",       "spec":Ref("ph.points::HotWaterValveCmd"),       "point":m, "cmd":m,     "kind":"Number", "equipRef":x, "unit":"%",  "hot":m, "water":m, "valve":m],
      ["id":Ref("f"), "dis":"DischargeDamperCmd",     "spec":Ref("ph.points::DischargeDamperCmd"),     "point":m, "cmd":m,     "kind":"Number", "equipRef":x, "unit":"%",  "discharge":m, "air":m, "damper":m],
      ["id":Ref("g"), "dis":"DischargeAirFlowSensor", "spec":Ref("ph.points::DischargeAirFlowSensor"), "point":m, "sensor":m,  "kind":"Number", "equipRef":x, "unit":"cfm","discharge":m, "air":m, "flow":m],
      ["id":Ref("h"), "dis":"DischargeAirTempSensor", "spec":Ref("ph.points::DischargeAirTempSensor"), "point":m, "sensor":m , "kind":"Number", "equipRef":x, "unit":"°F", "discharge":m, "air":m, "temp":m],
    ])

    verifyInstantiateGraph(ns, "hx.test.xeto::EqA", [
      ["id":Ref("x"), "dis":"EqA", "spec":Ref("hx.test.xeto::EqA"), "equip":m],
      ["id":Ref("a"), "dis":"a", "spec":Ref("ph.points::ZoneCo2Sensor"), "point":m, "sensor":m, "air":m, "co2":m, "concentration":m, "kind":"Number", "zone":m, "unit":"ppm", "equipRef":x],
      ["id":Ref("b"), "dis":"b", "spec":Ref("ph.points::ZoneCo2Sensor"), "point":m, "sensor":m, "air":m, "co2":m, "concentration":m, "kind":"Number", "zone":m, "unit":"ppm", "equipRef":x, "foo":"!"],
    ])

    verifyInstantiateGraph(ns, "hx.test.xeto::NestedEq", [
      ["id":Ref("x"),  "dis":"NestedEq", "spec":Ref("hx.test.xeto::NestedEq"), "equip":m],
      ["id":Ref("a"),  "dis":"EqA", "spec":Ref("hx.test.xeto::EqA"), "equip":m, "equipRef":Ref("x")],
      ["id":Ref("a1"), "dis":"a", "spec":Ref("ph.points::ZoneCo2Sensor"), "point":m, "sensor":m, "air":m, "co2":m, "concentration":m, "kind":"Number", "zone":m, "unit":"ppm", "equipRef":Ref("a")],
      ["id":Ref("a2"), "dis":"b", "spec":Ref("ph.points::ZoneCo2Sensor"), "point":m, "sensor":m, "air":m, "co2":m, "concentration":m, "kind":"Number", "zone":m, "unit":"ppm", "equipRef":Ref("a"), "foo":"!"],
      ["id":Ref("b"),  "dis":"EqB", "spec":Ref("hx.test.xeto::EqB"), "equip":m, "equipRef":Ref("x")],
      ["id":Ref("b2"), "dis":"DischargeAirTempSensor", "spec":Ref("ph.points::DischargeAirTempSensor"), "point":m, "sensor":m, "air":m, "discharge":m, "temp":m, "kind":"Number", "unit":"°F", "equipRef":Ref("b")],
      ["id":Ref("x1"), "dis":"OutsideAirTempSensor", "spec":Ref("ph.points::OutsideAirTempSensor"), "point":m, "sensor":m, "air":m, "outside":m, "temp":m, "kind":"Number", "unit":"°F", "equipRef":Ref("x")],
    ])

    verifyErr(Err#) { ns.instantiate(ns.spec("sys::Obj")) }
    verifyErr(Err#) { ns.instantiate(ns.spec("sys::Scalar")) }
  }

  Void verifyInstantiate(Namespace ns, Str qname, Obj? expect, Obj? opts := null)
  {
    spec := ns.spec(qname)

    opts = Etc.dictSet(Etc.makeDict(opts), "haystack", m)
    actual := ns.instantiate(spec, opts)
    // echo("-- $qname: $actual ?= $expect")
    if (expect is Map)
      verifyInstantiateDictEq(ns, actual, expect)
    else
      verifyValEq(actual, expect)
  }

  Void verifyInstantiateGraph(Namespace ns, Str qname, [Str:Obj][] expect)
  {
    // instantiate
    spec := ns.spec(qname)
    Dict[] actual := ns.instantiate(spec, dict2("graph", m, "haystack", m))

    // replace actual generated ids with the test ids we used
    swizzle := Ref:Ref[:]
    actual.each |a, i| { swizzle[a.id] = expect[i].get("id") }
    actual = actual.map |a->Dict|
    {
      acc := Str:Obj[:]
      a.each |v, n|
      {
        if (v is Ref)
        {
          sref := swizzle[v]
          if (sref != null) v = sref
        }
        acc[n] = v
      }
      return Etc.makeDict(acc)
    }

    // echo("\n" + actual.join("\n"))

    verifyEq(actual.size, expect.size)
    actual.each |a, i|
    {
      e := expect[i]
      verifyInstantiateDictEq(ns, a, e)
    }
  }

  Void verifyInstantiateDictEq(Namespace ns, Dict actual, Str:Obj expect)
  {
    // swizzle point dis -> navName, disMacro
    spec    := ns.spec(actual->spec.toStr)
    isPoint := spec.isa(ns.spec("ph::Point"))
    isEquip := spec.isa(ns.spec("ph::Equip"))
    if (isPoint || isEquip)
    {
      expect = expect.dup
      dis := expect.getChecked("dis")
      expect.remove("dis")
      expect.add("navName", dis)
      expect.add("disMacro", isEquip ? Str<|$siteRef $navName|> : Str<|$equipRef $navName|>)
    }
    verifyDictEq(actual, expect)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Lib verifyLibBasics(Namespace ns, Str name, Version version, Str[] categories, Bool hasMarkdown)
  {
    lib := ns.lib(name)

    verifySame(ns.lib(name), lib)
    verifyEq(lib.name, name)
    verifyEq(lib.version, version)
    verifySame(lib.meta->version, lib.version)
    if (name == "sys")
      verifyEq(lib.meta["depends"], null)
    else
      verifySame(lib.meta->depends, lib.depends)

    verifyEq(lib.hasMarkdown, hasMarkdown)

    verifyEq(lib.id, Ref("lib:$name"))
    verifySame(lib->id, lib.id)
    verifyEq(lib["loaded"], Marker.val)
    verifyEq(lib["spec"], Ref("sys::Lib"))


    cats := lib.meta["categories"] as List
    verifyEq(Str[,].addAll(cats), categories)

    asDict := Etc.dictMerge(lib.meta, [
      "id":lib.id,
      "spec":Ref("sys::Lib"),
      "loaded":m])
    verifyDictEq((Dict)lib, asDict)

    verifyEq(lib.type("Bad", false), null)
    verifyErr(UnknownSpecErr#) { lib.type("Bad") }
    verifyErr(UnknownSpecErr#) { lib.type("Bad", true) }

    // eachType
    types := Spec[,]
    lib.types.each |x| { types.add(x) }
    verifyEq(lib.types.list, types)

    // eachTypeWhile
    types.clear
    lib.types.eachWhile |x| { types.add(x); return types.size == 3 ? "break" : null }
    verifyEq(lib.types.list[0..<3], types)

    // eachInstance
    instances := Dict[,]
    lib.eachInstance |x| { instances.add(x) }
    verifyDictsEq(lib.instances, instances, false)

    return lib
  }

  Spec verifyLibType(Namespace ns, Lib lib, Str name, Spec? base, Obj? val := null)
  {
    type := lib.type(name)
    verifySame(type, lib.type(name))
    verifySame(type, lib.types.get(name))
    verifyEq(lib.types.list.containsSame(type), true)
    verifySame(type.parent, null)
    verifySame(type.lib, lib)

    // name/qname
    verifyEq(type.name, name)
    verifyEq(type.qname, lib.name + "::" + name)
    verifySame(type.qname, type.qname)

    // id
    verifyRefEq(((Dict)type).id, Ref(type.qname))
    verifyRefEq(type.id, Ref(type.qname))
    verifySame(type.id, type.id)
    verifySame(type["id"], type.id)
    verifySame(type->id, type.id)

    verifySame(lib.type(name), type)
    verifySame(type.type, type)
    verifySame(type.base, base)
    verifyEq(type.toStr, type.qname)
    verifySame(ns.specOf(type), ns.type("sys::Spec"))
    verifyFlavor(ns, type, SpecFlavor.type)
    verifyEq(type["val"], val)

    verifyFlavor(ns, type, SpecFlavor.type)

    return type
  }

  Spec verifyMeta(Namespace ns, Lib lib, Str name, Spec type)
  {
    slot := ns.metas.get(name)
    spec := ns.spec("sys::Spec")
    verifySame(ns.metas, ns.metas)
    verifySame(ns.metas.get(name), slot)
    if (lib.isSys)
    {
      // own slot
      x := verifySlot(ns, spec, name, type)
      verifySame(x, slot)
    }
    else
    {
      // mixin slot
      x := ns.specx(spec).slot(name)
      verifySame(x, slot)
      verifySame(x.lib, lib)
      verifySame(x.parent.isMixin, true)
      verifySame(x.parent, lib.mixinFor(spec))
      verifySame(x.parent.base, spec)
      verifyEq(x.name, name)
      verifySame(ns.specOf(slot), ns.type("sys::Spec"))
      verifyFlavor(ns, slot, SpecFlavor.slot)
    }
    return slot
  }

  Spec verifySlot(Namespace ns, Spec parent, Str name, Spec type)
  {
    slot := parent.slotOwn(name)
    verifyEq(slot.typeof.qname, "xetom::XetoSpec") // not type
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
    verifyFlavor(ns, slot, SpecFlavor.slot)
    return slot
  }

  Str slotNames(SpecMap slots)
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

