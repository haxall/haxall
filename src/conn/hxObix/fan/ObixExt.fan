//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Feb 2010  Brian Frank  Creation
//    3 Feb 2022  Brian Frank  Redesign for Haxall
//

using web
using hx
using hxConn

**
** Obix connector
**
const class ObixExt : ConnExt
{

  ** Publish server side APIs
  override const ExtWeb web := ObixExtWeb(this)

}

**************************************************************************
** ObixExtWeb
**************************************************************************

**
** ObixExtWeb is used to route to ObixWebMod
**
internal const class ObixExtWeb : ExtWeb
{
  new make(ObixExt ext) : super(ext) {  this.mod = ObixWebMod(ext) }
  const ObixWebMod mod
  override Void onService() { mod.onService }
}

