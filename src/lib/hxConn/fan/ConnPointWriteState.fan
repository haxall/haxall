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

  static new updateOk(ConnPoint pt, Obj? val, Int level)
  {
    makeOk(val, level)
  }

  static new updateErr(ConnPoint pt, Obj? val, Int level, Err err)
  {
    makeErr(val, level, err)
  }

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  Void details(StrBuf s, ConnPoint pt)
  {
    s.add("""writeAddr:        $pt.writeAddr
             writeStatus:      $status
             writeVal:         $val [${val?.typeof}]
             writeRaw:         TODO
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

  private new makeOk(Obj? val, Int level)
  {
    this.status     = ConnStatus.ok
    this.lastUpdate = Duration.nowTicks
    this.val        = val
    this.level      = level
  }

  private new makeErr(Obj? val, Int level, Err err)
  {
    this.status     = ConnStatus.fromErr(err)
    this.lastUpdate = Duration.nowTicks
    this.val        = val
    this.level      = level
    this.err        = err
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const ConnStatus status
  const Obj? val
  const Int level
  const Err? err
  const Int lastUpdate
}