//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Aug 2009  Brian Frank  Creation
//    2 Jul 2025  Brian Frank  Move some exceptions from haystack
//

**
** Xeto base class for errors that include metadata
**
@Js @NoDoc const class XetoErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}

  ** Meta to include in error responses, error grids
  virtual Dict meta() { EmptyDict.val }
}

** UnknownNameErr is thrown when `Dict.trap` or `Grid.col` fails
** to resolve a name.
@Js @NoDoc const class UnknownNameErr : Err
{
  ** Construct with message and optional cause.
  new make(Str? msg, Err? cause := null) : super(msg, cause) {}
}

** Invalid lookup for spec
@Js @NoDoc const class UnknownSpecErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

** Lookup for unqualified name resolved in multiple matches
@Js @NoDoc const class AmbiguousSpecErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

** Invalid lookup for library module
@Js @NoDoc const class UnknownLibErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

** Library could not be loaded
@Js @NoDoc const class LibLoadErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

**
** DependErr indicates a one or missing dependencies or circular depends
**
@Js @NoDoc const class DependErr : XetoErr
{
  ** Construct with message and optional cause.
  new make(Str? msg, Err? cause := null, Dict? meta := null) : super(msg, cause)
  {
    this.meta = meta ?: EmptyDict.val
  }

  ** Metadata may contain 'unmet' grid of information of libs required
  override const Dict meta
}

