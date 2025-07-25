//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Dec 2015  Brian Frank  Creation
//   22 Sep 2021  Brian Frank  Port to Haxall
//

using xeto
using axon
using haystack
using hx

**
** HTTP module functions
**
const class HttpFuncs
{
  ** Primary HTTP or HTTPS Uri - see `hx::HxHttpService.siteUri`
  @Api @Axon
  static Uri httpSiteUri() { curContext.sys.http.siteUri }

  ** Current context
  private static Context curContext() { Context.cur }

}

