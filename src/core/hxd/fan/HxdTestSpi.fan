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

  static HxRuntime boot(Test test)
  {
    boot := HxdBoot
    {
      it.dir = test.tempDir
      it.create = true
      it.requiredLibs.remove("hxHttp")
      it.log.level = LogLevel.warn
    }
    return  boot.init.start
  }

  override HxRuntime start()
  {
    boot(test)
  }

  override Void stop(HxRuntime rt)
  {
    ((HxdRuntime)rt).stop
  }

  override HxUser addUser(Str user, Str pass, Str:Obj? tags)
  {
    Slot.findMethod("hxUser::HxUserUtil.addUser").call(test.rt.db, user, pass, tags)
  }

  override HxContext makeContext(HxUser? user)
  {
    if (user == null)
    {
      tags := Etc.makeDict3("id", Ref("test-user"), "username", "test", "userRole", "su")
      user = Type.find("hxUser::HxUserImpl").make([tags])
    }
    return HxdContext(test.rt, user)
  }
}

