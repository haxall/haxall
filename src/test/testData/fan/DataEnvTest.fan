//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jan 2023  Brian Frank  Creation
//

using util
using data
using haystack

**
** DataEnvTest
**
@Js
class DataEnvTest : AbstractDataTest
{

//////////////////////////////////////////////////////////////////////////
// Sys Lib
//////////////////////////////////////////////////////////////////////////

  static Version curVersion() { Version("0.1.1") }

  Void testSysLib()
  {
    // lib basics
    sys := verifyLibBasics("sys", curVersion)
    verifySame(env.lib("sys"), sys)
    verifyEq(sys.qname, "sys")
    verifyEq(sys.version, curVersion)
// TODO
//    verifyEq(sys["version"], typeof.pod.version)
    verifySame(env.sysLib, sys)

     // env.print(sys)

    // types
    obj    := verifyLibType(sys, "Obj",      null)
    self   := verifyLibType(sys, "Self",     obj)
    scalar := verifyLibType(sys, "Scalar",   obj)
    none   := verifyLibType(sys, "None",     scalar, env.none)
    marker := verifyLibType(sys, "Marker",   scalar, env.marker)
    na     := verifyLibType(sys, "NA",       scalar, env.na)
    str    := verifyLibType(sys, "Str",      scalar, "")
    uri    := verifyLibType(sys, "Uri",      scalar, ``)
    ref    := verifyLibType(sys, "Ref",      scalar, Ref("x"))
    time   := verifyLibType(sys, "Time",     scalar, Time.defVal)
    date   := verifyLibType(sys, "Date",     scalar, Date.defVal)
    dt     := verifyLibType(sys, "DateTime", scalar, DateTime.defVal)
    seq    := verifyLibType(sys, "Seq",      obj)
    dict   := verifyLibType(sys, "Dict",     seq)
    list   := verifyLibType(sys, "List",     seq)
    spec   := verifyLibType(sys, "Spec",     dict)
    type   := verifyLibType(sys, "Type",     spec)
    lib    := verifyLibType(sys, "Lib",      spec)
    org    := verifyLibType(sys, "LibOrg",   dict)

    // slots
    orgDis := verifySlot(org, "dis", str)
    orgUri := verifySlot(org, "uri", uri)

    // Spec.of: Spec?
    specOf := verifySlot(spec, "of", spec)
    verifyEq(specOf.qname, "sys::Spec.of")
    verifySame(specOf.parent, spec)
    verifyEq(specOf["doc"], "Item type used for containers like Maybe, Seq, and Ref")
    verifyEq(specOf["maybe"], env.marker)

    // Spec.ofs: List? <of:Spec>
    specOfs := verifySlot(spec, "ofs", list)
    verifyEq(specOfs.parent, spec)
    verifyEq(specOfs.qname, "sys::Spec.ofs")
    verifyEq(specOfs["doc"], "Types used in compound types like And and Or")
    verifyEq(specOfs["maybe"], env.marker)
    verifySame(specOfs["of"], spec)

    // loukups
    verifySame(env.spec("sys"), sys)
    verifySame(env.spec("sys::LibOrg"), org)
    verifySame(env.spec("sys::LibOrg.dis"), orgDis)
    verifyErr(UnknownLibErr#) { env.spec("foo.bar.baz") }
    verifyErr(UnknownSpecErr#) { env.spec("foo.bar.baz::Qux") }
    verifyErr(UnknownSpecErr#) { env.spec("sys::Baz") }
    verifyErr(UnknownSpecErr#) { env.spec("sys::Str.foo") }
  }

//////////////////////////////////////////////////////////////////////////
// Ph Lib
//////////////////////////////////////////////////////////////////////////

  Void testPhLib()
  {
    // lib basics
    ph := verifyLibBasics("ph", curVersion)

    entity := verifyLibType(ph, "Entity", env.type("sys::Dict"))
    equip  := verifyLibType(ph, "Equip",  entity)
    meter  := verifyLibType(ph, "Meter",  equip)

  }

//////////////////////////////////////////////////////////////////////////
// Lookups
//////////////////////////////////////////////////////////////////////////

  Void testLookups()
  {
    // sys
    sys := env.lib("sys")
    verifySame(env.lib("sys"), sys)
    verifySame(env.type("sys::Dict"), sys.slotOwn("Dict"))

    // bad libs
    verifyEq(env.lib("bad.one", false), null)
    verifyEq(env.type("bad.one::Foo", false), null)
    verifyErr(UnknownLibErr#) { env.lib("bad.one") }
    verifyErr(UnknownLibErr#) { env.lib("bad.one", true) }
    verifyErr(UnknownTypeErr#) { env.type("bad.one::Foo") }
    verifyErr(UnknownTypeErr#) { env.type("bad.one::Foo", true) }

    // good lib, bad type
    verifyEq(env.type("sys::Foo", false), null)
    verifyErr(UnknownTypeErr#) { env.type("sys::Foo") }
    verifyErr(UnknownTypeErr#) { env.type("sys::Foo", true) }
  }

//////////////////////////////////////////////////////////////////////////
// TypeOf
//////////////////////////////////////////////////////////////////////////

/*
  Void testTypeOf()
  {
    verifyTypeOf(null, "sys::None")
    verifyTypeOf("hi", "sys::Str")
    verifyTypeOf(true, "sys::Bool")
    verifyTypeOf(`foo`, "sys::Uri")
    verifyTypeOf(123, "sys::Int")
    verifyTypeOf(123f, "sys::Float")
    verifyTypeOf(123sec,"sys::Duration")
    verifyTypeOf(Date.today, "sys::Date")
    verifyTypeOf(Time.now, "sys::Time")
    verifyTypeOf(DateTime.now, "sys::DateTime")

    verifyTypeOf(Marker.val,  "sys::Marker")
    verifyTypeOf(Number(123), "sys::Number")
    verifyTypeOf(Ref.gen,     "sys::Ref")

    verifyEq(env.typeOf(Buf(), false), null)
    verifyErr(UnknownTypeErr#) { env.typeOf(this) }
    verifyErr(UnknownTypeErr#) { env.typeOf(this, true) }
  }

  Void verifyTypeOf(Obj? val, Str qname)
  {
    t := env.typeOf(val)
    // echo(">> $val | $t ?= $qname")
    verifyEq(t.qname, qname)
    verifySame(t, env.type(qname))
  }
*/

//////////////////////////////////////////////////////////////////////////
// Dicts
//////////////////////////////////////////////////////////////////////////

  Void testDicts()
  {
    verifyDict(Str:Obj[:])
    verifyDict(["str":"hi there!"])
    verifyDict(["str":"hi", "int":123])
  }

  Void verifyDict(Str:Obj map, Str qname := "sys::Dict")
  {
    d := env.dict(map)

    type := (DataType)d.spec

    verifyEq(type.qname, qname)
    verifySame(d.spec, env.type(qname))
    if (map.isEmpty) verifySame(d, env.dict0)

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
// DependLibVersions
//////////////////////////////////////////////////////////////////////////

  Void testDependLibVersions()
  {
    verifyDependLibVersions("2.3.4", "2.3.3", false)
    verifyDependLibVersions("2.3.4", "2.3.4", true)
    verifyDependLibVersions("2.3.4", "2.3.5", false)
    verifyDependLibVersions("2.3.4", "2.7.4", false)
    verifyDependLibVersions("2.3.4", "1.3.4", false)
    verifyDependLibVersions("2.3.4", "2.3", false)
    verifyDependLibVersions("2.3.4", "2", false)

    verifyDependLibVersions("2.3.x", "2.3.3", true)
    verifyDependLibVersions("2.3.x", "2.3.1", true)
    verifyDependLibVersions("2.3.x", "2.3.22", true)
    verifyDependLibVersions("2.3.x", "2.4.0", false)
    verifyDependLibVersions("2.3.x", "3.3.0", false)

    verifyDependLibVersions("10.x.x", "10.300.400", true)
    verifyDependLibVersions("10.x.x", "9.300.400", false)
    verifyDependLibVersions("10.x.x", "11.0.0.123", false)

    verifyDependLibVersions("3.107.0 - 3.107.10", "2.107.0",  false)
    verifyDependLibVersions("3.107.0 - 3.107.10", "3.106.1",  false)
    verifyDependLibVersions("3.107.0 - 3.107.10", "3.107.0",  true)
    verifyDependLibVersions("3.107.0 - 3.107.10", "3.107.9",  true)
    verifyDependLibVersions("3.107.0 - 3.107.10", "3.107.10", true)
    verifyDependLibVersions("3.107.0 - 3.107.10", "3.107.11", false)
    verifyDependLibVersions("3.107.0 - 3.107.10", "3.108.2",  false)
    verifyDependLibVersions("3.107.0 - 3.107.10", "4.107.0",  false)

    verifyDependLibVersions("3.4.5 - 4.10.20",  "2.4.5",   false)
    verifyDependLibVersions("3.4.5 - 4.10.20",  "3.3.5",   false)
    verifyDependLibVersions("3.4.5 - 4.10.20",  "3.4.4",   false)
    verifyDependLibVersions("3.4.5 - 4.10.20",  "3.4.5",   true)
    verifyDependLibVersions("3.4.5 - 4.10.20",  "4.1.2",   true)
    verifyDependLibVersions("3.4.5 - 4.10.20",  "4.0.0",   true)
    verifyDependLibVersions("3.4.5 - 4.10.20",  "4.1.2",   true)
    verifyDependLibVersions("3.4.5 - 4.10.20",  "4.10.20", true)
    verifyDependLibVersions("3.4.5 - 4.10.20",  "4.10.21", false)
    verifyDependLibVersions("3.4.5 - 4.10.20",  "4.11.20", false)
    verifyDependLibVersions("3.4.5 - 4.10.20",  "5.10.20", false)

    verifyDependLibVersions("3.107.2 - 3.107.x", "2.107.2",   false)
    verifyDependLibVersions("3.107.2 - 3.107.x", "3.106.2",   false)
    verifyDependLibVersions("3.107.2 - 3.107.x", "3.107.1",   false)
    verifyDependLibVersions("3.107.2 - 3.107.x", "3.107.2",   true)
    verifyDependLibVersions("3.107.2 - 3.107.x", "3.107.999", true)
    verifyDependLibVersions("3.107.2 - 3.107.x", "3.108.0",   false)
    verifyDependLibVersions("3.107.2 - 3.107.x", "4.107.0",   false)

    verifyDependLibVersions("3.107.2 - 4.x.x", "2.107.2",   false)
    verifyDependLibVersions("3.107.2 - 4.x.x", "3.100.2",   false)
    verifyDependLibVersions("3.107.2 - 4.x.x", "3.107.1",   false)
    verifyDependLibVersions("3.107.2 - 4.x.x", "3.107.1",   false)
    verifyDependLibVersions("3.107.2 - 4.x.x", "3.107.2",   true)
    verifyDependLibVersions("3.107.2 - 4.x.x", "3.107.99",  true)
    verifyDependLibVersions("3.107.2 - 4.x.x", "3.199.99",  true)
    verifyDependLibVersions("3.107.2 - 4.x.x", "4.0.0",     true)
    verifyDependLibVersions("3.107.2 - 4.x.x", "4.8.9",     true)
    verifyDependLibVersions("3.107.2 - 4.x.x", "5.0.0",     false)

    verifyDependLibVersions("3.107.2 - x.x.x", "2.107.2",   false)
    verifyDependLibVersions("3.107.2 - x.x.x", "3.100.2",   false)
    verifyDependLibVersions("3.107.2 - x.x.x", "3.107.1",   false)
    verifyDependLibVersions("3.107.2 - x.x.x", "3.107.1",   false)
    verifyDependLibVersions("3.107.2 - x.x.x", "3.107.2",   true)
    verifyDependLibVersions("3.107.2 - x.x.x", "3.107.99",  true)
    verifyDependLibVersions("3.107.2 - x.x.x", "3.199.99",  true)
    verifyDependLibVersions("3.107.2 - x.x.x", "4.0.0",     true)
    verifyDependLibVersions("3.107.2 - x.x.x", "4.8.9",     true)
    verifyDependLibVersions("3.107.2 - x.x.x", "5.0.0",     true)
    verifyDependLibVersions("3.107.2 - x.x.x", "99.100.3",  true)

    verifyDependLibVersions("3.107.x - 3.x.x", "2.107.2",   false)
    verifyDependLibVersions("3.107.x - 3.x.x", "3.106.2",   false)
    verifyDependLibVersions("3.107.x - 3.x.x", "3.107.0",   true)
    verifyDependLibVersions("3.107.x - 3.x.x", "3.107.99",  true)
    verifyDependLibVersions("3.107.x - 3.x.x", "3.109.0",   true)
    verifyDependLibVersions("3.107.x - 3.x.x", "3.999.8",   true)
    verifyDependLibVersions("3.107.x - 3.x.x", "4.0.0",     false)
  }

  Void verifyDependLibVersions(Str s, Str v, Bool expect)
  {
    c := DataLibDependVersions(s)
    // echo("--> $c " + v + " = " + c.contains(Version(v)))
    verifyEq(c.toStr, s.replace(" ", ""))
    verifyEq(c.contains(Version(v)), expect)
  }

//////////////////////////////////////////////////////////////////////////
// Derive
//////////////////////////////////////////////////////////////////////////

  Void testDerive()
  {
    obj := env.type("sys::Obj")
    scalar := env.type("sys::Scalar")
    marker := env.type("sys::Marker")
    str := env.type("sys::Str")
    list := env.type("sys::List")
    dict := env.type("sys::Dict")
    m := Marker.val

    verifyDerive("foo", list, env.dict0, null)
    verifyDerive("foo", list, env.dict1("bar", m), null)
    verifyDerive("foo", list, env.dict2("bar", m, "baz", "hi"), Str:DataSpec[:])
    verifyDerive("foo", dict, env.dict0, ["foo":marker])
    verifyDerive("foo", dict, env.dict1("bar", m), ["foo":marker, "dis":str])
    verifyDerive("foo", dict, env.dict1("maybe", m), null)

    verifyDeriveErr("foo bar", scalar, env.dict0, null, "Invalid spec name: foo bar")
    verifyDeriveErr("foo", scalar, env.dict0, ["foo":marker], "Cannot add slots to non-dict type: sys::Scalar")
    verifyDeriveErr("foo", list, env.dict0, ["foo":marker], "Cannot add slots to non-dict type: sys::List")
  }

  Void verifyDerive(Str name, DataSpec base, DataDict meta, [Str:DataSpec]? slots)
  {
    x := env.derive(name, base, meta, slots)

    verifyEq(x.name, name)
    verifyEq(x.parent, null)
    verifyEq(x.qname.startsWith("derived"), true)
    verifyEq(x.qname.endsWith("::$name"), true)
    verifySame(x.env, env)
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

  Void verifyDeriveErr(Str name, DataSpec base, DataDict meta, [Str:DataSpec]? slots, Str msg)
  {
    verifyErrMsg(ArgErr#, msg) { env.derive(name, base, meta, slots) }
  }

//////////////////////////////////////////////////////////////////////////
// Instantiate
//////////////////////////////////////////////////////////////////////////

  Void testInstantiate()
  {
    verifyInstantiate("sys::None",     null)
    verifyInstantiate("sys::Str",      "")
    verifyInstantiate("sys::Number",   n(0))
    verifyInstantiate("sys::Int",      0)
    verifyInstantiate("sys::Ref",      Ref("x"))
    verifyInstantiate("sys::Date",     Date.defVal)
    verifyInstantiate("sys::Time",     Time.defVal)
    verifyInstantiate("sys::DateTime", DateTime.defVal)

    verifyInstantiate("sys::Dict", env.dict0)
    verifyInstantiate("sys::List", Obj?[,])

    verifyInstantiate("ph::Meter", ["dis":"Meter", "equip":m, "meter":m])
    verifyInstantiate("ph::ElecMeter", ["dis":"ElecMeter", "equip":m, "meter":m, "elec":m])
    verifyInstantiate("ph::AcElecMeter", ["dis":"AcElecMeter", "equip":m, "meter":m, "elec":m, "ac":m])

    verifyInstantiate("ph.points::DischargeAirTempSensor", ["dis":"DischargeAirTempSensor", "discharge":m, "air":m, "temp":m, "sensor":m, "point":m, "kind":"Number", "unit":"°F"])
    verifyInstantiate("ashrae.g36::G36ReheatVav", ["dis":"G36ReheatVav", "equip":m, "vav":m, "hotWaterHeating":m, "singleDuct":m])

    x := Ref("x")
    verifyInstantiateGraph("ashrae.g36::G36ReheatVav", [
      ["id":Ref("x"), "dis":"G36ReheatVav", "equip":m, "vav":m, "hotWaterHeating":m, "singleDuct":m],
      ["id":Ref("x"), "dis":"ZoneAirTempSensor",      "point":m, "sensor":m,  "kind":"Number", "equipRef":x, "unit":"°F", "zone":m, "air":m, "temp":m],
      ["id":Ref("x"), "dis":"ZoneAirTempEffectiveSp", "point":m, "sp":m,      "kind":"Number", "equipRef":x, "unit":"°F", "zone":m, "air":m, "effective":m, "temp":m],
      ["id":Ref("x"), "dis":"ZoneOccupiedSensor",     "point":m, "sensor":m,  "kind":"Bool",   "equipRef":x, "enum":"unoccupied,occupied", "zone":m, "occupied":m],
      ["id":Ref("x"), "dis":"ZoneCo2Sensor",          "point":m, "sensor":m,  "kind":"Number", "equipRef":x, "unit":"ppm", "zone":m, "air":m, "co2":m, "concentration":m],
      ["id":Ref("x"), "dis":"HotWaterValveCmd",       "point":m, "cmd":m,     "kind":"Number", "equipRef":x, "unit":"%",  "hot":m, "water":m, "valve":m],
      ["id":Ref("x"), "dis":"DischargeDamperCmd",     "point":m, "cmd":m,     "kind":"Number", "equipRef":x, "unit":"%",  "discharge":m, "air":m, "damper":m],
      ["id":Ref("x"), "dis":"DischargeAirFlowSensor", "point":m, "sensor":m,  "kind":"Number", "equipRef":x, "unit":"",   "discharge":m, "air":m, "flow":m],
      ["id":Ref("x"), "dis":"DischargeAirTempSensor", "point":m, "sensor":m , "kind":"Number", "equipRef":x, "unit":"°F", "discharge":m, "air":m, "temp":m],
    ])

    verifyErr(Err#) { env.instantiate(env.spec("sys::Obj")) }
    verifyErr(Err#) { env.instantiate(env.spec("sys::Scalar")) }
  }

  Void verifyInstantiate(Str qname, Obj? expect)
  {
    actual := env.instantiate(env.spec(qname))
    // echo("-- $qname: $actual ?= $expect")
    verifyValEq(actual, expect)
  }

  Void verifyInstantiateGraph(Str qname, [Str:Obj][] expect)
  {
    DataDict[] actual := env.instantiate(env.spec(qname), env.dict1("graph", m))
    baseId := (Ref)actual[0]->id
    verifyEq(actual.size, expect.size)
    actual.each |a, i|
    {
      e := expect[i]
      e = e.map |v, n|
      {
        if (n == "id") return a->id
        if (v is Ref) return baseId
        return v
      }
      verifyDictEq(a, e)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  DataLib verifyLibBasics(Str qname, Version version)
  {
    lib := env.lib(qname)

    verifySame(env.lib(qname), lib)
    verifySame(lib.env, env)
    verifyEq(lib.parent, null)
    verifyEq(lib.name, "")
    verifyEq(lib.qname, qname)
    verifyEq(lib.version, version)
    verifyEq(lib.isLib, true)
    verifyEq(lib.isType, false)
    verifySame(lib.type, env.type("sys::Lib"))
    verifySame(lib.base, env.type("sys::Lib"))
    verifySame(lib.spec, env.type("sys::Lib"))

    verifyEq(lib.slotOwn("Bad", false), null)
    verifyErr(UnknownNameErr#) { lib.slotOwn("Bad") }
    verifyErr(UnknownNameErr#) { lib.slotOwn("Bad", true) }

    verifyEq(lib.libType("Bad", false), null)
    verifyErr(UnknownTypeErr#) { lib.libType("Bad") }
    verifyErr(UnknownTypeErr#) { lib.libType("Bad", true) }

    return lib
  }

  DataSpec verifyLibType(DataLib lib, Str name, DataType? base, Obj? val := null)
  {
    DataType type := lib.libType(name)
    verifySame(type, lib.slot(name))
    verifySame(type, lib.slotOwn(name))
    verifySame(type.env, env)
    verifySame(type.parent, lib)
    verifySame(type.lib, lib)
    verifyEq(type.name, name)
    verifyEq(type.qname, lib.qname + "::" + name)
    verifySame(type.qname, type.qname)
    verifySame(lib.slotOwn(name), type)
    verifyEq(lib.slots.names.contains(name), true)
    verifySame(type.type, type)
    verifySame(type.base, base)
    verifyEq(type.toStr, type.qname)
    verifySame(type.spec, env.type("sys::Type"))
    verifyEq(type.isLib, false)
    verifyEq(type.isType, true)
    verifyEq(type["val"], val)
    return type
  }

  DataSpec verifySlot(DataSpec parent, Str name, DataType type)
  {
    slot := parent.slotOwn(name)
    verifyEq(slot.typeof.qname, "xeto::XetoSpec") // not type
    verifySame(slot.parent, parent)
    verifyEq(slot.name, name)
    verifyEq(slot.qname, parent.qname + "." + name)
    verifyNotSame(slot.qname, slot.qname)
    verifySame(slot.env, env)
    verifySame(parent.slot(name), slot)
    verifySame(parent.slotOwn(name), slot)
    verifyEq(parent.slots.names.contains(name), true)
    verifyEq(slot.toStr, slot.qname)
    verifySame(slot.type, type)
    verifySame(slot.base, type)
    verifySame(slot.spec, env.type("sys::Spec"))
    verifyEq(slot.isLib, false)
    verifyEq(slot.isType, false)
    return slot
  }

  Void dumpLib(DataLib lib)
  {
    echo("--- dump $lib.qname ---")
    lib.slotsOwn.each |DataType t|
    {
      hasSlots := !t.slotsOwn.isEmpty
      echo("$t.name: $t.type <$t>" + (hasSlots ? " {" : ""))
      //t.list.each |s| { echo("  $s.name: <$s.meta> $s.base") }
      if (hasSlots) echo("}")
    }
  }

}