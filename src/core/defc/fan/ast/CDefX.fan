//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jan 2019  Brian Frank  Creation
//

using xeto
using haystack

**
** CDef extension
**
class CDefX
{
  internal new make(CLoc loc, CLib lib, CSymbol symbol, Dict declared)
  {
    this.loc      = loc
    this.lib      = lib
    this.symbol   = symbol
    this.declared = declared
  }

  ** File location of source definition
  const CLoc loc

  ** Parent lib
  CLib lib

  ** Symbol key
  const CSymbol symbol

  ** Meta from defx
  const Dict declared

  ** Normalized meta computed in Resolve, Normalize
  [Str:CPair]? meta
}

