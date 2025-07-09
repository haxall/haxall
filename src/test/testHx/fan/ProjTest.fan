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
    projLibs := ["ph", "ph.points", "ph.equips", "bad.proj"]
    dir := tempDir
    dir.plus(`ns/libs.txt`).out.print(projLibs.join("\n")).close

    // boot project
    boot := TestProjBoot(tempDir)
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

    // initial libs
    boot.bootLibs.each |n| { verifyProjLib(p, n, "boot") }
    projLibs.each |n| { verifyProjLib(p, n, "enabled") }
  }

  Void verifyProjLib(Proj p, Str n, Str state)
  {
    x := p.libs.get(n)
    // echo("~~ $x.name $x.version $x.state")
    bad := n.startsWith("bad.")
    verifySame(p.libs.list.find { it.name == n }, x)
    verifyEq(x.name, n)
    verifyEq(x.state.name, bad ? "notFound" : state)
    if (!bad)
    {
      lib := p.ns.lib(n)
      verifyEq(p.ns.libStatus(n), LibStatus.ok)
      verifyEq(lib.version, x.version)
    }
    else
    {
      verifyEq(p.ns.lib(n, false), null)
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

