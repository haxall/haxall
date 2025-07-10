//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 May 2012  Brian Frank  Creation
//   22 Jun 2021  Brian Frank  Redesign for Haxall
//

using concurrent
using xeto
using haystack
using obs
using hx

**
** Connector framework library
**
@NoDoc
const class ConnFwLib : HxLib
{
  ** Publish HxConnRegistryService
  override HxService[] services() { [service] }

  ** Lookup tables for all conn libs, connectors, and points
  const ConnService service := ConnService(this)

  ** List the configured connTuning records
  const ConnTuningRoster tunings := ConnTuningRoster()

  ** Start callback
  override Void onStart()
  {
    observe("obsCommits",
        Etc.makeDict([
          "obsAdds":      Marker.val,
          "obsUpdates":   Marker.val,
          "obsRemoves":   Marker.val,
          "obsAddOnInit": Marker.val,
          "syncable":     Marker.val,
          "obsFilter":   "connTuning"
        ]), #onConnTuningEvent)
  }

  ** Handle commit event on a connTuning rec
  internal Void onConnTuningEvent(CommitObservation e)
  {
    tunings.onEvent(e)
  }

}

