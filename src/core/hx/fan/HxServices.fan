//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Aug 2021  Brian Frank  Creation
//

using concurrent
using haystack
using web
using obs

**
** Registry for service APIs by type.  Service APIs implement
** the `HxService` mixin and are implemented by libraries enabled
** in the runtime.
**
const mixin HxServiceRegistry : HxStdServices
{
  ** List the registered service types
  abstract Type[] list()

  ** Lookup a service installed for the given type.  If multiple
  ** services are installed for the given type, then its indeterminate
  ** which is returned.  If the service is not found then raise
  ** UnknownServiceErr or return null based on the check flag.
  abstract HxService? get(Type type, Bool checked := true)

  ** Lookup all services installed for the given type.  Return an
  ** empty list if no services are registered for given type.
  abstract HxService[] getAll(Type type)
}

**************************************************************************
** HxStdServices
**************************************************************************

**
** Lookups for the standard built-in services supported by all runtimes.
** This mixin is implemented by both `HxServiceRegistry` and `HxRuntime`,
** but by convention client code should access services the runtime.
**
const mixin HxStdServices
{
  ** Observable APIs
  abstract HxObsService obs()

  ** Watch subscription APIs
  abstract HxWatchService watch()

  ** HTTP APIs
  abstract HxHttpService http()

  ** User management APIs
  abstract HxUserService user()

  ** Point write service or no-op if point library is not enabled
  @NoDoc abstract HxPointWriteService pointWrite()
}

**************************************************************************
** HxService
**************************************************************************

**
** HxService is a marker interface used to indicate a service API.
**
const mixin HxService {}

**************************************************************************
** HxObsService
**************************************************************************

**
** Observable APIs
**
const mixin HxObsService : HxService
{
  ** List the published observables for the runtime
  abstract Observable[] list()

  ** Lookup a observable for the runtime by name.
  abstract Observable? get(Str name, Bool checked := true)
}

**************************************************************************
** HxWatchService
**************************************************************************

**
** Watch subscription APIs
**
const mixin HxWatchService : HxService
{
  ** List the watches currently open for this runtime.
  ** Also see `docSkySpark::Watches#fantom`.
  abstract HxWatch[] list()

  ** Return list of watches currently subscribed to the given id,
  ** or return empty list if the given id is not in any watches.
  abstract HxWatch[] listOn(Ref id)

  ** Find an open watch by its identifier.  If  not found
  ** then throw Err or return null based on checked flag.
  ** Also see `docSkySpark::Watches#fantom`.
  abstract HxWatch? get(Str id, Bool checked := true)

  ** Open a new watch with given display string for debugging.
  ** Also see `docSkySpark::Watches#fantom`.
  abstract HxWatch open(Str dis)

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

**************************************************************************
** HxHttpService
**************************************************************************

**
** HTTP APIs
**
const mixin HxHttpService : HxService
{
  ** Public HTTP or HTTPS URI of this host.  This is always
  ** an absolute URI such 'https://acme.com/'
  abstract Uri siteUri()

  ** URI on this host to the Haystack HTTP API.  This is always
  ** a host relative URI which end withs a slash such '/api/'.
  abstract Uri apiUri()
}

@NoDoc
const class NilHttpService : HxHttpService
{
  override Uri siteUri() { `http://localhost:8080/` }
  override Uri apiUri() { `/api/` }
}

**************************************************************************
** HxUserService
**************************************************************************

**
** User management APIs
**
const mixin HxUserService : HxService
{
  ** Lookup a user by username.  If not found then raise
  ** exception or return null based on the checked flag.
  abstract HxUser? read(Obj username, Bool checked := true)

  ** Authenticate a web request and return a context.  If request
  ** is not authenticated then redirect to login page and return null.
  abstract HxContext? authenticate(WebReq req, WebRes res)

  ** Create synthetic user.  The tags arg may be a dict or a map.
  abstract HxUser makeSyntheticUser(Str username, Obj? tags := null)
}

**************************************************************************
** HxPointWriteService
**************************************************************************

**
** HxPointWriteService is used to override writable points.
**
@NoDoc
const mixin HxPointWriteService : HxService
{
  **
  ** Set a writable point's priority array value at the given level.
  ** Level must be 1 to 17 (where 17 represents default value).  The
  ** who parameter must be a non-empty string which represent debugging
  ** information about which user or application is writing to this
  ** priorirty array level.
  **
  abstract Future write(Dict point, Obj? val, Int level, Obj who, Dict? opts := null)

  **
  ** Get current state of a writable points priority array.  The result
  ** is a grid with 17 rows including a 'level' and 'val' column.
  **
  abstract Grid array(Dict point)
}

@NoDoc
const class NilPointWriteService : HxPointWriteService
{
  override Future write(Dict point, Obj? val, Int level, Obj who, Dict? opts := null)
  {
    Future.makeCompletable.complete(null)
  }

  override Grid array(Dict point)
  {
    Etc.emptyGrid
  }

}

