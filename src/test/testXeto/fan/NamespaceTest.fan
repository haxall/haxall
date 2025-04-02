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
    verifyEq(sys.types.containsSame(str), true)

    // instances
    verifyEq(sys.instances.size, 0)
    verifyEq(sys.instances.isImmutable, true)
    verifySame(sys.instances, sys.instances)

    // slots
    orgDis := verifySlot(ns, org, "dis", str)
    orgUri := verifySlot(ns, org, "uri", uri)

    // of: Spec?
    of := verifyMeta(ns, sys, "of", ref)
    verifyEq(of.qname, "sys::of")
    verifySame(of.parent, null)
    verifyEq(of["doc"], "Item type for parameterized Seq/Query; target type for Ref/MultiRef")
    verifyEq(of["of"], Ref("sys::Spec"))
    verifySame(of.of, spec)

    // ofs: List? <of:Ref<of:Spec>>
    ofs := verifyMeta(ns, sys, "ofs", list)
    ofsOfRef := (Ref)ofs["of"]
    verifyEq(ofs.qname, "sys::ofs")
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

    // reify scalar default values
    verifySame(sys.type("Unit").meta["val"], Unit("%"))
    verifySame(sys.type("Unit").metaOwn["val"], Unit("%"))
    verifySame(sys.type("TimeZone").meta["val"], TimeZone.utc)
    verifySame(sys.type("TimeZone").metaOwn["val"], TimeZone.utc)

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
    verifyEq(sys.files.isSupported, !ns.isRemote)
    if (!ns.isRemote)
    {
      verifyEq(sys.files.list, Uri[,])
      Err? err := null
      sys.files.read(`bad`) |e,i| { err = e }
      verifyEq(err?.typeof, UnresolvedErr#)
    }
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

    entity    := ns.spec("sys::Entity")
    equip     := verifyLibType(ns, ph, "Equip",    entity)
    meter     := verifyLibType(ns, ph, "Meter",    equip)
    elecMeter := verifyLibType(ns, ph, "ElecMeter",meter)
    geoPlace  := verifyLibType(ns, ph, "GeoPlace", entity)
    site      := verifyLibType(ns, ph, "Site",     geoPlace)

    water := ph.global("water")
    verifySame(ns.spec("ph::water"), water)
    verifySame(water.meta["val"], Marker.val)

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

    // siteRef
    verifySame(ns.spec("ph::siteRef").of, site)
    verifySame(ns.spec("ph::Equip.siteRef").of, site)

    // hot water
    hotWater := ph.type("HotWater")
    verifyEq(hotWater.slots.names.join(","), "water,hot")

    // unqualifiedType
    verifyEq(ns.isAllLoaded, true)
    verifySame(ns.unqualifiedType("Str"), ns.spec("sys::Str"))
    verifySame(ns.unqualifiedType("Equip"), ns.spec("ph::Equip"))
    verifyEq(ns.unqualifiedType("FooBarBazBad", false), null)
    verifyErr(UnknownTypeErr#) { ns.unqualifiedType("FooBarBazBad") }
    verifyErr(UnknownTypeErr#) { ns.unqualifiedType("FooBarBazBad", true) }

    // global
    verifySame(ns.global("site"), ns.spec("ph::site"))
    verifySame(ns.global("badOne", false), null)
    verifyErr(UnknownSpecErr#) { ns.global("badOne") }
    verifyErr(UnknownSpecErr#) { ns.global("badOne", true) }

    // files
    verifyEq(ph.files.isSupported, !ns.isRemote)
    if (!ns.isRemote)
    {
      verifyEq(ph.files.list, Uri[,])
      Err? err := null
      ph.files.read(`bad`) |e,i| { err = e }
      verifyEq(err?.typeof, UnresolvedErr#)
    }
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

    // global spec
    verifyGlobal(ns, lib, "globalTag", ns.spec("sys::Str"))

    // meta spec
    verifyMeta(ns, lib, "testMetaTag", ns.spec("sys::Str"))

    // files
    files := lib.files
    verifyEq(files.isSupported, !ns.isRemote)
    if (!ns.isRemote)
    {
      verifyEq(files.list, [`/res/a.txt`, `/res/subdir/b.txt`])

      Obj? res := null
      files.read(`bad`) |err,in| { res = err }
      verifyEq(res?.typeof, UnresolvedErr#)

      res = null
      files.read(`/lib.xeto`) |err,in| { res = err }
      verifyEq(res?.typeof, UnresolvedErr#)

      res = null
      files.read(`/res/a.txt`) |err,in| { res = in.readAllStr.trim }
      verifyEq(res, "alpha")

      res = null
      files.read(`/res/subdir/b.txt`) |err,in| { res = in.readAllStr.trim }
      verifyEq(res, "beta")

      verifyEq(files.readStr(`/res/subdir/b.txt`).trim, "beta")
      verifyEq(files.readBuf(`/res/subdir/b.txt`).readAllStr.trim, "beta")

      verifyErr(UnresolvedErr#) { files.readStr(`/bad.txt`) }
    }
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

    // libAsync
    asyncErr := null
    asyncLib := null
    ns.libAsync("sys") |e, x| { asyncErr = e ; asyncLib = x }
    verifyEq(asyncLib, sys)
    verifyEq(asyncErr, null)
    ns.libAsync("badLib") |e, x| { asyncErr = e; asyncLib = x }
    verifyEq(asyncLib, null)
    verifyEq(asyncErr?.typeof, UnknownLibErr#)

    // libAsync
    asyncErr = null
    asyncLibs := null
    ns.libListAsync(["sys", "ashrae.g36"]) |e, x| { asyncErr = e; asyncLibs = x }
    verifyEq(asyncLibs, Lib[sys, ns.lib("ashrae.g36")])
    verifyEq(asyncErr, null)
    ns.libListAsync(["sys", "ashrae.g36"]) |e, x| { asyncErr = e; asyncLibs = x } // do it again for different code path
    verifyEq(asyncLibs, Lib[sys, ns.lib("ashrae.g36")])
    verifyEq(asyncErr, null)
    ns.libListAsync(["sys", "bad", "ph"]) |e, x| { asyncErr = e; asyncLibs = x }
    verifyEq(asyncLibs, null)
    verifyEq(asyncErr?.toStr, UnknownLibErr#.toStr + ": bad")

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
// Overlay
//////////////////////////////////////////////////////////////////////////

  Void testOverlay()
  {
    a := createNamespace(["ph"])
    verifyEq(a.isOverlay, false)
    verifyEq(a.base, null)
    verifyEq(a.versions.size, 2)
    verifyEq(a.versions[0].name, "sys")
    verifyEq(a.versions[1].name, "ph")

    // no duplicates
    repo := LibRepo.cur
    a.versions.each |v|
    {
      verifyErr(Err#) { repo.createOverlayNamespace(a, [v]) }
    }
    verifyErr(Err#) { repo.createOverlayNamespace(a, a.versions) }

    // missing depend
    verifyErr(DependErr#) { repo.createOverlayNamespace(a, [repo.latest("ashrae.g36")]) }

    // now create overlay
    b := repo.createOverlayNamespace(a, [repo.latest("ph.points"), repo.latest("ashrae.g36")])
    verifyEq(b.isOverlay, true)
    verifyEq(b.base, a)
    a.versions.each |v| { verifySame(v, b.version(v.name)) }
    verifySame(a.sysLib, b.sysLib)
    a.libs.each |lib| { verifySame(lib, b.lib(lib.name)) }
  }

//////////////////////////////////////////////////////////////////////////
// Dicts
//////////////////////////////////////////////////////////////////////////

  Void testDicts()
  {
    ns := LibNamespace.system
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

    verifyInstantiate(ns, "ph::Meter", ["id":Ref("foo"), "dis":"Meter", "spec":Ref("ph::Meter"), "equip":m, "meter":m], ["id":Ref("foo")])

    verifyInstantiate(ns, "ph.points::DischargeAirTempSensor", ["dis":"DischargeAirTempSensor", "spec":Ref("ph.points::DischargeAirTempSensor"),  "discharge":m, "air":m, "temp":m, "sensor":m, "point":m, "kind":"Number", "unit":"°F"])
    verifyInstantiate(ns, "ashrae.g36::G36ReheatVav", ["dis":"G36ReheatVav", "spec":Ref("ashrae.g36::G36ReheatVav"), "equip":m, "vav":m, "hotWaterHeating":m, "singleDuct":m])

    instantiateA := ns.spec("hx.test.xeto::InstantiateA")
    instantiateB := ns.spec("hx.test.xeto::InstantiateB")
    instantiateC := ns.spec("hx.test.xeto::InstantiateC")

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

  Void verifyInstantiate(LibNamespace ns, Str qname, Obj? expect, Obj? opts := null)
  {
    spec := ns.spec(qname)
    opts = Etc.dictSet(Etc.makeDict(opts), "haystack", m)
    actual := ns.instantiate(spec, opts)
    // echo("-- $qname: $actual ?= $expect")
    if (expect is Map)
      verifyDictEq(actual, expect)
    else
      verifyValEq(actual, expect)
  }

  Void verifyInstantiateGraph(LibNamespace ns, Str qname, [Str:Obj][] expect)
  {
    // instantiate
    spec := ns.spec(qname)
    Dict[] actual := ns.instantiate(spec, dict2("graph", m, "haystack", m))

    // replace actual generated ids with the test ids we used
    swizzle := Ref:Ref[:]
    actual.each |a, i| { swizzle[a._id] = expect[i].get("id") }
    actual = actual.map |a->Dict|
    {
      acc := Str:Obj[:]
      a.each |v, n|
      {
        if (v is Ref) v = swizzle[v] ?: v
        acc[n] = v
      }
      return Etc.makeDict(acc)
    }

    // echo("\n" + actual.join("\n"))

    verifyEq(actual.size, expect.size)
    actual.each |a, i|
    {
      e := expect[i]
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
    verifySame(lib.meta->version, lib.version)
    if (name == "sys")
      verifyEq(lib.meta["depends"], null)
    else
      verifySame(lib.meta->depends, lib.depends)
    verifySame(lib.name, ns.names.toName(ns.names.toCode(name)))

    verifyEq(lib.hasXMeta, name == "hx.test.xeto")
    verifyEq(lib.hasMarkdown, false)

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
    verifyFlavorLookup(ns, type, SpecFlavor.type)
    verifyEq(type["val"], val)
    return type
  }

  Spec verifyGlobal(LibNamespace ns, Lib lib, Str name, Spec type)
  {
    spec := lib.global(name)
    verifySame(ns.spec("$lib.name::$name"), spec)
    verifySame(spec.lib, lib)
    verifyEq(spec.parent, null)
    verifyFlavorLookup(ns, spec, SpecFlavor.global)
    verifySame(spec.type, type)
    verifySame(spec.base, type)
    return spec
  }

  Spec verifyMeta(LibNamespace ns, Lib lib, Str name, Spec type)
  {
    spec := lib.metaSpec(name)
    verifySame(ns.spec("$lib.name::$name"), spec)
    verifySame(spec.lib, lib)
    verifyEq(spec.parent, null)
    verifyFlavorLookup(ns, spec, SpecFlavor.meta)
    verifySame(spec.type, type)
    verifySame(spec.base, type)
    return spec
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
    verifyFlavorLookup(ns, slot, SpecFlavor.slot)
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

