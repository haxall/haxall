//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//    9 Jul 2025  Brian Frank  Updates for new 4.0 design
//

using concurrent
using xeto
using xetom
using haystack
using folio
using hx
using hxm
using hxd
using hxFolio

**
** RuntimeTest
**
class RuntimeTest : HxTest
{

//////////////////////////////////////////////////////////////////////////
// Boot
//////////////////////////////////////////////////////////////////////////

  Void testBoot()
  {
    dir := tempDir
    projLibs := ["sys", "ph", "ashrae.g36", "bad.proj"]

    // boot project
    boot := TestSysBoot(tempDir)
    boot.createLibs = projLibs
    boot.create
    bootLibs := boot.bootLibs
    p := HxdSys(boot).init(boot)

    // build up expectLib map of "libName":"basis status"
    expectLibs := Str:Str[:]
    projLibs.each |n|
    {
      status := n.startsWith("bad") || n == "ashrae.g36" ? "err" : "ok"
      expectLibs[n] = "sys $status"
    }
    initExpectFromBoot := |->|
    {
      expectLibs["proj"] = "boot ok"
      boot.bootLibs.each |n|
      {
        status := n.startsWith("bad") ? "err" : "ok"
        expectLibs[n] = "boot $status"
      }
    }
    initExpectFromBoot()
    expectExts := ["hx.api", "hx.crypto", "hx.hxd.file",
      "hx.hxd.his", "hx.http", "hx.hxd.user", "hx.hxd.proj",
      "hx.io", "hx.task", ]

    // verify initial state
    verifyEq(p.name, boot.name)
    verifyRefEq(p.id, Ref("p:$boot.name", boot.name))
    verifyEq(p.dir, dir)
    verifySame(p.sys, p)
    verifyEq(p.isSys, true)
    verifyEq(p.sys.info.productName, "Test Product")
    verifyEq(p.sys.info.version, Version("1.2.3"))
    verifyEq(p.sys.info.meta["extra"], "summertime")
    verifyEq(p.sys.config.get("testConfig"), "foo")
    verifyEq(p.isRunning, false)
    verifyEq(p.meta->projMeta, Marker.val)
    verifyEq(p.meta->version, "1.2.3")
    verifyProjLibs(p, expectLibs)
    verifyProjExts(p, expectExts)

    // verify system required libs
    verifySame(p.sys.crypto.spec.lib, p.ns.lib("hx.crypto"))
    verifySame(p.sys.http.spec.lib,   p.ns.lib("hx.http"))
    verifySame(p.sys.user.spec.lib,   p.ns.lib("hx.hxd.user"))
    verifySame(p.sys.proj.spec.lib,   p.ns.lib("hx.hxd.proj"))
    verifySame(p.sys.proj.get(p.name), p)
    verifySame(p.sys.proj.list, Proj#.emptyList)

    // add empty list is ignored
    p.libs.addAll(Str[,])
    verifyProjLibs(p, expectLibs)
    verifyProjExts(p, expectExts)

    // add - verify errors
    verifyErr(ArgErr#) { p.libs.add("ph") }
    verifyErr(DuplicateNameErr#) { p.libs.addAll(["ph.points", "ph.points"]) }
    verifyErr(UnknownLibErr#) { p.libs.add("bad.bad.bad") }
    verifyErr(DependErr#) { p.libs.add("hx.test.xeto") }

    // add new lib 'ph.points' which fills 'g36' depend
    p.libs.add("ph.points")
    expectLibs["ph.points"] = "sys ok"
    expectLibs["ashrae.g36"] = "sys ok"
    verifyProjLibs(p, expectLibs)

    // re-boot project and verify libs were persisted
    p.db.close
    p = HxdSys(boot).init(boot)
    verifyProjLibs(p, expectLibs)

    // remove - errors
    verifyErr(DuplicateNameErr#) { p.libs.removeAll(["ph.points", "ph.points"]) }
    verifyErr(DependErr#) { p.libs.remove("ph.points") }
    verifyErr(CannotRemoveBootLibErr#) { p.libs.removeAll(["ashrae.g36", "sys"]) }

    // remove g36
    p.libs.remove("ashrae.g36")
    expectLibs.remove("ashrae.g36")
    verifyProjLibs(p, expectLibs)

    // re-boot and verify libs were persisted
    p.db.close
    p = HxdSys(boot).init(boot)
    verifyProjLibs(p, expectLibs)

    // add new ext
    ext := p.exts.add("hx.shell")
    expectLibs["hx.shell"] = "sys ok"
    expectExts.add("hx.shell")
    verifyProjLibs(p, expectLibs)
    verifyProjExts(p, expectExts)
    verifyEq(ext.web.uri, `/shell/`)

    // clear
    p.libs.clear
    expectLibs.clear
    initExpectFromBoot()
    verifyProjLibs(p, expectLibs)
  }

//////////////////////////////////////////////////////////////////////////
// Meta
//////////////////////////////////////////////////////////////////////////

  @HxTestProj { meta =
    Str<|dis: "My Test"
         steadyState: 100ms
         fooBar|> }
  Void testProjMeta()
  {
    // verify test setup with meta data correctly
    meta := proj.meta
    verifySame(proj.meta, meta)
    verifyProjMeta(["dis":"My Test", "steadyState":n(100, "ms"), "fooBar":m])

    // verify changes to meta - Str:Obj
    proj.metaUpdate(["dis":"New Dis", "newTag":"!"])
    verifyNotSame(proj.meta, meta)
    meta = proj.meta
    verifyProjMeta(["dis":"New Dis", "steadyState":n(100, "ms"), "fooBar":m, "newTag":"!"])

    // verify some bad tags
    verifyErr(DiffErr#) { proj.metaUpdate(["rt":"foo"]) }
    verifyErr(DiffErr#) { proj.metaUpdate(Diff(proj.meta, ["rt":"foo"])) }
    verifyErr(DiffErr#) { proj.metaUpdate(Diff(proj.meta, ["projMeta":Remove.val])) }

    // verify steady state timer
    verifyEq(proj.isSteadyState, false)
    Actor.sleep(150ms)
    verifyEq(proj.isSteadyState, true)

    // restart and verify persisted
    projRestart
    verifyProjMeta(["dis":"New Dis", "steadyState":n(100, "ms"), "fooBar":m, "newTag":"!"])
  }

  Void verifyProjMeta(Str:Obj expect)
  {
    actual := proj.meta
    expect = expect.dup
              .set("id", actual->id)
              .set("rt", "meta")
              .set("projMeta", m)
              .set("version", proj.sys.info.version.toStr)
              .set("mod", actual->mod)
    verifyDictEq(actual, expect)
  }

//////////////////////////////////////////////////////////////////////////
// Companion
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testCompanion()
  {
    addLib("hx.modbus")
    verifyEq(proj.read("name==\"hx.modbus\"")->rt, "lib")

    slots   := Etc.makeMapGrid(null, ["name":"dis", "type":Ref("sys::Str")])
    specRef := Ref("sys::Spec")
    dictRef  := Ref("sys::Dict")
    funcRef  := Ref("sys::Func")

    // fresh start
    digest := proj.companion.libDigest
    verifyCompanionRecs(Str[,], Str[,], null)

    // add spec - SpecA
    proj.companion.add(d(["rt":"spec", "name":"SpecA", "base":Ref("sys::Dict"), "spec":specRef, "slots":slots, "doc":"testing", "admin":m]))
    digest = verifyCompanionRecs(["SpecA"], Str[,], digest)
    specA := proj.companion.lib.spec("SpecA")
    verifyEq(specA.base.qname, "sys::Dict")
    verifyEq(specA.metaOwn["doc"], "testing")
    verifyEq(specA.meta["admin"], m)
    verifyEq(specA.slot("dis").type.name, "Str")

    // add spec - specB
    proj.companion.add(d(["rt":"spec", "name":"specB", "base":Ref("sys::Func"), "spec":specRef]))
    specB := proj.companion.lib.spec("specB")
    digest = verifyCompanionRecs(["SpecA", "specB"], Str[,], digest)
    verifyEq(specB.base.qname, "sys::Func")

    // add spec errors
    companionMode = "add"
    verifyInvalidErr(["rt":null,   "name":"SpecB",    "base":dictRef, "spec":specRef, "slots":slots])
    verifyInvalidErr(["rt":"foo",  "name":"SpecB",    "base":dictRef, "spec":specRef, "slots":slots])
    verifyInvalidErr(["rt":"spec", "name":"Bad Name", "base":null,    "spec":specRef, "slots":slots])
    verifyInvalidErr(["rt":"spec", "name":"SpecB",    "base":"BadStr","spec":specRef, "slots":slots])
    verifyInvalidErr(["rt":"spec", "name":"SpecB",    "base":dictRef, "spec":null,    "slots":slots])
    verifyInvalidErr(["rt":"spec", "name":"SpecB",    "base":dictRef, "spec":Ref("bad"), "slots":slots])
    verifyInvalidErr(["rt":"spec", "name":"SpecB",    "base":null, "spec":specRef, "slots":slots])
    verifyInvalidErr(["rt":"spec", "name":"SpecB",    "base":"bad", "spec":specRef, "slots":slots])
    verifyInvalidErr(["rt":"spec", "name":"SpecB",    "base":Ref("Dict"), "spec":specRef, "slots":slots])
    verifyInvalidErr(["rt":"spec", "name":"SpecB",    "base":dictRef, "spec":specRef, "slots":"bad"])
    verifyInvalidErr(["rt":"spec", "name":"SpecB",    "base":dictRef, "spec":specRef, "slots":slots, "qname":"proj::SpecB"])
    verifyInvalidErr(["rt":"spec", "name":"SpecB",    "base":dictRef, "spec":specRef, "slots":slots, "type":"Dict"])
    verifyInvalidErr(["rt":"spec", "name":"SpecB",    "base":dictRef, "spec":specRef, "slots":"xxx"])
    verifyInvalidErr(["rt":"spec", "name":"SpecB",    "base":dictRef, "spec":specRef, "slots":Etc.makeMapGrid(null, ["foo":m])])
    verifyInvalidErr(["rt":"spec", "name":"SpecB",    "base":dictRef, "spec":specRef, "slots":Etc.makeMapGrid(null, ["name":m])])
    verifyInvalidErr(["rt":"spec", "name":"SpecB",    "base":dictRef, "spec":specRef, "slots":Etc.makeMapGrid(null, ["name":"x", "type":Ref("Obj")])])
    verifyInvalidErr(["rt":"spec", "name":"SpecB",    "base":dictRef, "spec":specRef, "slots":Etc.makeMapsGrid(null, [["name":"x", "type":Ref("sys::Obj")], ["name":"x", "type":Ref("sys::Obj")]])])
    verifyDuplicateErr(["rt":"spec", "name":"SpecA",  "base":Ref("sys::Scalar"), "spec":specRef, "slots":slots])
    digest = verifyCompanionRecs(["SpecA", "specB"], Str[,], null)

    // add instance - inst-a
    proj.companion.add(d(["rt":"instance", "name":"inst-a", "spec":Ref("proj::SpecA"), "dis":"Alpha"]))
    digest = verifyCompanionRecs(["SpecA", "specB"], Str["inst-a"], digest)

    // add instance errors
    verifyInvalidErr(["rt":"instance", "name":"bad id", "spec":Ref("proj::SpecA")])
    verifyInvalidErr(["rt":"instance", "name":"inst-b", "spec":Ref("sys::Spec")])
    verifyDuplicateErr(["rt":"instance", "name":"inst-a"])
    verifyDuplicateErr(["rt":"instance", "name":"SpecA"])

    // add instance - hx.modbus (duplicate lib name)
    proj.companion.add(d(["rt":"instance", "name":"hx.modbus", "spec":Ref("proj::SpecA"), "dis":"Lib Dup"]))
    digest = verifyCompanionRecs(["SpecA", "specB"], Str["hx.modbus", "inst-a"], digest)

    // update spec - SpecA
    proj.companion.update(d(["rt":"spec", "name":"SpecA", "base":funcRef, "spec":specRef, "slots":slots, "su":m]))
    digest = verifyCompanionRecs(["SpecA", "specB"], Str["hx.modbus", "inst-a"], digest)
    specA = proj.companion.lib.spec("SpecA")
    verifyEq(specA.base.qname, "sys::Func")
    verifyEq(specA.metaOwn["doc"], null)
    verifyEq(specA.meta["admin"], null)
    verifyEq(specA.meta["su"], m)

    // update errors
    companionMode = "update"
    verifyInvalidErr(["rt":null,   "name":"SpecA", "base":funcRef, "spec":specRef, "slots":slots, "su":m])
    verifyInvalidErr(["rt":"bad",  "name":"SpecA", "base":funcRef, "spec":specRef, "slots":slots, "su":m])
    verifyInvalidErr(["rt":"spec", "name":"SpecA", "base":"bad",       "spec":specRef, "slots":slots, "su":m])
    verifyInvalidErr(["rt":"spec", "name":"SpecA", "base":funcRef, "spec":null,    "slots":slots, "su":m])
    verifyInvalidErr(["rt":"spec", "name":"SpecA", "base":funcRef, "spec":"Bad",   "slots":slots, "su":m])
    verifyInvalidErr(["rt":"spec", "name":"SpecA", "base":funcRef, "spec":specRef, "slots":"bad", "su":m])
    verifyUnknownErr(["rt":"spec", "name":"SpecX", "base":funcRef, "spec":specRef, "slots":slots, "su":m])
    verifyCompanionRecs(["SpecA", "specB"], Str["hx.modbus", "inst-a"], null)

    // re-boot project and verify libs/specs were persisted
    projRestart
    digest = verifyCompanionRecs(["SpecA", "specB"], Str["hx.modbus", "inst-a"], digest)

    // rename spec and instance
    proj.companion.rename("specB", "specB2")
    proj.companion.rename("hx.modbus", "hx.modbus2")
    digest = verifyCompanionRecs(["SpecA", "specB2"], Str["hx.modbus2", "inst-a"], digest)

    // rename errors
    companionMode = "rename"
    verifyUnknownErr("notFound", "newName")
    verifyDuplicateErr("specB2", "SpecA")

    // remove spec and instance
    proj.companion.remove("specB2")
    proj.companion.remove("hx.modbus2")
    proj.companion.remove("ignore-me-does-not-exist")
    digest = verifyCompanionRecs(["SpecA"], Str["inst-a"], digest)

    // remove errors
    companionMode = "remove"
    proj.companion.remove("hx.modbus")
    verifyNotNull(proj.libs.get("hx.modbus"))

    // re-boot project and verify libs/specs were persisted
    projRestart
    digest = verifyCompanionRecs(["SpecA"], Str["inst-a"], digest)

    // update switch spec <-> instance
    proj.companion.add(d(["rt":"spec",     "name":"a", "base":Ref("sys::Dict"), "spec":specRef]))
    proj.companion.add(d(["rt":"instance", "name":"b", "foo":m]))
    digest = verifyCompanionRecs(["SpecA", "a"], ["b", "inst-a"], digest)
    proj.companion.update(d(["rt":"spec",     "name":"b", "base":Ref("sys::Dict"), "spec":specRef]))
    proj.companion.update(d(["rt":"instance", "name":"a", "foo":m]))
    digest = verifyCompanionRecs(["SpecA", "b"], ["a", "inst-a"], digest)

    // updates with id/mod
    companionMode = "update"
    rec := proj.companion.read("SpecA")
    proj.companion.update(Etc.dictSet(rec, "doc", "w/ id and mod"))
    specA = proj.companion.lib.spec("SpecA")
    verifyEq(specA.metaOwn["doc"], "w/ id and mod")
    rec = proj.companion.read("SpecA")
    verifyInvalidErr(Etc.dictSet(rec, "id", Ref.gen))
    verifyConcurrentErr(Etc.dictSet(rec, "mod", DateTime.nowUtc - 1hr))
  }

  Str? companionMode

  Void companionCall(Obj a, Obj? b)
  {
    switch (companionMode)
    {
      case "add":    proj.companion.add(d(a))
      case "update": proj.companion.update(d(a))
      case "rename": proj.companion.rename(a, b)
      case "remove": proj.companion.remove(a)
      default:       fail
    }
  }

  Void verifyInvalidErr(Obj a, Obj? b := null)
  {
    verifyErr(InvalidCompanionRecErr#) { companionCall(a, b) }
  }

  Void verifyDuplicateErr(Obj a, Obj? b := null)
  {
    verifyErr(DuplicateNameErr#) { companionCall(a, b) }
  }

  Void verifyUnknownErr(Obj a, Obj? b := null)
  {
    verifyErr(UnknownRecErr#) { companionCall(a, b) }
  }

  Void verifyConcurrentErr(Obj a, Obj? b := null)
  {
    verifyErr(ConcurrentChangeErr#) { companionCall(a, b) }
  }

  Str verifyCompanionRecs(Str[] expectSpecs, Str[] expectInstances, Str? oldDigest)
  {
    // ns - spec
    Str[] actualSpecs := proj.companion.lib.specs.map |s->Str| { s.name }
    // echo("~~ $actualSpecs $proj.companion.libDigest")
    verifyEq(actualSpecs.sort, expectSpecs)
    expectSpecs.each |n|
    {
      spec := proj.ns.spec("proj::$n")
      verifySame(spec.lib, proj.companion.lib)
      rec := proj.companion.read(n)
      verifyEq(rec["rt"], "spec")
    }

    // ns - instances
    Str[] actualInstances := proj.companion.lib.instances.map |s->Str| { XetoUtil.qnameToName(s.id.toStr) }
    // echo("~~ $actualInstances")
    verifyEq(actualInstances.sort, expectInstances)
    expectInstances.each |n|
    {
      inst := proj.ns.instance("proj::$n")
      rec := proj.companion.read(n)
      verifyEq(rec["rt"], "instance")
    }

    // check digest
    newDigest := proj.companion.libDigest
    if (oldDigest != null) verifyNotEq(newDigest, oldDigest)
    return newDigest
  }

//////////////////////////////////////////////////////////////////////////
// Axon
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testAxon()
  {
    p := proj
    addLib("hx.test.xeto")
    verifyEq(p.name, "test")
    verifyEq(p.isRunning, true)
    verifyEq(p.ns.libStatus("axon"),         LibStatus.ok)
    verifyEq(p.ns.libStatus("hx"),           LibStatus.ok)
    verifyEq(p.ns.libStatus("hx.test.xeto"), LibStatus.ok)

    // now simple one
    verifyEq(eval("today()"), Date.today)
    verifyEq(eval("cryptoReadAllKeys()") is Grid, true)

    // as maps to _as
    verifyEq(eval("as(3, 1ft)"), n(3, "ft"))

    // read is lazy
    rec := addRec(["dis":"Test", "foo":m])
    verifyDictEq(eval("read(foo)"), rec)

    // qualified names
    verifyEq(eval("axon::today()"), Date.today)
    verifyEq(eval("hx.crypto::cryptoReadAllKeys()") is Grid, true)

    // create axon func in proj
    f := addFunc("foo1", "() => today()")
    verifyEq(eval("foo1()"), Date.today)
    verifyDictEq(f.metaOwn, Etc.dict1("axon", "() => today()\n"))
    verifyEq(f.func.params.size, 0)
    verifyEq(f.func.returns.type.qname, "sys::Obj")

    // create axon func in proj with meta + params
    f = addFunc("foo2", "(a, b) => a + b", ["admin":m, "qux":"foo2"])
    verifyEq(eval("foo2(3, 4)"), n(7))
    verifyDictEq(f.metaOwn, Etc.dict3("axon", "(a, b) => a + b\n", "admin", m, "qux", "foo2"))
    verifyEq(f.func.params.size, 2)
    verifyEq(f.func.params[0].name, "a")
    verifyEq(f.func.params[1].name, "b")
    verifyEq(f.func.params[0].type.qname, "sys::Obj")
    verifyEq(f.func.params[1].type.qname, "sys::Obj")
    verifyEq(f.func.returns.type.qname, "sys::Obj")

    // update foo2
    frec :=  proj.companion.func("foo2", "(a) => a * a", Etc.makeDict(["su":m, "qux":"test!"]))
    proj.companion.update(frec)
    f = proj.ns.spec("proj::foo2")
    verifyEq(eval("foo2(3)"), n(9))
    verifyDictEq(f.metaOwn, Etc.dict3("axon", "(a) => a * a\n", "qux", "test!", "su", m))

    // funcSlots
    src := "(r, s, p, q) => null"
    objRef := Ref("sys::Obj")
    slots := proj.companion.funcSlots(src)
    verifyDictEq(slots[0], ["name":"r", "type":objRef, "maybe":m])
    verifyDictEq(slots[1], ["name":"s", "type":objRef, "maybe":m])
    verifyDictEq(slots[2], ["name":"p", "type":objRef, "maybe":m])
    verifyDictEq(slots[3], ["name":"q", "type":objRef, "maybe":m])
    verifyDictEq(slots[4], ["name":"returns", "type":objRef, "maybe":m])

    // func
    rec = proj.companion.func("foo3", src, Etc.dict1("admin", m))
    verifyDictEq(rec, ["rt":"spec", "name":"foo3", "admin":m, "axon":src,
      "base":Ref("sys::Func"), "spec":Ref("sys::Spec"), "slots":slots])

    // now as spec
    proj.companion.add(rec)
    f = proj.ns.spec("proj::foo3")
    verifyEq(f.func.params.size, 4)
    verifyEq(f.func.params[0].name, "r")
    verifyEq(f.func.params[1].name, "s")
    verifyEq(f.func.params[2].name, "p")
    verifyEq(f.func.params[3].name, "q")
  }

//////////////////////////////////////////////////////////////////////////
// Managed Restrictions
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testManagedChecks()
  {
    norm    := proj.commit(Diff(null, ["dis":"ok"], Diff.add.or(Diff.bypassRestricted))).newRec
    managed := proj.commit(Diff(null, ["dis":"ok", "rt":"foo"], Diff.add.or(Diff.bypassRestricted))).newRec

    // add
    verifyManagedCheck |->| { proj.commit(Diff(null, ["rt":"foo"], Diff.add)) }

    // updates
    verifyManagedCheck |->| { proj.commit(Diff(managed, ["something":m])) }
    verifyManagedCheck |->| { proj.commit(Diff(managed, ["rt":Remove.val])) }
    verifyManagedCheck |->| { proj.commit(Diff(managed, ["trash":m])) }
    verifyManagedCheck |->| { proj.commit(Diff(norm, ["something":m, "rt":m])) }

    // remove
    verifyManagedCheck |->| { proj.commit(Diff(managed, null, Diff.remove)) }
  }

  Void verifyManagedCheck(|->| cb)
  {
    verifyErrMsg(CommitErr#, "Cannot commit to managed rt rec", cb)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Void dump(Proj p)
  {
    echo("#### $p.name ####")
    p.ns.dump
    p.libs.status.dump
    p.exts.status.dump
  }

  Void verifyProjLibs(Proj p, Str:Str expect)
  {
    // echo("\n-- verifyProjLibs"); p.libs.status.dump

    expect.each |e, n|
    {
      ebasis  := e.split[0]
      estatus := e.split[1]
      abasis  := p.libs.get(n).basis.name
      astatus := p.ns.libStatus(n).name
      lib     := p.ns.lib(n, false)
      // echo("  ~~> $n $abasis $astatus")
      verifyEq(abasis,  ebasis)
      verifyEq(astatus, estatus)
      if (estatus=="ok")
      {
        verifyEq(lib.name, n)
      }
      else
      {
        verifyEq(lib, null)
      }
    }

    p.ns.versions.each |v|
    {
      e := expect[v.name] ?: throw Err(v.toStr)
      verifyNotNull(e)
    }

    verifySame(p.companion.lib.name, "proj")
    verifySame(p.companion.lib, p.ns.lib("proj"))
    verifyNotNull(p.companion.libDigest)
  }

  Void verifyProjExts(Proj p, Str[] names)
  {
    list := p.exts.list
    verifyEq(list.map |x->Str| { x.name }.sort.join(","), names.sort.join(","))

    webRoutes := Str:ExtWeb[:]
    list.each |x|
    {
      r := x.web.routeName
      if (!r.isEmpty) webRoutes[r] = x.web
    }
    verifyEq(p.exts.webRoutes, webRoutes)
    verifyEq(p.exts.webRoutes.isImmutable, true)
    verifySame(p.exts.webRoutes, p.exts.webRoutes)
  }

  Dict d(Obj x) { Etc.makeDict(x) }
}

**************************************************************************
** TestSysBoot
**************************************************************************

class TestSysBoot : HxdBoot
{
  new make(File dir) : super("test", dir)
  {
    this.log = Log.get("test")
    this.bootLibs.remove("hx.shell")
    this.bootLibs.add("bad.boot")
    this.sysInfo["version"] = "1.2.3"
    this.sysInfo["extra"] = "summertime"
    this.sysInfo["productName"] = "Test Product"
    this.sysConfig["testConfig"] = "foo"
  }

  override Folio initFolio()
  {
    config := FolioConfig
    {
      it.name = "haxall"
      it.dir  = this.dir + `db/`
      it.pool = ActorPool { it.name = "HxTest-Folio" }
    }
    return HxFolio.open(config)
  }

}

