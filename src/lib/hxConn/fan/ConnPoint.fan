//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 May 2012  Brian Frank  Creation
//   22 Jun 2021  Brian Frank  Redesign for Haxall
//

using concurrent
using haystack
using folio
using hx
using hxPoint

**
** ConnPoint models a point within a connector.
**
const final class ConnPoint
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Internal constructor
  internal new make(Conn conn, Dict rec)
  {
    this.connRef   = conn
    this.idRef     = rec.id
    this.configRef = AtomicRef(ConnPointConfig(conn.lib.model, rec))
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Parent connector
  Conn conn() { connRef }
  private const Conn connRef

  ** Record id
  Ref id() { idRef }
  private const Ref idRef

  ** Debug string
  override Str toStr() { "ConnPoint [$id.toZinc]" }

  ** Display name
  Str dis() { config.dis}

  ** Current version of the record
  Dict rec() { config.rec }

  ** Current address tag value if configured on the point
  Obj? curAddr() { config.curAddr }

  ** Write address tag value if configured on the point
  Obj? writeAddr() { config.writeAddr }

  ** History address tag value if configured on the point
  Obj? hisAddr() { config.hisAddr }

  ** Is current address supported on this point
  Bool hasCur() { config.curAddr != null }

  ** Is write address supported on this point
  Bool hasWrite() { config.writeAddr != null }

  ** Is history address supported on this point
  Bool hasHis() { config.hisAddr != null }

  ** Timezone defined by rec 'tz' tag
  TimeZone tz() { config.tz }

  ** Point kind defined by rec 'kind' tag
  Kind kind() { config.kind }

  ** Unit defined by rec 'unit' tag or null
  Unit? unit() { config.unit }

  ** Current value conversion if defined by rec 'curConvert' tag
  @NoDoc PointConvert? curConvert() { config.curConvert }

  ** Write value conversion if defined by rec 'writeTag' tag
  @NoDoc PointConvert? writeConvert() { config.writeConvert }

  ** History value conversion if defined by rec 'hisConvert' tag
  @NoDoc PointConvert? hisConvert() { config.hisConvert }

  ** Fault message if the record has configuration errors
  @NoDoc Str? fault() { config.fault }

  ** Conn rec configuration
  internal ConnPointConfig config() { configRef.val }
  private const AtomicRef configRef

//////////////////////////////////////////////////////////////////////////
// Lifecycle
//////////////////////////////////////////////////////////////////////////

  ** Called then record is modified
  internal Void onUpdated(Dict newRec)
  {
    configRef.val = ConnPointConfig(conn.lib.model, newRec)
  }

}

**************************************************************************
** ConnPointConfig
**************************************************************************

** ConnPointConfig models current state of rec dict
internal const class ConnPointConfig
{
  new make(ConnModel model, Dict rec)
  {
    this.rec  = rec
    this.dis  = rec.dis
    this.tz   = TimeZone.cur
    this.kind = Kind.obj
    try
    {
      this.tz           = FolioUtil.hisTz(rec)
      this.unit         = FolioUtil.hisUnit(rec)
      this.kind         = FolioUtil.hisKind(rec)
      this.curAddr      = toAddr(model, rec, model.curTag,   model.curTagType)
      this.writeAddr    = toAddr(model, rec, model.writeTag, model.writeTagType)
      this.hisAddr      = toAddr(model, rec, model.hisTag,   model.hisTagType)
      this.curConvert   = toConvert(rec, "curConvert")
      this.writeConvert = toConvert(rec, "writeConvert")
      this.hisConvert   = toConvert(rec, "hisConvert")
    }
    catch (Err e)
    {
      this.fault = e.msg
    }
  }

  private static Obj? toAddr(ConnModel model, Dict rec, Str? tag, Type? type)
  {
    if (tag == null) return null
    val := rec[tag]
    if (val == null) return null
    if (val.typeof !== type) throw Err("Invalid type for '$tag' [$val.typeof.name != $type.name]")
    return val
  }

  private static PointConvert? toConvert(Dict rec, Str tag)
  {
    str := rec[tag]
    if (str == null) return null
    if (str isnot Str) throw Err("Point convert not string: '$tag'")
    if (str.toStr.isEmpty) return null
    return PointConvert(str, false) ?: throw Err("Point convert invalid: '$tag'")
  }

  const Dict rec
  const Str dis
  const TimeZone tz
  const Unit? unit
  const Kind? kind
  const Obj? curAddr
  const Obj? writeAddr
  const Obj? hisAddr
  const PointConvert? curConvert
  const PointConvert? writeConvert
  const PointConvert? hisConvert
  const Str? fault
}