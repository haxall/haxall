//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 May 2021  Brian Frank  Creation
//    8 Jul 2025  Brian Frank  Redesign from HxRuntime
//

using concurrent
using xeto
using haystack
using obs
using folio

**
** Runtime manages a database, library namespace, and extensions.
** It is the base type for both `Sys` and `Proj`.  In the Haxall daemon
** there is one runtime that is both the Sys and Proj.  But in
** SkySpark there is one host level Sys for the VM and zero more
** separate Proj runtimes.
**
const mixin Runtime
{

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Reference to system runtime
  abstract Sys sys()

  ** Return if this runtime is the system
  abstract Bool isSys()

  ** Return if this runtime is a project
  abstract Bool isProj()

  ** Runtime id which is always formatted as "p:{name}"
  abstract Ref id()

  ** Programatic name of the runtime. This string is always a valid tag name.
  abstract Str name()

  ** Display name of the runtime.
  abstract Str dis()

  ** Log for runtime level logging
  abstract Log log()

  ** Running flag.  On startup this flag transitions to true before calling
  ** ready and start on all the extensions.  On shutdown this flag transitions
  ** to false before calling unready and stop on all the libraries.
  abstract Bool isRunning()

  ** Runtime file directory.  It the root directory of all runtime oriented
  ** operational files.  The folio database is stored under this directory
  ** in a sub-directory named 'db/', and namespace support in 'ns/'
  abstract File dir()

  ** Metadata dict
  abstract Dict meta()

  ** Update metadata with Str:Obj, Dict, or Diff.
  @NoDoc abstract Void metaUpdate(Obj changes)

  ** Folio database for this runtime
  abstract Folio db()

  ** Xeto lib namespace for this runtime
  abstract Namespace ns()

  ** Xeto library management
  abstract RuntimeLibs libs()

  ** Namespace of definitions (deprecated)
  @NoDoc abstract DefNamespace defs()

  ** Convenience for 'exts.get' to lookup extension by lib dotted name
  abstract Ext? ext(Str name, Bool checked := true)

  ** Extension lookup and management
  abstract RuntimeExts exts()

  ** Block until currently queued background processing completes
  abstract This sync(Duration? timeout := 30sec)

  ** Has the runtime has reached steady state.  Steady state is reached
  ** after a configurable wait period elapses after the runtime is
  ** fully loaded.  This gives internal services time to spin up before
  ** interacting with external systems.  See `docHaxall::Runtime#steadyState`.
  abstract Bool isSteadyState()

  ** Watch subscriptions
  abstract RuntimeWatches watch()

  ** Watch observables
  abstract RuntimeObservables obs()

  ** Construct new context with user
  virtual Context newContext(User user)
  {
    Context(sys, this as Proj, user)
  }

  ** Construct new context with user
  @NoDoc virtual Context newContextSession(UserSession session)
  {
    Context(sys, this as Proj, session)
  }

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

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Cache for ion data
  @NoDoc abstract Obj ionData()

}

