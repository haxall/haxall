//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Jan 2012  Brian Frank  Creation
//   17 Jul 2012  Brian Frank  Move to connExt framework
//   02 Oct 2012  Brian Frank  New Haystack 2.0 REST API
//   29 Dec 2021  Brian Frank  Redesign for Haxall
//

using haystack
using hxConn

**
** Dispatch callbacks for the Haystack connector
**
class HaystackDispatch : ConnDispatch
{
  new make(Conn conn)  : super(conn) {}

  override Void onOpen()
  {
    // gather configuration
    uriVal := rec["uri"] ?: throw FaultErr("Missing 'uri' tag")
    uri    := uriVal as Uri ?: throw FaultErr("Type of 'uri' must be Uri, not $uriVal.typeof.name")
    user   := rec["username"] as Str ?: ""
    pass   := db.passwords.get(id.toStr) ?: ""

    // open client
    opts := ["log":this.log, "timeout":conn.timeout]
    client = Client.open(uri, user, pass, opts)
  }

  override Void onClose()
  {
    client = null
    // TODO
    //watchClear
  }

  override Dict onPing()
  {
    // call "about" operation
    about := client.about

    // update tags
    tags := Str:Obj[:]
    if (about["productName"]    is Str) tags["productName"]    = about->productName
    if (about["productVersion"] is Str) tags["productVersion"] = about->productVersion
    if (about["moduleName"]     is Str) tags["moduleName"]     = about->moduleName
    if (about["moduleVersion"]  is Str) tags["moduleVersion"]  = about->moduleVersion
    about.each |v, n| { if (n.startsWith("host")) tags[n] = v }

    // update tz
    tzStr := about["tz"] as Str
    if (tzStr != null)
    {
      tz := TimeZone.fromStr(tzStr, false)
      if (tz != null) tags["tz"] = tz.name
    }

    return Etc.makeDict(tags)
  }

  private Client? client
}


