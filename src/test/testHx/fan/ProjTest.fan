//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Jul 2025 Brian Frank  Creation for new 4.0 design
//

using concurrent
using xeto
using haystack
using folio
using hx
using hx4
using hxm
using hxFolio

**
** ProjTest
**
class ProjTest : HxTest
{

  Void test()
  {
    // setup
    projLibs := ["ph", "ashrae.g36", "bad.proj"]
    dir := tempDir
    dir.plus(`ns/libs.txt`).out.print(projLibs.join("\n")).close

    // boot project
    boot := TestProjBoot(tempDir)
    bootLibs := boot.bootLibs
    p := boot.init

    // verify initial state
    verifyEq(p.name, boot.name)
    verifyRefEq(p.id, Ref("p:$boot.name", boot.name))
    verifyEq(p.dir, dir)
    verifyEq(p.isRunning, false)
    verifyEq(p.meta->projMeta, Marker.val)
    verifyEq(p.meta->version, boot.version.toStr)
    verifySame(p.meta, p.readById(p.meta.id))
    verifySame(p.meta, p.read("projMeta"))
    verifyProjLibs(p, bootLibs, projLibs, ["ashrae.g36"])

    // add lib already there, add empty list
    p.libs.add("ph")
    p.libs.addAll(Str[,])
    verifyProjLibs(p, bootLibs, projLibs, ["ashrae.g36"])

    // add - verify errors
    verifyErr(DuplicateNameErr#) { p.libs.addAll(["ph.points", "ph.points"]) }
    verifyErr(UnknownLibErr#) { p.libs.add("bad.bad.bad") }
    verifyErr(DependErr#) { p.libs.add("hx.test.xeto") }

    // add new lib 'ph.points' which fills 'g36' depend
    p.libs.add("ph.points")
    projLibs.add("ph.points")
    verifyProjLibs(p, bootLibs, projLibs, [,])

    // re-boot project and verify libs were persisted
    p.db.close
    p = TestProjBoot(tempDir).init
    verifyProjLibs(p, bootLibs, projLibs, [,])
    //dumpLibs(p)

    // remove - errors
    verifyErr(DuplicateNameErr#) { p.libs.removeAll(["ph.points", "ph.points"]) }
    verifyErr(DependErr#) { p.libs.remove("ph.points") }
    verifyErr(CannotRemoveBootLibErr#) { p.libs.removeAll(["ashrae.g36", "sys"]) }

    // remove g36
    p.libs.remove("ashrae.g36")
    projLibs.remove("ashrae.g36")

    // re-boot and verify libs were persisted
    p.db.close
    p = TestProjBoot(tempDir).init
    verifyProjLibs(p, bootLibs, projLibs, [,])
  }

  Void dumpLibs(Proj p)
  {
    echo(p.dir.plus(`ns/libs.txt`).readAllStr)
    p.libs.status.dump
    p.ns.dump
  }

  Void verifyProjLibs(Proj p, Str[] bootLibs, Str[] projLibs, Str[] errs)
  {
    bootLibs.each |n|
    {
      s := n.startsWith("bad.") ? "notFound" : "ok"
      if (errs.contains(n)) s = "err"
      verifyProjLib(p, n, true, s)
    }

    projLibs.each |n|
    {
      s := n.startsWith("bad.") ? "notFound" : "ok"
      if (errs.contains(n)) s = "err"
      verifyProjLib(p, n, false, s)
    }
  }

  Void verifyProjLib(Proj p, Str n, Bool isBoot, Str status)
  {
    x := p.libs.get(n)
    // echo("~~ $x.name [$x.status]  $x.err")
    verifySame(p.libs.list.find { it.name == n }, x)
    verifyEq(x.name, n)
    verifyEq(x.isBoot, isBoot)
    verifyEq(x.status.name, status)
    if (status == "ok")
    {
      lib := p.ns.lib(n)
      verifyEq(p.ns.libStatus(n), LibStatus.ok)
      verifyEq(x.version, lib.version)
      verifyEq(x.doc, p.ns.version(n).doc)
    }
    else
    {
      verifyEq(p.ns.lib(n, false), null)
      verifyNotNull(x.err)
    }
  }
}

**************************************************************************
** TestProjBoot
**************************************************************************

class TestProjBoot : ProjBoot
{
  new make(File dir) : super("test", dir) {}

  override const Log log := Log.get("test")

  override const Version version := Version("1.2.3")

  override Str[] bootLibs()
  {
    super.bootLibs.dup.addAll(["bad.boot"])
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

