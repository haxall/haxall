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
** ConnModel reflects specs to cache the features and tags supported
** for a specific connector type.
**
@NoDoc
const final class ConnModel
{
  ** Construct for given lib
  @NoDoc new make(ConnExt ext)
  {
    // simplify the hx.foo name to just foo
    this.name = ext.modelName
    prefix := name

    // infer tag names from prefix
    this.connTag    = prefix + "Conn"
    this.connRefTag = this.connTag + "Ref"
    this.pointTag   = prefix + "Point"

    // lookup key required specs
    ns := ext.rt.ns
    lib := ext.spec.lib
    connSpec  := lib.type(connTag.capitalize)
    pointSpec := lib.type(pointTag.capitalize)
    features  := ext.spec.meta["connFeatures"] as Dict ?: throw Err("Must define connFeatures meta on $ext.spec")

    // cur tags
    curTagSpec := pointSpec.slot("${prefix}Cur", false)
    if (curTagSpec != null)
    {
      this.curTag     = curTagSpec.name
      this.curTagType = toAddrType(curTagSpec)
    }

    // write addr
    writeTagSpec := pointSpec.slot("${prefix}Write", false)
    if (writeTagSpec != null)
    {
      this.writeTag      = writeTagSpec.name
      this.writeTagType  = toAddrType(writeTagSpec)
      this.writeLevelTag = pointSpec.slot("${prefix}WriteLevel", false)?.name
    }

    // his addr
    hisTagSpec := pointSpec.slot("${prefix}His", false)
    if (hisTagSpec != null)
    {
      this.hisTag     = hisTagSpec.name
      this.hisTagType = toAddrType(hisTagSpec)
    }

    // features
    this.hasLearn  = features.has("learn")
    this.hasCur    = curTag   != null
    this.hasWrite  = writeTag != null
    this.hasHis    = hisTag   != null
    this.pollMode  = ConnPollMode.fromStr(features["pollMode"] ?: "disabled")
    this.icon      = features["icon"]?.toStr ?: (connSpec.lib.name.startsWith("hx.") ? name : "conn")

    // polling tags
    if (pollMode === ConnPollMode.manual)
    {
      pollFreqTagSpec := connSpec.slot("${prefix}PollFreq")
      this.pollFreqTag     = pollFreqTagSpec.name
      this.pollFreqDefault = Etc.dictGetDuration(pollFreqTagSpec.meta, "val", 10sec)
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

  private static Type toAddrType(Spec spec)
  {
    spec.type.fantomType
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

  ** Icon name
  const Str icon

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

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  ** Debug dump
  Void dump()
  {
    typeof.fields.each |f|
    {
      if (!f.isStatic) echo("$f.name: " + f.get(this))
    }
  }
}

