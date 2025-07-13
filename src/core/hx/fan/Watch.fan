//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 May 2012  Brian Frank  Creation
//    4 Mar 2016  Brian Frank  Refactor for 3.0
//   22 Jul 2021  Brian Frank  Port to Haxall
//

using concurrent
using xeto
using haystack

**
** Watch is a subscription to a set of records in a project database.
** It provides an efficient mechanism to poll for changes.
** Also see `docHaxall::Watches#fantom`.
**
const abstract class Watch
{
  ** Project associated with this watch
  abstract Proj proj()

  ** Debug display string used during 'watchOpen'
  abstract Str dis()

  ** Identifier which uniquely identifies this watch in the project
  abstract Str id()

  ** List the rec ids currently subscribed by this watch.
  ** Raise exception if watch is closed.
  abstract Ref[] list()

  ** Return if the list of recs currently subscribed is empty.
  abstract Bool isEmpty()

  ** Ticks of the last call to `poll`
  @NoDoc abstract Duration lastPoll()

  ** Ticks of the last call to `poll` or `renew`
  @NoDoc abstract Duration lastRenew()

  ** The lease determines the max duration which may elapse without a
  ** renew call before the watch is expired.  The default is 1min. Clients
  ** can attempt to tune the lease time by setting this field, but no
  ** guarantee is made that the framework will honor extremely long
  ** lease times.
  abstract Duration lease

  ** Get all the records which have been modified since the given ticks.
  ** An empty list is returned if no changes have been made to the watched
  ** records since ticks.  There is no ordering to the resulting list.
  ** This method automatically renews the lease and keeps track of the
  ** last poll ticks.  Also see `docHaxall::Watches#fantom`.
  abstract Dict[] poll(Duration ticks := lastPoll)

  ** Update `lastRenew` just to maintain the lease, but don't
  ** update `lastPoll` or actually return any changes.
  @NoDoc abstract Void renew()

  ** Convenience for 'addAll([id])'
  Void add(Ref id) { addAll([id]) }

  ** Convenience for 'addAll' for 'id' column of each row. If any
  ** row is missing an 'id' tag then it is silently skipped.
  Void addGrid(Grid grid)
  {
    if (grid.isEmpty) return
    ids := Ref[,]
    ids.capacity = grid.size
    idCol := grid.col("id")
    grid.each |row|
    {
      id := row.val(idCol) as Ref
      if (id != null) ids.add(id)
    }
    addAll(ids)
  }

  ** Add the given records to this watch.  Silently ignore any ids already
  ** subscribed by this watch, not found in the database, or which are
  ** inaccessible to the current user.  Raise exception if watch is
  ** closed.  This call renews the lease.
  abstract Void addAll(Ref[] ids)

  ** Convenience for 'removeAll([id])'
  Void remove(Ref id) { removeAll([id]) }

  ** Remove the given records from this watch.  Any ids not
  ** currently subscribed by this watch are silently ignored.
  ** Raise exception if watch is closed. This call renews the lease.
  abstract Void removeAll(Ref[] ids)

  ** Set this watch to the given list of ids.  This is convenience
  ** for an `addAll` and `removeAll` between current ids and given ids.
  ** This call renews the lease.
  @NoDoc abstract Void set(Ref[] ids)

  ** Convenience for 'removeAll' for 'id' column of each row
  Void removeGrid(Grid grid)
  {
    ids := Ref[,]
    ids.capacity = grid.size
    idCol := grid.col("id")
    grid.each |row| { ids.add(row.val(idCol)) }
    removeAll(ids)
  }

  ** Return if this watch has been closed
  abstract Bool isClosed()

  ** Close this watch and unsubscribe all its records.
  ** If watch is already closed, this method is a no op.
  abstract Void close()

  ** Identity hash
  override final Int hash() { super.hash }

  ** Equality based on reference equality
  override final Bool equals(Obj? that) { this === that }

  ** Debug string
  override final Str toStr() { "Watch-$proj.name-$id" }

}

