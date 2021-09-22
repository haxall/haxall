//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Dec 2015  Brian Frank  Creation
//   22 Sep 2021  Brian Frank  Port to Haxall
//

using axon
using haystack
using hx

**
** HTTP module functions
**
const class HttpFuncs
{
  ** Primary HTTP or HTTPS Uri - see `hx::HxHttpService.siteUri`
  @Axon
  static Uri httpSiteUri() { curContext.rt.http.siteUri }

  ** Current context
  private static HxContext curContext() { HxContext.curHx }

}