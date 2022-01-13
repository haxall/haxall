//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 May 2012  Brian Frank  Creation
//   13 Jan 2022  Brian Frank  Redesign for Haxall
//

using concurrent
using haystack
using hxPoint

**
** ConnPointCurState stores and handles all curVal state
**
internal const final class ConnPointCurState
{

//////////////////////////////////////////////////////////////////////////
// Transitions
//////////////////////////////////////////////////////////////////////////

  static new updateOk(ConnPoint pt, Obj? val)
  {
    raw := val
    try
    {
      // check if we have a conversions
      if (pt.curConvert != null)
        val = pt.curConvert.convert(pt.lib.pointLib, pt.rec, raw)

      // check if we have calibration
      if (pt.curCalibration != null)
        val = ((Number)val).plus(pt.curCalibration)

      // add/check unit if Number
      if (pt.kind.isNumber)
        val = PointUtil.applyUnit(pt.rec, val, "updateCurOk")

      // check kind
      if (val != null)
      {
        valKind := Kind.fromVal(val)
        if (valKind !== pt.kind)
          throw FaultErr("curVal kind != configured kind: $valKind != $pt.kind")
      }

      return makeOk(raw, val)
    }
    catch (Err e)
    {
      return makeErr(e, raw)
    }
  }

  static new updateErr(ConnPoint pt, Err err)
  {
    makeErr(err, null)
  }

  static new updateStale(ConnPoint pt)
  {
    makeStale(pt.curState)
  }

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  Void details(StrBuf s, ConnPoint pt)
  {
    s.add("""curAddr:        $pt.curAddr
             curStatus:      $status TODO
             curVal:         $val [${val?.typeof}]
             curRaw:         $raw [${raw?.typeof}]
             curConvert:     $pt.curConvert
             curCalibration: $pt.curCalibration
             curLastUpdate:  ${Etc.debugDur(lastUpdate)}
             curErr:         ${Etc.debugErr(err)}
             """)
  }

//////////////////////////////////////////////////////////////////////////
// Constructors
//////////////////////////////////////////////////////////////////////////

  static const ConnPointCurState nil := makeNil()
  private new makeNil() { status = ConnStatus.unknown }

  private new makeOk(Obj? val, Obj? raw)
  {
    this.status     = ConnStatus.ok
    this.lastUpdate = Duration.nowTicks
    this.val        = val
    this.raw        = raw
  }

  private new makeStale(ConnPointCurState old)
  {
    this.status     = ConnStatus.stale
    this.lastUpdate = old.lastUpdate
    this.val        = old.val
    this.raw        = old.raw
  }

  private new makeErr(Err err, Obj? raw)
  {
    this.status     = ConnStatus.fromErr(err)
    this.err        = err
    this.lastUpdate = Duration.nowTicks
    this.raw        = raw
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const ConnStatus status
  const Obj? val
  const Obj? raw
  const Err? err
  const Int lastUpdate
}