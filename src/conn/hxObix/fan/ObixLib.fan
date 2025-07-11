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
const class ObixLib : ConnLib
{

  ** Publish server side APIs
  override const ExtWeb web := ObixLibWeb(this)

}

**************************************************************************
** ObixLibWeb
**************************************************************************

**
** ObixLibWeb is used to route to ObixWebMod
**
internal const class ObixLibWeb : ExtWeb
{
  new make(ObixLib lib) : super(lib) {  this.mod = ObixWebMod(lib) }
  const ObixWebMod mod
  override Void onService() { mod.onService }
}

