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

  override HxRuntime start()
  {
    boot := HxdBoot
    {
      it.dir = test.tempDir
      it.create = true
    }
    return boot.init.start
  }

  override Void stop(HxRuntime rt)
  {
    ((HxdRuntime)rt).stop
  }
}

