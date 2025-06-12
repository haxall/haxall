//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Jul 2012  Brian Frank  Creation
//

using concurrent
using haystack
using hxUtil
using folio

**
** HisCollectRec models state for a single point with his collection enabled.
** This object is always mutated and manipulated inside the HisCollectMgr thread.
**
@NoDoc
internal class HisCollectRec
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(Ref id, Dict rec)
  {
    this.id = id
    this.rec = rec
    this.status = statusInit
    this.tz = TimeZone.cur
    this.buf = CircularBuf(16)
    this.covRateLimit = 1sec
  }

//////////////////////////////////////////////////////////////////////////
// Check
//////////////////////////////////////////////////////////////////////////

  Void onCheck(HisCollectMgr mgr, Dict rec, DateTime now, Bool topOfMin)
  {
    // save latest state for rec
    this.rec = rec

    // get current value and status
    curVal    := rec["curVal"]
    curStatus := rec["curStatus"]

    // if doing interval logging
    collectRequired := false
    if (interval != null)
      collectRequired = isInterval(now, topOfMin)

    // if we don't have interval collection, check COV
    if (!collectRequired && cov != null)
      collectRequired = isCov(now, curVal)

    // if no collection required, then we are done for this cycle
    if (!collectRequired) return

    // make sure our date time is in correct timezone for point
    ts := now.toTimeZone(tz)

    // if buffer is full of unwritten items then resize up
    // to max size; or if already at max size force a flush
    if (bufFullOfPending)
    {
      newMax := buf.max * 2
      if (newMax < maxBufSize)
        buf.resize(newMax)
      else
        writePending(mgr)
    }

    // add to our memory buffer
    lastItem = HisCollectItem(ts, curVal, curStatus)
    buf.add(lastItem)

    // check if its time to write whats in buffer
    checkWrite(mgr)
  }

  private Bool isInterval(DateTime now, Bool topOfMin)
  {
    // sub-minute interval
    if (intervalSecs > 0)
    {
      // start on top of minute if this is first collection
      if (lastItem == null) return topOfMin

      // check how much time has elapsed:
      //   1. never log any faster than once a second with 300ms fudge
      //   2. if we have missed our collection by more than a second, force
      //      it even if we aren't on a clean secondly interval
      //   3. pick clean secondly interval
      lastItem := (HisCollectItem)buf.newest
      delta := now.ticks - lastItem.ts.ticks
      if (delta < 1300ms.ticks) return false
      if (delta > interval.ticks + 1sec.ticks) return true
      return now.sec % intervalSecs == 0
    }

    // minutely or higher is only logged on top of the minute
    if (!topOfMin) return false

    // check hourly or minutely interval
    if (intervalHours > 0)
      return now.hour % intervalHours == 0 && now.min == 0
    else
      return now.min % intervalMinutes == 0
  }

  private Bool isCov(DateTime now, Obj? curVal)
  {
    // if no collection since boot, always collect
    if (lastItem == null) return true

    // if no change, then definitely not a collect
    if (lastItem.curVal == curVal) return false

    // check for rate throttling
    if (throttleCov(now)) return false

    // if cov is Marker, then any change is a collect
    if (this.cov === Marker.val) return true

    // only collect if curVal is more than tolerance
    lastNum := lastItem.curVal as Number
    curNum := curVal as Number
    if (lastNum == null || curNum == null) return true
    return (lastNum.toFloat - curNum.toFloat).abs >= ((Number)cov).toFloat
  }

  private Bool throttleCov(DateTime now)
  {
    // check for rate throttling
    age := now - lastItem.ts
    return age < covRateLimit
  }

  private Bool bufFullOfPending()
  {
    if (buf.size < buf.max) return false
    old := (HisCollectItem)buf.oldest
    return old.written == HisCollectItemState.pending
  }

//////////////////////////////////////////////////////////////////////////
// Write
//////////////////////////////////////////////////////////////////////////

  private Void checkWrite(HisCollectMgr mgr)
  {
    // if we have a writeFreq configured, check if the period
    // has elapsed; in case of startup use boot time as our last write
    if (writeFreq != null)
    {
      last := writeLast
      if (last == 0) last = Duration.boot.ticks
      age := Duration.nowTicks - last
      if (age < writeFreq.ticks) return
    }

    // write
    writePending(mgr)
  }

  Bool writePending(HisCollectMgr mgr)
  {
    // find unwritten items to write (loops newest to oldest)
    toWrite := HisItem[,]
    buf.eachWhile |HisCollectItem item->Obj?|
    {
      // iterate only pending unwritten items, then exit loop
      if (item.written != HisCollectItemState.pending) return "done"

      // if value is bad, then we write NA to historian
      val := item.curVal
      if (val == null || item.curStatus != "ok")
      {
        if (!collectNA)
        {
          item.written = HisCollectItemState.skipped
          return null // skip bad data if not collecting NA
        }
        val = NA.val
        item.written = HisCollectItemState.wroteNA
      }
      else { item.written = HisCollectItemState.wroteVal }

      toWrite.add(HisItem(item.ts, val))
      return null
    }
    if (toWrite.isEmpty) return false

    // items are now ordered newest to oldest, so reverse list
    // which optimizes code path in FolioUtil.hisWriteCheck
    toWrite.reverse

    // write to historian; checks are sync, write to disk is async
    try
    {
      mgr.lib.rt.his.write(rec, toWrite, Etc.emptyDict)
      writeErr = null
    }
    catch (Err e)
    {
      writeErr = e
    }

    // now mark ticks of attempted write for writeFreq
    writeLast = Duration.nowTicks
    return true
  }

//////////////////////////////////////////////////////////////////////////
// Refresh
//////////////////////////////////////////////////////////////////////////

  Bool isHisCollect()
  {
    interval != null || cov != null
  }

  Void onRefresh(HisCollectMgr mgr, Dict rec)
  {
    try
    {
      settings := mgr.lib.rec

      // save current state of record
      this.rec = rec

      // check that rec is configured correctly
      if (rec["point"] !== Marker.val) throw FaultErr("Missing 'point' marker tag")
      if (rec["his"] !== Marker.val) throw FaultErr("Missing 'his' marker tag")

      // check tz
      tz := TimeZone.fromStr(rec["tz"] as Str ?: "", false)
      if (tz == null) throw FaultErr("Missing or invalid 'tz' tag")
      this.tz = tz

      // check write freq
      this.writeFreq = null
      if (rec.has("hisCollectWriteFreq"))
      {
        dur := (rec["hisCollectWriteFreq"] as Number)?.toDuration(false)
        if (dur == null) throw FaultErr("hisWriteFreq not valid dur")
        if (dur < 1sec) dur = 1sec
        if (dur > 1day) dur = 1day
        this.writeFreq = dur
      }

      // check interval
      this.interval = null
      this.intervalSecs = 0
      this.intervalHours = 0
      this.intervalMinutes = 0
      intervalVal := rec["hisCollectInterval"]
      if (intervalVal != null)
      {
        dur := 1min
        try
          dur = ((Number)intervalVal).toDuration
        catch (Err e)
          throw FaultErr("hisCollectInterval is not duration Number")

        // check interval
        if (dur > hisCollectIntervalMax) throw FaultErr("hisCollectInterval > $hisCollectIntervalMax")
        if (dur < hisCollectIntervalMin) throw FaultErr("hisCollectInterval < $hisCollectIntervalMin")

        // must be even number of minutes divisible into 60min
        // or else must be even number of hours divisible by 24hr
        secs := 0; mins := 0; hours := 0
        if (dur < 1min)
        {
          secs = dur.toSec
          if (secs * 1sec.ticks != dur.ticks) throw FaultErr("hisCollectInterval must be even number of seconds")
          if (60 % secs != 0) throw FaultErr("hisCollectInterval seconds must be evenly divisible by 60sec")
        }
        else if (dur < 1hr)
        {
          mins = dur.toMin
          if (mins * 1min.ticks != dur.ticks) throw FaultErr("hisCollectInterval must be even number of minutes")
          if (60 % mins != 0) throw FaultErr("hisCollectInterval minutes must be evenly divisible by 60min")
        }
        else
        {
          hours = dur.toHour
          if (hours * 1hr.ticks != dur.ticks) throw FaultErr("hisCollectInterval must be even number of hours")
          if (24 % hours != 0) throw FaultErr("hisCollectInterval hours must be evenly divisible by 24hr")
        }

        this.intervalSecs = secs
        this.intervalMinutes = mins
        this.intervalHours = hours
        this.interval = dur
      }

      // check COV
      this.cov = null
      cov := rec["hisCollectCov"]
      if (cov != null)
      {
        if (cov !== Marker.val)
        {
          num := cov as Number
          if (num == null) throw FaultErr("hisCollectCov must be Marker or Number")
          if (rec["kind"] != "Number") throw FaultErr("hisCollectCov Number on non-Number kind")
        }
        this.cov = cov
      }

      // check covRateLimit
      rateLimit := (rec["hisCollectCovRateLimit"] as Number)?.toDuration(false)
      if (rateLimit == null)
      {
        // if this is a number, throttle as 1/10 of interval
        if (rec["kind"] == Kind.number.name)
          rateLimit = ((interval ?: 1hr) / 10).min(1min)
        else
          rateLimit = 1sec
      }
      this.covRateLimit = rateLimit

      // check hisCollectNA
      this.collectNA = mgr.lib.hisCollectNA || rec.has("hisCollectNA")

      // at this point configuration is correct, but if we have a write error
      // we want to use hisStatus and hisErr to indicate that all is not right here
      if (writeErr != null) updateStatusErr(mgr, writeErr.toStr)

      // all is okay
      updateStatusOk(mgr)
    }
    catch (FaultErr e) updateStatusErr(mgr, e.msg)
    catch (Err e) updateStatusErr(mgr, e.toStr)
  }

  private Void updateStatusOk(HisCollectMgr mgr)
  {
    // short circuit if already ok
    if (status === statusOk) return

    this.status = statusOk
    this.err = null
    commit(mgr, Etc.dict2("hisStatus", statusOk, "hisErr", Remove.val))
  }

  private Void updateStatusErr(HisCollectMgr mgr, Str err)
  {
    // short circuit if already in same fauilt condition
    if (status === statusFault && err == this.err) return

    this.status = statusFault
    this.err = err
    commit(mgr, Etc.dict2("hisStatus", statusFault, "hisErr", err))
  }

  private Void commit(HisCollectMgr mgr, Dict changes)
  {
    rec = mgr.lib.rt.db.commit(Diff(rec, changes, Diff.forceTransient)).newRec
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  override Str toStr() { "$rec.dis interval=$interval cov=$cov" }

  Str toDetails()
  {
    pattern := "YYYY-MMM-DD hh:mm:ss"

    s := StrBuf().add(
    """His Collect
       =============================
       hisStatus:       $status
       hisErr:          $err
       interval:        $interval (${intervalHours}hr, ${intervalMinutes}min, ${intervalSecs}sec)
       cov:             $cov
       covRateLimit:    $covRateLimit
       collectNA:       $collectNA
       tz:              $tz
       writeFreq:       $writeFreq
       writeLast:       ${detailsDurToTs(writeLast)}
       writeErr:        ${detailsErr(writeErr)}
       """)

    // buffer
    s.add(
    """buffer:          $buf.size ($buf.max max)
       """)
    buf.each |HisCollectItem item|
    {
      valStr := item.curVal?.toStr ?: "null"
      s.add("  ").add(item.ts.toLocale(pattern))
       .add(" ").add(valStr)
       .add(" {").add(item.curStatus).add("} ")
       .add(item.writtenToStr).add("\n")
    }

    return s.toStr
  }

  private static Str detailsErr(Err? err) { Etc.debugErr(err) }

  private static Str detailsDurToTs(Int dur) { Etc.debugDur(dur) }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  // NOTE: these values are duplicated from hisCollectInterval def
  private const static Duration hisCollectIntervalMin := 1sec
  private const static Duration hisCollectIntervalMax := 1day

  private const static Int maxBufSize := 4096

  private const static Str statusInit  := "init"
  private const static Str statusOk    := "ok"
  private const static Str statusFault := "fault"

  const Ref id                     // record id
  private Dict rec                 // current state of record
  private Str status               // current history status
  private Str? err                 // if misconfigured
  private TimeZone tz              // configured timezone of point
  private Duration? interval       // if working with interval data
  private Int intervalHours        // number of hours between intervals
  private Int intervalMinutes      // number of minutes between intervals
  private Int intervalSecs         // number of seconds between intervals
  private Duration? writeFreq      // frequency to write to historian
  private Int writeLast            // ticks of last write
  private Err? writeErr            // if last write failed
  private Obj? cov                 // Marker of Number if vetted COV
  private Duration covRateLimit    // rate throttling
  private Bool collectNA           // historize NA for bad data
  private CircularBuf buf          // all items which met interval/cov
  private HisCollectItem? lastItem // last item in buf
}

**************************************************************************
** HisCollectItem
**************************************************************************

internal class HisCollectItem
{
  new make(DateTime ts, Obj? curVal, Str? curStatus)
  {
    this.ts        = ts
    this.curVal    = curVal
    this.curStatus = curStatus
    this.written   = HisCollectItemState.pending
  }

  const DateTime ts
  const Obj? curVal
  const Str? curStatus

  HisCollectItemState written

  Str writtenToStr() { written.toStr }

  override Str toStr() { "$ts.toLocale $curVal {$curStatus} $writtenToStr" }
}

**************************************************************************
** HisCollectItemState
**************************************************************************

internal enum class HisCollectItemState { pending, wroteVal, wroteNA, skipped }

