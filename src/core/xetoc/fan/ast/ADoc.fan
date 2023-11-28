//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Nov 2023  Brian Frank  Creation
//

using util
using xeto
using xetoEnv

**
** Document is top-level AST node - either a ALib or ADataDoc
**
internal abstract class ADoc : ANode
{
   ** Constructor
  new make(XetoCompiler c, FileLoc loc) : super(loc)
  {
    this.compiler = c
  }

  ** Compiler
  XetoCompiler compiler { private set }

  ** Instance data
  Str:AData instances := [:]

  ** Lookup top level instance data
  AData? instance(Str name) { instances.get(name) }

}

**************************************************************************
** ADataDoc
**************************************************************************

**
** Top-level node for a data file, it just wraps a root AData node
**
internal class ADataDoc : ADoc
{
   ** Constructor
  new make(XetoCompiler c, FileLoc loc) : super(c, loc) {}

  ** Root data object wrapped - set by Parser.parseDataFile
  AData? root

  override ANodeType nodeType() { ANodeType.dataDoc }

  override Obj asm() { root.asm }

  override Void walk(|ANode| f) { root.walk(f) } // don't walk myself

  override Void dump(OutStream out := Env.cur.out, Str indent := "") { root.dump(out, indent) }

}

