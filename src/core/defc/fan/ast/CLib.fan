//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Dec 2018  Brian Frank  Creation
//

using haystack
using def

**
** CLib
**
class CLib : CDef
{
  internal new make(CLoc loc, CSymbol symbol, Dict declared, LibInput input, CSymbol[] depends)
    : super(loc, this, symbol, declared)
  {
    this.input = input
    this.depends = depends
    this.defs.add(symbol, this)
  }

  const LibInput input          // Scan -> make
  CSymbol[] depends             // Scan -> make
  CSymbol:CDef defs := [:]      // Parse
  CDefX[] defXs := [,]          // Parse
  internal ResolveScope? scope  // Resolve

  ** Return simple name
  override Str dis() { name }



}