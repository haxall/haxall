//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Aug 2009  Brian Frank  Creation
//

**
** UnknownNameErr is thrown when `Dict.trap` or `Grid.col` fails
** to resolve a name.
**
@Js const class UnknownNameErr : Err
{
  ** Construct with message and optional cause.
  new make(Str? msg, Err? cause := null) : super(msg, cause) {}
}

**
** Invalid lookup for definition
**
@Js @NoDoc const class UnknownDefErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

** Invalid lookup for DataSpec
@Js @NoDoc const class UnknownSpecErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

** Invalid lookup for feature definition
@Js @NoDoc const class UnknownFeatureErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

** Invalid lookup for file type
@Js @NoDoc const class UnknownFiletypeErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

**
** Invalid lookup for library module
**
@Js @NoDoc const class UnknownLibErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

**
** UnknownKindErr when a Kind cannot be resolved or parsed
**
@Js const class UnknownRecErr : Err
{
  ** Construct with message and optional cause.
  new make(Str? msg, Err? cause := null) : super(msg, cause) {}
}

**
** Invalid lookup for kind
**
@Js @NoDoc const class UnknownKindErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

**
** Invalid lookup for tag definition
**
@Js @NoDoc const class UnknownTagErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

**
** Invalid lookup for function
**
@Js @NoDoc const class UnknownFuncErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

** Invalid lookup for comp
@Js @NoDoc const class UnknownCompErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

** Invalid lookup for cell
@Js @NoDoc const class UnknownCellErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

**
** Fantom object does not map to haystack kind
**
@Js @NoDoc const class NotHaystackErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

**
** UnitErr indicates an operation between two incompatible units
**
@Js const class UnitErr : Err
{
  ** Construct with message and optional cause.
  new make(Str? msg, Err? cause := null) : super(msg, cause) {}
}

**
** DependErr indicates a missing dependency
**
@Js const class DependErr : Err
{
  ** Construct with message and optional cause.
  new make(Str? msg, Err? cause := null) : super(msg, cause) {}
}

**
** CallErr is raised when a server returns an error grid from
** a client call to a REST operation.
**
@Js const class CallErr : Err
{
  @NoDoc new make(Grid errGrid) : super(errGrid.meta.dis)
  {
    this.meta = errGrid.meta
    this.remoteTrace = errGrid.meta["errTrace"] as Str
  }

  @NoDoc new makeMeta(Dict meta) : super.make(meta.dis)
  {
    this.meta = meta
    this.remoteTrace = meta["errTrace"] as Str
  }

  ** Grid.meta from the error grid response
  const Dict meta

  ** Remote stack trace if available
  const Str? remoteTrace
}

**
** DisabledErr indicates access of a disabled resource.
**
const class DisabledErr : Err
{
  new make(Str? msg, Err? cause := null) : super(msg, cause) {}
}

**
** FaultErr indicates a software or configuration problem
**
@Js const class FaultErr : Err
{
  ** Construct with message and optional cause
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

**
** DownErr indicates a communications or networking problem
**
@Js const class DownErr : Err
{
  ** Construct with message and optional cause
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

**
** CoerceErr indicates an invalid argument type to a type coercion
**
@Js @NoDoc const class CoerceErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

**
** PermissionErr is thrown when a function is called the
** user doesn't have permission to access.
**
@NoDoc const class PermissionErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

**
** ValidateErr when a validation fails.  The msg should
** be localized for display to users.
**
@Js const class ValidateErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

**
** Invalid name error
**
@NoDoc @Js
const class InvalidNameErr : Err
{
  new make(Str msg := "", Err? cause := null) : super(msg, cause) {}
}

**
** Invalid change error
**
@NoDoc @Js
const class InvalidChangeErr : Err
{
  new make(Str msg := "", Err? cause := null) : super(msg, cause) {}
}

**
** Using a name that already exists
**
@NoDoc @Js
const class DuplicateNameErr : Err
{
  new make(Str msg := "", Err? cause := null) : super(msg, cause) {}
}

**
** Raised when adding a component that already has a parent
**
@NoDoc @Js
const class AlreadyParentedErr : Err
{
  new make(Str msg := "", Err? cause := null) : super(msg, cause) {}
}

