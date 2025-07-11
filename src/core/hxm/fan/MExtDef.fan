//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    8 Jul 2025  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio
using hx
using hx4

**
** ExtDef implementation
**
const class MExtDef : MDef, ExtDef
{
  new make(Spec spec) : super(spec)
  {
  }

  override Type fantomType()
  {
    spec.fantomType
  }
}

**************************************************************************
** MDefs
**************************************************************************

**
** NamespaceExts implementation
**
const class MExtDefs : NamespaceExts
{
  new make(Str:MExtDef map) { this.map = map }

  override ExtDef[] list()
  {
    map.vals
  }

  override ExtDef? get(Str qname, Bool checked := true)
  {
    x := map.get(qname)
    if (x != null) return x
    if (checked) throw UnknownExtErr(qname)
    return null
  }

  const Str:MExtDef map
}

**************************************************************************
** Dummy code
**************************************************************************

/*
const class FooExt : Ext
{
  override Void onStart()
  {
    log.info("starting!!")
  }

  override Void onStop()
  {
    log.info("stopping!!")
  }
}
*/

