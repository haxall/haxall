//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Feb 2016  Brian Frank  Creation
//   10 Nov 2020  Brian Frank  Pull from folio3 for reuse
//

using xeto
using haystack

**
** FolioBrioReader to normalize refs for proper disVal
**
@NoDoc
class FolioBrioReader : BrioReader
{
  new make(Folio folio, InStream in) : super(in)
  {
    this.folio = folio
  }

  const Folio folio

  override Ref internRef(Str id, Str? dis)
  {
    folio.internRef(Ref(id, null))
  }
}

