//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Aug 2021  Brian Frank  Creation
//

using concurrent
using crypto
using haystack
using web
using obs

**
** Registry for service APIs by type.  Service APIs implement
** the `HxService` mixin and are published by libraries enabled
** in the runtime using `HxLib.services`.
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

  ** Cryptographic certificate and key pair management APIs
  abstract HxCryptoService crypto()

  ** HTTP APIs
  abstract HxHttpService http()

  ** User management APIs
  abstract HxUserService user()

  ** File resolution APIs
  @NoDoc abstract HxFileService file()

  ** I/O APIs
  @NoDoc abstract HxIOService io()

  ** Point historization service or no-op if not supported
  @NoDoc abstract HxHisService his()

  ** Point write service or no-op if point library is not enabled
  @NoDoc abstract HxPointWriteService pointWrite()

  ** Connector registry service or no-op if connector framework not installed
  @NoDoc abstract HxConnRegistryService conns()
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
** HxCryptoService
**************************************************************************

**
** Cryptographic certificate and key pair management
**
const mixin HxCryptoService : HxService
{
  ** The keystore to store all trusted keys and certificates
  abstract KeyStore keystore()

  ** Get a keystore containing only the key aliased as "https".
  abstract KeyStore? httpsKey(Bool checked := true)

  ** The host specific public/private key pair
  abstract KeyPair hostKeyPair()

  ** The host specific private key and certificate
  abstract PrivKeyEntry hostKey()
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
  @NoDoc abstract HxUser makeSyntheticUser(Str username, Obj? tags := null)
}

**************************************************************************
** HxIOService
**************************************************************************

**
** File APIs
**
@NoDoc
const mixin HxFileService : HxService
{
  **
  ** Resolve a virtual file system URI.  If the uri does not resolve
  ** to a file, then return a File instance where exists returns false.
  ** All runtimes must support a sandboxed directory accessed via the
  ** relative path "io/".  The current context is used for permission
  ** checking.
  **
  abstract File resolve(Uri uri)
}

**************************************************************************
** HxIOService
**************************************************************************

**
** I/O APIs
**
@NoDoc
const mixin HxIOService : HxService
{
  **
  ** Read from an I/O handle.  The callback is invoked with the input stream
  ** and the callback's result is returned.  The input stream is guaranteed
  ** to be closed.  Raise an exception if the handle cannot be accessed
  ** as an input stream.
  **
  abstract Obj? read(Obj? handle, |InStream->Obj?| f)

  **
  ** Write to an I/O handle.  The callback is invoked with the output stream.
  ** The output stream is guaranteed to be closed.  Raise an exception if the
  ** handle cannot be accessed as an output stream.
  **
  abstract Obj? write(Obj? handle, |OutStream| f)
}

**************************************************************************
** HxHisService
**************************************************************************

**
** Point historization APIs
**
const mixin HxHisService : HxService
{
  **
  ** Read the history items stored for given point.  If span is
  ** null then all items are read, otherwise the span's inclusive
  ** start/exclusive end are used.  Leading and trailing items
  ** may be included.
  **
  abstract Void read(Dict pt, Span? span, Dict? opts, |HisItem| f)

  **
  ** Write history items to the given point.  The items must have
  ** have a matching timezone, value kind, and unit (or be unitless).
  ** Before writing the timestamps are normalized to 1sec or 1ms precision;
  ** items with duplicate normalized timestamps are removed.  If there is
  ** existing history data with a given timestamp then the new data overwrites
  ** the current value, or if the new item's value is `haystack::Remove.val`
  ** then that item is removed.
  **
  abstract Future write(Dict pt, HisItem[] items, Dict? opts := null)
}

@NoDoc const class NilHisService : HxHisService
{
  override Void read(Dict pt, Span? span, Dict? opts, |HisItem| f)
  {
  }

  override Future write(Dict pt, HisItem[] items, Dict? opts := null)
  {
    Future.makeCompletable.complete(null)
  }
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

**************************************************************************
** HxConnRegistryService
**************************************************************************

**
** HxConnRegistryService manages the list of enabled connectors.
**
@NoDoc
const mixin HxConnRegistryService : HxService
{
  ** List of installed connectors
  abstract HxConnService[] list()

  ** List of connector ref tags for enabled connectors
  abstract Str[] connRefTags()

  ** Lookup enabled connector by its library name
  abstract HxConnService? byName(Str name, Bool checked := true)

  ** Lookup connector for given conn record
  abstract HxConnService? byConn(Dict conn, Bool checked := true)

  ** Lookup connector for given point record
  abstract HxConnService? byPoint(Dict point, Bool checked := true)

  ** Lookup connector for set of points which must all have same connector ref
  abstract HxConnService? byPoints(Dict[] points, Bool checked := true)

  ** Find primary connector ref for given point
  abstract Ref? connRef(Dict point, Bool checked := true)
}

@NoDoc
const class NilConnRegistryService : HxConnRegistryService
{
  override HxConnService[] list() { HxConnService#.emptyList }
  override Str[] connRefTags() { Str#.emptyList }
  override HxConnService? byName(Str name, Bool checked := true) { get(checked) }
  override HxConnService? byConn(Dict conn, Bool checked := true) { get(checked) }
  override HxConnService? byPoint(Dict point, Bool checked := true) { get(checked) }
  override HxConnService? byPoints(Dict[] points, Bool checked := true) { get(checked) }
  override Ref? connRef(Dict point, Bool checked := true) { get(checked) }

  private Obj? get(Bool checked)
  {
    if (checked) throw Err("no connectors installed")
    return null
  }
}

**************************************************************************
** HxConnService
**************************************************************************

**
** HxConnService models a protocol specific connector library
**
@NoDoc
const mixin HxConnService : HxService
{
  ** Connector library name such as "bacnet"
  abstract Str name()

  ** Connector marker tag such as "bacnetConn"
  abstract Str connTag()

  ** Connector reference tag such as "bacnetConnRef"
  abstract Str connRefTag()

  ** Point marker tag such as "bacnetPoint"
  abstract Str pointTag()

  ** Does connector support current value subscription
  abstract Bool isCurSupported()

  ** Does connector support history synchronization
  abstract Bool isHisSupported()

  ** Does connector support writable points
  abstract Bool isWriteSupported()

  ** Point current address tag name such as "bacnetCur"
  abstract Str? curTag()

  ** Point history sync address tag name such as "bacnetHis"
  abstract Str? hisTag()

  ** Point write address tag name such as "bacnetWrite"
  abstract Str? writeTag()

  ** Does connector support learn
  abstract Bool isLearnSupported()

  ** Return if given record matches this connector type
  abstract Bool isConn(Dict rec)

  ** Return if given record is a point under this connector type
  abstract Bool isPoint(Dict rec)

  ** Return debug details for connector
  abstract Str connDetails(Dict rec)

  ** Return debug details for point
  abstract Str pointDetails(Dict rec)
}


