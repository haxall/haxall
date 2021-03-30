//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jan 2019  Brian Frank  Creation
//

using concurrent
using haystack

**
** Filetype implementation
**
@Js
internal const class MFiletype : MDef, Filetype
{
  new make(BDef b) : super(b)
  {
    this.mimeType = MimeType.fromStr(meta->mime)
  }

  override const MimeType mimeType
}

**************************************************************************
** MFiletypeFeature
**************************************************************************

@Js
internal const class MFiletypeFeature : MFeature
{
  new make(BFeature b) : super(b) {}

  override Bool isFiletype() { true }

  override Type defType() { Filetype# }

  override MDef createDef(BDef b) { MFiletype(b) }

  override Err createUnknownErr(Str name) { UnknownFiletypeErr(name) }
}



