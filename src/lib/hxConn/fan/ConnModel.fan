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

@NoDoc
const final class ConnModel
{
  ** Construct for given lib
  @NoDoc new make(ConnLib lib)
  {
    this.name = lib.name
    prefix := name

    ns := lib.rt.ns
    libDef := lib.def
    connDef := def(ns, lib, "${prefix}Conn")
    features := connDef["connFeatures"] as Dict ?: Etc.emptyDict

    // check tag/func defs
    this.connTag    = connDef.name
    this.connRefTag = def(ns, lib, "${prefix}ConnRef").name
    this.pointTag   = def(ns, lib, "${prefix}Point").name

    // cur tags
    curTagDef := def(ns, lib, "${prefix}Cur", false)
    if (curTagDef != null)
    {
      this.curTag     = curTagDef.name
      this.curTagType = toAddrType(curTagDef)
    }

    // write addr
    writeTagDef := def(ns, lib, "${prefix}Write", false)
    if (writeTagDef != null)
    {
      this.writeTag      = writeTagDef.name
      this.writeTagType  = toAddrType(writeTagDef)
      this.writeLevelTag = def(ns, lib, "${prefix}WriteLevel", false)?.name
    }

    // his addr
    hisTagDef := def(ns, lib, "${prefix}His", false)
    if (hisTagDef != null)
    {
      this.hisTag     = hisTagDef.name
      this.hisTagType = toAddrType(hisTagDef)
    }

    // features
    this.hasLearn  = features.has("learn")
    this.hasCur    = curTag != null
    this.hasWrite  = writeTag != null
    this.hasHis    = hisTag != null

    // helper classes
    this.dispatchType = lib.typeof.pod.type(name.capitalize + "Dispatch")

    // dict for features
    f := Str:Obj[:]
    f["name"] = name
    if (hasCur)   f["cur"]   = Marker.val
    if (hasHis)   f["his"]   = Marker.val
    if (hasWrite) f["write"] = Marker.val
    if (hasLearn) f["learn"] = Marker.val
    this.features = Etc.makeDict(f)
  }

  private static Def? def(Namespace ns, ConnLib lib, Str symbol, Bool checked := true)
  {
    def := ns.def(symbol, false)
    if (def == null)
    {
      if (checked) throw Err("Missing required def: $symbol")
      return null
    }
    if (def.lib !== lib.def) throw Err("Def in wrong lib: $symbol [$def.lib != $lib]")
    return def
  }

  private static Type toAddrType(Def def)
  {
    symbol := ((Symbol[])def["is"])[0].name
    if (symbol == "str") return Str#
    if (symbol == "uri") return Uri#
    throw Err("Unsupported point address type: $symbol")
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

  ** Tag name for points such as "fooPoint"
  const Str pointTag

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

  ** Expected cur tag type
  const Type? curTagType

  ** Expected write tag type
  const Type? writeTagType

  ** Expected history tag type
  const Type? hisTagType

  ** Polling strategy to use for connector
  const PollingMode pollingMode := PollingMode.disabled

  ** Dispatch subclass
  const Type dispatchType

  ** Dict encoding for HxConn.connFeature
  const Dict features

//////////////////////////////////////////////////////////////////////////
// Support
//////////////////////////////////////////////////////////////////////////

  ** Does this connector support learning to walk remote "tree"
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


