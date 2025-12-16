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
using util::Macro as Macro

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
    user   := (c.rec["username"] as Str)?.trimToNull
    pass   := c.db.passwords.get(c.id.toStr) ?: "<ERROR_NO_PASSWORD>"
    hasPw  := false

    //Support the util::Macro syntax for the uri tag to look up values of tags on the conn record
    //and handle looking up the stored password
    uriStr := Macro(uri.toStr).apply |Str key->Str|{
      if (key == "password")
      {
        hasPw = true
        return pass
      }
      else
      {
        return c.rec[key] ?: "<ERROR_NOT_FOUND>"
      }
    }

    try
    {
      return SqlClient.open(uriStr, user, pass)
    }
    catch (SqlErr e)
    {
      //Some Java SQL error messages include the connection string in the error message
      //which may have the password so this prevents that password from getting diplayed
      //in the user interface
      if (hasPw)
      {
        sanitizedErrMsg := e.traceToStr.replace(pass, "<OBFUSCATED>")
        if (e.msg.contains("Communications link failure")) throw DownErr(sanitizedErrMsg)
        throw SqlErr(sanitizedErrMsg)
      }
      else
      {
        if (e.msg.contains("Communications link failure")) throw DownErr(e.msg, e)
        throw e
      }
    }
  }

  override Str onConnDetails(Conn c)
  {
    rec     := c.rec
    uriVal  := rec["uri"] ?: ``
    uri     := uriVal as Uri ?: ``
    pass    := c.db.passwords.get(c.id.toStr) == null ? "<ERROR_NO_PASSWORD>" : "<OBFUSCATED>"
    uriStr  := Macro(uri.toStr).apply { it == "password" ? pass : (rec[it] ?: "<ERROR_NOT_FOUND>") }
    product := "" + rec["productName"] + " " + rec["productVersion"]
    driver  := "" + rec["driverName"]  + " " + rec["driverVersion"]

    s := StrBuf()
    s.add("""uri:           $uriStr
             uriRaw:        $uri
             product:       $product
             driver:        $driver
             """)
    return s.toStr
  }

}


