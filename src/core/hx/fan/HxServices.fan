//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Aug 2021  Brian Frank  Creation
//

using haystack

**
** Registry for service APIs by type.  Service APIs implement
** the `HxService` mixin and are implemented by libraries enabled
** in the runtime.
**
const mixin HxServiceRegistry
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

  ** Lookup point write service or provide no-op implementation
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
  abstract Void write(Dict point, Obj? val, Int level, Obj who, Dict? opts := null)
}

@NoDoc
const class NilPointWriteService : HxPointWriteService
{
  override Void write(Dict point, Obj? val, Int level, Obj who, Dict? opts := null) {}
}

