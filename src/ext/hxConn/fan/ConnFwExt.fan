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
const class ConnFwExt : ExtObj, IConnExt
{

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

//////////////////////////////////////////////////////////////////////////
// IConnExt
//////////////////////////////////////////////////////////////////////////

  override HxConnExt[] exts() { service.exts }

  override HxConnExt? ext(Str name, Bool checked := true) { service.ext(name, checked) }

  override HxConn[] conns() { service.conns }

  override HxConn? conn(Ref id, Bool checked := true) { service.conn(id, checked) }

  override Bool isConn(Ref id) { service.isConn(id) }

  override HxConnPoint[] points() { service.points }

  override HxConnPoint? point(Ref id, Bool checked := true) { service.point(id, checked) }

  override Bool isPoint(Ref id) { service.isPoint(id) }
}

