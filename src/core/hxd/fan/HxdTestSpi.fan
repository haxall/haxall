//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 May 2021  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio
using hx
using hxm

**
** Haxall daemon HxTest service provider implementation
**
class HxdTestSpi : HxTestSpi
{
  new make(HxTest test) : super(test) {}

  static Proj boot(File dir, Bool create, Dict projMeta := Etc.dict0)
  {
    boot := HxdBoot
    {
      it.name = "test"
      it.dir = dir
      it.createProjMeta = Etc.dictToMap(projMeta)
      it.sysConfig["test"] = Marker.val
      it.sysConfig["platformSerialSpi"] = "hxPlatformSerial::TestSerialSpi"
      it.bootLibs.remove("hx.http")
      it.log.level = LogLevel.warn
    }
    if (create) { dir.delete; boot.create }
    return boot.load.start
  }

  override Proj start(Dict projMeta)
  {
    boot(test.tempDir, true, projMeta)
  }

  override Void stop(Proj proj)
  {
    ((HxProj)proj).stop
  }

  override Proj restart(Proj proj)
  {
    stop(proj)
    return boot(proj.dir, false)
  }

  override Void addLib(Str libName)
  {
    // solve depends we need to enable too
    depends := proj.ns.env.repo.solveDepends([LibDepend(libName)])
    libNames := depends.map |d->Str| { d.name }
    proj.libs.addAll(libNames)
  }

  override Ext addExt(Str libName, Str:Obj? tags)
  {
    // solve depends we need to enable too (but not the ext itself)
    depends := proj.ns.env.repo.solveDepends([LibDepend(libName)])
    libNames := depends.map |d->Str| { d.name }
    libNames.remove(libName)

    // then add ext
    ext := proj.exts.add(libName, Etc.makeDict(tags))
    ext.spi.sync
    return ext
  }

  override HxUser addUser(Str user, Str pass, Str:Obj? tags)
  {
    Slot.findMethod("hxUser::HxUserUtil.addUser").call(test.proj.db, user, pass, tags)
  }

  override Context makeContext(User? user)
  {
    if (user == null)
      user = test.proj.sys.user.makeSyntheticUser("test", ["userRole":"su"])
    return Context(test.proj, user)
  }

  override Void forceSteadyState()
  {
    ((HxProj)proj).backgroundMgr.forceSteadyState
  }

  Proj proj() { test.proj }
}

