//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Apr 2010  Brian Frank  Creation
//   29 Dec 2021  Brian Frank  Redesign for Haxall
//

using haystack
using hx
using hxConn
using sql::SqlConn as SqlClient
using sql::SqlErr

**
** Dispatch callbacks for the SQL connector
**
class SqlDispatch : ConnDispatch
{
  new make(Obj arg) : super(arg) {}

  static SqlClient doOpen(Conn c)
  {
    // gather configuration
    uriVal := c.rec["uri"] ?: throw FaultErr("Missing 'uri' tag")
    uri    := uriVal as Uri ?: throw FaultErr("Type of 'uri' must be Uri, not $uriVal.typeof.name")
    user   := c.rec["username"] as Str ?: ""
    pass   := c.db.passwords.get(c.id.toStr) ?: ""

    try
    {
      return SqlClient.open(uri.toStr, user, pass)
    }
    catch (SqlErr e)
    {
      if (e.msg.contains("Communications link failure")) throw DownErr(e.msg, e)
      throw e
    }
  }

  override Void onOpen()
  {
    this.client = doOpen(conn)
  }

  override Void onClose()
  {
    client.close
    client = null
  }

  override Dict onPing()
  {
    meta := client.meta
    tags := Str:Obj[:]
    tags["productName"]    = meta.productName
    tags["productVersion"] = meta.productVersionStr
    tags["driverName"]     = meta.driverName
    tags["driverVersion"]  = meta.driverVersionStr
    return Etc.makeDict(tags)
  }

  private SqlClient? client
}


