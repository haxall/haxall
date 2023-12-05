//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Dec 2023  Brian Frank  Creation
//

using util
using xetoEnv

**
** AST namespace manages dependencies and imported names
**
internal class ANamespace
{
  new make(XetoCompiler compiler)
  {
    this.compiler = compiler
  }

//////////////////////////////////////////////////////////////////////////
// Global Slots
//////////////////////////////////////////////////////////////////////////

  ** Lookup global slot for given slot name
  CSpec? resolveGlobal(Str name, FileLoc loc)
  {
    if (!globals.containsKey(name))
      globals[name] = doResolveGlobal(name, loc)
    return globals[name]
  }

  private CSpec? doResolveGlobal(Str name, FileLoc loc)
  {
    // walk thru my lib and dependencies
    acc := CSpec[,]

    // check my own lib
    mine := compiler.lib.tops[name]
    if (mine != null && mine.isGlobal) acc.add(mine)

    // check my dependencies
    // TODO

    // no global slots by this name
    if (acc.isEmpty) return null

    // exactly one
    if (acc.size == 1) return acc.first

    // duplicate global slots with this name
    compiler.err("Duplicate global slots: $name", loc)
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  XetoCompiler compiler                 // make
  MLibDepend[]? depends                 // ProcessPragma
  [Str:XetoLib]? dependLibs             // Resolve
  private Str:CSpec? globals := [:]     // resolveGlobals
}