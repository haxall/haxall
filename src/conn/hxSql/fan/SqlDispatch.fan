//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Apr 2010  Brian Frank  Creation
//   29 Dec 2021  Brian Frank  Redesign for Haxall
//

using hx
using hxConn

**
** Dispatch callbacks for the SQL connector
**
class SqlDispatch : ConnDispatch
{
  ** Constructor with parent connector
  new make(Conn conn)  : super(conn) {}
}


