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
const class SqlExt : ConnExt
{
  static SqlClient doOpen(Conn c)
  {
    // gather configuration
    rec    := c.rec
    uriVal := rec["uri"] ?: throw FaultErr("Missing 'uri' tag")
    uri    := uriVal as Uri ?: throw FaultErr("Type of 'uri' must be Uri, not $uriVal.typeof.name")
    user   := (rec["username"] as Str)?.trimToNull
    pass   := getPassword(c)
    uriStr := getUriStr(c)

    try
    {
      return SqlClient.open(uriStr, user, pass)
    }
    catch (SqlErr e)
    {
      //Some Java SQL error messages include the connection string in the error message
      //which may have the password so this prevents that password from getting diplayed
      //in the user interface
      if (Macro(uri.toStr).keys.contains("password"))
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
    uriStr  := getUriStr(c, true)
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

  private static Str getPassword(Conn c) { c.db.passwords.get(c.id.toStr) ?: "" }

  //Support the util::Macro syntax for the uri tag to look up values of tags on the conn record
  //and handle looking up the stored password
  private static Str getUriStr(Conn c, Bool obfuscatePw := false)
  {
    rec := c.rec
    uri := (rec["uri"] as Uri) ?: ``
    return Macro(uri.toStr).apply |Str key->Str| {
      if (key == "password")
      {
        pass := getPassword(c)
        return obfuscatePw ? (pass.trimToNull == null ? "<ERROR_NO_PASSWORD>" : "<OBFUSCATED>") : pass
      }
      else
      {
        return rec[key] ?: "<ERROR_NOT_FOUND>"
      }
    }
  }
}

