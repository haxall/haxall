//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//

using hx

**
** Haystack HTTP API service handling
**
const class HxdApiLib : HxdLib
{
  override const HxdApiWeb web := HxdApiWeb(this)
}

**************************************************************************
** HxdApiLibWeb
**************************************************************************

**
** HTTP API web service handling
**
const class HxdApiWeb : HxLibWeb
{
  new make(HxdApiLib lib) : super(lib) { this.lib = lib }

  override const HxdApiLib lib

  override Void onService()
  {
    cx := rt.users.authenticate(req, res)
echo("-- authenticate cx=$cx")
    if (cx == null) return

    res.statusCode = 200
    res.headers["Content-Type"] = "text/plain"
    res.out.print("API web handling is alive!")
  }
}



