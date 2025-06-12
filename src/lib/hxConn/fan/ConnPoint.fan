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
    this.isWatchedRef.val = conn.rt.watch.isWatched(id)
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

  ** Is current address enabled on this point.
  ** This returns true only when all the of following conditions are met:
  ** - the connector supports current values
  ** - this point has a cur address tag configured
  ** - the address tag value is of the proper type
  ** - the point is not disabled
  Bool isCurEnabled() { config.isCurEnabled }

  ** Is write address enabled on this point.
  ** This returns true only when all the of following conditions are met:
  ** - the connector supports writable points
  ** - this point has a write address tag configured
  ** - the address tag value is of the proper type
  ** - the point is not disabled
  Bool isWriteEnabled() { config.isWriteEnabled }

  ** Is history address supported on this point.
  ** This returns true only when all the of following conditions are met:
  ** - the connector supports history synchronization
  ** - this point has a his address tag configured
  ** - the address tag value is of the proper type
  ** - the point is not disabled
  Bool isHisEnabled() { config.isHisEnabled }

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

  ** Is the record missing 'disabled' marker configured
  Bool isEnabled() { !config.isDisabled }

  ** Does the record have the 'disabled' marker configured
  Bool isDisabled() { config.isDisabled }

  ** Is this point currently in one or more watches
  Bool isWatched() { isWatchedRef.val }
  internal const AtomicBool isWatchedRef := AtomicBool(false)

  ** Library specific point data.  This value is managed by the
  ** connector actor via `ConnDispatch.setPointData`.
  Obj? data() { dataRef.val }
  private const AtomicRef dataRef := AtomicRef()
  internal Void setData(ConnMgr mgr, Obj? val) { dataRef.val = val }

  ** Conn rec configuration
  internal ConnPointConfig config() { configRef.val }
  private const AtomicRef configRef
  internal Void setConfig(ConnMgr mgr, ConnPointConfig c) { configRef.val = c }

  ** Manages all status commits to this record
  private const ConnCommitter committer := ConnCommitter()

//////////////////////////////////////////////////////////////////////////
// Current Value State
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

  ** Set or clear the quick poll flag
  internal Void updateCurQuickPoll(Bool quickPoll)
  {
    curStateRef.val = ConnPointCurState.updateQuickPoll(this, quickPoll)
  }

  ** Update curStatus, curVal, curErr
  private Void updateCurTags(ConnPointCurState s)
  {
    status := s.status
    val    := null
    err    := null
    config := config
    if (config.curFault != null)
    {
      status = ConnStatus.fault
      err = config.curFault
    }
    else if (config.isDisabled)
    {
      status = ConnStatus.disabled
      err = "Point is disabled"
    }
    else if (!conn.status.isOk)
    {
      status = conn.status
      err = "conn $status"
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

  ** Cur value state storage and handling
  internal ConnPointCurState curState() { curStateRef.val }
  private const AtomicRef curStateRef := AtomicRef(ConnPointCurState.nil)

//////////////////////////////////////////////////////////////////////////
// Write State
//////////////////////////////////////////////////////////////////////////

  ** Update write value and status
  Void updateWriteOk(ConnWriteInfo info)
  {
    s := ConnPointWriteState.updateOk(this, info)
    writeStateRef.val = s
    updateWriteTags(s)
  }

  ** Update write status down/fault with given error
  Void updateWriteErr(ConnWriteInfo info, Err err)
  {
    s := ConnPointWriteState.updateErr(this, info, err)
    writeStateRef.val = s
    updateWriteTags(s)
  }

  ** Write value state storage and handling
  internal ConnPointWriteState writeState() { writeStateRef.val }
  private const AtomicRef writeStateRef := AtomicRef(ConnPointWriteState.nil)

  ** Update write state lastInfo field and clear queued flag
  internal Void updateWriteReceived(ConnWriteInfo lastInfo)
  {
    writeStateRef.val = ConnPointWriteState.updateReceived(this, lastInfo)
  }

  ** Update write state pending flag
  internal Void updateWritePending(Bool pending)
  {
    writeStateRef.val = ConnPointWriteState.updatePending(this, pending)
  }

  ** Update write state queued flag
  internal Void updateWriteQueued(Bool queued)
  {
    writeStateRef.val = ConnPointWriteState.updateQueued(this, queued)
  }

  ** Update writeStatus, writeVal, writeLevel, writeErr
  private Void updateWriteTags(ConnPointWriteState s)
  {
    status := s.status
    val    := null
    err    := null
    level  := null
    config := config
    if (config.writeFault != null)
    {
      status = ConnStatus.fault
      err = config.writeFault
    }
    else if (config.isDisabled)
    {
      status = ConnStatus.disabled
      err = "Point is disabled"
    }
    else if (!conn.status.isOk)
    {
      status = conn.status
      err = "conn $status"
    }
    else if (status.isOk)
    {
      val = s.raw
      level = ConnUtil.levelToNumber(s.level)
    }
    else
    {
      err = ConnStatus.toErrStr(s.err)
      level = ConnUtil.levelToNumber(s.level)
    }
    committer.commit2(lib, rec, "writeStatus", status.name, "writeErr", err)
  }

//////////////////////////////////////////////////////////////////////////
// History State
//////////////////////////////////////////////////////////////////////////

  ** Write new history items and update status.  Span should be same value
  ** passed to 'onSyncHis'.  The items will be normalized, clipped by span,
  ** converted by 'hisConvert' if configured, and then and written to historian.
  Obj? updateHisOk(HisItem[] items, Span span)
  {
    s := ConnPointHisState.updateOk(this, items, span)
    hisStateRef.val = s
    updateHisTags(s)
    return Etc.dict2("id", id, "num", Number(items.size))
  }

  ** Update his sync with given error
  Obj? updateHisErr(Err err)
  {
    s := ConnPointHisState.updateErr(this, err)
    hisStateRef.val = s
    updateHisTags(s)
    return Etc.dict2("id", id, "err", err.toStr)
  }

  ** Update hisState to pending (just transient tag, not state)
  internal Void updateHisPending()
  {
    committer.commit1(lib, rec, "hisStatus", "pending")
  }

  ** History sync state
  internal ConnPointHisState hisState() { hisStateRef.val }
  private const AtomicRef hisStateRef := AtomicRef(ConnPointHisState.nil)

  ** Update hisStatus, hisErr
  private Void updateHisTags(ConnPointHisState s)
  {
    status := s.status
    err    := null
    config := config
    if (config.writeFault != null)
    {
      status = ConnStatus.fault
      err = config.writeFault
    }
    else if (config.isDisabled)
    {
      status = ConnStatus.disabled
      err = "Point is disabled"
    }
    else if (!conn.status.isOk)
    {
      status = conn.status
      err = "conn $status"
    }
    else if (!status.isOk)
    {
      err = ConnStatus.toErrStr(s.err)
    }
    committer.commit2(lib, rec, "hisStatus", status.name, "hisErr", err)
  }

//////////////////////////////////////////////////////////////////////////
// Status
//////////////////////////////////////////////////////////////////////////

  ** Transition when conn status updates
  internal Void onConnStatus()
  {
    updateStatus
  }

  ** Update all the status tags
  internal Void updateStatus()
  {
    // TODO: join together commits
    c := config
    if (c.curAddr   != null) updateCurTags(curState)
    if (c.writeAddr != null) updateWriteTags(writeState)
    if (c.hisAddr   != null) updateHisTags(hisState)
  }

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
             conn:           $conn.dis [$conn.id] $conn.status
             kind:           $kind
             tz:             $tz
             unit:           $unit
             tuning:         $tuning.rec.id.toZinc
             data:           $data
             isWatched:      $isWatched

             """)

    detailsAddr(s, model.curTag,   curAddr)
    detailsAddr(s, model.writeTag, writeAddr)
    detailsAddr(s, model.hisTag,   hisAddr)

    s.add("\n")
    committer.details(s)

    extra := lib.onPointDetails(this).trim
    if (!extra.isEmpty) s.add("\n").add(extra).add("\n")

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

    if (curAddr != null)
    {
      s.add("""
               Conn Cur
               =============================
               """)
      curState.details(s, this)
    }

    if (writeAddr != null)
    {
      s.add("""
               Conn Write
               =============================
               """)
      writeState.details(s, this)
    }

    if (hisAddr != null || hisState !== ConnPointHisState.nil)
    {
      s.add("""
               Conn His Sync
               =============================
               """)
      hisState.details(s, this)
    }

    try
    {
      more := PointUtil.pointDetails(conn.pointLib, rec, false)
      s.add(more)
    }
    catch (Err e) conn.log.err("pointDetails", e)

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
      this.curAddr        = toAddr(model, rec, model.curTag)
      this.writeAddr      = toAddr(model, rec, model.writeTag)
      this.hisAddr        = toAddr(model, rec, model.hisTag)
      this.curFault       = toAddrFault(model.curTag,   this.curAddr,   model.curTagType)
      this.writeFault     = toAddrFault(model.writeTag, this.writeAddr, model.writeTagType)
      this.hisFault       = toAddrFault(model.hisTag,   this.hisAddr,   model.hisTagType)
      this.tz             = rec.has("tz") ? FolioUtil.hisTz(rec) : TimeZone.cur
      this.unit           = FolioUtil.hisUnit(rec)
      this.kind           = FolioUtil.hisKind(rec)
      this.tuning         = lib.tunings.forRec(rec)
      this.curCalibration = rec["curCalibration"] as Number
      this.curConvert     = toConvert(rec, "curConvert")
      this.writeConvert   = toConvert(rec, "writeConvert")
      this.hisConvert     = toConvert(rec, "hisConvert")
    }
    catch (Err e)
    {
      fault := e.msg
      if (curAddr   != null) this.curFault   = this.curFault   ?: fault
      if (writeAddr != null) this.writeFault = this.writeFault ?: fault
      if (hisAddr   != null) this.hisFault   = this.hisFault   ?: fault
    }
  }

  private static Obj? toAddr(ConnModel model, Dict rec, Str? tag)
  {
    if (tag == null) return null
    val := rec[tag]
    if (val == null) return null
    return val
  }

  private static Str? toAddrFault(Str? tag, Obj? val, Type? type)
  {
    if (val == null) return null
    if (val.typeof !== type) return "Invalid type for '$tag' [$val.typeof.name != $type.name]"
    return null
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
  const Bool isDisabled
  const Str? curFault
  const Str? writeFault
  const Str? hisFault
  const Number? curCalibration
  const PointConvert? curConvert
  const PointConvert? writeConvert
  const PointConvert? hisConvert

  Bool isEnabled() { !isDisabled }

  Bool isCurEnabled() { curAddr != null && curFault == null && isEnabled }

  Bool isWriteEnabled() { writeAddr != null && writeFault == null && isEnabled }

  Bool isHisEnabled() { hisAddr != null && hisFault == null && isEnabled }

  Bool isStatusUpdate(ConnPointConfig b)
  {
    a := this
    if (a.isDisabled != b.isDisabled) return true
    if (a.curFault   != b.curFault) return true
    if (a.writeFault != b.writeFault) return true
    if (a.hisFault   != b.hisFault) return true
    return false
  }

}

