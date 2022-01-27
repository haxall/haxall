//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 May 2021  Brian Frank  Creation
//

using concurrent
using haystack
using folio
using hx

**
** Haxall daemon HxTest service provider implementation
**
class HxdTestSpi : HxTestSpi
{
  new make(HxTest test) : super(test) {}

  static HxRuntime boot(File dir, Dict projMeta := Etc.emptyDict)
  {
    boot := HxdBoot
    {
      it.dir = dir
      it.projMeta = projMeta
      it.create = true
      it.config["test"] = Marker.val
      it.config["serialSpi"] = "hxSerial::TestSerialSpi"
      it.requiredLibs.remove("http")
      it.log.level = LogLevel.warn
    }
    return boot.init.start
  }

  override HxRuntime start(Dict projMeta)
  {
    boot(test.tempDir, projMeta)
  }

  override Void stop(HxRuntime rt)
  {
    ((HxdRuntime)rt).stop
  }

  override HxLib addLib(Str libName, Str:Obj? tags)
  {
    rt := (HxdRuntime)test.rt
    if (rt.lib(libName, false) != null) return rt.lib(libName)
    lib := rt.installed.lib(libName)
    lib.depends.each |d| { addLib(d, Str:Obj[:]) }
    return rt.libs.add(libName, Etc.makeDict(tags))
  }

  override HxUser addUser(Str user, Str pass, Str:Obj? tags)
  {
    Slot.findMethod("hxUser::HxUserUtil.addUser").call(test.rt.db, user, pass, tags)
  }

  override HxContext makeContext(HxUser? user)
  {
    if (user == null)
      user = test.rt.user.makeSyntheticUser("test", ["userRole":"su"])
    return HxdContext(test.rt, user)
  }

  override Void forceSteadyState(HxRuntime rt)
  {
    ((HxdRuntime)test.rt).backgroundMgr.forceSteadyState
  }
}

