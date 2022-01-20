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
const final class ConnPoint : HxConnPoint
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Internal constructor
  internal new make(Conn conn, Dict rec)
  {
    this.connRef   = conn
    this.idRef     = rec.id
    this.configRef = AtomicRef(ConnPointConfig(conn.lib, rec))

// TODO: need to design startup status, fault handling, and conn status merge
    if (fault != null)
      committer.commit3(lib, rec, "curStatus", "fault", "curVal", null, "curErr", fault)
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Parent connector library
  override ConnLib lib() { connRef.lib }

  ** Parent connector
  override Conn conn() { connRef }
  private const Conn connRef

  ** Record id
  override Ref id() { idRef }
  private const Ref idRef

  ** Debug string
  override Str toStr() { "ConnPoint [$id.toZinc]" }

  ** Display name
  Str dis() { config.dis}

  ** Current version of the record.
  ** This dict only represents the current persistent tags.
  ** It does not track transient changes such as 'curVal' and 'curStatus'.
  override Dict rec() { config.rec }

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

  ** Point kind defined by rec 'kind' tag
  Kind kind() { config.kind }

  ** Timezone defined by rec 'tz' tag
  TimeZone tz() { config.tz }

  ** Unit defined by rec 'unit' tag or null
  Unit? unit() { config.unit }

  ** Conn tuning configuration to use for this point
  ConnTuning tuning() { config.tuning ?: conn.tuning }

  ** Current value adjustment defined by rec 'curCalibration' tag
  @NoDoc Number? curCalibration() { config.curCalibration }

  ** Current value conversion if defined by rec 'curConvert' tag
  @NoDoc PointConvert? curConvert() { config.curConvert }

  ** Write value conversion if defined by rec 'writeTag' tag
  @NoDoc PointConvert? writeConvert() { config.writeConvert }

  ** History value conversion if defined by rec 'hisConvert' tag
  @NoDoc PointConvert? hisConvert() { config.hisConvert }

  ** Does the record have the 'disabled' marker configured
  Bool isDisabled() { config.isDisabled }

  ** Fault message if the record has configuration errors
  @NoDoc Str? fault() { config.fault }

  ** Is this point currently in one or more watches
  Bool isWatched() { isWatchedRef.val }
  internal const AtomicBool isWatchedRef := AtomicBool(false)

  ** Conn rec configuration
  internal ConnPointConfig config() { configRef.val }
  private const AtomicRef configRef
  internal Void setConfig(ConnMgr mgr, ConnPointConfig c) { configRef.val = c }

  ** Manages all status commits to this record
  private const ConnCommitter committer := ConnCommitter()

//////////////////////////////////////////////////////////////////////////
// Current Value
//////////////////////////////////////////////////////////////////////////

  ** Update current value and status
  Void updateCurOk(Obj? val)
  {
    s := ConnPointCurState.updateOk(this, val)
    curStateRef.val = s
    updateCurTags(s)
  }

  ** Put point into down/fault/remoteErr with given error.
  Void updateCurErr(Err err)
  {
    s := ConnPointCurState.updateErr(this, err)
    curStateRef.val = s
    updateCurTags(s)
  }

  ** Transition point to stale status
  internal Void updateCurStale()
  {
    s := ConnPointCurState.updateStale(this)
    curStateRef.val = s
    committer.commit1(lib, rec, "curStatus", s.status.name)
  }

  private Void updateCurTags(ConnPointCurState s)
  {
    status := s.status
    val    := null
    err    := null
    config := config
    if (!conn.status.isOk)
    {
      status = conn.status
      err = "conn $status"
    }
    else if (config.isDisabled)
    {
      status = ConnStatus.disabled
      err = "Point is disabled"
    }
    else if (config.fault != null)
    {
      status = ConnStatus.fault
      err = config.fault
    }
    else if (status.isOk)
    {
      val = s.val
    }
    else
    {
      err = ConnStatus.toErrStr(s.err)
    }
    committer.commit3(lib, rec, "curStatus", status.name, "curVal", val, "curErr", err)
  }

  internal Void onConnStatus()
  {
    updateCurTags(curState)
  }

  ** Cur value state storage and handling
  internal ConnPointCurState curState() { curStateRef.val }
  private const AtomicRef curStateRef := AtomicRef(ConnPointCurState.nil)

  internal Bool curQuickPoll { get { false } set {} }  // TODO

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  ** Debug details
  @NoDoc override Str details()
  {
    model := lib.model
    s := StrBuf()
    s.add("""id:             $id
             dis:            $dis
             rt:             $lib.rt.platform.hostModel [$lib.rt.version]
             lib:            $lib.typeof [$lib.typeof.pod.version]
             conn:           $conn.dis [$conn.id]
             kind:           $kind
             tz:             $tz
             unit:           $unit
             tuning:         $tuning.rec.id.toZinc
             isWatched:      $isWatched

             """)

    detailsAddr(s, model.curTag,   curAddr)
    detailsAddr(s, model.writeTag, writeAddr)
    detailsAddr(s, model.hisTag,   hisAddr)

    s.add("\n")
    committer.details(s)

    watches := lib.rt.watch.listOn(id)
    s.add("""
             Watches ($watches.size)
             =============================
             """)
    if (watches.isEmpty) s.add("none\n")
    else watches.each |w|
    {
      s.add(w.dis).add(" (lastRenew: ").add(Etc.debugDur(w.lastRenew.ticks)).add(", lease: ").add(w.lease).add(")\n")
    }

    if (hasCur)
    {
      s.add("""
               Conn Cur
               =============================
               """)
      curState.details(s, this)
    }

    return s.toStr
  }

  private static Void detailsAddr(StrBuf s, Str? tag, Obj? val)
  {
    if (tag == null) return
    s.add("$tag:".padr(16)).add(val == null ? "-" : ZincWriter.valToStr(val)).add("\n")
  }
}

**************************************************************************
** ConnPointConfig
**************************************************************************

** ConnPointConfig models current state of rec dict
internal const final class ConnPointConfig
{
  new make(ConnLib lib, Dict rec)
  {
    model := lib.model

    this.rec  = rec
    this.dis  = rec.dis
    this.tz   = TimeZone.cur
    this.kind = Kind.obj
    try
    {
      this.isDisabled     = rec.has("disabled")
      this.tz             = rec.has("tz") ? FolioUtil.hisTz(rec) : TimeZone.cur
      this.unit           = FolioUtil.hisUnit(rec)
      this.kind           = FolioUtil.hisKind(rec)
      this.tuning         = lib.tunings.forRec(rec)
      this.curAddr        = toAddr(model, rec, model.curTag,   model.curTagType)
      this.writeAddr      = toAddr(model, rec, model.writeTag, model.writeTagType)
      this.hisAddr        = toAddr(model, rec, model.hisTag,   model.hisTagType)
      this.curCalibration = rec["curCalibration"] as Number
      this.curConvert     = toConvert(rec, "curConvert")
      this.writeConvert   = toConvert(rec, "writeConvert")
      this.hisConvert     = toConvert(rec, "hisConvert")
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
  const ConnTuning? tuning
  const Obj? curAddr
  const Obj? writeAddr
  const Obj? hisAddr
  const Number? curCalibration
  const PointConvert? curConvert
  const PointConvert? writeConvert
  const PointConvert? hisConvert
  const Bool isDisabled
  const Str? fault
}