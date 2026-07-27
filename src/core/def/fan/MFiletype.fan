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
** Filetype feature.  The filetype defs remain in the ontology as
** ordinary defs accessible via the generic feature API; the
** reader/writer registry lives in `haystack::Filetype`.
**
@Js
internal const class MFiletypeFeature : MFeature
{
  new make(BFeature b) : super(b) {}

  override Err createUnknownErr(Str name) { UnknownFiletypeErr(name) }
}

