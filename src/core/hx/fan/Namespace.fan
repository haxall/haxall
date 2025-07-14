//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    8 Jul 2025  Brian Frank  Creation
//

using xeto

**
** Namespace adds Haxall specific APIs to the core Xeto namespace
**
const mixin Namespace : LibNamespace
{
}

**************************************************************************
** NamespaceDef
**************************************************************************

**
** NamespaceDef is base type for a namespace based definitions
**
const mixin NamespaceDef
{
  ** Spec for this definition
  abstract Spec spec()

  ** Spec qname
  abstract Str qname()

  ** Return qname
  abstract override Str toStr()
}

