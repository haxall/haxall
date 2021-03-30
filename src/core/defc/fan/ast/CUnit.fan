//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Jul 2018  Brian Frank  Creation
//    9 Jan 2019  Brian Frank  Redesign
//

**
** Compilation unit (typically a pod)
**
class CUnit
{
  new make(Str name) { this.name = name }

  const Str name          // make
  File[] files:= [,]      // Scan

  CUnit[] includes()
  {
    if (includesList == null) throw Err("Resolve.resolveDepends step not run")
    return includesList
  }

  internal Void resolveDepends(CUnit[] includes)
  {
    this.includesList = includes
  }

  private CUnit[]? includesList
}

