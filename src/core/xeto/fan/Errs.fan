//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Aug 2009  Brian Frank  Creation
//    2 Jul 2025  Brian Frank  Move some exceptions from haystack
//

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

**
** DependErr indicates a missing dependency
**
@Js @NoDoc const class DependErr : Err
{
  ** Construct with message and optional cause.
  new make(Str? msg, Err? cause := null, Str? name := null) : super(msg, cause) { this.name = name }
  const Str? name
}

