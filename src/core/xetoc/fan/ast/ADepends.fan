//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Dec 2023  Brian Frank  Creation
//

using util
using xeto
using xetom

**
** AST dependencies and imported namespace handling
**
internal class ADepends
{
  new make(XetoCompiler compiler)
  {
    this.compiler = compiler
  }

  XetoCompiler compiler                 // make
  MLibDepend[]? list                    // ProcessPragma
  [Str:XetoLib]? libs                   // Resolve
  private Str:CSpec? globals := [:]     // resolveGlobals
}

