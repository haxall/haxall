//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jan 2019  Brian Frank  Creation
//

using haystack


**
** CDefRef is a reference to a def which may be a
** parameterized generic used in a compose
**
class CDefRef
{
  ** Construct with resolved def
  internal new makeResolved(CLoc loc, CSymbol symbol, CDef def)
  {
    this.loc      = loc
    this.symbol   = symbol
    this.resolved = def
  }

  ** File location of usage site
  const CLoc loc

  ** Symbol key
  const CSymbol symbol

  ** Resolved definition
  CDef deref() { resolved ?: throw Err("Not resolved yet: $toStr") }

  ** Return symbol
  override Str toStr() { symbol.toStr }

  private CDef? resolved
}