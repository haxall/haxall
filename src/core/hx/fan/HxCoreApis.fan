//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Feb 2025  Brian Frank  Creation
//

using web
using haystack

**
** Standard HTTP API implementations
**
@NoDoc
class HxCoreApis
{
  ** Implementation of 'sys.api::ping'
  @HxApi static Dict ping(HxApiReq req)
  {
    Etc.dict1("time", DateTime.now)
  }

  ** Implementation of 'hx.api::eval'
  @HxApi static Obj? eval(HxApiReq req)
  {
    req.context.eval(req.args->expr)
  }
}

