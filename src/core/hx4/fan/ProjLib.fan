//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    9 Jul 2025  Brian Frank  Creation
//

using xeto

**
** Project library status
**
const mixin ProjLib : NamespaceDef
{
  ** Dotted library name
  abstract Str name()

  ** Latest version which is used by Haxall
  abstract Version version()

  ** Enable state of the lib
  abstract ProjLibState state()

  ** Summary documentation
  @NoDoc abstract Str doc()
}

**************************************************************************
** ProjLibState
**************************************************************************

**
** ProjLibState is install status of a ProjLib
**
enum class ProjLibState
{
  boot,
  sys,
  enabled,
  disabled
}

