//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Feb 2025  Brian Frank  Creation
//

using concurrent
using inet
using haystack
using auth
using axon
using hx

**
** Api4Test tests Haxall 4.x Xeto based APIs defined by Haystack 5.0
**
class Api4Test : ApiTest
{
  @HxRuntimeTest
  Void test()
  {
    init
    doPing
    cleanup
  }


  Void doPing()
  {
    verifyPing(a)
    verifyPing(b)
    verifyPing(c)
  }

  private Void verifyPing(Client c)
  {
    str := c.toWebClient(`sys/ping`).getStr
echo(str)
  }

}

