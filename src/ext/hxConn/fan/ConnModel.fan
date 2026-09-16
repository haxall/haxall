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
using pi

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
    // reflect specs via PiConn
    pi := PiConn(ext.rt.ns, ext.spec)

    // tag names from specs
    this.name          = pi.name
    this.connTag       = pi.conn.name.decapitalize
    this.connRefTag    = pi.connRefSlot.name
    this.pointTag      = pi.point.name.decapitalize
    this.curTag        = pi.curSlot?.name
    this.writeTag      = pi.writeSlot?.name
    this.writeLevelTag = pi.writeLevelSlot?.name
    this.hisTag        = pi.hisSlot?.name

    // expected fantom types for address tags
    this.curTagType   = toAddrType(pi.curSlot)
    this.writeTagType = toAddrType(pi.writeSlot)
    this.hisTagType   = toAddrType(pi.hisSlot)

    // features
    this.hasLearn = pi.hasLearn
    this.hasCur   = pi.hasCur
    this.hasWrite = pi.hasWrite
    this.hasHis   = pi.hasHis
    this.pollMode = ConnPollMode.fromStr(pi.features["pollMode"] ?: "disabled")
    this.icon3    = ext.spec.lib.name.startsWith("hx.") ? name : "conn"

    // polling tags
    if (pollMode === ConnPollMode.manual)
    {
      this.pollFreqTag     = pi.pollFreqSlot.name
      this.pollFreqDefault = Etc.dictGetDuration(pi.pollFreqSlot.meta, "val", 10sec)
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

  private static Type? toAddrType(Spec? spec)
  {
    spec?.type?.fantomType
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

  ** Legacy icon name for Fresco UI
  const Str icon3

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

