//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 May 2012  Brian Frank  Creation
//   31 Jan 2022  Brian Frank  Redesign for Haxall
//

using haystack

**
** ConnPointHisState stores and handles all history sink state
**
internal const final class ConnPointHisState
{

//////////////////////////////////////////////////////////////////////////
// Transitions
//////////////////////////////////////////////////////////////////////////

  static new updateOk(ConnPoint pt, HisItem[] items, Span span)
  {
    old := pt.hisState
    try
    {
      // debug string for items
      lastItems := StrBuf()
      lastItems.add(items.size.toStr).add(" items")
      if (items.size > 0) lastItems.add(", ").add(items.last)

      // convert if configured
      rec := pt.rec
      convert := pt.hisConvert
      if (convert != null)
      {
        for (i := 0; i<items.size; ++i)
        {
          oldItem := items[i]
          items[i] = HisItem(oldItem.ts, convert.convert(pt.ext.pointLib, rec, oldItem.val))
        }
      }

      // write history items with clip span option
      pt.ext.rt.his.write(rec, items, Etc.dict1("clip", span))

      return makeOk(old, lastItems.toStr)
    }
    catch (Err e)
    {
      return makeErr(old, e)
    }
  }

  static new updateErr(ConnPoint pt, Err err)
  {
    makeErr(pt.hisState, err)
  }

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  Void details(StrBuf s, ConnPoint pt)
  {
    s.add("""hisAddr:        $pt.writeAddr
             hisStatus:      $status
             hisConvert:     $pt.hisConvert
             hisLastUpdate:  ${Etc.debugDur(lastUpdate)}
             hisLastItems    $lastItems
             hisNumUpdate:   $numUpdates
             hisErr:         ${Etc.debugErr(err)}
             """)
  }

//////////////////////////////////////////////////////////////////////////
// Constructors
//////////////////////////////////////////////////////////////////////////

  static const ConnPointHisState nil := makeNil()
  private new makeNil() { status = ConnStatus.unknown; lastItems = "" }

  private new makeOk(ConnPointHisState old, Str lastItems)
  {
    this.status     = ConnStatus.ok
    this.lastUpdate = Duration.nowTicks
    this.lastItems  = lastItems
    this.numUpdates = old.numUpdates + 1
  }

  private new makeErr(ConnPointHisState old, Err err)
  {
    this.status     = ConnStatus.fromErr(err)
    this.lastUpdate = Duration.nowTicks
    this.lastItems  = ""
    this.numUpdates = old.numUpdates + 1
    this.err        = err
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const ConnStatus status
  const Err? err
  const Int lastUpdate
  const Str lastItems
  const Int numUpdates
}

