//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 May 2012  Brian Frank  Creation
//   22 Jun 2021  Brian Frank  Redesign for Haxall
//

using xeto
using haystack
using hx

**
** ConnModel reflects defs to cache the features and tags supported
** for a specific connector type.
**
@NoDoc
const final class ConnModel
{
  ** Construct for given lib
  @NoDoc new make(ConnExt ext)
  {
    this.name = ext.name
    prefix := name

    ns := ext.proj.defs
// TODO
libDef := ext.proj.defs.lib(name)
    connDef := def(ns, ext, "${prefix}Conn")
    features := connDef["connFeatures"] as Dict ?: Etc.emptyDict

    // check tag/func defs
    this.connTag    = connDef.name
    this.connRefTag = def(ns, ext, "${prefix}ConnRef").name
    this.pointTag   = def(ns, ext, "${prefix}Point").name

    // cur tags
    curTagDef := def(ns, ext, "${prefix}Cur", false)
    if (curTagDef != null)
    {
      this.curTag     = curTagDef.name
      this.curTagType = toAddrType(curTagDef)
    }

    // write addr
    writeTagDef := def(ns, ext, "${prefix}Write", false)
    if (writeTagDef != null)
    {
      this.writeTag      = writeTagDef.name
      this.writeTagType  = toAddrType(writeTagDef)
      this.writeLevelTag = def(ns, ext, "${prefix}WriteLevel", false)?.name
    }

    // his addr
    hisTagDef := def(ns, ext, "${prefix}His", false)
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
    this.pollMode  = ConnPollMode.fromStr(features["pollMode"] ?: "disabled")

    // polling tags
    if (pollMode === ConnPollMode.manual)
    {
      pollFreqTagDef := def(ns, ext, "${prefix}PollFreq")
      this.pollFreqTag     = pollFreqTagDef.name
      this.pollFreqDefault = (pollFreqTagDef["val"] as Number)?.toDuration ?: 10sec
    }

    // helper classes
    this.dispatchType = ext.typeof.pod.type(name.capitalize + "Dispatch")

    // dict for features
    f := Str:Obj[:]
    f["name"] = name
    if (hasCur)   f["cur"]   = Marker.val
    if (hasHis)   f["his"]   = Marker.val
    if (hasWrite) f["write"] = Marker.val
    if (hasLearn) f["learn"] = Marker.val
    this.features = Etc.makeDict(f)
  }

  private static Def? def(DefNamespace ns, ConnExt ext, Str symbol, Bool checked := true)
  {
    def := ns.def(symbol, false)
    if (def == null)
    {
      if (checked) throw Err("Missing required def: $symbol")
      return null
    }
// TODO
//    if (def.lib !== ns.lib(ext.name)) throw Err("Def in wrong lib: $symbol [$def.lib != $ext.def]")
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
  const ConnPollMode pollMode

  ** Tag to use for manual poll frequency
  const Str? pollFreqTag

  ** Default poll frequency for manual polling
  const Duration? pollFreqDefault

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

