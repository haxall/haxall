//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Jul 2025  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using xetoc
using hx

**
** ProjSpecs implementation
**
const class MProjSpecs : ProjSpecs
{

  new make(MProjLibs libs)
  {
    this.libs = libs
  }

  const MProjLibs libs

  override Spec add(Str name, Str body)
  {
    throw Err("TODO")
  }

  override Spec update(Str name, Str body)
  {
    throw Err("TODO")
  }

  override Void remove(Str name)
  {
    throw Err("TODO")
  }
}

