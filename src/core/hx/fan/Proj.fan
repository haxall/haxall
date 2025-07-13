//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 May 2021  Brian Frank  Creation
//    8 Jul 2025  Brian Frank  Redesign from HxRuntime
//

using xeto
using haystack
using obs
using folio

**
** Proj manages a project database
**
const mixin Proj
{
  ** Reference to system project (in Haxall daemon it is always this)
  abstract Sys sys()

  ** Programatic name of the runtime. This string is always a valid tag name.
  abstract Str name()

  ** Display name of the runtime.
  abstract Str dis()

  ** Runtime version
  abstract Version version()

  ** Log for project level logging
  abstract Log log()

  ** Running flag.  On startup this flag transitions to true before calling
  ** ready and start on all the libraries.  On shutdown this flag transitions
  ** to false before calling unready and stop on all the libraries.
  abstract Bool isRunning()

  ** Platform hosting the runtime
  abstract HxPlatform platform()

  ** Runtime project directory.  It the root directory of all project
  ** oriented operational files.  The folio database is stored under
  ** this directory in a sub-directory named 'db/'.
  abstract File dir()

  ** Runtime level meta data stored in the `projMeta` database record
  abstract Dict meta()

  ** Folio database for this runtime
  abstract Folio db()

  ** Xeto lib namespace
  abstract Namespace ns()

  ** Project xeto library management
  abstract ProjLibs libs()

  ** Project spec management
  abstract ProjSpecs specs()

  ** Namespace of definitions
  abstract DefNamespace defs()

  ** Convenience for 'exts.get' to lookup extension by lib dotted name
  abstract Ext? ext(Str name, Bool checked := true)

  ** Project extensions
  abstract ProjExts exts()

  ** Block until currently queued background processing completes
  abstract This sync(Duration? timeout := 30sec)

  ** Has the runtime has reached steady state.  Steady state is reached
  ** after a configurable wait period elapses after the runtime is
  ** fully loaded.  This gives internal services time to spin up before
  ** interacting with external systems.  See `docHaxall::Runtime#steadyState`.
  abstract Bool isSteadyState()

  ** Configuration options defined at bootstrap
  @NoDoc abstract HxConfig config()

** TODO
abstract Void recompileDefs()

  ** Watch subscriptions
  abstract ProjWatches watch()

  ** Watch observables
  abstract ProjObservables obs()

/////////////////////////////////////////////////////////////////////////
// Folio Conveniences
//////////////////////////////////////////////////////////////////////////

  ** Convenience for `readByIds`
  abstract Dict? readById(Ref? id, Bool checked := true)

  ** Read a list of records by ids into a grid.  The rows in the
  ** result correspond by index to the ids list.  If checked is true,
  ** then every id must be found in the project or UnknownRecErr
  ** is thrown.  If checked is false, then an unknown record is
  ** returned as a row with every column set to null (including
  ** the 'id' tag).
  abstract  Grid readByIds(Ref[] ids, Bool checked := true)

  ** Read a list of records by id.  The resulting list matches
  ** the list of ids by index (null if record not found).
  abstract Dict?[] readByIdsList(Ref[] ids, Bool checked := true)

  ** Return the number of records which match the given filter string.
  abstract Int readCount(Str filter)

  ** Find the first record which matches the given filter string.
  ** Throw UnknownRecErr or return null based on checked flag.
  ** See [Filter Chapter]`docHaystack::Filters` for filter format.
  abstract Dict? read(Str filter, Bool checked := true)

  ** Match all the records against a filter string and return as grid.
  ** See [Filter Chapter]`docHaystack::Filters` for filter format.
  abstract Grid readAll(Str filter, Dict? opts := null)

  ** Match all the records against a filter string and return as
  ** list.  See [Filter Chapter]`docHaystack::Filters` for filter
  ** format.  See `readAll` to return results as a grid.
  abstract Dict[] readAllList(Str filter, Dict? opts := null)

  ** Convenience for `commitAll` to commit a single diff.
  abstract Diff commit(Diff diff)

  ** Apply a list of diffs to the database in batch.  Either all the
  ** changes are successfully applied, or else none of them are applied
  ** and an exception is raised.  Return updated Diffs which encapsulate
  ** both the old and new version of each record.
  **
  ** If any of the records have been modified since they were read
  ** for the given change set then ConcurrentChangeErr is thrown
  ** unless 'Diff.force' configured.
  abstract Diff[] commitAll(Diff[] diffs)

}

