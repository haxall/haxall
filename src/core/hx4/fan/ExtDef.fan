//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    8 Jul 2025  Brian Frank  Creation
//

using xeto

**
** Extension definition
**
const mixin ExtDef : NamespaceDef
{
  ** Fantom type for this extension
  abstract Type fantomType()
}

**************************************************************************
** NamespaceExts
**************************************************************************

**
** Namespace APIs for ExtDefs
**
const mixin NamespaceExts
{
  ** List the extension definitions
  abstract ExtDef[] list()

  ** Get an extension def by its qname
  abstract ExtDef? get(Str qname, Bool checked := true)
}

