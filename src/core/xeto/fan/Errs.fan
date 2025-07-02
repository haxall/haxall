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
@Js const class UnknownNameErr : Err
{
  ** Construct with message and optional cause.
  new make(Str? msg, Err? cause := null) : super(msg, cause) {}
}

** Invalid lookup for DataSpec
@Js @NoDoc const class UnknownSpecErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

** Invalid lookup for library module
@Js @NoDoc const class UnknownLibErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

