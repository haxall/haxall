//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Dec 2022  Brian Frank  Creation
//

using util
using concurrent
using xeto
using haystack::UnknownLibErr

**
** MRegistry manages the cache and loading of the environments libs
**
@Js
abstract const class MRegistry : LibRegistry
{

  ** Load the given library
  abstract Lib? load(Str qname, Bool checked := true)

}

