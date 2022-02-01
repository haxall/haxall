//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Apr 2010  Brian Frank  Creation
//   23 Jun 2021  Brian Frank  Redesign for Haxall
//

using sql::SqlConn as SqlClient
using sql::SqlErr
using haystack
using hx
using hxConn

**
** SQL connector library
**
const class SqlLib : ConnLib
{
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

  override Str onConnDetails(Conn c)
  {
    rec     := c.rec
    uri     := rec["uri"]
    product := "" + rec["productName"] + " " + rec["productVersion"]
    driver  := "" + rec["driverName"]  + " " + rec["driverVersion"]

    s := StrBuf()
    s.add("""uri:           $uri
             product:       $product
             driver:        $driver
             """)
    return s.toStr
  }
}


