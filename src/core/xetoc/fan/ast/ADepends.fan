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
@Js
internal class ADepends
{
  new make(MXetoCompiler compiler)
  {
    this.compiler = compiler
  }

  MXetoCompiler compiler                // make
  MLibDepend[]? list                    // ProcessPragma
  [Str:XetoLib]? libs                   // Resolve
  private Str:CSpec? globals := [:]     // resolveGlobals
}

