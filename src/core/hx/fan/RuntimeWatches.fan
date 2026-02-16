//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 May 2012  Brian Frank  Creation
//    4 Mar 2016  Brian Frank  Refactor for 3.0
//   22 Jul 2021  Brian Frank  Port to Haxall
//   13 Jul 2024  Brian Frank  Refactor fro 4.0
//

using concurrent
using xeto
using haystack

**
** Runtime watch subscription APIs
**
const mixin RuntimeWatches
{
  ** List the watches currently open for the runtime.
  ** Also see `hx.doc.haxall::Watches#fantom-apis`.
  abstract Watch[] list()

  ** Return list of watches currently subscribed to the given id,
  ** or return empty list if the given id is not in any watches.
  abstract Watch[] listOn(Ref id)

  ** Find an open watch by its identifier.  If  not found
  ** then throw Err or return null based on checked flag.
  ** Also see `hx.doc.haxall::Watches#fantom-apis`.
  abstract Watch? get(Str id, Bool checked := true)

  ** Open a new watch with given display string for debugging.
  ** Also see `hx.doc.haxall::Watches#fantom-apis`.
  abstract Watch open(Str dis)

  ** Return if given record id is under at least one watch
  abstract Bool isWatched(Ref id)

  ** Close expired watches
  @NoDoc abstract Void checkExpires()

  ** Return debug grid.  Columns:
  **   - watchId: watch id
  **   - dis: watch dis
  **   - created: timestamp when watch was created
  **   - lastRenew: timestamp of last lease renewal
  **   - lastPoll: timestamp of last poll
  **   - size: number of records in watch
  @NoDoc abstract Grid debugGrid()
}

