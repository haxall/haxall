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
    // setup
    dir := tempDir
    projLibs := ["sys", "ph", "ashrae.g36", "bad.proj"]
    dir.plus(`ns/libs.txt`).out.print(projLibs.join("\n")).close

    // boot project
    boot := TestSysBoot(tempDir)
    bootLibs := boot.bootLibs
    p := HxdSys(boot).init(boot)

    // build up expectLib map of "libName":"basis status"
    expectLibs := Str:Str[:]
    expectLibs["proj"] = "boot ok"
    projLibs.each |n|
    {
      status := n.startsWith("bad") || n == "ashrae.g36" ? "err" : "ok"
      expectLibs[n] = "sys $status"
    }
    boot.bootLibs.each |n|
    {
      status := n.startsWith("bad") ? "err" : "ok"
      expectLibs[n] = "boot $status"
    }
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

    // add spec
    pld := p.companion.libDigest
    specA := p.companion._add("SpecA", "Dict { dis: Str }")
    specB := p.companion._add("SpecB", "Dict { dis: Str }")
    verifyEq(specA.qname, "proj::SpecA")
    verifyEq(specA.base.qname, "sys::Dict")
    verifyEq(p.companion._read("SpecA"), "Dict { dis: Str }")
    pld = verifyProjSpecs(p, ["SpecA", "SpecB"], pld)

    // add errors
    verifyErr(DuplicateNameErr#) { p.companion._add("SpecA", "Dict { foo: Str }") }
    verifyErr(NameErr#) { p.companion._add("Bad Name", "Dict { foo: Str }") }

    // update spec
    specA = p.companion._update("SpecA", "Scalar")
    verifyEq(specA.qname, "proj::SpecA")
    verifyEq(specA.base.qname, "sys::Scalar")
    verifyEq(p.companion._read("SpecA"), "Scalar")
    pld = verifyProjSpecs(p, ["SpecA", "SpecB"], pld)

    // update errors
    verifyErr(UnknownSpecErr#) { p.companion._update("SpecX", "Dict { foo: Str }") }

    // re-boot project and verify libs/specs were persisted
    p.db.close
    p = HxdSys(boot).init(boot)
    verifyProjLibs(p, expectLibs)
    pld = verifyProjSpecs(p, ["SpecA", "SpecB"], pld)

    // remove - errors
    verifyErr(DuplicateNameErr#) { p.libs.removeAll(["ph.points", "ph.points"]) }
    verifyErr(DependErr#) { p.libs.remove("ph.points") }
    verifyErr(CannotRemoveBootLibErr#) { p.libs.removeAll(["ashrae.g36", "sys"]) }
    verifyEq(pld, p.companion.libDigest)

    // remove g36
    p.libs.remove("ashrae.g36")
    expectLibs.remove("ashrae.g36")
    verifyProjLibs(p, expectLibs)

    // rename specs
    specA = p.companion._rename("SpecA", "NewSpecA")
    verifyEq(specA.qname, "proj::NewSpecA")
    verifyEq(specA.base.qname, "sys::Scalar")
    verifyEq(p.companion._read("NewSpecA"), "Scalar")
    pld = verifyProjSpecs(p, ["NewSpecA", "SpecB"], pld)

    // rename errors
    verifyErr(UnknownSpecErr#) { p.companion._rename("Bad", "NewBad") }
    verifyErr(DuplicateNameErr#) { p.companion._rename("NewSpecA", "SpecB") }
    verifyErr(NameErr#) { p.companion._rename("NewSpecA", "Bad Name") }
    pld = verifyProjSpecs(p, ["NewSpecA", "SpecB"], pld)

    // remove specs
    p.companion._remove("NewSpecA")
    pld = verifyProjSpecs(p, ["SpecB"], pld)

    // re-boot and verify libs were persisted
    p.db.close
    p = HxdSys(boot).init(boot)
    verifyProjLibs(p, expectLibs)
    pld = verifyProjSpecs(p, ["SpecB"], pld)

    // test specs with comments
    src := """
              // this is a comment
              // and another line

              Dict { newOne: Str }

              """
    specA = p.companion._add("SpecAnotherA", src)
    verifyEq(specA.qname, "proj::SpecAnotherA")
    verifyEq(p.companion._read(specA.name), src.splitLines.findAll { !it.isEmpty }.join("\n").trim)
    pld = verifyProjSpecs(p, ["SpecAnotherA", "SpecB"], pld)

    // add new ext
    ext := p.exts.add("hx.shell")
    expectLibs["hx.shell"] = "sys ok"
    expectExts.add("hx.shell")
    verifyProjLibs(p, expectLibs)
    verifyProjExts(p, expectExts)
    verifyEq(ext.web.uri, `/shell/`)
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
              .set("id", Ref("projMeta", proj.meta.dis))
              .set("projMeta", m)
              .set("version", proj.sys.info.version.toStr)
              .set("mod", actual->mod)
    verifyDictEq(actual, expect)
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

    // update foo2 (src only)
    f = proj.companion.updateFunc("foo2", "(a) => a * a")
    verifyEq(eval("foo2(3)"), n(9))
    verifyDictEq(f.metaOwn, Etc.dict3("axon", "(a) => a * a\n", "admin", m, "qux", "foo2"))

    // update foo2 (meta only)
    f = proj.companion.updateFunc("foo2", null, Etc.makeDict(["su":m, "qux":"test 1!"]))
    verifyEq(eval("foo2(4)"), n(16))
    verifyDictEq(f.metaOwn, Etc.dict3("axon", "(a) => a * a\n", "su", m, "qux", "test 1!"))

    // update foo2 (src and meta)
    f = proj.companion.updateFunc("foo2", "(a)=>a+100", Etc.makeDict(["qux":"test 2!"]))
    verifyEq(eval("foo2(4)"), n(104))
    verifyDictEq(f.metaOwn, Etc.dict2("axon", "(a)=>a+100\n", "qux", "test 2!"))

    // update with string containing "----"
    src := "() => \"-----\""
    f = proj.companion.updateFunc("foo2", src)
    verifyEq(eval("foo2()"), "-----")
    verifyDictEq(f.metaOwn, Etc.dict2("axon", src+"\n", "qux", "test 2!"))
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Void dump(Proj p)
  {
    echo("#### $p.name ####")
    echo(p.dir.plus(`ns/libs.txt`).readAllStr)
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

  Str verifyProjSpecs(Proj p, Str[] names, Str oldDigest)
  {
    newDigest := p.companion.libDigest
    Str[] actualNames := p.companion.lib.specs.map |s->Str| { s.name }
    verifyEq(p.companion._list.dup.sort, names.sort)
    verifyEq(actualNames.sort, names.sort)
    names.each |n|
    {
      spec := p.ns.spec("proj::$n")
      verifySame(spec.lib, p.companion.lib)
    }
    return newDigest
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

