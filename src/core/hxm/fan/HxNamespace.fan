//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    8 Jul 2025  Brian Frank  Creation
//

using xeto
using haystack
using folio
using hx
using xetom
using xetoc

**
** Namespace implementation
**
const class HxNamespace : LocalNamespace, Namespace
{
  internal new make(LocalNamespaceInit init) : super(init) {}
}

