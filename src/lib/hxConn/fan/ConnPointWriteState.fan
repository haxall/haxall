//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 May 2012  Brian Frank  Creation
//   24 Jan 2022  Brian Frank  Redesign for Haxall
//

using concurrent
using haystack
using hxPoint

**
** ConnPointWriteState stores and handles all writeVal state
**
internal const final class ConnPointWriteState
{

//////////////////////////////////////////////////////////////////////////
// Transitions
//////////////////////////////////////////////////////////////////////////

  static new updateOk(ConnPoint pt, ConnWriteInfo info)
  {
    makeOk(info)
  }

  static new updateErr(ConnPoint pt, ConnWriteInfo info, Err err)
  {
    makeErr(info, err)
  }

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  Void details(StrBuf s, ConnPoint pt)
  {
    s.add("""writeAddr:        $pt.writeAddr
             writeStatus:      $status
             writeVal:         $val [${val?.typeof}]
             writeRaw:         $raw [${raw?.typeof}]
             writeConvert:     $pt.writeConvert
             writeLastUpdate:  ${Etc.debugDur(lastUpdate)}
             writeErr:         ${Etc.debugErr(err)}
             """)
  }

//////////////////////////////////////////////////////////////////////////
// Constructors
//////////////////////////////////////////////////////////////////////////

  static const ConnPointWriteState nil := makeNil()
  private new makeNil() { status = ConnStatus.unknown }

  private new makeOk(ConnWriteInfo info)
  {
    this.status     = ConnStatus.ok
    this.lastUpdate = Duration.nowTicks
    this.val        = info.val
    this.raw        = info.raw
    this.level      = info.level
  }

  private new makeErr(ConnWriteInfo info, Err err)
  {
    this.status     = ConnStatus.fromErr(err)
    this.lastUpdate = Duration.nowTicks
    this.val        = info.val
    this.raw        = info.raw
    this.level      = info.level
    this.err        = err
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const ConnStatus status
  const Obj? val
  const Obj? raw
  const Int level
  const Err? err
  const Int lastUpdate
}


**************************************************************************
** ConnWriteInfo
**************************************************************************

**
** ConnWriteInfo wraps the value to write to the remote system.
** It carries information used to update local transient tags.
**
const class ConnWriteInfo
{
  ** Constructor
  internal new make(Obj? val, Obj? raw, Int level)
  {
    this.val   = val
    this.raw   = raw
    this.level = level
  }

  ** Value to write to the remote system; might be converted from writeVal
  const Obj? val

  ** Local effective value; used to update writeVal
  @NoDoc const Obj? raw

  ** Local effective level; used to update writeLevel
  @NoDoc const Int level

  ** Debug string representation
  override Str toStr() { "$val | $raw @ $level" }
}

