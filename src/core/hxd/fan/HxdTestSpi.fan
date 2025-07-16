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

  static Proj boot(File dir, Dict projMeta := Etc.dict0)
  {
if (!projMeta.isEmpty) throw Err("TODO")
    dir.delete
    boot := HxdBoot
    {
      it.name = "test"
      it.dir = dir
//      it.projMeta = projMeta
      it.config["test"] = Marker.val
      it.config["platformSerialSpi"] = "hxPlatformSerial::TestSerialSpi"
      it.bootLibs.remove("http")
      it.log.level = LogLevel.warn
    }
    return boot.create.load.start
  }

  override Proj start(Dict projMeta)
  {
    boot(test.tempDir, projMeta)
  }

  override Void stop(Proj rt)
  {
    ((HxProj)rt).stop
  }

  override Ext addLib(Str libName, Str:Obj? tags)
  {
echo("XXXX TEST $libName")
throw Err("TODO")
/*
    rt := (HxProj)test.rt
    x := rt.libsOld.get(libName, false)
    if (x != null) return x
    lib := rt.installed.lib(libName)
    lib.depends.each |d| { addLib(d, Str:Obj[:]) }
    return rt.libsOld.add(libName, Etc.makeDict(tags))
*/
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

  override Void forceSteadyState(Proj rt)
  {
throw Err("TODO")
//    ((HxProj)test.rt).backgroundMgr.forceSteadyState
  }
}

