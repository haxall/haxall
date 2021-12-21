//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 May 2012  Brian Frank  Creation
//   22 Jun 2021  Brian Frank  Redesign for Haxall
//

using haystack
using hx

@Js
const final class ConnModel
{

  ** Construct with extension pod
  @NoDoc new make(Namespace ns, Lib lib)
  {
    this.name = lib.name
    prefix := name

    connDef := def(ns, lib, "${prefix}Conn")
    features := connDef["connFeatures"] as Dict ?: Etc.emptyDict

    // check tag/func defs
    this.connTag       = connDef.name
    this.connRefTag    = def(ns, lib, "${prefix}ConnRef").name
    this.curTag        = def(ns, lib, "${prefix}Cur", false)?.name
    this.writeTag      = def(ns, lib, "${prefix}Write", false)?.name
    this.writeLevelTag = def(ns, lib, "${prefix}WriteLevel", false)?.name
    this.hisTag        = def(ns, lib, "${prefix}His", false)?.name

    // features
    this.hasLearn  = features.has("learn")
    this.hasCur    = curTag != null
    this.hasWrite  = writeTag != null
    this.hasHis    = hisTag != null

    // dict for misc
    misc := Str:Obj[:]
    misc["name"] = name
    if (hasCur)   misc["cur"]   = Marker.val
    if (hasHis)   misc["his"]   = Marker.val
    if (hasWrite) misc["write"] = Marker.val
    if (hasLearn) misc["learn"] = Marker.val
    this.misc = Etc.makeDict(misc)
  }

  private static Def? def(Namespace ns, Lib lib, Str symbol, Bool checked := true)
  {
    def := ns.def(symbol, false)
    if (def == null)
    {
      if (checked) throw Err("Missing required def: $symbol")
      return null
    }
    if (def.lib !== lib) throw Err("Def in wrong lib: $symbol [$def.lib != $lib]")
    return def
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Name of the connector such as "foo"
  const Str name

  ** Tag name of the connector such as "fooConn"
  const Str connTag

  ** Tag name of the connector reference such as "fooConnRef"
  const Str connRefTag

  ** Tag name of point's current address such as "fooCur".
  ** This field is null if current values are not supported.
  const Str? curTag

  ** Tag name of point's write address such as "fooWrite".
  ** This field is null if writes are not supported.
  const Str? writeTag

  ** Tag name if connector requires level for pushing write to remote system (bacnet, haystack)
  ** This field is null if writes are not supported or write level is not applicable.
  const Str? writeLevelTag

  ** Tag name of point's history address such as "fooHis"
  ** This field is null if history syncs are not supported.
  const Str? hisTag

  ** Polling strategy to use for connector
  const PollingMode pollingMode := PollingMode.disabled

  ** Encoding for SysNamespace misc entry
  @NoDoc const Dict misc

//////////////////////////////////////////////////////////////////////////
// Support
//////////////////////////////////////////////////////////////////////////

  ** Does this connector support learn such as "fooLearn"
  const Bool hasLearn

  ** Does this connector support current value subscription
  const Bool hasCur

  ** Does this connector support writable points
  const Bool hasWrite

  ** Does this connector support history synchronization
  const Bool hasHis
}

**************************************************************************
** PollingMode
**************************************************************************

**
** The polling modes supported by the connector framework
**
@Js
enum class PollingMode
{
  ** Disable polling
  disabled,

  ** The connector implementation handles all polling logic
  manual,

  ** The connector framework handles the polling logic and utilizes
  ** a "poll buckets" strategy.
  buckets

  ** Return 'true' if the mode is not `disabled`.
  Bool isPollingEnabled() { this !== disabled }
}


