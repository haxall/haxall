//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Jul 2025  Brian Frank  Garden City Beach
//

using concurrent
using xeto
using haystack

**
** FolioRec is used to manage watches on a per record basis.
**
@NoDoc
const mixin FolioRec
{
  ** Dict representation of rec
  abstract Dict dict()

  ** Ticks of last persistent or transient change for watching
  abstract Int ticks()

  ** Watch counter for this record
  abstract Int watchCount()

  ** Increment watch count, return new count
  abstract Int watchesIncrement()

  ** Decrement watch count, return new count
  abstract Int watchesDecrement()
}

