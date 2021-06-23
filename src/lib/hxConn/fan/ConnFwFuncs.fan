//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 May 2012  Brian Frank  Creation
//   22 Jun 2021  Brian Frank  Redesign for Haxall
//

using haystack
using axon
using hx

**
** Connector framework functions
**
@NoDoc
const class ConnFwFuncs
{
  @Axon static Obj? connPing(Obj conn) { "Conn ping $conn" }
}